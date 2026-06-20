import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/snack.dart';
import '../models/cliente.dart';
import '../providers/fiado_provider.dart';

class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente;
  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _observacao;
  String? _numeroConta;
  bool _salvando = false;

  bool get _editando => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.cliente?.nome ?? '');
    _telefone =
        TextEditingController(text: widget.cliente?.telefone ?? '');
    _observacao =
        TextEditingController(text: widget.cliente?.observacao ?? '');
    if (!_editando) _carregarNumeroConta();
  }

  Future<void> _carregarNumeroConta() async {
    final conta =
        await context.read<FiadoProvider>().proximoNumeroConta();
    if (mounted) setState(() => _numeroConta = conta);
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final provider = context.read<FiadoProvider>();
    final cliente = Cliente(
      id: widget.cliente?.id,
      numeroConta: widget.cliente?.numeroConta ?? _numeroConta ?? '0001',
      nome: _nome.text.trim(),
      telefone:
          _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
      observacao: _observacao.text.trim().isEmpty
          ? null
          : _observacao.text.trim(),
      criadoEm: widget.cliente?.criadoEm,
    );

    final ok = _editando
        ? await provider.atualizarCliente(cliente)
        : await provider.adicionarCliente(cliente);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      Snack.error(context, 'Erro ao salvar. Tente novamente.');
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isModal = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: isModal
          ? AppBar(
              title: Text(_editando ? 'Editar Cliente' : 'Novo Cliente'),
            )
          : null,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!isModal) ...[
              const Text(
                'Cadastrar Cliente',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGreen),
              ),
              const SizedBox(height: 4),
              Text(
                'Preencha os dados do novo cliente',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 24),
            ],
            if (!_editando) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.greenLight.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.green.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag,
                        color: AppColors.green, size: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Número da conta',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        Text(
                          _numeroConta != null
                              ? '#${_numeroConta!}'
                              : 'Gerando...',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('Automático',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(
                labelText: 'Nome completo *',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefone,
              decoration: const InputDecoration(
                labelText: 'Telefone / WhatsApp (opcional)',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observacao,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_editando ? Icons.save : Icons.person_add),
              label: Text(_editando ? 'Salvar alterações' : 'Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}
