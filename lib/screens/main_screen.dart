import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_navigation.dart';
import '../providers/fiado_provider.dart';
import '../utils/backup.dart';
import '../utils/update_checker.dart';
import 'dashboard_screen.dart';
import 'buscar_cliente_screen.dart';
import 'relatorios_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _titles = ['Dashboard', 'Buscar Cliente', 'Relatórios'];
  static const _bodies = [
    DashboardScreen(),
    BuscarClienteScreen(),
    RelatoriosScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FiadoProvider>().carregar();
      verificarAtualizacao(context);
    });
  }

  void _navegar(int index) {
    _scaffoldKey.currentState?.closeDrawer();
    if (index == 3) {
      abrirCadastroCliente();
    } else {
      mainTab.value = index;
    }
  }

  void _fazerBackup() {
    _scaffoldKey.currentState?.closeDrawer();
    // Usa o context do Scaffold (estável) para o snackbar não se perder.
    exportarBackup(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mainTab,
      builder: (context, selectedIndex, _) => Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_titles[selectedIndex]),
          actions: [
            if (selectedIndex == 0)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar',
                onPressed: () => context.read<FiadoProvider>().carregar(),
              ),
          ],
        ),
        drawer: _AppDrawer(
          selectedIndex: selectedIndex,
          onNavegar: _navegar,
          onBackup: _fazerBackup,
        ),
        body: IndexedStack(
          index: selectedIndex,
          children: _bodies,
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavegar;
  final VoidCallback onBackup;

  const _AppDrawer({
    required this.selectedIndex,
    required this.onNavegar,
    required this.onBackup,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onNavegar,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fiados',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Mercadinho',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: Text('Buscar Cliente'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: Text('Relatórios'),
        ),
        const Divider(indent: 16, endIndent: 16),
        const NavigationDrawerDestination(
          icon: Icon(Icons.person_add_outlined),
          selectedIcon: Icon(Icons.person_add),
          label: Text('Cadastrar Cliente'),
        ),
        const Divider(indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Fazer backup'),
            subtitle: const Text('Salva uma cópia em Downloads'),
            onTap: onBackup,
          ),
        ),
      ],
    );
  }
}
