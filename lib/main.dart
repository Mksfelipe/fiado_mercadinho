import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/app_navigation.dart';
import 'core/app_theme.dart';
import 'providers/fiado_provider.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('pt_BR', null);
  runApp(const FiadoApp());
}

class FiadoApp extends StatelessWidget {
  const FiadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FiadoProvider(),
      child: MaterialApp(
        title: 'Fiados',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: navigatorKey,
        // Atalhos globais (valem em qualquer tela): F1 = Buscar Cliente,
        // F2 = Cadastrar Cliente. Ficam acima do Navigator.
        builder: (context, child) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f1): abrirBuscarCliente,
            const SingleActivator(LogicalKeyboardKey.f2): abrirCadastroCliente,
          },
          child: Focus(autofocus: true, child: child!),
        ),
        home: const MainScreen(),
      ),
    );
  }
}
