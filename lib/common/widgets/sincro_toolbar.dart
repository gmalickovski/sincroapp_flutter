import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class SincroFilterItem {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;
  final GlobalKey? key; // Added key for popup anchoring

  SincroFilterItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
    this.key,
  });
}

class SincroToolbar extends StatefulWidget implements PreferredSizeWidget {
  final List<SincroFilterItem> filters;

  // Optional Actions (If null, the feature is disabled for that page)
  final bool isSelectionMode;
  final bool isAllSelected;
  final VoidCallback? onToggleSelectionMode; // Nullable
  final VoidCallback? onToggleSelectAll; // Nullable
  final VoidCallback? onDeleteSelected; // Nullable
  final ValueChanged<String>? onSearchChanged; // Nullable
  final VoidCallback? onClearFilters; // Nullable if no clear needed
  final int selectedCount;
  final bool hasActiveFilters;
  final bool?
      forceDesktop; // Forces desktop layout regardless of width constraints
  final EdgeInsetsGeometry? contentPadding;

  const SincroToolbar({
    super.key,
    required this.filters,
    this.isSelectionMode = false,
    this.isAllSelected = false,
    this.onToggleSelectionMode,
    this.onToggleSelectAll,
    this.onDeleteSelected,
    this.onSearchChanged,
    this.onClearFilters,
    this.hasActiveFilters = false,
    this.selectedCount = 0,
    this.forceDesktop,
    this.title, // Optional title
    this.titleTrailing, // Optional widget after title (e.g. chevron)
    this.contentPadding,
    this.useSliverAppBar =
        false, // If true, maybe render differently? No, just keep simple.
  });

  final String? title;
  final Widget? titleTrailing;
  final bool useSliverAppBar; // Unused for now, but good for future?

  @override
  Size get preferredSize => Size.fromHeight(title != null ? 110.0 : 60.0);

  @override
  State<SincroToolbar> createState() => _SincroToolbarState();
}

class _SincroToolbarState extends State<SincroToolbar> {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey _searchButtonKey = GlobalKey();

  // Scroll arrow state
  final ScrollController _filterScrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _filterScrollController.addListener(_updateArrows);
  }

  @override
  void dispose() {
    _filterScrollController.removeListener(_updateArrows);
    _filterScrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_filterScrollController.hasClients) return;
    final pos = _filterScrollController.position;
    final newLeft = pos.pixels > 0;
    final newRight = pos.pixels < pos.maxScrollExtent - 1;
    if (newLeft != _showLeftArrow || newRight != _showRightArrow) {
      setState(() {
        _showLeftArrow = newLeft;
        _showRightArrow = newRight;
      });
    }
  }

  void _checkOverflow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_filterScrollController.hasClients) return;
      final pos = _filterScrollController.position;
      setState(() {
        _showRightArrow = pos.maxScrollExtent > 0 && pos.pixels < pos.maxScrollExtent - 1;
        _showLeftArrow = pos.pixels > 0;
      });
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (_isSearchOpen) {
        _searchFocus.requestFocus();
      } else {
        _searchController.clear();
        widget.onSearchChanged?.call('');
        _searchFocus.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isDesktop = widget.forceDesktop ?? (availableWidth > 800);

        _checkOverflow();

        return Container(
          padding: widget.contentPadding ??
              EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40.0 : 16.0, vertical: isDesktop ? 8.0 : 4.0),
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Title Row (Always on top)
              if (widget.title != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 24 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.titleTrailing != null) widget.titleTrailing!,
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // 2. Actions & Filters Row with scroll arrows
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    // Left scroll arrow
                    if (_showLeftArrow)
                      _ScrollArrowButton(
                        direction: AxisDirection.left,
                        onTap: () {
                          _filterScrollController.animateTo(
                            (_filterScrollController.offset - 120).clamp(0.0, _filterScrollController.position.maxScrollExtent),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _filterScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          height: 40,
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.zero,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children:
                                _buildToolbarChildren(availableWidth, isDesktop),
                          ),
                        ),
                      ),
                    ),
                    // Right scroll arrow
                    if (_showRightArrow)
                      _ScrollArrowButton(
                        direction: AxisDirection.right,
                        onTap: () {
                          _filterScrollController.animateTo(
                            (_filterScrollController.offset + 120).clamp(0.0, _filterScrollController.position.maxScrollExtent),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                  ],
                ),
              ),

              // 3. Search Bar Row (slides in below when active)
              if (widget.onSearchChanged != null)
                _buildSearchRow(isDesktop: isDesktop),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildToolbarChildren(double availableWidth, bool isDesktop) {
    return [
      // 1. Search Button (icon-only, toggles search row below)
      if (!widget.isSelectionMode && widget.onSearchChanged != null) ...[
        _SincroActionButton(
          key: _searchButtonKey,
          icon: Icons.search,
          isActive: _isSearchOpen,
          onTap: _toggleSearch,
          tooltip: 'Pesquisar',
        ),
        const SizedBox(width: 8),
      ],

      // 2. Actions (Selection/Normal)
      SizedBox(
        height: 30,
        child: _buildUnifiedActions(),
      ),

      // 3. Clear Filters (Always right next to divider)
      SizedBox(
        height: 30,
        child: Builder(builder: (context) {
          final bool showClear = (widget.onClearFilters != null) &&
              (widget.hasActiveFilters ||
                  widget.filters.any((f) => f.isSelected));

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axis: Axis.horizontal,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: showClear
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      _SincroActionButton(
                        key: const ValueKey('clear_filters_btn_global'),
                        icon: Icons.filter_alt_off_outlined,
                        isActive: true,
                        onTap: widget.onClearFilters!,
                        tooltip: "Limpar Filtros",
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          );
        }),
      ),

      // 4. Filters Divider and List
      if (widget.filters.isNotEmpty) ...[
        const SizedBox(width: 8),
        Container(height: 24, width: 1, color: Colors.white24),
        const SizedBox(width: 8),
        ...widget.filters.map((item) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _SincroFilterChip(item: item),
            )),
      ],
    ];
  }

  Widget _buildUnifiedActions() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      // Use Center alignment in layoutBuilder to ensure children are centered
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment
              .centerLeft, // Change to centerLeft for predictable alignment
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axis: Axis.horizontal,
        axisAlignment: -1.0,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: widget.isSelectionMode
          ? _buildSelectionModeActions()
          : _buildNormalModeActions(),
    );
  }

  Widget _buildSelectionModeActions() {
    return Row(
      key: const ValueKey('selection_mode_actions'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Select All Button
        _SincroActionButton(
          icon: widget.isAllSelected
              ? Icons.check_box
              : Icons.check_box_outline_blank,
          label: "Todos",
          isActive: widget.isAllSelected,
          onTap: widget.onToggleSelectAll ?? () {},
          activeColor: Colors.deepPurple,
          forceFill: widget.isAllSelected,
          overrideColor: Colors.white,
        ),
        const SizedBox(width: 8),
        // 2. Delete Button
        // Use SizedBox to enforce height and alignment
        SizedBox(
          height: 30,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axis: Axis.horizontal,
              axisAlignment: -1.0,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: widget.selectedCount > 0
                ? Padding(
                    key: const ValueKey('delete_btn'),
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _SincroActionButton(
                      icon: Icons.delete_outline,
                      label: "Excluir",
                      isActive: true,
                      onTap: widget.onDeleteSelected ?? () {},
                      activeColor: Colors.redAccent,
                      forceFill: true,
                      useWhiteBorderOnActive: true,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        // 3. Clear Filters removed from here since it's global now
        const SizedBox.shrink(),

        // 4. Close
        _SincroActionButton(
          icon: Icons.close,
          isActive: true,
          activeColor: Colors.white,
          disableBackground: true,
          overrideColor: Colors.white,
          onTap: widget.onToggleSelectionMode ?? () {},
          isCircular: true,
        ),
      ],
    );
  }

  Widget _buildNormalModeActions() {
    return Row(
      key: const ValueKey('normal_mode_actions'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Note: Search Bar is handled in parent build method (padded by parent)

        // 1. Selection Toggle
        _SincroActionButton(
          icon: Icons.checklist,
          isActive: false,
          onTap: widget.onToggleSelectionMode ?? () {},
          tooltip: "Selecionar Itens",
        ),

        // 2. Clear Filters moved out of here to global position.
      ],
    );
  }

  Widget _buildSearchRow({required bool isDesktop}) {

    return TapRegion(
      onTapOutside: (event) {
        if (_isSearchOpen) {
          // Ignora se o tap foi no botão de pesquisa (ele já faz toggle)
          final searchBtnBox = _searchButtonKey.currentContext
              ?.findRenderObject() as RenderBox?;
          if (searchBtnBox != null) {
            final localPos = searchBtnBox.globalToLocal(event.position);
            if (searchBtnBox.paintBounds.contains(localPos)) return;
          }
          _toggleSearch();
        }
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: _isSearchOpen
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          autofocus: true,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Pesquisar...',
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: widget.onSearchChanged,
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleSearch,
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SincroActionButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? activeColor;
  final bool isCircular;
  final bool useGreyishStyle;
  final bool forceFill;
  final bool useWhiteBorderOnActive;
  final Color? overrideColor;
  final bool disableBackground;

  const _SincroActionButton({
    super.key,
    required this.icon,
    this.label,
    this.isActive = false,
    required this.onTap,
    this.tooltip,
    this.activeColor,
    this.isCircular = false,
    this.useGreyishStyle = false,
    this.forceFill = false,
    this.useWhiteBorderOnActive = false,
    this.overrideColor,
    this.disableBackground = false,
  });

  @override
  State<_SincroActionButton> createState() => _SincroActionButtonState();
}

class _SincroActionButtonState extends State<_SincroActionButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final Color baseContentColor =
        Colors.white.withValues(alpha: 0.5); // Greyish default

    // Content Color (Icon/Text) - Unaffected by hover, depends on state/override
    Color contentColor = widget.overrideColor ??
        (widget.isActive ? Colors.white : baseContentColor);

    // Border Color - Changes to Purple on Hover
    Color borderColor = _isHovering ? AppColors.primary : contentColor;

    // Fill Logic:
    Color? bgColor = Colors.transparent;
    if (!widget.disableBackground) {
      if (widget.forceFill && widget.activeColor != null) {
        bgColor = widget.activeColor!.withValues(alpha: 0.2);
      } else if (widget.isActive) {
        bgColor = (widget.activeColor ?? Colors.white).withValues(alpha: 0.1);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 30, // Enforce 30px height
            // Enforce 30px width if it is a circular/icon-only button.
            width: (widget.label == null || widget.isCircular) ? 30 : null,
            padding: EdgeInsets.symmetric(
              horizontal: (widget.label != null && !widget.isCircular) ? 12 : 0,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  widget.isCircular ? null : BorderRadius.circular(100),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              shape: widget.isCircular ? BoxShape.circle : BoxShape.rectangle,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: contentColor),
                if (widget.label != null && !widget.isCircular) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label!,
                    style: TextStyle(
                      color: contentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SincroFilterChip extends StatelessWidget {
  final SincroFilterItem item;

  const _SincroFilterChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final isSelected = item.isSelected;

    Color bgColor = AppColors.primary;
    if (isSelected) {
      bgColor = item.activeColor ?? AppColors.primary;
    }

    return Tooltip(
      message: item.label,
      child: GestureDetector(
        key: item.key,
        onTap: item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          height: 30,
          width: isSelected ? null : 30,
          padding: isSelected
              ? const EdgeInsets.symmetric(horizontal: 12)
              : EdgeInsets.zero,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            shape: isSelected ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isSelected ? BorderRadius.circular(100) : null,
            border:
                isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: Colors.white,
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact scroll arrow button with purple hover for the filter toolbar.
class _ScrollArrowButton extends StatefulWidget {
  final AxisDirection direction;
  final VoidCallback onTap;

  const _ScrollArrowButton({required this.direction, required this.onTap});

  @override
  State<_ScrollArrowButton> createState() => _ScrollArrowButtonState();
}

class _ScrollArrowButtonState extends State<_ScrollArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.direction == AxisDirection.left;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: _isHovered ? AppColors.primary : Colors.white54,
            size: 18,
          ),
        ),
      ),
    );
  }
}
