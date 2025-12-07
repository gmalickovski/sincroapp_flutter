// ... (imports)
import '../../feedback/presentation/feedback_modal.dart';

// ... (inside _SettingsScreenState)

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
      // Feedback is a bit special, it's not a tab but an action.
      // However, to fit the current structure, we might want a separate button in the sidebar 
      // OR a "Help" tab. The user asked for "Area de report".
      // A dedicated button at the bottom of the sidebar is often best.
    ];
  }

  // ... (inside _buildDesktopSidebar)

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
                },
                selected: isSelected,
                selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                hoverColor: AppColors.cardBackground.withValues(alpha: 0.5),
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

// ... (We also need to update Mobile Layout to include it)
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
