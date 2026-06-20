import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Estes testes exercitam o contrato SQL central do app — cálculo de saldo
/// (fiado menos pagamento) e o `ON DELETE CASCADE` — num banco em memória,
/// com o mesmo esquema usado em produção.

Future<Database> _abrirBancoTeste() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
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
      },
    ),
  );
  return db;
}

Future<int> _novoCliente(Database db) => db.insert('clientes', {
      'numero_conta': '0001',
      'nome': 'Teste',
      'criado_em': DateTime(2026, 1, 1).toIso8601String(),
    });

Future<void> _lancar(Database db, int clienteId, String tipo, double valor) =>
    db.insert('transacoes', {
      'cliente_id': clienteId,
      'tipo': tipo,
      'valor': valor,
      'data': DateTime.now().toIso8601String(),
    });

Future<double> _saldo(Database db, int clienteId) async {
  final r = await db.rawQuery(
    '''SELECT
        COALESCE(SUM(CASE WHEN tipo='fiado' THEN valor ELSE 0 END),0) -
        COALESCE(SUM(CASE WHEN tipo='pagamento' THEN valor ELSE 0 END),0) AS saldo
       FROM transacoes WHERE cliente_id = ?''',
    [clienteId],
  );
  return (r.first['saldo'] as num).toDouble();
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('saldo é a soma dos fiados menos os pagamentos', () async {
    final db = await _abrirBancoTeste();
    final id = await _novoCliente(db);

    await _lancar(db, id, 'fiado', 30);
    await _lancar(db, id, 'fiado', 20);
    await _lancar(db, id, 'pagamento', 15);

    expect(await _saldo(db, id), 35);
    await db.close();
  });

  test('cliente sem dívida tem saldo zero', () async {
    final db = await _abrirBancoTeste();
    final id = await _novoCliente(db);

    await _lancar(db, id, 'fiado', 40);
    await _lancar(db, id, 'pagamento', 40);

    expect(await _saldo(db, id), 0);
    await db.close();
  });

  test('excluir cliente remove as transações (cascade)', () async {
    final db = await _abrirBancoTeste();
    final id = await _novoCliente(db);
    await _lancar(db, id, 'fiado', 10);

    await db.delete('clientes', where: 'id = ?', whereArgs: [id]);

    final restantes = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM transacoes WHERE cliente_id = ?',
      [id],
    );
    expect(restantes.first['n'], 0);
    await db.close();
  });
}
