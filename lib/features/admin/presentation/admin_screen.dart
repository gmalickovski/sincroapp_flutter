// lib/features/admin/presentation/admin_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/admin/presentation/tabs/admin_dashboard_tab.dart';
import 'package:sincro_app_flutter/features/admin/presentation/tabs/admin_users_tab.dart';
import 'package:sincro_app_flutter/features/admin/presentation/tabs/admin_ai_config_tab.dart';

import 'package:sincro_app_flutter/features/admin/presentation/widgets/admin_sidebar.dart';

class AdminScreen extends StatefulWidget {
  final UserModel userData;

  const AdminScreen({
    super.key,
    required this.userData,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  final _usersTabKey = GlobalKey<AdminUsersTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      } else if (_tabController.index == 1) {
        // IndexedStack keeps widgets alive; manually refresh Users tab
        // when the tab animation finishes settling on index 1 (desktop layout).
        _usersTabKey.currentState?.refresh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSidebarSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _tabController.animateTo(index);
    });
    if (index == 1) {
      // Eagerly refresh Users tab when sidebar item is tapped on desktop.
      // The tabController listener also fires, but this ensures immediate refresh
      // even if the animation was already at index 1.
      Future.microtask(() => _usersTabKey.currentState?.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Proteção: só admin pode acessar
    if (!widget.userData.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline,
                  size: 80, color: AppColors.secondaryText),
              const SizedBox(height: 24),
              const Text(
                'Acesso Restrito',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Você não tem permissão para acessar esta área.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  'Voltar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            AdminSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onSidebarSelected,
            ),
            Expanded(
              child: Column(
                children: [
                  // Desktop Header
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      border:
                          Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedIndex == 0
                              ? 'Dashboard'
                              : _selectedIndex == 1
                                  ? 'Gerenciar Usuários'
                                  : 'Configuração de IA',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // User Profile / Actions could go here
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        AdminDashboardTab(userData: widget.userData),
                        AdminUsersTab(
                          key: _usersTabKey,
                          userData: widget.userData,
                        ),
                        const AdminAiConfigTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Layout (Existing)
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            SizedBox(width: 12),
            Text(
              'Painel Admin',
              style: TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.secondaryText,
          // Remove custom height to let it adjust
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_outlined),
                  SizedBox(width: 8),
                  Text('Dashboard'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline),
                  SizedBox(width: 8),
                  Text('Usuários'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology_outlined),
                  SizedBox(width: 8),
                  Text('IA'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminDashboardTab(userData: widget.userData),
          AdminUsersTab(userData: widget.userData),
          const AdminAiConfigTab(),
        ],
      ),
    );
  }
}
