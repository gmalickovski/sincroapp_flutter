// lib/common/widgets/dashboard_sidebar.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/settings/presentation/settings_screen.dart';

class DashboardSidebar extends StatelessWidget {
  final bool isExpanded;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final UserModel userData;

  const DashboardSidebar({
    super.key,
    required this.isExpanded,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.userData,
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
      width: isExpanded ? 250 : 80, // Largura controlada aqui
      decoration: BoxDecoration(
        color: const Color(0xff111827), // Cor de fundo da sidebar
        border: Border(
          right: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                // Ajusta padding geral da lista
                padding: EdgeInsets.symmetric(
                    vertical: 24, horizontal: isExpanded ? 12 : 8),
                children: List.generate(navItems.length, (index) {
                  return _buildNavItem(
                    context: context,
                    icon: navItems[index]['icon'] as IconData,
                    text: navItems[index]['label'] as String,
                    index: index,
                  );
                }),
              ),
            ),
            // Divisor e itens inferiores
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isExpanded ? 12.0 : 8.0), // Padding condicional
              child: const Divider(color: Color(0x804B5563), height: 1),
            ),
            const SizedBox(height: 8),
            _buildNavItem(
              context: context,
              icon: Icons.settings_outlined,
              text: 'Configurações',
              index: 98,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => SettingsScreen(userData: userData),
                ));
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.logout,
              text: 'Sair',
              index: 99,
              isLogout: true,
              onTap: () async {/* ... Lógica de confirmação e logout ... */},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper (sem alterações)
  Widget _buildNavItem({
    required BuildContext context,
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

// Widget interno para o item da Sidebar (COM CORREÇÃO DE PADDING)
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
    // Define cores (sem alterações)
    Color textColor;
    Color iconColor;
    Color? hoverBgColor;
    Color? hoverTextColor = Colors.white;
    if (widget.isLogout) {
      textColor =
          _isHovered ? const Color(0xfff87171) : const Color(0xfffca5a5);
      iconColor = textColor;
      hoverBgColor = const Color(0x33ef4444);
    } else if (widget.isSelected) {
      textColor = Colors.white;
      iconColor = Colors.white;
      hoverBgColor = const Color(0xff7c3aed);
    } else {
      textColor = const Color(0xff9ca3af);
      iconColor = textColor;
      hoverBgColor = const Color(0xff1f2937);
    }

    // *** Define padding condicional ***
    final EdgeInsets itemPadding = widget.isExpanded
        ? const EdgeInsets.symmetric(
            horizontal: 12) // Padding original quando expandido
        : EdgeInsets.zero; // Sem padding horizontal quando recolhido

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
          // *** USA O PADDING CONDICIONAL ***
          padding: itemPadding,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xff7c3aed) // Roxo se selecionado
                : (_isHovered ? hoverBgColor : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          // Garante que o conteúdo (Row) também se centralize quando recolhido
          alignment: Alignment.center, // <<< Adicionado alignment aqui
          child: Row(
            // Centraliza o ícone se estiver recolhido
            mainAxisAlignment: widget.isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            mainAxisSize: MainAxisSize
                .min, // <<< Adicionado para Row encolher ao redor do conteúdo
            children: [
              Icon(widget.icon,
                  size: 20, color: _isHovered ? hoverTextColor : iconColor),
              // Mostra o texto apenas se estiver expandido
              if (widget.isExpanded)
                Expanded(
                  // Mantém Expanded para overflow do texto
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: widget.isExpanded ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0), // Padding só no texto
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: _isHovered ? hoverTextColor : textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
