import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../common/constants/app_colors.dart';

class UpdateDetailModal extends StatelessWidget {
  final String version;
  final String changelog;

  const UpdateDetailModal({
    super.key,
    required this.version,
    required this.changelog,
  });

  static Future<void> show(
    BuildContext context, {
    required String version,
    required String changelog,
  }) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          UpdateDetailModal(version: version, changelog: changelog),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.tertiaryText.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.rocket_launch_rounded,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nova Atualização Disponível! 🎉',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Versão $version',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.tertiaryText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'O que há de novo:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: MarkdownBody(
                      data: changelog,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 14),
                        h1: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        h2: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        h3: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: AppColors.primary),
                        code: TextStyle(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          color: AppColors.secondaryText,
                          fontFamily: 'monospace',
                        ),
                      ),
                      onTapLink: (text, href, title) {
                        if (href != null) launchUrl(Uri.parse(href));
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildImportantNote(),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Fechar',
                        style: TextStyle(color: AppColors.secondaryText)),
                  ),
                ),
                // Only on web/desktop we usually prompt refresh, on mobile update is manual store/install
                // But user context is tricky (mobile debug vs web).
                // We'll add a generic action if relevant, or just Close.
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Para atualizar, se estiver no celular via cabo, faça um "git pull" e rode novamente. Se for Web, recarregue a página.',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
