import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy', 'pt_BR');
final _dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

String formatarMoeda(double valor) => _moeda.format(valor);
String formatarData(DateTime data) => _data.format(data);
String formatarDataHora(DateTime data) => _dataHora.format(data);
