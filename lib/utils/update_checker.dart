import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/snack.dart';

/// Verifica se há uma versão mais nova publicada no GitHub Releases e, se houver,
/// oferece baixar e instalar a atualização.
///
/// COMO FUNCIONA: a cada nova versão você publica um Release no GitHub com o
/// instalador (.exe) anexado. O app abre, consulta o "release mais recente",
/// compara com a versão atual e, se for mais nova, baixa o instalador e o roda.
///
/// >>> CONFIGURE AQUI <<<: troque pelo seu usuário/repositório do GitHub.
const _githubOwner = 'SEU_USUARIO';
const _githubRepo = 'fiado_mercadinho';

const _apiUrl =
    'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

/// Ponto de entrada: chame na abertura do app. Falha em silêncio se estiver
/// offline ou der qualquer erro de rede — não atrapalha o uso no balcão.
Future<void> verificarAtualizacao(BuildContext context) async {
  try {
    final info = await _buscarReleaseMaisRecente();
    if (info == null) return;

    final atual = (await PackageInfo.fromPlatform()).version;
    if (!_ehMaisNova(info.versao, atual)) return; // já está atualizado

    if (!context.mounted) return;
    final confirmou = await _perguntar(context, info.versao);
    if (confirmou != true || !context.mounted) return;

    await _baixarEInstalar(context, info);
  } catch (e, s) {
    debugPrint('verificarAtualizacao falhou: $e\n$s');
  }
}

class _ReleaseInfo {
  final String versao; // ex: "1.2.0"
  final String urlDownload; // URL do instalador .exe
  const _ReleaseInfo(this.versao, this.urlDownload);
}

Future<_ReleaseInfo?> _buscarReleaseMaisRecente() async {
  final resp = await http
      .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github+json'})
      .timeout(const Duration(seconds: 10));
  if (resp.statusCode != 200) return null;

  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  // tag_name costuma vir como "v1.2.0"; tiramos o "v".
  final tag = (json['tag_name'] as String?)?.trim() ?? '';
  final versao = tag.startsWith('v') ? tag.substring(1) : tag;
  if (versao.isEmpty) return null;

  final assets = (json['assets'] as List?) ?? const [];
  final exe = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.exe'),
        orElse: () => const {},
      );
  final url = exe['browser_download_url'] as String?;
  if (url == null) return null;

  return _ReleaseInfo(versao, url);
}

/// Compara "1.2.0" com "1.1.0" numericamente, campo a campo.
bool _ehMaisNova(String nova, String atual) {
  final a = _partes(nova);
  final b = _partes(atual);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

List<int> _partes(String versao) {
  final nums = versao.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  while (nums.length < 3) {
    nums.add(0);
  }
  return nums;
}

Future<bool?> _perguntar(BuildContext context, String versao) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Atualização disponível'),
      content: Text(
        'Uma nova versão ($versao) do aplicativo está disponível.\n\n'
        'Deseja atualizar agora? O programa será fechado durante a instalação.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Atualizar'),
        ),
      ],
    ),
  );
}

Future<void> _baixarEInstalar(BuildContext context, _ReleaseInfo info) async {
  Snack.info(context, 'Baixando atualização…');
  try {
    final resp = await http.get(Uri.parse(info.urlDownload));
    if (resp.statusCode != 200) {
      if (context.mounted) Snack.error(context, 'Falha ao baixar a atualização.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final destino = p.join(dir.path, 'FiadosMercadinho-Setup-${info.versao}.exe');
    await File(destino).writeAsBytes(resp.bodyBytes);

    // Roda o instalador (o .iss tem CloseApplications=yes, então ele fecha e
    // substitui o app) e encerra o app atual para liberar os arquivos.
    await Process.start(destino, [], runInShell: true);
    exit(0);
  } catch (e, s) {
    debugPrint('_baixarEInstalar falhou: $e\n$s');
    if (context.mounted) Snack.error(context, 'Não foi possível atualizar.');
  }
}
