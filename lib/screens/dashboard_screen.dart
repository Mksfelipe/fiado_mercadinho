import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/dados_periodo.dart';
import '../providers/fiado_provider.dart';
import '../utils/formatters.dart';
import 'cliente_detalhe_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FiadoProvider>();

    if (p.hasError) {
      return const _ErrorState();
    }

    if (p.isLoading && p.clientes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => p.carregar(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Saudacao(),
          const SizedBox(height: 16),
          _CardDestaque(
            label: 'Total em fiados em aberto',
            valor: formatarMoeda(p.totalFiados),
            sub: '${p.clientesComFiado} cliente(s) com dívida',
            cor: AppColors.darkGreen,
            icone: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _MiniCard(
                label: 'Fiados hoje',
                valor: formatarMoeda(p.totalHoje),
                icone: Icons.today,
                cor: AppColors.lightBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniCard(
                label: 'Esta semana',
                valor: formatarMoeda(p.totalSemana),
                icone: Icons.date_range,
                cor: AppColors.purple,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _MiniCard(
            label: 'Este mês',
            valor: formatarMoeda(p.totalMes),
            icone: Icons.calendar_month,
            cor: AppColors.orange,
            wide: true,
          ),
          const SizedBox(height: 20),
          _SecaoTitulo(titulo: 'Últimos 7 dias — fiados vs pagamentos'),
          const SizedBox(height: 8),
          _MiniGrafico7Dias(provider: p),
          const SizedBox(height: 20),
          _SecaoTitulo(titulo: 'Top devedores'),
          const SizedBox(height: 8),
          _TopDevedores(provider: p),
          const SizedBox(height: 20),
          _SecaoTitulo(titulo: 'Últimas movimentações'),
          const SizedBox(height: 8),
          _UltimasTransacoes(provider: p),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Widgets utilitários ──────────────────────────────────────────

class _Saudacao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    final greeting = hora < 12
        ? 'Bom dia!'
        : hora < 18
            ? 'Boa tarde!'
            : 'Boa noite!';
    return Text(
      greeting,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.darkGreen,
      ),
    );
  }
}

class _SecaoTitulo extends StatelessWidget {
  final String titulo;
  const _SecaoTitulo({required this.titulo});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(
              width: 3,
              height: 18,
              child: ColoredBox(color: AppColors.green)),
          const SizedBox(width: 8),
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF333333))),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Não foi possível carregar os dados',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
}

// ─── Cards ───────────────────────────────────────────────────────

class _CardDestaque extends StatelessWidget {
  final String label, valor, sub;
  final Color cor;
  final IconData icone;

  const _CardDestaque({
    required this.label,
    required this.valor,
    required this.sub,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cor, cor.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: cor.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Icon(icone, color: Colors.white.withAlpha(180), size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(valor,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label, valor;
  final IconData icone;
  final Color cor;
  final bool wide;

  const _MiniCard({
    required this.label,
    required this.valor,
    required this.icone,
    required this.cor,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withAlpha(50)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(valor,
                    style: TextStyle(
                        fontSize: wide ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: cor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini gráfico 7 dias ─────────────────────────────────────────

class _MiniGrafico7Dias extends StatelessWidget {
  final FiadoProvider provider;
  const _MiniGrafico7Dias({required this.provider});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DadosPeriodo>>(
      future: provider.dadosPorDia(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!;
        return Container(
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GraficoBarra(data: data, altura: 100),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _Legenda(cor: AppColors.red, label: 'Fiados'),
                  SizedBox(width: 16),
                  _Legenda(cor: AppColors.greenLight, label: 'Pagamentos'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GraficoBarra extends StatelessWidget {
  final List<DadosPeriodo> data;
  final double altura;
  const _GraficoBarra({required this.data, required this.altura});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(
        1,
        (m, d) =>
            [m, d.totalFiados, d.totalPagamentos]
                .reduce((a, b) => a > b ? a : b));

    return SizedBox(
      height: altura,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Barra(
                          valor: d.totalFiados,
                          maxVal: maxVal,
                          maxAltura: altura - 20,
                          cor: AppColors.red),
                      const SizedBox(width: 2),
                      _Barra(
                          valor: d.totalPagamentos,
                          maxVal: maxVal,
                          maxAltura: altura - 20,
                          cor: AppColors.greenLight),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(d.label,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.grey),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  final double valor, maxVal, maxAltura;
  final Color cor;
  const _Barra({
    required this.valor,
    required this.maxVal,
    required this.maxAltura,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final h = valor == 0 ? 2.0 : (valor / maxVal) * maxAltura;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: 8,
      height: h,
      decoration: BoxDecoration(
        color: valor == 0 ? Colors.grey.withAlpha(50) : cor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String label;
  const _Legenda({required this.cor, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

// ─── Top devedores ───────────────────────────────────────────────

class _TopDevedores extends StatelessWidget {
  final FiadoProvider provider;
  const _TopDevedores({required this.provider});

  @override
  Widget build(BuildContext context) {
    final top = provider.topDevedoresClientes;
    if (top.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('Nenhum devedor',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }
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
        children: top.asMap().entries.map((e) {
          final idx = e.key;
          final cliente = e.value;
          final saldo = provider.saldoDoCliente(cliente.id!);
          final isLast = idx == top.length - 1;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _rankColor(idx),
                  child: Text(
                    '${idx + 1}°',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                title: Text(cliente.nome,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Conta #${cliente.numeroConta}',
                    style: const TextStyle(fontSize: 11)),
                trailing: Text(
                  formatarMoeda(saldo),
                  style: const TextStyle(
                      color: AppColors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClienteDetalheScreen(cliente: cliente),
                  ),
                ).then((_) => provider.carregar()),
              ),
              if (!isLast)
                const Divider(height: 0, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _rankColor(int idx) => switch (idx) {
        0 => AppColors.gold,
        1 => AppColors.silver,
        2 => AppColors.bronze,
        _ => AppColors.green,
      };
}

// ─── Últimas transações ──────────────────────────────────────────

class _UltimasTransacoes extends StatelessWidget {
  final FiadoProvider provider;
  const _UltimasTransacoes({required this.provider});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TransacaoResumo>>(
      future: provider.ultimasTransacoes(8),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()));
        }
        final lista = snap.data!;
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text('Nenhuma movimentação',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
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
            children: lista.asMap().entries.map((e) {
              final t = e.value;
              final isLast = e.key == lista.length - 1;
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: t.isFiado
                          ? AppColors.red.withAlpha(20)
                          : AppColors.greenLight.withAlpha(20),
                      child: Icon(
                        t.isFiado ? Icons.shopping_cart : Icons.payment,
                        size: 16,
                        color: t.isFiado ? AppColors.red : AppColors.green,
                      ),
                    ),
                    title: Text(t.clienteNome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                      t.descricao ?? (t.isFiado ? 'Fiado' : 'Pagamento'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${t.isFiado ? '+' : '-'} ${formatarMoeda(t.valor)}',
                          style: TextStyle(
                            color: t.isFiado ? AppColors.red : AppColors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          formatarDataHora(t.data),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 0, indent: 52, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
