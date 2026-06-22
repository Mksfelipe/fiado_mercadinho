import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/cliente.dart';
import '../models/dados_periodo.dart';
import '../providers/fiado_provider.dart';
import '../utils/formatters.dart';

/// Tela de relatórios com pesquisa por período personalizado e cliente.
/// Mostra um resumo, gráficos agregados do período e a lista detalhada.
class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

enum _Gran { dia, semana, mes }

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  late DateTime _de;
  late DateTime _ate;
  Cliente? _cliente; // null = todos os clientes

  bool _carregando = true;
  List<TransacaoResumo> _resultado = [];

  @override
  void initState() {
    super.initState();
    // Padrão: últimos 30 dias.
    final hoje = _hojeData();
    _ate = hoje;
    _de = hoje.subtract(const Duration(days: 29));
    WidgetsBinding.instance.addPostFrameCallback((_) => _pesquisar());
  }

  static DateTime _hojeData() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pesquisar() async {
    setState(() => _carregando = true);
    final res = await context.read<FiadoProvider>().buscarTransacoes(
          de: _de,
          ate: _ate,
          clienteId: _cliente?.id,
        );
    if (!mounted) return;
    setState(() {
      _resultado = res;
      _carregando = false;
    });
  }

  // ─── ações de filtro ───────────────────────────────────────────
  Future<void> _escolherData({required bool inicio}) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _de : _ate,
      firstDate: DateTime(2020),
      lastDate: _hojeData(),
      helpText: inicio ? 'Data inicial' : 'Data final',
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _de = _soData(escolhida);
        if (_de.isAfter(_ate)) _ate = _de;
      } else {
        _ate = _soData(escolhida);
        if (_ate.isBefore(_de)) _de = _ate;
      }
    });
    _pesquisar();
  }

  void _aplicarPreset(_Preset p) {
    final hoje = _hojeData();
    setState(() {
      switch (p) {
        case _Preset.hoje:
          _de = hoje;
          _ate = hoje;
        case _Preset.dias7:
          _de = hoje.subtract(const Duration(days: 6));
          _ate = hoje;
        case _Preset.dias30:
          _de = hoje.subtract(const Duration(days: 29));
          _ate = hoje;
        case _Preset.esteMes:
          _de = DateTime(hoje.year, hoje.month, 1);
          _ate = hoje;
        case _Preset.mesPassado:
          _de = DateTime(hoje.year, hoje.month - 1, 1);
          _ate = DateTime(hoje.year, hoje.month, 0);
        case _Preset.ano:
          _de = DateTime(hoje.year, 1, 1);
          _ate = hoje;
      }
    });
    _pesquisar();
  }

  Future<void> _escolherCliente() async {
    final clientes = context.read<FiadoProvider>().clientes;
    final r = await showDialog<Object>(
      context: context,
      builder: (_) => _ClientePickerDialog(clientes: clientes),
    );
    if (r == null) return; // cancelou
    setState(() => _cliente = r == _todos ? null : r as Cliente);
    _pesquisar();
  }

  // ─── derivados ─────────────────────────────────────────────────
  double get _totalFiados => _resultado
      .where((t) => t.isFiado)
      .fold(0.0, (s, t) => s + t.valor);

  double get _totalPagamentos => _resultado
      .where((t) => !t.isFiado)
      .fold(0.0, (s, t) => s + t.valor);

  _Gran get _granularidade {
    final dias = _ate.difference(_de).inDays + 1;
    if (dias <= 31) return _Gran.dia;
    if (dias <= 182) return _Gran.semana;
    return _Gran.mes;
  }

  List<DadosPeriodo> get _agrupado {
    final gran = _granularidade;
    final buckets = <String, DadosPeriodo>{};
    final ordem = <String>[];

    void garantir(String key, String label) {
      if (!buckets.containsKey(key)) {
        buckets[key] = DadosPeriodo(label: label);
        ordem.add(key);
      }
    }

    // Cria os baldes vazios cobrindo todo o período (para não "pular" dias/meses).
    if (gran == _Gran.dia) {
      for (var d = _de; !d.isAfter(_ate); d = d.add(const Duration(days: 1))) {
        garantir(_chave(d, gran), DateFormat('dd/MM').format(d));
      }
    } else if (gran == _Gran.semana) {
      for (var d = _de; !d.isAfter(_ate); d = d.add(const Duration(days: 7))) {
        garantir(_chave(d, gran), DateFormat('dd/MM').format(d));
      }
    } else {
      for (var m = DateTime(_de.year, _de.month);
          !m.isAfter(DateTime(_ate.year, _ate.month));
          m = DateTime(m.year, m.month + 1)) {
        garantir(_chave(m, gran), DateFormat('MMM/yy', 'pt_BR').format(m));
      }
    }

    for (final t in _resultado) {
      final b = buckets[_chave(t.data, gran)];
      if (b == null) continue;
      buckets[_chave(t.data, gran)] = DadosPeriodo(
        label: b.label,
        totalFiados: b.totalFiados + (t.isFiado ? t.valor : 0),
        totalPagamentos: b.totalPagamentos + (t.isFiado ? 0 : t.valor),
      );
    }

    return [for (final k in ordem) buckets[k]!];
  }

  String _chave(DateTime d, _Gran gran) {
    final dia = _soData(d);
    switch (gran) {
      case _Gran.dia:
        return DateFormat('yyyy-MM-dd').format(dia);
      case _Gran.semana:
        final semanas = dia.difference(_de).inDays ~/ 7;
        return 'S$semanas';
      case _Gran.mes:
        return '${dia.year}-${dia.month}';
    }
  }

  // ─── build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BarraFiltros(
          de: _de,
          ate: _ate,
          cliente: _cliente,
          onData: _escolherData,
          onPreset: _aplicarPreset,
          onCliente: _escolherCliente,
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ResumoPeriodo(
                      totalFiados: _totalFiados,
                      totalPagamentos: _totalPagamentos,
                      qtd: _resultado.length,
                    ),
                    const SizedBox(height: 16),
                    if (_resultado.isEmpty)
                      const _Vazio()
                    else ...[
                      _GraficoCard(
                        titulo: 'Fiados por período',
                        data: _agrupado,
                        barColor: AppColors.red,
                        getValue: (d) => d.totalFiados,
                      ),
                      const SizedBox(height: 12),
                      _GraficoCard(
                        titulo: 'Pagamentos por período',
                        data: _agrupado,
                        barColor: AppColors.greenLight,
                        getValue: (d) => d.totalPagamentos,
                      ),
                      const SizedBox(height: 16),
                      _ListaLancamentos(itens: _resultado),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

enum _Preset { hoje, dias7, dias30, esteMes, mesPassado, ano }

/// Sentinela para "todos os clientes" no resultado do seletor.
const _todos = 'TODOS';

// ─── Barra de filtros ────────────────────────────────────────────
class _BarraFiltros extends StatelessWidget {
  final DateTime de;
  final DateTime ate;
  final Cliente? cliente;
  final Future<void> Function({required bool inicio}) onData;
  final void Function(_Preset) onPreset;
  final VoidCallback onCliente;

  const _BarraFiltros({
    required this.de,
    required this.ate,
    required this.cliente,
    required this.onData,
    required this.onPreset,
    required this.onCliente,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _CampoData(
                    rotulo: 'De',
                    valor: formatarData(de),
                    onTap: () => onData(inicio: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CampoData(
                    rotulo: 'Até',
                    valor: formatarData(ate),
                    onTap: () => onData(inicio: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _CampoFiltro(
              icon: Icons.person_outline,
              texto: cliente?.nome ?? 'Todos os clientes',
              onTap: onCliente,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PresetChip('Hoje', () => onPreset(_Preset.hoje)),
                  _PresetChip('7 dias', () => onPreset(_Preset.dias7)),
                  _PresetChip('30 dias', () => onPreset(_Preset.dias30)),
                  _PresetChip('Este mês', () => onPreset(_Preset.esteMes)),
                  _PresetChip('Mês passado', () => onPreset(_Preset.mesPassado)),
                  _PresetChip('Este ano', () => onPreset(_Preset.ano)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoData extends StatelessWidget {
  final String rotulo;
  final String valor;
  final VoidCallback onTap;
  const _CampoData(
      {required this.rotulo, required this.valor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white70, size: 15),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo,
                    style: const TextStyle(color: Colors.white60, fontSize: 9)),
                Text(valor,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoFiltro extends StatelessWidget {
  final IconData icon;
  final String texto;
  final VoidCallback onTap;
  const _CampoFiltro(
      {required this.icon, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.darkGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
}

// ─── Seletor de cliente ──────────────────────────────────────────
class _ClientePickerDialog extends StatefulWidget {
  final List<Cliente> clientes;
  const _ClientePickerDialog({required this.clientes});

  @override
  State<_ClientePickerDialog> createState() => _ClientePickerDialogState();
}

class _ClientePickerDialogState extends State<_ClientePickerDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = _q.isEmpty
        ? widget.clientes
        : widget.clientes
            .where((c) =>
                c.nome.toLowerCase().contains(_q.toLowerCase()) ||
                c.numeroConta.contains(_q))
            .toList();

    return AlertDialog(
      title: const Text('Filtrar por cliente'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar nome ou conta…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Todos os clientes'),
              onTap: () => Navigator.pop(context, _todos),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: filtrados.length,
                itemBuilder: (ctx, i) {
                  final c = filtrados[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.green.withAlpha(40),
                      child: Text(c.nome[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.darkGreen)),
                    ),
                    title: Text(c.nome),
                    subtitle: Text('Conta #${c.numeroConta}'),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// ─── Resumo do período ───────────────────────────────────────────
class _ResumoPeriodo extends StatelessWidget {
  final double totalFiados, totalPagamentos;
  final int qtd;
  const _ResumoPeriodo({
    required this.totalFiados,
    required this.totalPagamentos,
    required this.qtd,
  });

  @override
  Widget build(BuildContext context) {
    final saldo = totalFiados - totalPagamentos;
    return Column(
      children: [
        Row(
          children: [
            _ResumoItem(
                label: 'Fiados', valor: totalFiados, cor: AppColors.red),
            _ResumoItem(
                label: 'Pagamentos',
                valor: totalPagamentos,
                cor: AppColors.greenLight),
            _ResumoItem(
                label: 'Saldo',
                valor: saldo,
                cor: saldo > 0 ? AppColors.orange : AppColors.green),
          ],
        ),
        const SizedBox(height: 6),
        Text('$qtd lançamento(s) no período',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _ResumoItem extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;
  const _ResumoItem(
      {required this.label, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: cor.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(formatarMoeda(valor),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
      ),
    );
  }
}

// ─── Lista de lançamentos ────────────────────────────────────────
class _ListaLancamentos extends StatelessWidget {
  final List<TransacaoResumo> itens;
  const _ListaLancamentos({required this.itens});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Lançamentos (${itens.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const Divider(height: 0),
          ...itens.asMap().entries.map((e) {
            final t = e.value;
            final isFiado = t.isFiado;
            final cor = isFiado ? AppColors.red : AppColors.green;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cor.withAlpha(18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFiado ? Icons.shopping_cart : Icons.payment,
                          color: cor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.clienteNome,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                              t.descricao?.isNotEmpty == true
                                  ? '${formatarDataHora(t.data)} · ${t.descricao}'
                                  : formatarDataHora(t.data),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isFiado ? '+' : '-'} ${formatarMoeda(t.valor)}',
                        style: TextStyle(
                            color: cor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (e.key != itens.length - 1)
                  const Divider(height: 0, indent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Nenhum lançamento no filtro',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 4),
            Text('Ajuste o período ou o cliente',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
}

// ─── Gráfico de barras ───────────────────────────────────────────
class _GraficoCard extends StatelessWidget {
  final String titulo;
  final List<DadosPeriodo> data;
  final Color barColor;
  final double Function(DadosPeriodo) getValue;

  const _GraficoCard({
    required this.titulo,
    required this.data,
    required this.barColor,
    required this.getValue,
  });

  @override
  Widget build(BuildContext context) {
    final valores = data.map(getValue).toList();
    final maxVal =
        valores.isEmpty ? 1.0 : valores.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF333333))),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_compact(effectiveMax), style: _labelStyle),
                      Text(_compact(effectiveMax * 0.75), style: _labelStyle),
                      Text(_compact(effectiveMax * 0.5), style: _labelStyle),
                      Text(_compact(effectiveMax * 0.25), style: _labelStyle),
                      Text('0', style: _labelStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomPaint(
                    painter: _GridPainter(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: data.asMap().entries.map((e) {
                        final v = getValue(e.value);
                        final frac = v / effectiveMax;
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (v > 0)
                                  Text(
                                    _compact(v),
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: barColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                const SizedBox(height: 2),
                                Flexible(
                                  child: FractionallySizedBox(
                                    heightFactor: frac.clamp(0.02, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: v == 0
                                            ? Colors.grey.withAlpha(40)
                                            : barColor,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(e.value.label,
                                    style: const TextStyle(
                                        fontSize: 8, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000) return 'R\$${(v / 1000).toStringAsFixed(1)}k';
    return 'R\$${v.toStringAsFixed(0)}';
  }

  static const _labelStyle = TextStyle(fontSize: 9, color: Colors.grey);
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(40)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
