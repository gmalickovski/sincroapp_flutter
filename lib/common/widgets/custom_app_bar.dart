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
  final ValueChanged<String>? onSearchChanged;
  final List<Widget>? actions;
  final bool showSearch;
  final Widget? assistantIcon;

  const CustomAppBar({
    super.key,
    required this.userData,
    required this.onMenuPressed,
    required this.menuAnimationController,
    this.isEditMode = false,
    this.onEditPressed,
    this.onSearchChanged,
    this.actions,
    this.showSearch = true,
    this.assistantIcon,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}

class _CustomAppBarState extends State<CustomAppBar> with WindowListener {
  bool _isSearchOpen = false;
  bool _isSearchHovered = false;
  bool _isCloseHovered = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this); // Add listener
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    windowManager.removeListener(this); // Remove listener
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  void _openSearch() {
    if (!_isSearchOpen) {
      setState(() {
        _isSearchOpen = true;
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _closeSearch() {
    if (_isSearchOpen) {
      setState(() {
        _isSearchOpen = false;
        _searchFocusNode.unfocus();
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isSearchOpen) {
          _searchController.clear();
          widget.onSearchChanged?.call('');
        }
      });
    }
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

    // Wrap title in DragToMoveArea for window dragging
    Widget titleWidget = DragToMoveArea(
      child: SvgPicture.asset(
        'assets/images/sincroapp_logo.svg',
        height: isDesktop ? 32 : 24,
        fit: BoxFit.contain,
      ),
    );

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      // Use flexibleSpace for draggable background area
      flexibleSpace: DragToMoveArea(
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
      title: (_isSearchOpen && !isDesktop) ? const SizedBox.shrink() : titleWidget,
      centerTitle: true,
      actions: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildUnifiedSearch(context, isDesktop: isDesktop),
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

        if (widget.assistantIcon != null)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: widget.assistantIcon!,
          ),

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

        // Add Window Buttons on Desktop
        if (isDesktop) _buildWindowButtons(),
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
              icon: isMaximized ? Icons.crop_square : Icons.crop_din, // Placeholder capability
              // Better icons: Icons.check_box_outline_blank (max) vs Icons.filter_none (restore)
              // But standard Material icons are fine
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

  // ... _buildUnifiedSearch, _buildSearchButton, _buildCloseButton (kept as is)
  Widget _buildUnifiedSearch(BuildContext context, {required bool isDesktop}) {
    final isOpen = _isSearchOpen;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = isDesktop ? screenWidth * 0.35 : screenWidth * 0.70;
    Color borderColor = Colors.transparent;
    Color bgColor = Colors.transparent;

    if (isOpen) {
      bgColor = AppColors.cardBackground.withValues(alpha: 0.5);
      if (_searchFocusNode.hasFocus) {
        borderColor = AppColors.primary;
      } else if (_isSearchHovered) {
        borderColor = AppColors.secondaryText;
      } else {
        borderColor = AppColors.border;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isOpen ? targetWidth : 48.0,
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isOpen)
            Positioned.fill(
              child: MouseRegion(
                onEnter: (_) => setState(() => _isSearchHovered = true),
                onExit: (_) => setState(() => _isSearchHovered = false),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofillHints: const [],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar...',
                    hintStyle: TextStyle(color: AppColors.tertiaryText, fontSize: 14),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: widget.onSearchChanged,
                  onTapOutside: (event) {
                    if (_isSearchOpen) _closeSearch();
                  },
                ),
              ),
            ),
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: SizedBox(
              width: 48, height: 48,
              child: isOpen ? _buildCloseButton() : _buildSearchButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    return Center(
      child: SizedBox(
        width: 40, height: 40,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _openSearch,
            customBorder: const CircleBorder(),
            hoverColor: AppColors.primary.withValues(alpha: 0.1),
            splashColor: AppColors.primary.withValues(alpha: 0.2),
            child: const Center(
              child: Icon(Icons.search, color: AppColors.secondaryText, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isCloseHovered = true),
      onExit: (_) => setState(() => _isCloseHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _closeSearch,
        child: Container(
          width: 48, height: 48,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Icon(
            Icons.close,
            color: _isCloseHovered ? AppColors.primary : AppColors.secondaryText,
            size: 20,
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
