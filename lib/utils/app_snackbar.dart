import 'dart:ui';
import 'package:flutter/material.dart';

class AppSnackBar {
  /// Shows a modern, semi-transparent frosted-glass Error SnackBar.
  static void showError(BuildContext context, String message, {String title = "Error"}) {
    _showCustomSnackBar(
      context: context,
      message: message,
      title: title,
      accentColor: const Color(0xFFEF5350), // Vibrant Red
      icon: Icons.error_outline_rounded,
    );
  }

  /// Shows a modern, semi-transparent frosted-glass Success SnackBar.
  static void showSuccess(BuildContext context, String message, {String title = "Success"}) {
    _showCustomSnackBar(
      context: context,
      message: message,
      title: title,
      accentColor: const Color(0xFF66BB6A), // Emerald Green
      icon: Icons.check_circle_outline_rounded,
    );
  }

  /// Shows a modern, semi-transparent frosted-glass Warning SnackBar.
  static void showWarning(BuildContext context, String message, {String title = "Warning"}) {
    _showCustomSnackBar(
      context: context,
      message: message,
      title: title,
      accentColor: const Color(0xFFFFA726), // Amber Orange
      icon: Icons.warning_amber_rounded,
    );
  }

  /// Shows a modern, semi-transparent frosted-glass Info SnackBar.
  static void showInfo(BuildContext context, String message, {String title = "Notice"}) {
    _showCustomSnackBar(
      context: context,
      message: message,
      title: title,
      accentColor: const Color(0xFF42A5F5), // Light Blue
      icon: Icons.info_outline_rounded,
    );
  }

  static void _showCustomSnackBar({
    required BuildContext context,
    required String message,
    required String title,
    required Color accentColor,
    required IconData icon,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent, // 👈 Fully transparent base SnackBar
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 4),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xDC1E222B), // 👈 Beautiful semi-transparent glass dark fill
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.5), // 👈 Glass glow border
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      messenger.hideCurrentSnackBar();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
