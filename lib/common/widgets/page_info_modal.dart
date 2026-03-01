// lib/common/widgets/page_info_modal.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

/// Shows a floating info dialog describing a page's meaning and function.
/// Follows the same design language as [showVibrationInfoModal].
void showPageInfoModal(BuildContext context, {required String pageKey}) {
  final info = ContentData.pageInfo[pageKey];
  if (info == null) return;

  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: Container(
              color: AppColors.cardBackground,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header com botão fechar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.secondaryText),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                  ),

                  // Conteúdo
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                      child: Column(
                        children: [
                          // Subtítulo colorido
                          Text(
                            info['subtitle'] as String,
                            style: TextStyle(
                              color: AppColors.primary
                                  .withValues(alpha: 0.85),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Título principal
                          Text(
                            info['title'] as String,
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Divisor sutil
                          Container(
                            width: 60,
                            height: 4,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Seção "Na Numerologia"
                          _buildSection(
                            icon: Icons.auto_awesome,
                            label: 'Na Numerologia',
                            text: info['numerologia'] as String,
                          ),
                          const SizedBox(height: 24),

                          // Seção "No App"
                          _buildSection(
                            icon: Icons.phone_android,
                            label: 'No App',
                            text: info['noApp'] as String,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildSection({
  required IconData icon,
  required String label,
  required String text,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          text,
          style: TextStyle(
            color: AppColors.primaryText.withValues(alpha: 0.85),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

/// A subtle info icon button to be placed next to page titles.
class PageInfoButton extends StatelessWidget {
  final String pageKey;
  final double size;

  const PageInfoButton({
    super.key,
    required this.pageKey,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showPageInfoModal(context, pageKey: pageKey),
      icon: Icon(
        Icons.info_outline_rounded,
        color: AppColors.secondaryText.withValues(alpha: 0.5),
        size: size,
      ),
      tooltip: 'Sobre esta página',
      splashRadius: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}
