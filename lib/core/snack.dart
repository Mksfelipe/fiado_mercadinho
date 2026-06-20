import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class Snack {
  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.green, Icons.check_circle_outline);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.red, Icons.error_outline);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.slateGrey, Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
        ),
      );
  }
}
