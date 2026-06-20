import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/snack.dart';
import '../models/cliente.dart';
import 'formatters.dart';

/// Mantém só os dígitos do telefone e garante o DDI 55 (Brasil) na frente.
/// Retorna null se não houver dígitos suficientes para um número válido.
String? _normalizarTelefone(String? telefone) {
  if (telefone == null) return null;
  var digitos = telefone.replaceAll(RegExp(r'\D'), '');
  if (digitos.length < 10) return null;
  if (!digitos.startsWith('55')) digitos = '55$digitos';
  return digitos;
}

/// Mensagem padrão de cobrança amigável.
String _mensagemCobranca(Cliente cliente, double saldo) {
  return 'Olá, ${cliente.nome}! Passando para lembrar do seu fiado no '
      'mercadinho, que está em ${formatarMoeda(saldo)}. '
      'Quando puder, é só passar aqui pra acertar. Obrigado!';
}

/// Abre o WhatsApp com a mensagem de cobrança pronta para o telefone do
/// cliente. Mostra um aviso se o número for inválido ou o app não abrir.
Future<void> cobrarPorWhatsApp(
  BuildContext context,
  Cliente cliente,
  double saldo,
) async {
  final fone = _normalizarTelefone(cliente.telefone);
  if (fone == null) {
    Snack.info(context, 'Cliente sem telefone válido cadastrado.');
    return;
  }

  final texto = Uri.encodeComponent(_mensagemCobranca(cliente, saldo));
  final uri = Uri.parse('https://wa.me/$fone?text=$texto');

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      Snack.error(context, 'Não foi possível abrir o WhatsApp.');
    }
  } catch (e, s) {
    debugPrint('cobrarPorWhatsApp falhou: $e\n$s');
    if (context.mounted) {
      Snack.error(context, 'Não foi possível abrir o WhatsApp.');
    }
  }
}
