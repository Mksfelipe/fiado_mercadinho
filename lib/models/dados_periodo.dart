class DadosPeriodo {
  final String label;
  final double totalFiados;
  final double totalPagamentos;

  const DadosPeriodo({
    required this.label,
    this.totalFiados = 0,
    this.totalPagamentos = 0,
  });

  double get saldoLiquido => totalFiados - totalPagamentos;
}

class TransacaoResumo {
  final int id;
  final int clienteId;
  final String clienteNome;
  final String numeroConta;
  final String tipo;
  final double valor;
  final String? descricao;
  final DateTime data;

  const TransacaoResumo({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    required this.numeroConta,
    required this.tipo,
    required this.valor,
    this.descricao,
    required this.data,
  });

  bool get isFiado => tipo == 'fiado';

  factory TransacaoResumo.fromMap(Map<String, dynamic> m) => TransacaoResumo(
        id: m['id'] as int,
        clienteId: m['cliente_id'] as int,
        clienteNome: m['cliente_nome'] as String,
        numeroConta: m['numero_conta'] as String,
        tipo: m['tipo'] as String,
        valor: (m['valor'] as num).toDouble(),
        descricao: m['descricao'] as String?,
        data: DateTime.parse(m['data'] as String),
      );
}
