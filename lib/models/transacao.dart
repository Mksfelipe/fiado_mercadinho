enum TipoTransacao { fiado, pagamento }

class Transacao {
  final int? id;
  final int clienteId;
  final TipoTransacao tipo;
  final double valor;
  final String? descricao;
  final DateTime data;

  /// Quando o valor/descrição foi editado depois de lançado. `null` = nunca
  /// editado. Serve para marcar o lançamento na lista.
  final DateTime? editadoEm;

  /// Valor com que o lançamento foi originalmente registrado, preservado no
  /// primeiro edit para dar transparência ("antes: R$ X").
  final double? valorOriginal;

  Transacao({
    this.id,
    required this.clienteId,
    required this.tipo,
    required this.valor,
    this.descricao,
    DateTime? data,
    this.editadoEm,
    this.valorOriginal,
  }) : data = data ?? DateTime.now();

  double get valorSinalizado =>
      tipo == TipoTransacao.fiado ? valor : -valor;

  bool get foiEditado => editadoEm != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'tipo': tipo.name,
        'valor': valor,
        'descricao': descricao,
        'data': data.toIso8601String(),
        'editado_em': editadoEm?.toIso8601String(),
        'valor_original': valorOriginal,
      };

  factory Transacao.fromMap(Map<String, dynamic> map) => Transacao(
        id: map['id'] as int?,
        clienteId: map['cliente_id'] as int,
        tipo: TipoTransacao.values.byName(map['tipo'] as String),
        valor: (map['valor'] as num).toDouble(),
        descricao: map['descricao'] as String?,
        data: DateTime.parse(map['data'] as String),
        editadoEm: map['editado_em'] != null
            ? DateTime.parse(map['editado_em'] as String)
            : null,
        valorOriginal: (map['valor_original'] as num?)?.toDouble(),
      );
}
