import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/payment_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/subscription/presentation/widgets/pricing_card.dart';

class SubscriptionScreen extends StatefulWidget {
  final UserModel user;
  const SubscriptionScreen({super.key, required this.user});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingCycle _billingCycle = BillingCycle.monthly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Planos e Assinatura'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1000;
          
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : 16,
              vertical: 32,
            ),
            child: Column(
              children: [
                // Header Section
                const Text(
                  'Escolha o plano ideal para sua jornada',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Desbloqueie todo o potencial da sua evolução com recursos exclusivos.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Toggle Mensal/Anual
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleOption('Mensal', BillingCycle.monthly),
                      _buildToggleOption('Anual', BillingCycle.annual, badge: '20% OFF'),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Pricing Cards
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildCards(context, true),
                  )
                else
                  Column(
                    children: _buildCards(context, false),
                  ),
                  
                const SizedBox(height: 64),
                
                // FAQ ou Informações Adicionais (Opcional)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Dúvidas Frequentes',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Você pode cancelar sua assinatura a qualquer momento. O acesso aos recursos premium continuará até o final do período faturado.',
                        style: TextStyle(color: AppColors.secondaryText),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggleOption(String label, BillingCycle cycle, {String? badge}) {
    final isSelected = _billingCycle == cycle;
    return GestureDetector(
      onTap: () => setState(() => _billingCycle = cycle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context, bool isDesktop) {
    final plans = [
      SubscriptionPlan.free,
      SubscriptionPlan.plus,
      SubscriptionPlan.premium,
    ];

    return plans.map((plan) {
      final isCurrent = widget.user.subscription.plan == plan;
      
      // Lógica de Destaque Dinâmico
      bool isRecommended = false;
      
      switch (widget.user.subscription.plan) {
        case SubscriptionPlan.free:
          // Se for Grátis, destaca Plus e Premium para incentivar upgrade
          if (plan == SubscriptionPlan.plus || plan == SubscriptionPlan.premium) {
            isRecommended = true;
          }
          break;
        case SubscriptionPlan.plus:
          // Se for Plus, destaca Premium para incentivar upgrade
          if (plan == SubscriptionPlan.premium) {
            isRecommended = true;
          }
          break;
        case SubscriptionPlan.premium:
          // Se for Premium, destaca apenas ele mesmo (não incentiva downgrade)
          if (plan == SubscriptionPlan.premium) {
            isRecommended = true;
          }
          break;
      }
      
      final card = PricingCard(
        plan: plan,
        isCurrent: isCurrent,
        isRecommended: isRecommended,
        billingCycle: _billingCycle,
        onSelect: () => _handlePurchase(context, plan),
      );

      if (isDesktop) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: card,
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: card,
        );
      }
    }).toList();
  }

  Future<void> _handlePurchase(BuildContext context, SubscriptionPlan plan) async {
    final service = PaymentService();
    try {
      final ok = await service.purchaseSubscription(
        userId: widget.user.uid,
        plan: plan,
        cycle: _billingCycle,
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
