// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'tabs/account_settings_tab.dart';
import 'tabs/numerology_settings_tab.dart';

class SettingsScreen extends StatelessWidget {
  final UserModel userData;

  const SettingsScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Por enquanto, 2 abas funcionais
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text('Configurações'),
          leading: const BackButton(color: AppColors.secondaryText),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondaryText,
            tabs: const [
              Tab(text: 'Minha Conta'),
              Tab(text: 'Dados da Análise'),
              // Tab(text: 'Meu Plano'),
              // Tab(text: 'Integrações'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AccountSettingsTab(userData: userData),
            NumerologySettingsTab(userData: userData),
            // Center(child: Text('Gerenciamento de plano em breve...', style: TextStyle(color: AppColors.secondaryText))),
            // Center(child: Text('Integrações em breve...', style: TextStyle(color: AppColors.secondaryText))),
          ],
        ),
      ),
    );
  }
}
