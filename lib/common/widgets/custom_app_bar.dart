// lib/common/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/settings/presentation/settings_screen.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final UserModel? userData;
  final VoidCallback onMenuPressed;
  final AnimationController menuAnimationController;
  final bool isEditMode;
  final VoidCallback? onEditPressed;
  final ValueChanged<String>? onSearchChanged; // New callback
  final List<Widget>? actions; // New Parameter
  final bool showSearch; // New Parameter to toggle search visibility
  final Widget? assistantIcon; // New Parameter

  const CustomAppBar({
    super.key,
    required this.userData,
    required this.onMenuPressed,
    required this.menuAnimationController,
    this.isEditMode = false,
    this.onEditPressed,
    this.onSearchChanged,
    this.actions,
    this.showSearch = true, // Default to true
    this.assistantIcon, // New Parameter
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);
}

class _CustomAppBarState extends State<CustomAppBar> {
  bool _isSearchOpen = false;
  bool _isSearchHovered = false; // Track field hover
  bool _isCloseHovered = false; // Track close button hover (for color change)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {}); // Rebuild to update border on focus change
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
      // Delay clearing text until animation finishes to avoid visual snap
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

    Widget titleWidget = SvgPicture.asset(
      'assets/images/sincroapp_logo.svg',
      height: isDesktop ? 32 : 24,
      fit: BoxFit.contain,
    );

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: AnimatedIcon(
          icon: AnimatedIcons.menu_close,
          progress: widget.menuAnimationController,
          color: AppColors.secondaryText,
        ),
        onPressed: widget.onMenuPressed,
        tooltip: 'Menu',
      ),
      // Hide title on mobile when search is open to avoid push/shrink effect
      title: (_isSearchOpen && !isDesktop) ? const SizedBox.shrink() : titleWidget,
      centerTitle: true,
      actions: [
        // Unified Search (same behavior for mobile and desktop)
        if (widget.showSearch) // Check visibility
          Padding(
            padding: const EdgeInsets.only(right: 8.0), // Spacing from next element
            child: _buildUnifiedSearch(context, isDesktop: isDesktop),
          ),

        if (isDesktop && widget.onEditPressed != null && !widget.isEditMode)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(
                Icons.swap_vert,
                color: AppColors.secondaryText,
              ),
              tooltip: 'Reordenar Cards',
              onPressed: widget.onEditPressed,
            ),
          ),

        // Assistant Icon (Hollow Star) - Positioned BEFORE Avatar or custom actions
        if (widget.assistantIcon != null)
           Padding(
             padding: const EdgeInsets.only(right: 12.0), // Spacing from Avatar
             child: widget.assistantIcon!,
           ),

        if (widget.userData != null && isDesktop) // Mostra avatar apenas no desktop
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



        if (widget.actions != null) ...widget.actions!, // Insert custom actions

        if (!isDesktop && widget.userData == null)
          const SizedBox(width: kToolbarHeight),
      ],
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1.0),
      ),
    );
  }

  /// Unified search widget - same behavior for mobile and desktop.
  /// Expands leftward from the button position, X stays in place.
  Widget _buildUnifiedSearch(BuildContext context, {required bool isDesktop}) {
    final isOpen = _isSearchOpen;
    final screenWidth = MediaQuery.of(context).size.width;
    // Desktop: 35% of screen. Mobile: ~70% of screen (leaving space for menu and avatar)
    final targetWidth = isDesktop ? screenWidth * 0.35 : screenWidth * 0.70;
    
    // Determine Border Color or Transparent if closed
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
      // Use Stack to keep button anchored to the right
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The Search Field (Visible only when open)
          if (isOpen)
            Positioned.fill(
              child: MouseRegion(
                onEnter: (_) => setState(() => _isSearchHovered = true),
                onExit: (_) => setState(() => _isSearchHovered = false),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofillHints: const [], // Prevent browser password save prompt
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlignVertical: TextAlignVertical.center, // Center vertically
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar...',
                    hintStyle: TextStyle(
                        color: AppColors.tertiaryText, fontSize: 14),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Symmetric vertical padding for centering
                  ),
                  onChanged: widget.onSearchChanged,
                  onTapOutside: (event) {
                    if (_isSearchOpen) _closeSearch();
                  },
                ),
              ),
            ),

          // The Toggle Button (Search or Close) - always anchored to right
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 48,
              height: 48,
              child: isOpen 
                ? _buildCloseButton()
                : _buildSearchButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _openSearch,
            customBorder: const CircleBorder(),
            hoverColor: AppColors.primary.withValues(alpha: 0.1),
            splashColor: AppColors.primary.withValues(alpha: 0.2),
            child: const Center(
              child: Icon(
                Icons.search,
                color: AppColors.secondaryText,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a close button that changes color on hover (no background splash).
  Widget _buildCloseButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isCloseHovered = true),
      onExit: (_) => setState(() => _isCloseHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _closeSearch,
        child: Container(
          width: 48,
          height: 48,
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
}

