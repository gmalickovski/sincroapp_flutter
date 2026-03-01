import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/widgets/page_info_modal.dart';

/// Container separado para a linha do título da página.
///
/// Renderiza o título e o botão de info da página em seu próprio container,
/// separado do [SincroToolbar] e do conteúdo. Isso permite alterar cada parte
/// da página de forma independente.
///
/// Usage:
/// ```dart
/// Column(
///   children: [
///     PageTitleRow(title: 'Manuscritos', pageKey: 'journal'),
///     SincroToolbar(...),  // sem title/titleTrailing
///     Expanded(child: ...),
///   ],
/// )
/// ```
class PageTitleRow extends StatelessWidget {
  /// Texto do título da página.
  final String title;

  /// Chave da página usada pelo [PageInfoButton] para exibir o modal de info.
  /// Se null, nenhum botão de info é exibido.
  final String? pageKey;

  /// Widget opcional exibido após o título (em vez do [PageInfoButton] padrão).
  final Widget? trailing;

  /// Se true, usa padding e fontSize de desktop.
  /// Se null, calcula automaticamente via LayoutBuilder.
  final bool? forceDesktop;

  const PageTitleRow({
    super.key,
    required this.title,
    this.pageKey,
    this.trailing,
    this.forceDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = forceDesktop ?? (constraints.maxWidth > 800);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40.0 : 16.0,
          ).copyWith(
            top: isDesktop ? 8.0 : 4.0,
          ),
          alignment: Alignment.topLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null)
                trailing!
              else if (pageKey != null)
                PageInfoButton(pageKey: pageKey!),
            ],
          ),
        );
      },
    );
  }
}
