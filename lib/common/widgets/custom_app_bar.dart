// lib/common/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/settings/presentation/settings_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserModel? userData;
  final VoidCallback onMenuPressed;
  final AnimationController menuAnimationController;
  final bool isEditMode;
  final VoidCallback? onEditPressed;

  const CustomAppBar({
    super.key,
    required this.userData,
    required this.onMenuPressed,
    required this.menuAnimationController,
    this.isEditMode = false,
    this.onEditPressed,
  });

  void _navigateToSettings(BuildContext context) {
    if (userData != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SettingsScreen(userData: userData!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: isDesktop
          ? IconButton(
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: menuAnimationController,
                color: AppColors.secondaryText,
              ),
              onPressed: onMenuPressed,
              tooltip: 'Menu',
            )
          : IconButton(
              icon: const Icon(Icons.menu, color: AppColors.secondaryText),
              onPressed: onMenuPressed,
              tooltip: 'Menu',
            ),
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
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
      centerTitle: true,
      actions: [
        if (onEditPressed != null)
          TextButton.icon(
            icon: Icon(
              isEditMode ? Icons.check : Icons.edit_outlined,
              color: isEditMode ? Colors.green : AppColors.secondaryText,
              size: 18,
            ),
            label: Text(
              isEditMode ? 'Concluir' : 'Editar',
              style: TextStyle(
                color: isEditMode ? Colors.green : AppColors.secondaryText,
              ),
            ),
            onPressed: onEditPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isEditMode
                      ? Colors.green.withOpacity(0.5)
                      : AppColors.border,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        if (userData != null)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => _navigateToSettings(context),
              child: UserAvatar(
                // *** CORREÇÃO FINAL APLICADA AQUI ***
                photoUrl: userData!.photoUrl, // Propriedade corrigida
                firstName: userData!.primeiroNome,
                lastName: userData!.sobrenome,
                radius: 18,
              ),
            ),
          ),
      ],
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1.0),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}
