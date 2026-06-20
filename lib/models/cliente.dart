class Cliente {
  final int? id;
  final String numeroConta;
  final String nome;
  final String? telefone;
  final String? observacao;
  final DateTime criadoEm;

  Cliente({
    this.id,
    required this.numeroConta,
    required this.nome,
    this.telefone,
    this.observacao,
    DateTime? criadoEm,
  }) : criadoEm = criadoEm ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero_conta': numeroConta,
        'nome': nome,
        'telefone': telefone,
        'observacao': observacao,
        'criado_em': criadoEm.toIso8601String(),
      };

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
        id: map['id'] as int?,
        numeroConta: map['numero_conta'] as String? ?? '0000',
        nome: map['nome'] as String,
        telefone: map['telefone'] as String?,
        observacao: map['observacao'] as String?,
        criadoEm: DateTime.parse(map['criado_em'] as String),
      );

  Cliente copyWith({
    int? id,
    String? numeroConta,
    String? nome,
    String? telefone,
    String? observacao,
  }) =>
      Cliente(
        id: id ?? this.id,
        numeroConta: numeroConta ?? this.numeroConta,
        nome: nome ?? this.nome,
        telefone: telefone ?? this.telefone,
        observacao: observacao ?? this.observacao,
        criadoEm: criadoEm,
      );
}
