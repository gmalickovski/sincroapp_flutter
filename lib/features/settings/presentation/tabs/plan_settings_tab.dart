import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/features/subscription/presentation/widgets/pricing_card.dart';
import 'package:sincro_app_flutter/services/payment_service.dart';

class PlanSettingsTab extends StatelessWidget {
  final UserModel userData;
  const PlanSettingsTab({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final currentPlan = userData.subscription.plan;
    final planName = PlanLimits.getPlanName(currentPlan);


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção do Plano Atual
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: isMobile
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.workspace_premium,
                                    color: AppColors.primary, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Seu Plano Atual',
                                      style: TextStyle(
                                        color: AppColors.secondaryText,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      planName,
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.subscription,
                                  arguments: {'user': userData},
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.background,
                                foregroundColor: AppColors.primaryText,
                                elevation: 0,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Gerenciar Assinatura'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.workspace_premium,
                                color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Seu Plano Atual',
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  planName,
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.subscription,
                                arguments: {'user': userData},
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.background,
                              foregroundColor: AppColors.primaryText,
                              elevation: 0,
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: const Text('Gerenciar Assinatura'),
                          ),
                        ],
                      ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Se não for Premium, mostra opção de upgrade
          if (currentPlan != SubscriptionPlan.premium) ...[
            const Text(
              'Faça um Upgrade',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Mostra o próximo plano recomendado
            PricingCard(
              plan: currentPlan == SubscriptionPlan.free 
                  ? SubscriptionPlan.plus 
                  : SubscriptionPlan.premium,
              isRecommended: true,
              onSelect: () => _handleUpgrade(context, currentPlan == SubscriptionPlan.free 
                  ? SubscriptionPlan.plus 
                  : SubscriptionPlan.premium),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleUpgrade(BuildContext context, SubscriptionPlan plan) async {
    final service = PaymentService();
    try {
      final ok = await service.purchaseSubscription(
        userId: userData.uid,
        plan: plan,
      );
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Redirecionando para checkout...'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Falha ao iniciar compra: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}
