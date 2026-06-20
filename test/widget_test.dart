import 'package:flutter_test/flutter_test.dart';
import 'package:fiado_mercadinho/models/transacao.dart';

void main() {
  group('Transacao.valorSinalizado', () {
    test('fiado soma (positivo)', () {
      final t = Transacao(clienteId: 1, tipo: TipoTransacao.fiado, valor: 10);
      expect(t.valorSinalizado, 10);
    });

    test('pagamento subtrai (negativo)', () {
      final t =
          Transacao(clienteId: 1, tipo: TipoTransacao.pagamento, valor: 10);
      expect(t.valorSinalizado, -10);
    });
  });

  group('Transacao serialização', () {
    test('toMap/fromMap mantém os dados', () {
      final original = Transacao(
        id: 7,
        clienteId: 3,
        tipo: TipoTransacao.fiado,
        valor: 12.5,
        descricao: 'Pão',
        data: DateTime(2026, 1, 2, 10, 30),
      );
      final round = Transacao.fromMap(original.toMap());
      expect(round.id, original.id);
      expect(round.clienteId, original.clienteId);
      expect(round.tipo, original.tipo);
      expect(round.valor, original.valor);
      expect(round.descricao, original.descricao);
      expect(round.data, original.data);
    });
  });
}
