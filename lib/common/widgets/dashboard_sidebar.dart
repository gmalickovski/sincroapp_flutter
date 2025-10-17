// lib/common/widgets/dashboard_sidebar.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';

class DashboardSidebar extends StatelessWidget {
  final bool isExpanded;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const DashboardSidebar({
    super.key,
    required this.isExpanded,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'icon': Icons.home_outlined, 'label': 'Rota do Dia'},
      {'icon': Icons.calendar_today_outlined, 'label': 'Agenda'},
      {'icon': Icons.book_outlined, 'label': 'Diário de Bordo'},
      {'icon': Icons.check_box_outlined, 'label': 'Foco do Dia'},
      {'icon': Icons.track_changes_outlined, 'label': 'Jornadas'},
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: isExpanded ? 250 : 80,
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        border: Border(
          right: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1),
        ),
      ),
      // *** SAFEAREA REMOVIDO DAQUI ***
      // O Scaffold na tela principal agora gerencia o espaçamento.
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 24, left: 12, right: 12),
              children: List.generate(navItems.length, (index) {
                return _buildNavItem(
                  icon: navItems[index]['icon'] as IconData,
                  text: navItems[index]['label'] as String,
                  index: index,
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: const Divider(color: Color(0x804b5563), height: 1),
          ),
          const SizedBox(height: 8),
          _buildNavItem(
              icon: Icons.settings_outlined, text: 'Configurações', index: 98),
          _buildNavItem(
              icon: Icons.logout,
              text: 'Sair',
              index: 99,
              isLogout: true,
              onTap: () => AuthRepository().signOut()),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String text,
    required int index,
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    final bool isSelected = selectedIndex == index;
    return _SidebarItem(
      onTap: onTap ?? () => onDestinationSelected(index),
      isExpanded: isExpanded,
      isSelected: isSelected,
      isLogout: isLogout,
      icon: icon,
      text: text,
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final VoidCallback onTap;
  final bool isExpanded;
  final bool isSelected;
  final bool isLogout;
  final IconData icon;
  final String text;

  const _SidebarItem({
    required this.onTap,
    required this.isExpanded,
    required this.isSelected,
    this.isLogout = false,
    required this.icon,
    required this.text,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color iconColor;
    Color? hoverBgColor;
    Color? hoverTextColor;

    if (widget.isLogout) {
      textColor =
          _isHovered ? const Color(0xfff87171) : const Color(0xfffca5a5);
      iconColor = textColor;
      hoverBgColor = const Color(0x33ef4444);
    } else {
      textColor = widget.isSelected ? Colors.white : const Color(0xff9ca3af);
      iconColor = textColor;
      hoverTextColor = Colors.white;
      hoverBgColor = const Color(0xff1f2937);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xff7c3aed)
                : (_isHovered ? hoverBgColor : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  size: 20, color: _isHovered ? hoverTextColor : iconColor),
              if (widget.isExpanded)
                Flexible(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: widget.isExpanded ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: _isHovered ? hoverTextColor : textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
