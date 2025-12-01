import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.cardBackground,
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
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sincro Admin',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          
          // Menu Items
          _buildMenuItem(
            index: 0,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Dashboard',
          ),
          _buildMenuItem(
            index: 1,
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: 'Usuários',
          ),
          
          const Spacer(),
          
          // Bottom Actions
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair', style: TextStyle(color: Colors.red)),
            onTap: () {
              // Handle logout logic if passed or just pop
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(
                    right: BorderSide(color: AppColors.primary, width: 3),
                  )
                : null,
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? AppColors.primary : AppColors.secondaryText,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
