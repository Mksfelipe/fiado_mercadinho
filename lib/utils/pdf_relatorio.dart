import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/cliente.dart';
import '../models/transacao.dart';
import 'printer_config.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dtFmt = DateFormat('dd/MM/yyyy');

// Fonte monoespaçada em negrito (estilo cupom) — alinha as colunas e dá
// contraste numa térmica, que costuma imprimir claro.
final pw.Font _fonteBold = pw.Font.courierBold();

/// Imprime o extrato de fiado numa impressora térmica não fiscal 80mm.
///
/// Na primeira vez pede para o usuário escolher a impressora e guarda a escolha.
/// Nas próximas, imprime direto, sem abrir o diálogo do Windows.
Future<void> imprimirFiadoCliente({
  required BuildContext context,
  required Cliente cliente,
  required double saldo,
  required List<Transacao> transacoes,
}) async {
  final doc = _montarDocumento(
    cliente: cliente,
    saldo: saldo,
    transacoes: transacoes,
  );
  await _imprimirDocumento(context, doc, 'Fiado - ${cliente.nome}');
}

/// Imprime o comprovante de um pagamento: valor pago, troco (se pagou a mais)
/// e o novo saldo devedor.
Future<void> imprimirComprovantePagamento({
  required BuildContext context,
  required Cliente cliente,
  required List<Transacao> transacoes,
  required double saldoAnterior,
  required double valorPago,
  required double troco,
  required double novoSaldo,
}) async {
  final doc = _montarComprovante(
    cliente: cliente,
    transacoes: transacoes,
    saldoAnterior: saldoAnterior,
    valorPago: valorPago,
    troco: troco,
    novoSaldo: novoSaldo,
  );
  await _imprimirDocumento(context, doc, 'Pagamento - ${cliente.nome}');
}

/// Envia um documento para a térmica salva (imprime direto). Na primeira vez
/// pede para escolher a impressora e guarda; se a salva sumir, cai no diálogo.
Future<void> _imprimirDocumento(
  BuildContext context,
  pw.Document doc,
  String nome,
) async {
  Printer? impressora = await PrinterConfig.carregar();

  // Sem impressora salva: pede para escolher e guarda.
  if (impressora == null) {
    if (!context.mounted) return;
    impressora = await Printing.pickPrinter(context: context);
    if (impressora == null) return; // usuário cancelou
    await PrinterConfig.salvar(impressora);
  }

  try {
    final ok = await Printing.directPrintPdf(
      printer: impressora,
      onLayout: (_) async => doc.save(),
      name: nome,
      // Respeita o tamanho de papel configurado no driver da térmica (80mm).
      usePrinterSettings: true,
    );

    // Impressora salva não está mais disponível: limpa e cai no diálogo.
    if (!ok) {
      await PrinterConfig.limpar();
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: nome,
        usePrinterSettings: true,
      );
    }
  } catch (_) {
    // Falha ao imprimir direto (ex.: driver/impressora trocada): usa o diálogo.
    await PrinterConfig.limpar();
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: nome,
      usePrinterSettings: true,
    );
  }
}

/// Reabre o seletor para o usuário trocar de impressora térmica.
Future<void> selecionarImpressoraTermica(BuildContext context) async {
  final p = await Printing.pickPrinter(context: context);
  if (p != null) await PrinterConfig.salvar(p);
}

pw.Document _montarDocumento({
  required Cliente cliente,
  required double saldo,
  required List<Transacao> transacoes,
}) {
  // Os pagamentos abatem as compras mais antigas primeiro (FIFO). O cupom
  // mostra só o que ainda está em aberto (valor positivo): compras quitadas
  // somem e a parcialmente paga aparece apenas com o valor que falta.
  final abertas = _comprasEmAberto(transacoes);

  // Altura justa ao conteúdo, para não desperdiçar papel na bobina.
  // Cabeçalho/rodapé fixos (~52mm) + cada linha em aberto (~5mm).
  final alturaConteudo =
      52.0 + (abertas.isEmpty ? 6.0 : abertas.length * 5.0);

  // Largura = área imprimível real da térmica 80mm (~72mm). Usar 80mm faz a
  // coluna da direita (Valor) cair fora da área de impressão e ser cortada.
  final pageFormat = PdfPageFormat(
    72 * PdfPageFormat.mm,
    alturaConteudo * PdfPageFormat.mm,
    marginLeft: 2 * PdfPageFormat.mm,
    marginRight: 2 * PdfPageFormat.mm,
    marginTop: 3 * PdfPageFormat.mm,
    marginBottom: 2 * PdfPageFormat.mm,
  );

  // Fonte base em negrito: a térmica imprime fino/claro, e tudo em bold
  // melhora bastante o contraste/legibilidade do cupom.
  final doc = pw.Document(
    title: 'Fiado - ${cliente.nome}',
    theme: pw.ThemeData.withFont(base: _fonteBold, bold: _fonteBold),
  );

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            'FIADOS MERCADINHO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Compras em aberto',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
          _sep(),
          _linha('Cliente', cliente.nome),
          _linha('Conta', '#${cliente.numeroConta}'),
          if (cliente.telefone != null) _linha('Tel', cliente.telefone!),
          _sep(),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('Data',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('Valor',
                  style:
                      pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          _sep(),
          ..._linhasAbertas(abertas),
          _sep(),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('SALDO DEVEDOR',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text(_moeda.format(saldo),
                  style:
                      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          _sep(),
          pw.Text(
            'Emitido: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ),
    ),
  );

  return doc;
}

pw.Document _montarComprovante({
  required Cliente cliente,
  required List<Transacao> transacoes,
  required double saldoAnterior,
  required double valorPago,
  required double troco,
  required double novoSaldo,
}) {
  // Itens que compunham a conta no momento do pagamento (antes deste pagar).
  final abertas = _comprasEmAberto(transacoes);
  final temTroco = troco > 0.005;

  // Cabeçalho/rodapé + cada item (~5mm) + bloco de totais. Cresce com troco.
  final alturaConteudo = 64.0 +
      (abertas.isEmpty ? 6.0 : abertas.length * 5.0) +
      (temTroco ? 5.0 : 0.0);

  final pageFormat = PdfPageFormat(
    72 * PdfPageFormat.mm,
    alturaConteudo * PdfPageFormat.mm,
    marginLeft: 2 * PdfPageFormat.mm,
    marginRight: 2 * PdfPageFormat.mm,
    marginTop: 3 * PdfPageFormat.mm,
    marginBottom: 2 * PdfPageFormat.mm,
  );

  final doc = pw.Document(
    title: 'Pagamento - ${cliente.nome}',
    theme: pw.ThemeData.withFont(base: _fonteBold, bold: _fonteBold),
  );

  pw.Widget valor(String rotulo, double v, {bool destaque = false}) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(rotulo,
                style: pw.TextStyle(
                    fontSize: destaque ? 9 : 8,
                    fontWeight:
                        destaque ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
          pw.Text(_moeda.format(v),
              style: pw.TextStyle(
                  fontSize: destaque ? 9 : 8,
                  fontWeight:
                      destaque ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      );

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            'FIADOS MERCADINHO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Comprovante de pagamento',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
          _sep(),
          _linha('Cliente', cliente.nome),
          _linha('Conta', '#${cliente.numeroConta}'),
          _sep(),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('Data',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('Valor',
                  style:
                      pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          _sep(),
          ..._linhasAbertas(abertas),
          _sep(),
          valor('Total da conta', saldoAnterior),
          valor('Valor pago', valorPago),
          if (temTroco) valor('Troco', troco),
          _sep(),
          valor('NOVO SALDO DEVEDOR', novoSaldo, destaque: true),
          _sep(),
          pw.Text(
            'Emitido: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ),
    ),
  );

  return doc;
}

pw.Widget _sep() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Divider(thickness: 0.5, height: 0.5),
    );

/// Linhas "data ... valor" das compras em aberto, ou um aviso se não houver.
List<pw.Widget> _linhasAbertas(List<_CompraAberta> abertas) {
  if (abertas.isEmpty) {
    return [
      pw.Text('Nenhuma compra em aberto.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8)),
    ];
  }
  return abertas
      .map((c) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(_dtFmt.format(c.data),
                      style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Text(_moeda.format(c.restante),
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ))
      .toList();
}

/// Uma compra (ou o que restou dela) que ainda não foi paga.
class _CompraAberta {
  final DateTime data;
  final double restante;
  _CompraAberta(this.data, this.restante);
}

/// Aplica os pagamentos às compras mais antigas (FIFO) e devolve só o que
/// continua em aberto (valor positivo), das mais recentes para as mais antigas.
List<_CompraAberta> _comprasEmAberto(List<Transacao> transacoes) {
  final compras = transacoes
      .where((t) => t.tipo == TipoTransacao.fiado)
      .toList()
    ..sort((a, b) => a.data.compareTo(b.data)); // mais antigas primeiro

  var credito = transacoes
      .where((t) => t.tipo == TipoTransacao.pagamento)
      .fold(0.0, (sum, t) => sum + t.valor);

  const eps = 0.005; // tolerância p/ centavos (ponto flutuante)
  final abertas = <_CompraAberta>[];

  for (final c in compras) {
    if (credito >= c.valor - eps) {
      credito -= c.valor; // compra totalmente quitada — não entra no cupom
      continue;
    }
    final restante = c.valor - credito; // só o que falta (sempre positivo)
    credito = 0;
    abertas.add(_CompraAberta(c.data, restante));
  }

  abertas.sort((a, b) => b.data.compareTo(a.data)); // mais recentes primeiro
  return abertas;
}

pw.Widget _linha(String rotulo, String valor) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        children: [
          pw.Text('$rotulo: ',
              style:
                  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
              child: pw.Text(valor, style: const pw.TextStyle(fontSize: 8))),
        ],
      ),
    );
