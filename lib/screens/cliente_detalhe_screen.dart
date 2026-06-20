import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/snack.dart';
import '../models/cliente.dart';
import '../models/transacao.dart';
import '../providers/fiado_provider.dart';
import '../utils/formatters.dart';
import '../utils/pdf_relatorio.dart';
import '../utils/whatsapp.dart';
import 'cliente_form_screen.dart';
import 'transacao_form_screen.dart';

// ─── tipos para a lista renderizada ──────────────────────────────
sealed class _Item {}

final class _DateHeader extends _Item {
  final String rotulo;
  final String data;
  _DateHeader(this.rotulo, this.data);
}

final class _TxItem extends _Item {
  final Transacao transacao;
  _TxItem(this.transacao);
}

// ─── widget principal ─────────────────────────────────────────────
class ClienteDetalheScreen extends StatefulWidget {
  final Cliente cliente;
  const ClienteDetalheScreen({super.key, required this.cliente});

  @override
  State<ClienteDetalheScreen> createState() => _ClienteDetalheScreenState();
}

class _ClienteDetalheScreenState extends State<ClienteDetalheScreen> {
  late Cliente _cliente;
  List<Transacao> _todas = [];
  bool _carregando = true;
  String _filtro = 'todos';
  final Map<int, double> _saldosAcumulados = {};

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final transacoes = await context
        .read<FiadoProvider>()
        .transacoesDoCliente(_cliente.id!);
    if (!mounted) return;
    setState(() {
      _todas = transacoes;
      _carregando = false;
    });
    _computeSaldos();
  }

  void _computeSaldos() {
    _saldosAcumulados.clear();
    final sorted = _todas.toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    double running = 0;
    for (final t in sorted) {
      running += t.valorSinalizado;
      _saldosAcumulados[t.id!] = running;
    }
  }

  List<Transacao> get _filtradas => switch (_filtro) {
        'fiados' =>
          _todas.where((t) => t.tipo == TipoTransacao.fiado).toList(),
        'pagamentos' =>
          _todas.where((t) => t.tipo == TipoTransacao.pagamento).toList(),
        _ => _todas,
      };

  List<_Item> get _renderItems {
    final result = <_Item>[];
    String? lastKey;
    for (final t in _filtradas) {
      final key = formatarData(t.data);
      if (key != lastKey) {
        result.add(_DateHeader(_rotuloRelativo(t.data), key));
        lastKey = key;
      }
      result.add(_TxItem(t));
    }
    return result;
  }

  String _rotuloRelativo(DateTime dt) {
    final hoje = DateTime.now();
    final diff = DateTime(hoje.year, hoje.month, hoje.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    const d = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    return d[dt.weekday - 1];
  }

  double get _totalFiadoHistorico => _todas
      .where((t) => t.tipo == TipoTransacao.fiado)
      .fold(0.0, (s, t) => s + t.valor);

  double get _totalPagoHistorico => _todas
      .where((t) => t.tipo == TipoTransacao.pagamento)
      .fold(0.0, (s, t) => s + t.valor);

  int get _qtdFiados =>
      _todas.where((t) => t.tipo == TipoTransacao.fiado).length;

  int get _qtdPagamentos =>
      _todas.where((t) => t.tipo == TipoTransacao.pagamento).length;

  Future<void> _abrirFormTransacao(TipoTransacao tipo) async {
    if (!mounted) return;
    final saldo =
        context.read<FiadoProvider>().saldoDoCliente(_cliente.id!);

    if (tipo == TipoTransacao.pagamento && saldo <= 0) {
      Snack.info(context, 'Este cliente não possui débito em aberto.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransacaoFormScreen(
          cliente: _cliente,
          tipoInicial: tipo,
          saldoAtual: saldo,
        ),
      ),
    );
    if (mounted) _carregar();
  }

  Future<bool> _confirmarExclusao(Transacao t) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text(
          'Remover ${t.tipo == TipoTransacao.fiado ? "fiado" : "pagamento"}'
          ' de ${formatarMoeda(t.valor)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _excluirTransacao(Transacao t) async {
    setState(() {
      _todas.remove(t);
      _computeSaldos();
    });
    if (!mounted) return;
    await context
        .read<FiadoProvider>()
        .excluirTransacao(t.id!, _cliente.id!);
  }

  @override
  Widget build(BuildContext context) {
    final saldo =
        context.watch<FiadoProvider>().saldoDoCliente(_cliente.id!);
    final temFiado = saldo > 0;
    final corBase =
        temFiado ? AppColors.darkRed : AppColors.darkGreen;
    final expandedHeight =
        MediaQuery.of(context).padding.top + kToolbarHeight + 185.0;
    final items = _renderItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            stretch: true,
            backgroundColor: corBase,
            foregroundColor: Colors.white,
            elevation: 0,
            title: _TituloCompacto(cliente: _cliente),
            actions: [
              if (temFiado && (_cliente.telefone?.trim().isNotEmpty ?? false))
                IconButton(
                  icon: const Icon(Icons.chat_outlined),
                  tooltip: 'Cobrar pelo WhatsApp',
                  onPressed: () =>
                      cobrarPorWhatsApp(context, _cliente, saldo),
                ),
              GestureDetector(
                onLongPress: () => selecionarImpressoraTermica(context),
                child: IconButton(
                  icon: const Icon(Icons.print_outlined),
                  tooltip: 'Imprimir fiado (segure para trocar a impressora)',
                  onPressed: () => imprimirFiadoCliente(
                    context: context,
                    cliente: _cliente,
                    saldo: saldo,
                    transacoes: _todas,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClienteFormScreen(cliente: _cliente),
                    ),
                  );
                  if (!context.mounted) return;
                  final updated =
                      context.read<FiadoProvider>().clientes.firstWhere(
                            (c) => c.id == _cliente.id,
                            orElse: () => _cliente,
                          );
                  setState(() => _cliente = updated);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: ClipRect(
                child: _HeaderExpandido(
                  cliente: _cliente,
                  saldo: saldo,
                  temFiado: temFiado,
                  corBase: corBase,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _StatsRow(
              totalFiado: _totalFiadoHistorico,
              totalPago: _totalPagoHistorico,
              count: _todas.length,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _AcaoBtn(
                      label: 'Lançar Fiado',
                      icon: Icons.add_shopping_cart,
                      color: AppColors.red,
                      onTap: () =>
                          _abrirFormTransacao(TipoTransacao.fiado),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AcaoBtn(
                      label: 'Pagamento',
                      icon: Icons.payment,
                      color: AppColors.green,
                      enabled: saldo > 0,
                      onTap: () =>
                          _abrirFormTransacao(TipoTransacao.pagamento),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _FiltroBarra(
              filtro: _filtro,
              countTodos: _todas.length,
              countFiados: _qtdFiados,
              countPagamentos: _qtdPagamentos,
              onChanged: (f) => setState(() => _filtro = f),
            ),
          ),

          if (_carregando)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (items.isEmpty)
            SliverToBoxAdapter(child: _EstadoVazio(filtro: _filtro))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return switch (item) {
                    _DateHeader(:final rotulo, :final data) =>
                      _Separador(rotulo: rotulo, data: data),
                    _TxItem(:final transacao) => _TileTransacao(
                        transacao: transacao,
                        saldo: _saldosAcumulados[transacao.id!] ?? 0,
                        onConfirm: () => _confirmarExclusao(transacao),
                        onDelete: () => _excluirTransacao(transacao),
                      ),
                  };
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Widgets de apoio ─────────────────────────────────────────────

class _TituloCompacto extends StatelessWidget {
  final Cliente cliente;
  const _TituloCompacto({required this.cliente});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cliente.nome,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          Text('Conta #${cliente.numeroConta}',
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70)),
        ],
      );
}

class _HeaderExpandido extends StatelessWidget {
  final Cliente cliente;
  final double saldo;
  final bool temFiado;
  final Color corBase;

  const _HeaderExpandido({
    required this.cliente,
    required this.saldo,
    required this.temFiado,
    required this.corBase,
  });

  @override
  Widget build(BuildContext context) {
    final topSpace =
        MediaQuery.of(context).padding.top + kToolbarHeight;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [corBase, corBase.withAlpha(190)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topSpace + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(nome: cliente.nome, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente.nome,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.1),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _Badge('#${cliente.numeroConta}'),
                          if (cliente.telefone != null) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.phone,
                                color: Colors.white60, size: 12),
                            const SizedBox(width: 2),
                            Text(cliente.telefone!,
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(temFiado: temFiado),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.white24, height: 1),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  temFiado ? 'Saldo devedor' : 'Conta quitada',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  formatarMoeda(saldo),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1),
                ),
                if (cliente.observacao != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.notes,
                          color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cliente.observacao!,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String nome;
  final double radius;
  const _Avatar({required this.nome, required this.radius});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white.withAlpha(45),
        child: Text(
          nome[0].toUpperCase(),
          style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.9,
              fontWeight: FontWeight.bold),
        ),
      );
}

class _Badge extends StatelessWidget {
  final String texto;
  const _Badge(this.texto);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(texto,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool temFiado;
  const _StatusBadge({required this.temFiado});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(60), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              temFiado ? Icons.warning_amber : Icons.check_circle,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              temFiado ? 'DEVENDO' : 'QUITADO',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      );
}

class _StatsRow extends StatelessWidget {
  final double totalFiado;
  final double totalPago;
  final int count;
  const _StatsRow({
    required this.totalFiado,
    required this.totalPago,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _StatItem(
              label: 'Total fiado',
              value: formatarMoeda(totalFiado),
              cor: AppColors.red,
              icon: Icons.trending_up),
          _VDiv(),
          _StatItem(
              label: 'Total pago',
              value: formatarMoeda(totalPago),
              cor: AppColors.green,
              icon: Icons.trending_down),
          _VDiv(),
          _StatItem(
              label: 'Movimentos',
              value: '$count',
              cor: AppColors.blue,
              icon: Icons.receipt_long),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color cor;
  final IconData icon;
  const _StatItem({
    required this.label,
    required this.value,
    required this.cor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: cor.withAlpha(160), size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: cor)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 10)),
          ],
        ),
      );
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 44,
        color: Colors.grey.withAlpha(50),
      );
}

class _AcaoBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _AcaoBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
        ),
      );
}

class _FiltroBarra extends StatelessWidget {
  final String filtro;
  final int countTodos, countFiados, countPagamentos;
  final ValueChanged<String> onChanged;

  const _FiltroBarra({
    required this.filtro,
    required this.countTodos,
    required this.countFiados,
    required this.countPagamentos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Histórico de lançamentos',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FiltroChip(
                  label: 'Todos',
                  count: countTodos,
                  selected: filtro == 'todos',
                  cor: AppColors.slateGrey,
                  onTap: () => onChanged('todos'),
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  label: 'Fiados',
                  count: countFiados,
                  selected: filtro == 'fiados',
                  cor: AppColors.red,
                  onTap: () => onChanged('fiados'),
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  label: 'Pagamentos',
                  count: countPagamentos,
                  selected: filtro == 'pagamentos',
                  cor: AppColors.green,
                  onTap: () => onChanged('pagamentos'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color cor;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? cor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? cor : Colors.grey.shade300),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: cor.withAlpha(60),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withAlpha(50)
                      : Colors.grey.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        selected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Separador extends StatelessWidget {
  final String rotulo;
  final String data;
  const _Separador({required this.rotulo, required this.data});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          children: [
            Expanded(
                child: Divider(
                    color: Colors.grey.withAlpha(70), height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: rotulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF444444)),
                    ),
                    TextSpan(
                      text: '  $data',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
                child: Divider(
                    color: Colors.grey.withAlpha(70), height: 1)),
          ],
        ),
      );
}

class _TileTransacao extends StatelessWidget {
  final Transacao transacao;
  final double saldo;
  final Future<bool> Function() onConfirm;
  final VoidCallback onDelete;

  const _TileTransacao({
    required this.transacao,
    required this.saldo,
    required this.onConfirm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isFiado = transacao.tipo == TipoTransacao.fiado;
    final accentColor = isFiado ? AppColors.red : AppColors.green;

    return Dismissible(
      key: ValueKey(transacao.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (dir) => onConfirm(),
      onDismissed: (dir) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text('Excluir',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFiado ? Icons.shopping_cart : Icons.payment,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transacao.descricao ??
                          (isFiado ? 'Fiado' : 'Pagamento'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatarDataHora(transacao.data),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isFiado ? '+' : '-'} ${formatarMoeda(transacao.valor)}',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Saldo: ',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        formatarMoeda(saldo),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: saldo > 0
                              ? AppColors.red
                              : AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _EstadoVazio extends StatelessWidget {
  final String filtro;
  const _EstadoVazio({required this.filtro});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filtro) {
      'fiados' => 'Nenhum fiado lançado',
      'pagamentos' => 'Nenhum pagamento registrado',
      _ => 'Nenhum lançamento ainda',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          if (filtro == 'todos') ...[
            const SizedBox(height: 6),
            Text(
              'Use os botões acima para lançar',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
