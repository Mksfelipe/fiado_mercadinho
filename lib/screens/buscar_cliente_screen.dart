import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_navigation.dart';
import '../models/cliente.dart';
import '../providers/fiado_provider.dart';
import '../utils/formatters.dart';
import 'cliente_detalhe_screen.dart';

class BuscarClienteScreen extends StatefulWidget {
  const BuscarClienteScreen({super.key});

  @override
  State<BuscarClienteScreen> createState() => _BuscarClienteScreenState();
}

class _BuscarClienteScreenState extends State<BuscarClienteScreen> {
  final _ctrl = TextEditingController();
  List<Cliente>? _resultados;
  List<Cliente> _recentes = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _carregarRecentes();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _carregarRecentes() async {
    final lista =
        await context.read<FiadoProvider>().clientesRecentes(limit: 20);
    if (mounted) setState(() => _recentes = lista);
  }

  Future<void> _buscar(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _resultados = null;
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    final res = await context.read<FiadoProvider>().buscar(query);
    if (mounted) {
      setState(() {
        _resultados = res;
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.darkGreen,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: TextField(
            controller: _ctrl,
            focusNode: buscaClienteFocus,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou nº da conta...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _ctrl.clear();
                        _buscar('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _buscar,
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_buscando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Pesquisa ativa sem resultados
    if (_resultados != null && _resultados!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Nenhum cliente encontrado',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    final provider = context.watch<FiadoProvider>();
    final lista = _resultados ?? _recentes;
    final isSearch = _resultados != null;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Nenhum cliente cadastrado',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: lista.length + 1,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  isSearch ? Icons.search : Icons.history,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  isSearch
                      ? '${lista.length} resultado(s)'
                      : 'Clientes recentes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final c = lista[i - 1];
        final saldo = provider.saldoDoCliente(c.id!);
        final temFiado = saldo > 0;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  temFiado ? AppColors.red : AppColors.greenLight,
              child: Text(
                c.nome[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(c.nome,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conta #${c.numeroConta}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.green)),
                if (c.telefone != null)
                  Text(c.telefone!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
              ],
            ),
            isThreeLine: c.telefone != null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatarMoeda(saldo),
                  style: TextStyle(
                    color: temFiado ? AppColors.red : AppColors.greenLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  temFiado ? 'em aberto' : 'quitado',
                  style: TextStyle(
                    fontSize: 11,
                    color: temFiado ? Colors.red[300] : Colors.green[400],
                  ),
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ClienteDetalheScreen(cliente: c)),
              );
              if (!mounted) return;
              context.read<FiadoProvider>().carregar();
              _carregarRecentes();
              if (_ctrl.text.isNotEmpty) _buscar(_ctrl.text);
            },
          ),
        );
      },
    );
  }
}
