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
const _githubOwner = 'Mksfelipe';
const _githubRepo = 'fiado_mercadinho';

const _apiUrl =
    'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

/// Ponto de entrada.
///
/// Na abertura do app (`manual: false`) a checagem é discreta: se der qualquer
/// erro de rede, não atrapalha o uso no balcão — só registra no log.
/// Pelo menu "Verificar atualizações" (`manual: true`) o resultado é sempre
/// mostrado na tela, inclusive o erro, para dar pra diagnosticar a máquina.
Future<void> verificarAtualizacao(
  BuildContext context, {
  bool manual = false,
}) async {
  final atual = (await PackageInfo.fromPlatform()).version;
  try {
    await _log('checando atualização (versão instalada: $atual)');
    final info = await _buscarReleaseMaisRecente();

    await _log('release mais recente: ${info.versao} — ${info.urlDownload}');

    if (!_ehMaisNova(info.versao, atual)) {
      await _log('já está atualizado');
      if (manual && context.mounted) {
        Snack.success(context, 'Você já está na versão mais recente ($atual).');
      }
      return;
    }

    if (!context.mounted) return;
    final confirmou = await _perguntar(context, info.versao);
    if (confirmou != true || !context.mounted) return;

    await _baixarEInstalar(context, info);
  } catch (e, s) {
    await _log('FALHOU: $e\n$s');
    if (manual && context.mounted) {
      await _mostrarErro(context, atual, e);
    }
  }
}

class _ReleaseInfo {
  final String versao; // ex: "1.2.0"
  final String urlDownload; // URL do instalador .exe
  const _ReleaseInfo(this.versao, this.urlDownload);
}

/// Erro com mensagem já pronta para mostrar ao usuário.
class _UpdateException implements Exception {
  final String mensagem;
  const _UpdateException(this.mensagem);
  @override
  String toString() => mensagem;
}

Future<_ReleaseInfo> _buscarReleaseMaisRecente() async {
  final http.Response resp;
  try {
    resp = await http.get(
      Uri.parse(_apiUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        // A API do GitHub recusa requisições sem User-Agent.
        'User-Agent': 'FiadosMercadinho-Updater',
      },
    ).timeout(const Duration(seconds: 20));
  } on SocketException catch (e) {
    throw _UpdateException(
      'Não foi possível acessar a internet (api.github.com).\n'
      'Verifique a conexão, o firewall ou o antivírus desta máquina.\n\n$e',
    );
  }

  if (resp.statusCode == 403 || resp.statusCode == 429) {
    throw const _UpdateException(
      'O GitHub recusou a consulta por excesso de tentativas '
      '(limite por hora). Tente de novo mais tarde.',
    );
  }
  if (resp.statusCode == 404) {
    throw const _UpdateException(
      'Nenhum release publicado foi encontrado em '
      '$_githubOwner/$_githubRepo (ou o repositório está privado).',
    );
  }
  if (resp.statusCode != 200) {
    throw _UpdateException(
      'O GitHub respondeu com erro ${resp.statusCode} ao consultar a '
      'versão mais recente.',
    );
  }

  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  // tag_name costuma vir como "v1.2.0"; tiramos o "v".
  final tag = (json['tag_name'] as String?)?.trim() ?? '';
  final versao = tag.startsWith('v') ? tag.substring(1) : tag;
  if (versao.isEmpty) {
    throw const _UpdateException('O release publicado não tem número de versão.');
  }

  final assets = (json['assets'] as List?) ?? const [];
  final exe = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.exe'),
        orElse: () => const {},
      );
  final url = exe['browser_download_url'] as String?;
  if (url == null) {
    throw _UpdateException(
      'O release $versao não tem o instalador (.exe) anexado.',
    );
  }

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

Future<void> _mostrarErro(BuildContext context, String atual, Object erro) {
  final detalhe = erro is _UpdateException ? erro.mensagem : erro.toString();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Não foi possível verificar'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Versão instalada: $atual'),
            const SizedBox(height: 12),
            Text(detalhe),
            const SizedBox(height: 12),
            Text(
              'Detalhes gravados em:\n${_caminhoLog ?? "(log indisponível)"}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}

Future<void> _baixarEInstalar(BuildContext context, _ReleaseInfo info) async {
  Snack.info(context, 'Baixando atualização…');
  try {
    await _log('baixando ${info.urlDownload}');
    final resp = await http
        .get(Uri.parse(info.urlDownload))
        .timeout(const Duration(minutes: 5));
    if (resp.statusCode != 200) {
      await _log('download falhou: HTTP ${resp.statusCode}');
      if (context.mounted) {
        Snack.error(
          context,
          'Falha ao baixar a atualização (erro ${resp.statusCode}).',
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final destino = p.join(dir.path, 'FiadosMercadinho-Setup-${info.versao}.exe');
    await File(destino).writeAsBytes(resp.bodyBytes);
    await _log('instalador salvo em $destino (${resp.bodyBytes.length} bytes)');

    // Roda o instalador (o .iss tem CloseApplications=yes, então ele fecha e
    // substitui o app) e encerra o app atual para liberar os arquivos.
    // `runInShell` é o que dispara o prompt de administrador (UAC) do
    // instalador; `detached` mantém o processo vivo depois do exit(0).
    await Process.start(
      destino,
      const [],
      runInShell: true,
      mode: ProcessStartMode.detached,
    );
    await _log('instalador iniciado, encerrando o app');
    // Um respiro para o instalador subir antes de o app sumir.
    await Future<void>.delayed(const Duration(seconds: 1));
    exit(0);
  } catch (e, s) {
    await _log('_baixarEInstalar falhou: $e\n$s');
    if (context.mounted) {
      Snack.error(context, 'Não foi possível atualizar: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Log em arquivo — é o que permite descobrir por que a atualização não rolou
// numa máquina em que você não está na frente.

String? _caminhoLog;

Future<void> _log(String mensagem) async {
  try {
    final arquivo = File(
      _caminhoLog ??= p.join(
        (await getApplicationSupportDirectory()).path,
        'atualizacao.log',
      ),
    );
    // Recomeça o arquivo quando passa de 64 KB, pra não crescer sem fim.
    if (await arquivo.exists() && await arquivo.length() > 64 * 1024) {
      await arquivo.writeAsString('');
    }
    await arquivo.writeAsString(
      '${DateTime.now().toIso8601String()}  $mensagem\n',
      mode: FileMode.append,
    );
  } catch (e) {
    debugPrint('não consegui gravar o log de atualização: $e');
  }
  debugPrint('[update] $mensagem');
}
