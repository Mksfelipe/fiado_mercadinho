import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/snack.dart';
import '../models/cliente.dart';
import '../models/transacao.dart';
import '../providers/fiado_provider.dart';
import '../utils/formatters.dart';
import '../utils/pdf_relatorio.dart';

class TransacaoFormScreen extends StatefulWidget {
  final Cliente cliente;
  final TipoTransacao tipoInicial;
  final double saldoAtual;

  const TransacaoFormScreen({
    super.key,
    required this.cliente,
    required this.tipoInicial,
    required this.saldoAtual,
  });

  @override
  State<TransacaoFormScreen> createState() => _TransacaoFormScreenState();
}

class _TransacaoFormScreenState extends State<TransacaoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valor = TextEditingController();
  final _descricao = TextEditingController();
  late TipoTransacao _tipo;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
  }

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  bool get isFiado => _tipo == TipoTransacao.fiado;

  void _preencherTotal() {
    if (!isFiado && widget.saldoAtual > 0) {
      _valor.text =
          widget.saldoAtual.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  Future<void> _salvar() async {
    if (_salvando) return; // evita salvar 2x (ex.: Enter + clique)
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final valorDigitado = double.parse(_valor.text.replaceAll(',', '.'));

    // No pagamento, o cliente pode entregar mais do que deve: o excedente vira
    // troco e só o necessário para quitar é registrado (saldo nunca fica
    // negativo). Num pagamento parcial, registra-se o valor inteiro.
    final pagaMais = !isFiado && valorDigitado > widget.saldoAtual;
    final troco = pagaMais ? valorDigitado - widget.saldoAtual : 0.0;
    final valorRegistrado = pagaMais ? widget.saldoAtual : valorDigitado;

    final provider = context.read<FiadoProvider>();

    // Itens da conta no momento do pagamento (antes de registrar este pagar),
    // para listar no comprovante.
    final transacoesAntes = isFiado
        ? const <Transacao>[]
        : await provider.transacoesDoCliente(widget.cliente.id!);

    final transacao = Transacao(
      clienteId: widget.cliente.id!,
      tipo: _tipo,
      valor: valorRegistrado,
      descricao:
          _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
    );

    if (!mounted) return;
    final ok = await provider.adicionarTransacao(transacao);
    if (!mounted) return;
    if (!ok) {
      Snack.error(context, 'Erro ao registrar. Tente novamente.');
      setState(() => _salvando = false);
      return;
    }

    // Comprovante do pagamento: lista os itens da conta e fecha com o valor
    // pago, o troco (se houver) e o novo saldo devedor.
    if (!isFiado) {
      final novoSaldo = widget.saldoAtual - valorRegistrado;
      await imprimirComprovantePagamento(
        context: context,
        cliente: widget.cliente,
        transacoes: transacoesAntes,
        saldoAnterior: widget.saldoAtual,
        valorPago: valorDigitado,
        troco: troco,
        novoSaldo: novoSaldo,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cor = isFiado ? AppColors.red : AppColors.green;

    return CallbackShortcuts(
      bindings: {
        // Esc fecha sem salvar; Enter confirma (igual ao botão). Num campo
        // de texto multilinha (descrição) o Enter continua quebrando linha.
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
        const SingleActivator(LogicalKeyboardKey.enter): _salvar,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _salvar,
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cor,
          title: Text(isFiado ? 'Lançar Fiado' : 'Registrar Pagamento'),
        ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TipoSelector(
              tipo: _tipo,
              onChanged: (t) => setState(() => _tipo = t),
            ),
            const SizedBox(height: 20),

            // Info do cliente
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cor.withAlpha(30),
                    child: Text(
                      widget.cliente.nome[0].toUpperCase(),
                      style: TextStyle(
                          color: cor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.cliente.nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Conta #${widget.cliente.numeroConta}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Saldo devedor',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey)),
                      Text(
                        formatarMoeda(widget.saldoAtual),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: widget.saldoAtual > 0
                              ? AppColors.red
                              : AppColors.greenLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _valor,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _salvar(),
              decoration: InputDecoration(
                labelText: 'Valor (R\$)',
                prefixIcon: const Icon(Icons.attach_money),
                suffixIcon: !isFiado && widget.saldoAtual > 0
                    ? TextButton(
                        onPressed: _preencherTotal,
                        child: const Text('Total',
                            style: TextStyle(fontSize: 12)),
                      )
                    : null,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o valor';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [5, 10, 20, 50, 100].map((v) {
                return ActionChip(
                  label: Text('R\$ $v'),
                  onPressed: () {
                    _valor.text = v.toString().replaceAll('.', ',');
                  },
                  backgroundColor: cor.withAlpha(15),
                  labelStyle: TextStyle(color: cor, fontSize: 12),
                  side: BorderSide(color: cor.withAlpha(60)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descricao,
              decoration: InputDecoration(
                labelText: isFiado
                    ? 'Produto/descrição (opcional)'
                    : 'Observação (opcional)',
                prefixIcon: const Icon(Icons.description),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              style: FilledButton.styleFrom(backgroundColor: cor),
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(isFiado ? Icons.shopping_cart : Icons.payment),
              label: Text(
                  isFiado ? 'Confirmar fiado' : 'Confirmar pagamento'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _TipoSelector extends StatelessWidget {
  final TipoTransacao tipo;
  final ValueChanged<TipoTransacao> onChanged;
  const _TipoSelector({required this.tipo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Chip(
            label: 'Fiado',
            icon: Icons.shopping_cart,
            selected: tipo == TipoTransacao.fiado,
            color: AppColors.red,
            onTap: () => onChanged(TipoTransacao.fiado),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Chip(
            label: 'Pagamento',
            icon: Icons.payment,
            selected: tipo == TipoTransacao.pagamento,
            color: AppColors.green,
            onTap: () => onChanged(TipoTransacao.pagamento),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
