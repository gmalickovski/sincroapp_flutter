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
  final VoidCallback?
      onEditPressed; // Callback remains, but button visibility changes

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
      leading: IconButton(
        // Use IconButton consistently
        icon: AnimatedIcon(
          // Use AnimatedIcon for desktop, simple Menu icon for mobile driven by controller state
          icon: AnimatedIcons.menu_close,
          progress: menuAnimationController, // Animation driven by controller
          color: AppColors.secondaryText,
        ),
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
        // *** CHANGE HERE: Only show Edit button if on Desktop AND callback is provided ***
        if (isDesktop && onEditPressed != null)
          Padding(
            // Add padding for better spacing on desktop
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              icon: Icon(
                // Logic remains the same: show check when isEditMode is true (modal open)
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
              onPressed: onEditPressed, // This still calls _openReorderModal
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
          ),
        // *** END CHANGE ***

        // User Avatar / Settings Navigation
        if (userData != null)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => _navigateToSettings(context),
              child: UserAvatar(
                photoUrl: userData!.photoUrl,
                firstName: userData!.primeiroNome,
                lastName: userData!.sobrenome,
                radius: 18,
              ),
            ),
          ),
        // Add SizedBox if on mobile and userData is null to prevent title shift
        if (!isDesktop && userData == null)
          const SizedBox(
              width: kToolbarHeight), // Approx. width of avatar action
      ],
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1.0),
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + 1.0); // Keep border height
}
