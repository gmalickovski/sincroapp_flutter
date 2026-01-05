import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/dashboard/presentation/dashboard_screen.dart';

class AdminSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  // Admin sidebar is always expanded on desktop for now, matching the requested image 
  // where it looks like a permanent sidebar. Or we can make it collapsible if desired.
  // The images show a wide sidebar.
  final bool _isExpanded = true; 

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xff111827), // Dark background matching Dashboard
        border: Border(
          right: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5), 
            width: 1
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary, // Solid primary color for logo bg
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sincro Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  index: 0,
                  isSelected: widget.selectedIndex == 0,
                  onTap: () => widget.onItemSelected(0),
                ),
                const SizedBox(height: 8),
                _buildNavItem(
                  icon: Icons.people_outline,
                  label: 'Usuários',
                  index: 1,
                  isSelected: widget.selectedIndex == 1,
                  onTap: () => widget.onItemSelected(1),
                ),
              ],
            ),
          ),
          
          // Bottom Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            child: Column(
              children: [
                const Divider(color: Color(0x804B5563), height: 1),
                const SizedBox(height: 16),
                
                // Back to App Button
                _buildNavItem(
                  icon: Icons.arrow_back,
                  label: 'Voltar para o App',
                  index: 98,
                  isSelected: false,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                
                // Logout Button
                _buildNavItem(
                  icon: Icons.logout,
                  label: 'Sair',
                  index: 99,
                  isSelected: false,
                  isLogout: true,
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return _SidebarItem(
      icon: icon,
      text: label,
      isSelected: isSelected,
      isLogout: isLogout,
      onTap: onTap,
    );
  }
}

// Internal Item Widget (Ported from DashboardSidebar for consistency)
class _SidebarItem extends StatefulWidget {
  final VoidCallback onTap;
  final bool isSelected;
  final bool isLogout;
  final IconData icon;
  final String text;

  const _SidebarItem({
    required this.onTap,
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
    Color? hoverTextColor = Colors.white;

    if (widget.isLogout) {
      textColor = _isHovered ? const Color(0xfff87171) : const Color(0xfffca5a5);
      iconColor = textColor;
      hoverBgColor = const Color(0xff1f2937); // Standard hover background
    } else if (widget.isSelected) {
      textColor = Colors.white;
      iconColor = Colors.white;
      hoverBgColor = const Color(0xff7c3aed);
    } else {
      textColor = const Color(0xff9ca3af); // Gray text for unselected
      iconColor = textColor;
      hoverBgColor = const Color(0xff1f2937); // Dark gray hover
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xff7c3aed) // Purple when selected
                : (_isHovered ? hoverBgColor : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: _isHovered ? hoverTextColor : iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: _isHovered ? hoverTextColor : textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
