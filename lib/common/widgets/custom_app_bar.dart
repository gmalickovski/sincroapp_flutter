import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? userName;
  final VoidCallback onMenuPressed;
  final bool isDesktop;
  final bool isEditMode;
  final VoidCallback? onEditPressed;

  const CustomAppBar({
    super.key,
    required this.onMenuPressed,
    this.userName,
    this.isDesktop = false,
    this.isEditMode = false,
    this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom:
              BorderSide(color: AppColors.border.withOpacity(0.5), width: 1),
        ),
      ),
      child: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- LOGO CENTRALIZADO ---
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync, color: AppColors.primaryAccent, size: 28),
                SizedBox(width: 12),
                Text(
                  "SincroApp",
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // --- BOTÕES LATERAIS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botão de Menu (Esquerda)
                IconButton(
                  icon: const Icon(Icons.menu,
                      color: AppColors.secondaryText, size: 24),
                  onPressed: onMenuPressed,
                  tooltip: 'Menu',
                ),

                // Botões de Ação (Direita)
                Row(
                  children: [
                    if (isDesktop && onEditPressed != null) ...[
                      TextButton.icon(
                        icon: Icon(
                            isEditMode ? Icons.check : Icons.edit_outlined,
                            color: isEditMode
                                ? Colors.green
                                : AppColors.secondaryText,
                            size: 18),
                        label: Text(isEditMode ? 'Concluir' : 'Editar',
                            style: TextStyle(
                                color: isEditMode
                                    ? Colors.green
                                    : AppColors.secondaryText)),
                        onPressed: onEditPressed,
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                  color: isEditMode
                                      ? Colors.green.withOpacity(0.5)
                                      : AppColors.border),
                            )),
                      ),
                      const SizedBox(width: 16),
                    ],
                    UserAvatar(name: userName),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  // Altura aumentada para dar mais "respiro"
  Size get preferredSize => const Size.fromHeight(80.0);
}
