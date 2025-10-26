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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. A Sidebar de Navegação (Esquerda)
          SizedBox(
            width: 260, // Largura fixa para a sidebar
            child: _buildDesktopSidebar(),
          ),
          // Uma divisória visual
          const VerticalDivider(width: 1, color: AppColors.border),

          // 2. A Área de Conteúdo (Direita)
          Expanded(
            // ***** ALTERAÇÃO AQUI *****
            // Trocamos 'Center' por 'Container' com 'alignment: Alignment.topCenter'.
            // Isso alinha o conteúdo ao topo, mas mantém o centramento horizontal.
            child: Container(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                // Exibe a página com base no índice selecionado
                child: _settingsPages[_selectedIndex].page,
              ),
            ),
          ),
        ],
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
          selectedTileColor: AppColors.primary.withOpacity(0.1),
          hoverColor: AppColors.cardBackground.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        );
      },
    );
  }
}
