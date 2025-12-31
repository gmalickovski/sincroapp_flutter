import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';

class PlanSettingsTab extends StatefulWidget {
  final UserModel userData;
  const PlanSettingsTab({super.key, required this.userData});

  @override
  State<PlanSettingsTab> createState() => _PlanSettingsTabState();
}

class _PlanSettingsTabState extends State<PlanSettingsTab> {
  final bool _isLoadingPortal = false;

  @override
  Widget build(BuildContext context) {
    final currentPlan = widget.userData.subscription.plan;
    final planName = PlanLimits.getPlanName(currentPlan);
    
    // Check if running on desktop
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    return SingleChildScrollView(
      padding: isDesktop
          ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
          : const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção do Plano Atual
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isFree = currentPlan == SubscriptionPlan.free;

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
                          if (isFree)
                            SizedBox(
                              width: double.infinity,
                              child: _buildSubscribeButton(context),
                            )
                          else ...[
                            SizedBox(
                              width: double.infinity,
                              child: _buildManageButton(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: _buildViewPlansButton(context),
                            ),
                          ]
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
                            children: isFree
                                ? [_buildSubscribeButton(context)]
                                : [
                                    _buildManageButton(),
                                    const SizedBox(height: 8),
                                    _buildViewPlansButton(context),
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
      onPressed: () async {
        final Uri url = Uri.parse(
            'https://billing.stripe.com/p/login/test_eVq7sN3y5alp4fndNj5c400');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      child: const Text('Gerenciar Assinatura'),
    );
  }

  Widget _buildSubscribeButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final Uri url = Uri.parse(kDebugMode
            ? 'http://localhost:3000/planos-e-precos' // Dev Local
            : 'https://sincroapp.com.br/planos-e-precos'); // Prod
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      child: const Text('Assinar Agora'),
    );
  }

  Widget _buildViewPlansButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final Uri url = Uri.parse(kDebugMode
            ? 'http://localhost:3000/planos-e-precos'
            : 'https://sincroapp.com.br/planos-e-precos');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        foregroundColor: AppColors.primary,
        elevation: 0,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      child: const Text('Ver Planos'),
    );
  }
}
