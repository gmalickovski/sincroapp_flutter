// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'tabs/account_settings_tab.dart';
import 'tabs/integrations_settings_tab.dart';
import 'tabs/numerology_settings_tab.dart';
import 'tabs/plan_settings_tab.dart';

// Definindo um "breakpoint". Telas menores que isso usarão o layout mobile (TabBar).
// Telas maiores usarão o layout desktop (Sidebar + Conteúdo).
const double kDesktopBreakpoint = 720.0;

class SettingsScreen extends StatefulWidget {
  final UserModel userData;

  const SettingsScreen({super.key, required this.userData});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Índice da aba selecionada, usado APENAS no layout de desktop.
  int _selectedIndex = 0;

  // Lista que define nossas páginas de configuração.
  // Usar uma estrutura de dados centralizada facilita a manutenção
  // e a construção de ambos os layouts (mobile e desktop) a partir de uma única fonte.
  late final List<({IconData icon, String title, Widget page})> _settingsPages;

  @override
  void initState() {
    super.initState();
    // Inicializamos a lista de páginas aqui para ter acesso ao `widget.userData`
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
    // LayoutBuilder é o widget chave para criar UIs responsivas.
    // Ele nos dá as 'constraints' (restrições) de espaço do widget pai.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Verificamos a largura da tela para decidir qual layout mostrar.
        if (constraints.maxWidth < kDesktopBreakpoint) {
          // Se a tela for estreita (mobile), usamos o layout com TabBar.
          return _buildMobileLayout(context);
        } else {
          // Se a tela for larga (desktop/web), usamos o layout com Sidebar.
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  // Layout para Mobile (basicamente o seu código original, mas adaptado)
  Widget _buildMobileLayout(BuildContext context) {
    // Usamos o DefaultTabController para sincronizar a TabBar e o TabBarView.
    return DefaultTabController(
      length: _settingsPages.length, // Usamos o tamanho da nossa lista
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
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondaryText,
            // Geramos as abas a partir da nossa lista
            tabs: _settingsPages.map((page) => Tab(text: page.title)).toList(),
          ),
        ),
        body: TabBarView(
          // Geramos as visualizações a partir da nossa lista
          children: _settingsPages.map((page) => page.page).toList(),
        ),
      ),
    );
  }

  // Layout para Desktop/Web (o novo layout "Notion-style")
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Configurações'),
        leading: BackButton(
          color: AppColors.secondaryText,
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Não temos 'bottom' (TabBar) no layout desktop
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. A Sidebar de Navegação (Esquerda)
                Container(
                  width: 260, // Largura fixa para a sidebar
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.border),
                    ),
                    color: AppColors.background, // Sidebar um pouco mais escura
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            const Icon(Icons.settings,
                                color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Configurações',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryText,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _buildDesktopSidebar()),
                    ],
                  ),
                ),

                // 2. A Área de Conteúdo (Direita)
                Expanded(
                  child: Container(
                    color: AppColors.cardBackground,
                    child: Column(
                      children: [
                        // Header da área de conteúdo
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 24),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _settingsPages[_selectedIndex].icon,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _settingsPages[_selectedIndex].title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                                tooltip: 'Fechar',
                              ),
                            ],
                          ),
                        ),
                        // Conteúdo rolável
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: _settingsPages[_selectedIndex].page,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget que constrói a sidebar para o layout desktop
  Widget _buildDesktopSidebar() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _settingsPages.length,
      itemBuilder: (context, index) {
        final page = _settingsPages[index];
        final isSelected = _selectedIndex == index;

        // Usamos ListTile por ser uma forma fácil e bonita de criar
        // itens de menu clicáveis.
        return ListTile(
          leading: Icon(
            page.icon,
            color: isSelected ? AppColors.primary : AppColors.secondaryText,
          ),
          title: Text(
            page.title,
            style: TextStyle(
              color:
                  isSelected ? AppColors.primaryText : AppColors.secondaryText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            // Ao clicar, atualizamos o estado para mudar o índice
            // e reconstruir a área de conteúdo.
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
    );
  }
}
