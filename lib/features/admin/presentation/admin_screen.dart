// lib/features/admin/presentation/admin_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/admin/presentation/tabs/admin_dashboard_tab.dart';
import 'package:sincro_app_flutter/features/admin/presentation/tabs/admin_users_tab.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              Icon(Icons.lock_outline,
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

    // UI Admin
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text(
              'Painel Administrativo',
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
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_outlined),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.people_outline),
              text: 'Usuários',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminDashboardTab(userData: widget.userData),
          AdminUsersTab(userData: widget.userData),
        ],
      ),
    );
  }
}
