import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Persistência simples da impressora térmica escolhida pelo usuário,
/// guardada num JSON ao lado do banco de dados (diretório de suporte do app).
class PrinterConfig {
  PrinterConfig._();

  static File? _arquivo;

  static Future<File> _config() async {
    if (_arquivo != null) return _arquivo!;
    final appDir = await getApplicationSupportDirectory();
    return _arquivo = File(p.join(appDir.path, 'impressora.json'));
  }

  /// Impressora salva, ou `null` se nunca foi escolhida.
  static Future<Printer?> carregar() async {
    try {
      final f = await _config();
      if (!await f.exists()) return null;
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final url = map['url'] as String?;
      if (url == null || url.isEmpty) return null;
      return Printer(url: url, name: map['name'] as String? ?? url);
    } catch (_) {
      return null;
    }
  }

  static Future<void> salvar(Printer printer) async {
    final f = await _config();
    await f.writeAsString(
      jsonEncode({'url': printer.url, 'name': printer.name}),
    );
  }

  static Future<void> limpar() async {
    try {
      final f = await _config();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
