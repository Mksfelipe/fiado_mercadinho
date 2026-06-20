import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/snack.dart';
import '../database/database_helper.dart';

/// Exporta uma cópia do banco para a pasta de Downloads (ou Documentos, como
/// fallback) com um nome contendo data e hora. Mostra o resultado num snackbar.
Future<void> exportarBackup(BuildContext context) async {
  try {
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final carimbo = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final destino = p.join(dir.path, 'fiados_backup_$carimbo.db');

    await DatabaseHelper.instance.exportarBackup(destino);

    if (!context.mounted) return;
    Snack.success(context, 'Backup salvo em: $destino');
  } catch (e, s) {
    debugPrint('exportarBackup falhou: $e\n$s');
    if (!context.mounted) return;
    Snack.error(context, 'Não foi possível gerar o backup.');
  }
}
