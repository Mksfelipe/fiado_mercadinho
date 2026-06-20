import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fiado_provider.dart';
import '../screens/cliente_form_screen.dart';

/// Navigator global — permite navegar de qualquer lugar (inclusive dos
/// atalhos de teclado) sem precisar de um BuildContext específico.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Aba atual da tela principal (0=Dashboard, 1=Buscar, 2=Relatórios).
/// É um notifier global para que os atalhos possam trocar de aba mesmo
/// estando em outra tela.
final ValueNotifier<int> mainTab = ValueNotifier<int>(0);

/// Foco do campo de busca de cliente — global porque a tela fica viva dentro
/// do IndexedStack, então focamos sob demanda ao entrar na busca.
final FocusNode buscaClienteFocus = FocusNode();

/// F1 — volta para a tela principal, abre a aba "Buscar Cliente" e já deixa
/// o cursor no campo de busca para digitar direto.
void abrirBuscarCliente() {
  navigatorKey.currentState?.popUntil((r) => r.isFirst);
  mainTab.value = 1;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    buscaClienteFocus.requestFocus();
  });
}

/// F2 — abre o formulário de cadastro de cliente sobre a tela atual.
void abrirCadastroCliente() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav
      .push(MaterialPageRoute(builder: (_) => const ClienteFormScreen()))
      .then((_) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) ctx.read<FiadoProvider>().carregar();
  });
}
