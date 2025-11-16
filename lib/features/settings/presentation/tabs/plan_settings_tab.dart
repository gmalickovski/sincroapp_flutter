// lib/features/settings/presentation/tabs/plan_settings_tab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';

class PlanSettingsTab extends StatelessWidget {
  final UserModel userData;
  const PlanSettingsTab({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    // Lógica simples para determinar o plano (em um app real, isso viria do backend)
    const String currentPlan = "Plano Gratuito";
    const bool isFreePlan = true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Plano Atual',
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  currentPlan,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.subscription,
                      arguments: {'user': userData},
                    );
                  },
                  child: const Text('Gerenciar Assinatura'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isFreePlan)
            _buildUpgradeCard(
              title: 'SincroApp Plus',
              price: 'R\$ 19,90/mês',
              features: [
                'Análises ilimitadas',
                'Insights diários personalizados com IA',
                'Integração com Google Agenda',
                'Relatórios avançados',
                'Suporte prioritário',
              ],
              onUpgrade: () {
                // Adicionar lógica para iniciar o fluxo de upgrade
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget content}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildUpgradeCard({
    required String title,
    required String price,
    required List<String> features,
    required VoidCallback onUpgrade,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.cardBackground.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Divider(height: 32, color: AppColors.border),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onUpgrade,
            child: const Text('Fazer Upgrade para o Plus'),
          ),
        ],
      ),
    );
  }
}
