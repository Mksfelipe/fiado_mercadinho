import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/cliente.dart';
import '../models/transacao.dart';
import '../models/dados_periodo.dart';

enum ProviderStatus { initial, loading, loaded, error }

class FiadoProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Cliente> _clientes = [];
  Map<int, double> _saldos = {};
  double _totalHoje = 0;
  double _totalSemana = 0;
  double _totalMes = 0;
  ProviderStatus _status = ProviderStatus.initial;

  List<Cliente> get clientes => _clientes;
  Map<int, double> get saldos => _saldos;
  double get totalHoje => _totalHoje;
  double get totalSemana => _totalSemana;
  double get totalMes => _totalMes;
  ProviderStatus get status => _status;
  bool get isLoading => _status == ProviderStatus.loading;
  bool get hasError => _status == ProviderStatus.error;

  double get totalFiados =>
      _saldos.values.where((s) => s > 0).fold(0, (sum, s) => sum + s);

  int get clientesComFiado => _saldos.values.where((s) => s > 0).length;

  double saldoDoCliente(int clienteId) => _saldos[clienteId] ?? 0.0;

  List<Cliente> get topDevedoresClientes {
    final comDivida =
        _clientes.where((c) => saldoDoCliente(c.id!) > 0).toList();
    comDivida.sort((a, b) =>
        saldoDoCliente(b.id!).compareTo(saldoDoCliente(a.id!)));
    return comDivida.take(5).toList();
  }

  Future<void> carregar() async {
    _status = ProviderStatus.loading;
    notifyListeners();
    try {
      _clientes = await _db.listarClientes();
      _saldos = await _db.saldoTodosClientes();
      _totalHoje = await _db.totalFiadoHoje();
      _totalSemana = await _db.totalFiadoSemana();
      _totalMes = await _db.totalFiadoMes();
      _status = ProviderStatus.loaded;
    } catch (e, s) {
      debugPrint('FiadoProvider.carregar falhou: $e\n$s');
      _status = ProviderStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<List<Cliente>> buscar(String query) => _db.buscarClientes(query);

  Future<List<Cliente>> clientesRecentes({int limit = 20}) =>
      _db.clientesRecentes(limit);

  Future<String> proximoNumeroConta() => _db.proximoNumeroConta();

  Future<bool> adicionarCliente(Cliente cliente) async {
    try {
      final id = await _db.inserirCliente(cliente);
      _clientes.add(cliente.copyWith(id: id));
      _clientes.sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return true;
    } catch (e, s) {
      debugPrint('FiadoProvider.adicionarCliente falhou: $e\n$s');
      return false;
    }
  }

  Future<bool> atualizarCliente(Cliente cliente) async {
    try {
      await _db.atualizarCliente(cliente);
      final idx = _clientes.indexWhere((c) => c.id == cliente.id);
      if (idx != -1) _clientes[idx] = cliente;
      _clientes.sort((a, b) => a.nome.compareTo(b.nome));
      notifyListeners();
      return true;
    } catch (e, s) {
      debugPrint('FiadoProvider.atualizarCliente falhou: $e\n$s');
      return false;
    }
  }

  Future<void> excluirCliente(int clienteId) async {
    await _db.excluirCliente(clienteId);
    _clientes.removeWhere((c) => c.id == clienteId);
    _saldos.remove(clienteId);
    notifyListeners();
  }

  Future<List<Transacao>> transacoesDoCliente(int clienteId) =>
      _db.listarTransacoesPorCliente(clienteId);

  Future<bool> adicionarTransacao(Transacao transacao) async {
    try {
      await _db.inserirTransacao(transacao);
      _saldos[transacao.clienteId] =
          await _db.saldoCliente(transacao.clienteId);
      if (transacao.tipo == TipoTransacao.fiado) {
        _totalHoje = await _db.totalFiadoHoje();
        _totalSemana = await _db.totalFiadoSemana();
        _totalMes = await _db.totalFiadoMes();
      }
      notifyListeners();
      return true;
    } catch (e, s) {
      debugPrint('FiadoProvider.adicionarTransacao falhou: $e\n$s');
      return false;
    }
  }

  Future<void> excluirTransacao(int transacaoId, int clienteId) async {
    await _db.excluirTransacao(transacaoId);
    _saldos[clienteId] = await _db.saldoCliente(clienteId);
    _totalHoje = await _db.totalFiadoHoje();
    _totalSemana = await _db.totalFiadoSemana();
    _totalMes = await _db.totalFiadoMes();
    notifyListeners();
  }

  Future<List<TransacaoResumo>> ultimasTransacoes(int limit) =>
      _db.ultimasTransacoes(limit);

  Future<List<TransacaoResumo>> buscarTransacoes({
    DateTime? de,
    DateTime? ate,
    int? clienteId,
  }) =>
      _db.buscarTransacoes(de: de, ate: ate, clienteId: clienteId);

  Future<List<Map<String, dynamic>>> topDevedoresDetalhado(int limit) =>
      _db.topDevedores(limit);

  Future<List<DadosPeriodo>> dadosPorDia() => _db.dadosPorDia();
  Future<List<DadosPeriodo>> dadosPorSemana() => _db.dadosPorSemana();
  Future<List<DadosPeriodo>> dadosPorMes() => _db.dadosPorMes();
}
