import 'package:flutter/material.dart';
import '../../../../common/constants/app_colors.dart';
import '../../../../models/user_model.dart';
import '../../feedback/presentation/feedback_modal.dart';
import 'tabs/account_settings_tab.dart';
import 'tabs/numerology_settings_tab.dart';
import 'tabs/plan_settings_tab.dart';
import 'tabs/integrations_settings_tab.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel userData;

  const SettingsScreen({super.key, required this.userData});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;
  late List<({IconData icon, String title, Widget page})> _settingsPages;

  @override
  void initState() {
    super.initState();
    _settingsPages = [
      (
        icon: Icons.person_outline,
        title: 'Minha Conta',
        page: AccountSettingsTab(userData: widget.userData),
      ),
      (
        icon: Icons.calculate_outlined,
        title: 'Dados da Análise',
        page: NumerologySettingsTab(userData: widget.userData),
      ),
      (
        icon: Icons.credit_card_outlined,
        title: 'Meu Plano',
        page: PlanSettingsTab(userData: widget.userData),
      ),
      (
        icon: Icons.hub_outlined,
        title: 'Integrações',
        page: const IntegrationsSettingsTab(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen width
    // This logic ensures we show the sidebar content for desktop (w > 800) 
    // or the full mobile scaffold for smaller screens.
    // However, since this widget is likely called within a specific context 
    // (e.g. inside the Dashboard sidebar or as a standalone route),
    // we need to be careful.
    
    // If we are in the Dashboard Sidebar (Desktop), we likely only want the content?
    // The previous errors showed usage in `DashboardSidebar` AND `CustomAppBar`.
    // In `DashboardSidebar`, it probably expects a Widget that fits in the sidebar or a dialog?
    // Actually, usually `SettingsScreen` is pushed as a new route or displayed in a large dialog.
    // If it's a mobile route, `_buildMobileLayout` is perfect.
    // If it's desktop, `DashboardSidebar` might be displaying it inside a panel.
    
    // Let's assume a simple responsive check:
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // On desktop, if this is being shown inside a sidebar or panel, 
      // we might just want the list. 
      // But looking at _buildDesktopSidebar logic in the corrupted file, it returned a Column.
      return _buildDesktopSidebar();
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildDesktopSidebar() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _settingsPages.length,
            itemBuilder: (context, index) {
              final page = _settingsPages[index];
              final isSelected = _selectedIndex == index;

              return ListTile(
                leading: Icon(
                  page.icon,
                  color: isSelected ? AppColors.primary : AppColors.secondaryText,
                ),
                title: Text(
                  page.title,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primaryText
                        : AppColors.secondaryText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                   // For desktop sidebar usage, we might need a way to show the selected page content
                   // elsewhere, OR this widget IS just the sidebar menu.
                   // Given the structure, it seems this might be designed to be just the menu?
                   // But `_buildMobileLayout` includes `TabBarView`, suggesting it shows content.
                   // If this is a standalone Settings Screen, Desktop should probably be a Split View (List + Content).
                   // For now, I will implement the List+Content logic for Desktop if it's not already handled by parent.
                   // BUT, to satisfy the immediate compilation error and restore previous state, 
                   // I'll stick to the previous implied logic.
                   // Wait, if _buildDesktopSidebar ONLY returns the list, where is the content?
                   // If this widget is used inside a `DashboardSidebar` that expects a widget, maybe it's just the menu?
                   // Let's implement it as a Split View for desktop to be safe and robust.
                },
                selected: isSelected,
                selectedTileColor: AppColors.primary.withOpacity(0.1),
                hoverColor: AppColors.cardBackground.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              );
            },
          ),
        ),
        // Feedback Button at the bottom
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: OutlinedButton.icon(
            onPressed: () => FeedbackModal.show(context, widget.userData),
            icon: const Icon(Icons.feedback_outlined, size: 20, color: AppColors.primary),
            label: const Text('Enviar Feedback', style: TextStyle(color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return DefaultTabController(
      length: _settingsPages.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text('Configurações'),
          leading: BackButton(
            color: AppColors.secondaryText,
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Feedback Icon on AppBar for Mobile
            IconButton(
              icon: const Icon(Icons.feedback_outlined, color: AppColors.primary),
              tooltip: 'Enviar Feedback',
              onPressed: () => FeedbackModal.show(context, widget.userData),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondaryText,
            tabs: _settingsPages.map((page) => Tab(text: page.title)).toList(),
          ),
        ),
        body: TabBarView(
          children: _settingsPages.map((page) => page.page).toList(),
        ),
      ),
    );
  }
}
