import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/dados_periodo.dart';
import '../providers/fiado_provider.dart';
import '../utils/formatters.dart';

class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: AppColors.darkGreen,
            child: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              tabs: [
                Tab(icon: Icon(Icons.today, size: 18), text: 'Diário'),
                Tab(icon: Icon(Icons.view_week, size: 18), text: 'Semanal'),
                Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Mensal'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _TabRelatorio(tipo: _TipoRelatorio.diario),
                _TabRelatorio(tipo: _TipoRelatorio.semanal),
                _TabRelatorio(tipo: _TipoRelatorio.mensal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TipoRelatorio { diario, semanal, mensal }

class _TabRelatorio extends StatelessWidget {
  final _TipoRelatorio tipo;
  const _TabRelatorio({required this.tipo});

  Future<List<DadosPeriodo>> _carregar(FiadoProvider p) => switch (tipo) {
        _TipoRelatorio.diario => p.dadosPorDia(),
        _TipoRelatorio.semanal => p.dadosPorSemana(),
        _TipoRelatorio.mensal => p.dadosPorMes(),
      };

  String get _tituloGrafico => switch (tipo) {
        _TipoRelatorio.diario => 'Últimos 7 dias',
        _TipoRelatorio.semanal => 'Últimas 4 semanas',
        _TipoRelatorio.mensal => 'Últimos 6 meses',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FiadoProvider>();
    return FutureBuilder<List<DadosPeriodo>>(
      future: _carregar(p),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final totalFiados =
            data.fold<double>(0, (s, d) => s + d.totalFiados);
        final totalPagamentos =
            data.fold<double>(0, (s, d) => s + d.totalPagamentos);
        final saldoLiquido = totalFiados - totalPagamentos;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ResumoPeriodo(
              totalFiados: totalFiados,
              totalPagamentos: totalPagamentos,
              saldoLiquido: saldoLiquido,
            ),
            const SizedBox(height: 16),
            _GraficoCard(
              titulo: '$_tituloGrafico — Fiados',
              data: data,
              barColor: AppColors.red,
              getValue: (d) => d.totalFiados,
            ),
            const SizedBox(height: 12),
            _GraficoCard(
              titulo: '$_tituloGrafico — Pagamentos',
              data: data,
              barColor: AppColors.greenLight,
              getValue: (d) => d.totalPagamentos,
            ),
            const SizedBox(height: 12),
            _TabelaPeriodo(data: data),
          ],
        );
      },
    );
  }
}

// ─── Resumo do período ───────────────────────────────────────────

class _ResumoPeriodo extends StatelessWidget {
  final double totalFiados, totalPagamentos, saldoLiquido;
  const _ResumoPeriodo({
    required this.totalFiados,
    required this.totalPagamentos,
    required this.saldoLiquido,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ResumoItem(
            label: 'Total Fiados',
            valor: totalFiados,
            cor: AppColors.red),
        _ResumoItem(
            label: 'Pagamentos',
            valor: totalPagamentos,
            cor: AppColors.greenLight),
        _ResumoItem(
            label: 'Em aberto',
            valor: saldoLiquido,
            cor: saldoLiquido > 0 ? AppColors.orange : AppColors.green),
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
                                const EdgeInsets.symmetric(horizontal: 3),
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
                                        fontSize: 9, color: Colors.grey),
                                    textAlign: TextAlign.center),
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

// ─── Tabela detalhada ────────────────────────────────────────────

class _TabelaPeriodo extends StatelessWidget {
  final List<DadosPeriodo> data;
  const _TabelaPeriodo({required this.data});

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('Período',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    child: Text('Fiados',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.red),
                        textAlign: TextAlign.right)),
                Expanded(
                    child: Text('Pagamentos',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.greenLight),
                        textAlign: TextAlign.right)),
                Expanded(
                    child: Text('Saldo',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 0),
          ...data.asMap().entries.map((e) {
            final d = e.value;
            final saldo = d.saldoLiquido;
            final isLast = e.key == data.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text(d.label,
                              style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: Text(
                          formatarMoeda(d.totalFiados),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.red),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatarMoeda(d.totalPagamentos),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.greenLight),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatarMoeda(saldo),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: saldo > 0 ? AppColors.orange : AppColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 0, indent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}
