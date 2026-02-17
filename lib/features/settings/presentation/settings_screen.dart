import 'package:flutter/material.dart';
import '../../../../common/constants/app_colors.dart';
import '../../../../models/user_model.dart';
import '../../feedback/presentation/feedback_modal.dart';
import 'tabs/account_settings_tab.dart';
import 'tabs/numerology_settings_tab.dart';
import 'tabs/plan_settings_tab.dart';
import 'tabs/integrations_settings_tab.dart';
import 'tabs/contacts_settings_tab.dart';
import 'tabs/about_settings_tab.dart'; // NOVO import

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
        icon: Icons.people_outline,
        title: 'Contatos',
        page: ContactsSettingsTab(userData: widget.userData), // NOVO Tab
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
      (
        icon: Icons.info_outline,
        title: 'Sobre o App',
        page: const AboutSettingsTab(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen width
    final isDesktop = MediaQuery.of(context).size.width >=
        720; // Matching the sidebar breakpoint

    if (isDesktop) {
      return _buildDesktopDialog(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildDesktopDialog(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        height: 700,
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
        child: Row(
          children: [
            // Sidebar (Left)
            Container(
              width: 280,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Configurações',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _settingsPages.length,
                      itemBuilder: (context, index) {
                        final page = _settingsPages[index];
                        final isSelected = _selectedIndex == index;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Icon(
                              page.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.secondaryText,
                              size: 22,
                            ),
                            title: Text(
                              page.title,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primaryText
                                    : AppColors.secondaryText,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () => setState(() => _selectedIndex = index),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Content (Right)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content Header
                  Container(
                    // Adjusted padding to match sidebar title padding (horizontal 24)
                    // Reduced vertical padding to 16 to tighten spacing
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Title Removed as per request (redundant with sidebar)
                        // Support Button
                        // Support Button
                        OutlinedButton(
                          onPressed: () =>
                              FeedbackModal.show(context, widget.userData),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Suporte',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16, // Increased font size
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.secondaryText),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                  ),
                  // Content Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _settingsPages[_selectedIndex].page,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // _buildDesktopSidebar removed as it is replaced by _buildDesktopDialog
  // _buildMobileLayout remains below...

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
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(Icons.feedback_outlined,
                    color: AppColors.primary),
                tooltip: 'Enviar Feedback',
                onPressed: () => FeedbackModal.show(context, widget.userData),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondaryText,
            overlayColor: WidgetStateProperty.all(
                Colors.transparent), // Removes the square hover
            splashFactory: NoSplash.splashFactory, // Removes splash effect
            tabs: _settingsPages.map((page) => Tab(text: page.title)).toList(),
          ),
        ),
        body: TabBarView(
          children: _settingsPages
              .map((page) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 16.0),
                    child: page.page,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
