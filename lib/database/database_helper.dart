import 'dart:io';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/cliente.dart';
import '../models/transacao.dart';
import '../models/dados_periodo.dart';

final _fmt = DateFormat('yyyy-MM-dd');

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Caminho do arquivo físico do banco (usado também pelo backup).
  Future<String> get caminhoArquivo async {
    final appDir = await getApplicationSupportDirectory();
    return join(appDir.path, 'fiado_mercadinho_v2.db');
  }

  Future<Database> _initDb() async {
    final path = await caminhoArquivo;
    return openDatabase(
      path,
      version: 3,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// As foreign keys do SQLite ficam DESLIGADAS por padrão a cada conexão.
  /// Sem isto o `ON DELETE CASCADE` não roda e excluir um cliente deixaria
  /// transações órfãs somando nos relatórios.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_conta TEXT NOT NULL UNIQUE,
        nome TEXT NOT NULL,
        telefone TEXT,
        observacao TEXT,
        criado_em TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        valor REAL NOT NULL,
        descricao TEXT,
        data TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
      )
    ''');
    await _criarIndices(db);
  }

  /// Índices nas colunas usadas em todo filtro/agrupamento de transações.
  Future<void> _criarIndices(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transacoes_cliente ON transacoes(cliente_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transacoes_data ON transacoes(data)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
            'ALTER TABLE clientes ADD COLUMN numero_conta TEXT NOT NULL DEFAULT "0000"');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      // Bancos migrados da v1 ficaram com todos os clientes em '0000', o que
      // viola a unicidade da conta. Reatribui um número sequencial por cliente.
      await _backfillNumeroConta(db);
      await _criarIndices(db);
    }
  }

  /// Dá a cada cliente sem conta única um número sequencial (0001, 0002...),
  /// preservando quem já tem um número válido distinto.
  Future<void> _backfillNumeroConta(Database db) async {
    final duplicados = await db.rawQuery('''
      SELECT id FROM clientes
      WHERE numero_conta IS NULL OR numero_conta = '0000'
      ORDER BY id ASC
    ''');
    if (duplicados.isEmpty) return;

    final usados = await db.rawQuery('''
      SELECT COALESCE(MAX(CAST(numero_conta AS INTEGER)), 0) AS m
      FROM clientes
      WHERE numero_conta <> '0000'
    ''');
    var proximo = ((usados.first['m'] as int?) ?? 0) + 1;

    final batch = db.batch();
    for (final row in duplicados) {
      batch.update(
        'clientes',
        {'numero_conta': proximo.toString().padLeft(4, '0')},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      proximo++;
    }
    await batch.commit(noResult: true);
  }

  // --- Backup ---

  /// Copia o arquivo do banco para [destino] (um caminho completo de arquivo).
  /// Garante que tudo esteja gravado em disco antes de copiar.
  Future<void> exportarBackup(String destino) async {
    final database = await db;
    // Força o checkpoint do WAL para que o arquivo .db contenha tudo.
    await database.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final origem = await caminhoArquivo;
    await File(origem).copy(destino);
  }

  // --- Número de conta ---

  Future<String> proximoNumeroConta() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COALESCE(MAX(CAST(numero_conta AS INTEGER)), 0) + 1 AS proximo FROM clientes');
    final proximo = (result.first['proximo'] as int?) ?? 1;
    return proximo.toString().padLeft(4, '0');
  }

  // --- Clientes ---

  Future<int> inserirCliente(Cliente c) async {
    final database = await db;
    final map = c.toMap()..remove('id');
    return database.insert('clientes', map);
  }

  Future<int> atualizarCliente(Cliente c) async {
    final database = await db;
    return database.update(
      'clientes',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> excluirCliente(int id) async {
    final database = await db;
    return database.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Cliente>> listarClientes() async {
    final database = await db;
    final rows = await database.query('clientes', orderBy: 'nome ASC');
    return rows.map(Cliente.fromMap).toList();
  }

  Future<List<Cliente>> buscarClientes(String query) async {
    final database = await db;
    final q = '%${query.trim()}%';
    final rows = await database.query(
      'clientes',
      where: 'nome LIKE ? OR numero_conta LIKE ?',
      whereArgs: [q, q],
      orderBy: 'nome ASC',
    );
    return rows.map(Cliente.fromMap).toList();
  }

  // --- Transações ---

  Future<int> inserirTransacao(Transacao t) async {
    final database = await db;
    return database.insert('transacoes', t.toMap()..remove('id'));
  }

  Future<int> excluirTransacao(int id) async {
    final database = await db;
    return database.delete('transacoes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Transacao>> listarTransacoesPorCliente(int clienteId) async {
    final database = await db;
    final rows = await database.query(
      'transacoes',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'data DESC',
    );
    return rows.map(Transacao.fromMap).toList();
  }

  Future<double> saldoCliente(int clienteId) async {
    final database = await db;
    final result = await database.rawQuery(
      '''SELECT
          COALESCE(SUM(CASE WHEN tipo='fiado' THEN valor ELSE 0 END),0) -
          COALESCE(SUM(CASE WHEN tipo='pagamento' THEN valor ELSE 0 END),0) AS saldo
         FROM transacoes WHERE cliente_id = ?''',
      [clienteId],
    );
    return (result.first['saldo'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<int, double>> saldoTodosClientes() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT cliente_id,
        COALESCE(SUM(CASE WHEN tipo='fiado' THEN valor ELSE 0 END),0) -
        COALESCE(SUM(CASE WHEN tipo='pagamento' THEN valor ELSE 0 END),0) AS saldo
      FROM transacoes GROUP BY cliente_id
    ''');
    return {
      for (final r in rows)
        (r['cliente_id'] as int): (r['saldo'] as num).toDouble()
    };
  }

  Future<List<TransacaoResumo>> ultimasTransacoes(int limit) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT t.id, t.cliente_id, t.tipo, t.valor, t.descricao, t.data,
             c.nome AS cliente_nome, c.numero_conta
      FROM transacoes t
      JOIN clientes c ON t.cliente_id = c.id
      ORDER BY t.data DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(TransacaoResumo.fromMap).toList();
  }

  // --- Totais rápidos ---

  Future<double> _totalFiadoNoIntervalo(String de, String ate) async {
    final database = await db;
    final r = await database.rawQuery('''
      SELECT COALESCE(SUM(valor), 0) as total
      FROM transacoes
      WHERE tipo = 'fiado' AND date(data) >= ? AND date(data) <= ?
    ''', [de, ate]);
    return (r.first['total'] as num).toDouble();
  }

  Future<double> totalFiadoHoje() async {
    final hoje = _fmt.format(DateTime.now());
    return _totalFiadoNoIntervalo(hoje, hoje);
  }

  Future<double> totalFiadoSemana() async {
    final now = DateTime.now();
    final inicioSemana =
        now.subtract(Duration(days: now.weekday - 1));
    return _totalFiadoNoIntervalo(
      _fmt.format(inicioSemana),
      _fmt.format(now),
    );
  }

  Future<double> totalFiadoMes() async {
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    return _totalFiadoNoIntervalo(
      _fmt.format(inicioMes),
      _fmt.format(now),
    );
  }

  // --- Relatórios ---

  Future<List<DadosPeriodo>> dadosPorDia() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT date(data) as periodo,
        COALESCE(SUM(CASE WHEN tipo='fiado' THEN valor ELSE 0 END),0) as tf,
        COALESCE(SUM(CASE WHEN tipo='pagamento' THEN valor ELSE 0 END),0) as tp
      FROM transacoes
      WHERE date(data) >= date('now','-6 days')
      GROUP BY date(data) ORDER BY periodo ASC
    ''');
    final map = {for (final r in rows) r['periodo'] as String: r};

    final now = DateTime.now();
    final diasSemana = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = _fmt.format(day);
      final r = map[key];
      return DadosPeriodo(
        label: diasSemana[day.weekday % 7],
        totalFiados: r != null ? (r['tf'] as num).toDouble() : 0,
        totalPagamentos: r != null ? (r['tp'] as num).toDouble() : 0,
      );
    });
  }

  Future<List<DadosPeriodo>> dadosPorSemana() async {
    final database = await db;
    final now = DateTime.now();
    final inicioSemanaAtual =
        now.subtract(Duration(days: now.weekday - 1));

    final result = <DadosPeriodo>[];
    for (int i = 3; i >= 0; i--) {
      final inicio = DateTime(
        inicioSemanaAtual.year,
        inicioSemanaAtual.month,
        inicioSemanaAtual.day,
      ).subtract(Duration(days: i * 7));
      final fim = inicio.add(const Duration(days: 6));

      final rows = await database.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN tipo='fiado' THEN valor ELSE 0 END),0) as tf,
          COALESCE(SUM(CASE WHEN tipo='pagamento' THEN valor ELSE 0 END),0) as tp
        FROM transacoes
        WHERE date(data) >= ? AND date(data) <= ?
      ''', [_fmt.format(inicio), _fmt.format(fim)]);

      result.add(DadosPeriodo(
        label: DateFormat('dd/MM').format(inicio),
        totalFiados: (rows.first['tf'] as num).toDouble(),
        totalPagamentos: (rows.first['tp'] as num).toDouble(),
      ));
    }
    return result;
  }

  Future<List<DadosPeriodo>> dadosPorMes() async {
    final database = await db;
    final meses = ['', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
                   'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    final now = DateTime.now();
    final result = <DadosPeriodo>[];

    for (int i = 5; i >= 0; i--) {
      final mes = DateTime(now.year, now.month - i, 1);
      final fimMes = DateTime(mes.year, mes.month + 1, 0);

      final rows = await database.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN tipo='fiado' THEN valor ELSE 0 END),0) as tf,
          COALESCE(SUM(CASE WHEN tipo='pagamento' THEN valor ELSE 0 END),0) as tp
        FROM transacoes
        WHERE date(data) >= ? AND date(data) <= ?
      ''', [_fmt.format(mes), _fmt.format(fimMes)]);

      result.add(DadosPeriodo(
        label: meses[mes.month],
        totalFiados: (rows.first['tf'] as num).toDouble(),
        totalPagamentos: (rows.first['tp'] as num).toDouble(),
      ));
    }
    return result;
  }

  // --- Clientes recentes (por última movimentação) ---

  Future<List<Cliente>> clientesRecentes(int limit) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT c.id, c.numero_conta, c.nome, c.telefone, c.observacao, c.criado_em
      FROM clientes c
      LEFT JOIN (
        SELECT cliente_id, MAX(data) AS ultima_data
        FROM transacoes
        GROUP BY cliente_id
      ) t ON t.cliente_id = c.id
      ORDER BY
        CASE WHEN t.ultima_data IS NULL THEN 1 ELSE 0 END,
        t.ultima_data DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Cliente.fromMap).toList();
  }

  // --- Top devedores ---

  Future<List<Map<String, dynamic>>> topDevedores(int limit) async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT c.id, c.nome, c.numero_conta,
        COALESCE(SUM(CASE WHEN t.tipo='fiado' THEN t.valor ELSE 0 END),0) -
        COALESCE(SUM(CASE WHEN t.tipo='pagamento' THEN t.valor ELSE 0 END),0) AS saldo
      FROM clientes c
      LEFT JOIN transacoes t ON t.cliente_id = c.id
      GROUP BY c.id
      HAVING saldo > 0
      ORDER BY saldo DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((r) => {
              'id': r['id'],
              'nome': r['nome'],
              'numero_conta': r['numero_conta'],
              'saldo': (r['saldo'] as num).toDouble(),
            })
        .toList();
  }
}
