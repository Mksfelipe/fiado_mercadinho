enum TipoTransacao { fiado, pagamento }

class Transacao {
  final int? id;
  final int clienteId;
  final TipoTransacao tipo;
  final double valor;
  final String? descricao;
  final DateTime data;

  Transacao({
    this.id,
    required this.clienteId,
    required this.tipo,
    required this.valor,
    this.descricao,
    DateTime? data,
  }) : data = data ?? DateTime.now();

  double get valorSinalizado =>
      tipo == TipoTransacao.fiado ? valor : -valor;

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'tipo': tipo.name,
        'valor': valor,
        'descricao': descricao,
        'data': data.toIso8601String(),
      };

  factory Transacao.fromMap(Map<String, dynamic> map) => Transacao(
        id: map['id'] as int?,
        clienteId: map['cliente_id'] as int,
        tipo: TipoTransacao.values.byName(map['tipo'] as String),
        valor: (map['valor'] as num).toDouble(),
        descricao: map['descricao'] as String?,
        data: DateTime.parse(map['data'] as String),
      );
}
