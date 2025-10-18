// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'tabs/account_settings_tab.dart';
import 'tabs/integrations_settings_tab.dart';
import 'tabs/numerology_settings_tab.dart';
import 'tabs/plan_settings_tab.dart';

class SettingsScreen extends StatelessWidget {
  final UserModel userData;

  const SettingsScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // ATUALIZADO: Agora temos 4 abas
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
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondaryText,
            tabs: [
              Tab(text: 'Minha Conta'),
              Tab(text: 'Dados da Análise'),
              Tab(text: 'Meu Plano'),
              Tab(text: 'Integrações'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AccountSettingsTab(userData: userData),
            NumerologySettingsTab(userData: userData),
            PlanSettingsTab(userData: userData),
            const IntegrationsSettingsTab(),
          ],
        ),
      ),
    );
  }
}
