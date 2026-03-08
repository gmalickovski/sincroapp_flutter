import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/settings/presentation/settings_screen.dart';
import 'package:window_manager/window_manager.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final UserModel? userData;
  final VoidCallback onMenuPressed;
  final AnimationController menuAnimationController;
  final bool isEditMode;
  final VoidCallback? onEditPressed;
  final VoidCallback? onSearchToggle;
  final bool isSearchActive;
  final bool showSearch;
  final List<Widget>? actions;
  final Widget? assistantIcon;

  const CustomAppBar({
    super.key,
    required this.userData,
    required this.onMenuPressed,
    required this.menuAnimationController,
    this.isEditMode = false,
    this.onEditPressed,
    this.onSearchToggle,
    this.isSearchActive = false,
    this.showSearch = true,
    this.actions,
    this.assistantIcon,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}

class _CustomAppBarState extends State<CustomAppBar> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (!kIsWeb) windowManager.removeListener(this);
    super.dispose();
  }

  void _navigateToSettings(BuildContext context) {
    if (widget.userData != null) {
      final isDesktop = MediaQuery.of(context).size.width >= 720;
      if (isDesktop) {
        showDialog(
          context: context,
          builder: (context) => SettingsScreen(userData: widget.userData!),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SettingsScreen(userData: widget.userData!),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // Wrap title in DragToMoveArea for window dragging (native desktop only)
    Widget titleWidget = kIsWeb
        ? SvgPicture.asset(
            'assets/images/sincroapp_logo.svg',
            height: isDesktop ? 32 : 24,
            fit: BoxFit.contain,
          )
        : DragToMoveArea(
            child: SvgPicture.asset(
              'assets/images/sincroapp_logo.svg',
              height: isDesktop ? 32 : 24,
              fit: BoxFit.contain,
            ),
          );

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      // Use flexibleSpace for draggable background area (native desktop only)
      flexibleSpace: kIsWeb
          ? null
          : DragToMoveArea(
              child: Container(
                color: Colors.transparent, // Ensures hit testing works
              ),
            ),
      leading: IconButton(
        icon: AnimatedIcon(
          icon: AnimatedIcons.menu_close,
          progress: widget.menuAnimationController,
          color: AppColors.secondaryText,
        ),
        onPressed: widget.onMenuPressed,
        tooltip: 'Menu',
      ),
      title: titleWidget,
      centerTitle: true,
      actions: [
        if (widget.showSearch && widget.onSearchToggle != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildSearchToggleButton(),
          ),

        if (isDesktop && widget.onEditPressed != null && !widget.isEditMode)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.swap_vert, color: AppColors.secondaryText),
              tooltip: 'Reordenar Cards',
              onPressed: widget.onEditPressed,
            ),
          ),

        if (widget.assistantIcon != null) widget.assistantIcon!,

        if (widget.userData != null && isDesktop)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => _navigateToSettings(context),
              child: UserAvatar(
                photoUrl: widget.userData!.photoUrl,
                firstName: widget.userData!.primeiroNome,
                lastName: widget.userData!.sobrenome,
                radius: 18,
              ),
            ),
          ),

        if (widget.actions != null) ...widget.actions!,

        if (!isDesktop && widget.userData == null)
          const SizedBox(width: kToolbarHeight),

        // Add Window Buttons on native Desktop only (not web)
        if (isDesktop && !kIsWeb) _buildWindowButtons(),
      ],
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1.0),
      ),
    );
  }

  /// Builds Minimize, Maximize/Restore, Close buttons
  Widget _buildWindowButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.minimize,
          onPressed: () => windowManager.minimize(),
        ),
        FutureBuilder<bool>(
          future: windowManager.isMaximized(),
          builder: (context, snapshot) {
            final isMaximized = snapshot.data ?? false;
            return _WindowButton(
              icon: isMaximized
                  ? Icons.crop_square
                  : Icons.crop_din,
              onPressed: () {
                if (isMaximized) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
                setState(() {}); // Rebuild icon
              },
            );
          },
        ),
        _WindowButton(
          icon: Icons.close,
          onPressed: () => windowManager.close(),
          isClose: true,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Circular search toggle button — white border & icon when active, muted when inactive
  Widget _buildSearchToggleButton() {
    final isActive = widget.isSearchActive;
    final Color iconColor = isActive ? Colors.white : AppColors.secondaryText;
    final Color borderColor = isActive ? Colors.white : Colors.transparent;

    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(
            side: BorderSide(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: widget.onSearchToggle,
            customBorder: const CircleBorder(),
            hoverColor: AppColors.primary.withValues(alpha: 0.1),
            splashColor: AppColors.primary.withValues(alpha: 0.2),
            child: Center(
              child: Icon(Icons.search, color: iconColor, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  // WindowListener callbacks
  @override
  void onWindowMaximize() {
    setState(() {});
  }

  @override
  void onWindowUnmaximize() {
    setState(() {});
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32, // Typical title bar height
          color: _isHovered
              ? (widget.isClose ? Colors.red : Colors.white.withAlpha(25))
              : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.isClose
                ? Colors.white
                : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
