import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/app/routs/app_router.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/features/subscription/presentation/subscription_screen.dart';
import 'package:sincro_app_flutter/services/payment_service.dart';

class PlanSettingsTab extends StatefulWidget {
  final UserModel userData;
  const PlanSettingsTab({super.key, required this.userData});

  @override
  State<PlanSettingsTab> createState() => _PlanSettingsTabState();
}

class _PlanSettingsTabState extends State<PlanSettingsTab> {
  bool _isLoadingPortal = false;

  @override
  Widget build(BuildContext context) {
    final currentPlan = widget.userData.subscription.plan;
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
                            child: _buildManageButton(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: _buildChangePlanButton(context),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildManageButton(),
                              const SizedBox(height: 8),
                              _buildChangePlanButton(context),
                            ],
                          ),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManageButton() {
    return ElevatedButton(
      onPressed: _isLoadingPortal
          ? null
          : () async {
              setState(() => _isLoadingPortal = true);
              try {
                await PaymentService().openCustomerPortal();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao abrir portal: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoadingPortal = false);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      child: _isLoadingPortal
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryText,
              ),
            )
          : const Text('Gerenciar Assinatura'),
    );
  }

  Widget _buildChangePlanButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SubscriptionScreen(user: widget.userData),
          ),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
      child: const Text('Alterar meu plano'),
    );
  }
}
