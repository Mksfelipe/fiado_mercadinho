import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fiado_provider.dart';
import '../utils/formatters.dart';
import '../models/cliente.dart';
import 'cliente_detalhe_screen.dart';
import 'cliente_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _busca = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FiadoProvider>().carregar();
    });
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FiadoProvider>();
    final clientes = provider.clientes
        .where((c) => c.nome.toLowerCase().contains(_filtro.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Fiados do Mercadinho'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _ResumoCard(provider: provider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _busca,
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filtro.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busca.clear();
                          setState(() => _filtro = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
          ),
          Expanded(
            child: clientes.isEmpty
                ? _EmptyState(hasFilter: _filtro.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: clientes.length,
                    itemBuilder: (ctx, i) =>
                        _ClienteTile(cliente: clientes[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClienteFormScreen(),
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo cliente'),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final FiadoProvider provider;
  const _ResumoCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total em Fiados',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  formatarMoeda(provider.totalFiados),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Clientes com fiado',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${provider.clientesComFiado}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  final Cliente cliente;
  const _ClienteTile({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final saldo = context.watch<FiadoProvider>().saldoDoCliente(cliente.id!);
    final temFiado = saldo > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              temFiado ? const Color(0xFFE53935) : const Color(0xFF43A047),
          child: Text(
            cliente.nome[0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(cliente.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: cliente.telefone != null
            ? Text(cliente.telefone!,
                style: const TextStyle(color: Colors.grey))
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatarMoeda(saldo),
              style: TextStyle(
                color: temFiado
                    ? const Color(0xFFE53935)
                    : const Color(0xFF43A047),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              temFiado ? 'deve' : 'quitado',
              style: TextStyle(
                color: temFiado ? Colors.red[300] : Colors.green[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClienteDetalheScreen(cliente: cliente),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.search_off : Icons.people_outline,
            size: 72,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'Nenhum cliente encontrado' : 'Nenhum cliente ainda',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 8),
            Text(
              'Toque em "Novo cliente" para começar',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
