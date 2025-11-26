import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';

class PricingCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final VoidCallback? onSelect;
  final bool isRecommended;

  const PricingCard({
    super.key,
    required this.plan,
    this.isCurrent = false,
    this.onSelect,
    this.isRecommended = false,
  });

  @override
  State<PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<PricingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name = PlanLimits.getPlanName(widget.plan);
    final price = PlanLimits.getPlanPrice(widget.plan);
    final features = _getFeatures(widget.plan);
    
    // Cores baseadas no plano
    Color planColor;
    Color gradientStart;
    Color gradientEnd;
    
    switch (widget.plan) {
      case SubscriptionPlan.free:
        planColor = Colors.grey;
        gradientStart = Colors.grey.shade800;
        gradientEnd = Colors.grey.shade900;
        break;
      case SubscriptionPlan.plus:
        planColor = AppColors.primary;
        gradientStart = AppColors.primary.withValues(alpha: 0.2);
        gradientEnd = AppColors.cardBackground;
        break;
      case SubscriptionPlan.premium:
        planColor = Colors.amber;
        gradientStart = Colors.amber.withValues(alpha: 0.2);
        gradientEnd = AppColors.cardBackground;
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isCurrent || _isHovered ? planColor : AppColors.border.withValues(alpha: 0.5),
            width: widget.isCurrent || _isHovered ? 2 : 1,
          ),
          boxShadow: [
            if (_isHovered || widget.isRecommended)
              BoxShadow(
                color: planColor.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientStart.withValues(alpha: 0.1),
              gradientEnd.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        _getIcon(widget.plan),
                        color: planColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        name,
                        style: TextStyle(
                          color: widget.isCurrent ? planColor : AppColors.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Preço
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.plan == SubscriptionPlan.free ? 'Grátis' : 'R\$ ${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.plan != SubscriptionPlan.free)
                        const Text(
                          '/mês',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Botão de Ação
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: widget.isCurrent ? null : widget.onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isCurrent 
                            ? AppColors.cardBackground 
                            : planColor,
                        foregroundColor: widget.isCurrent 
                            ? planColor 
                            : (widget.plan == SubscriptionPlan.premium ? Colors.black : Colors.white),
                        elevation: widget.isCurrent ? 0 : 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: widget.isCurrent 
                              ? BorderSide(color: planColor) 
                              : BorderSide.none,
                        ),
                      ),
                      child: Text(
                        widget.isCurrent ? 'Plano Atual' : 'Começar Agora',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Features
                  ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: planColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            
            // Badge de Recomendado
            if (widget.isRecommended)
              Positioned(
                top: -12,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: planColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: planColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'RECOMENDADO',
                    style: TextStyle(
                      color: widget.plan == SubscriptionPlan.premium ? Colors.black : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return Icons.spa_outlined;
      case SubscriptionPlan.plus:
        return Icons.rocket_launch_outlined;
      case SubscriptionPlan.premium:
        return Icons.diamond_outlined;
    }
  }

  List<String> _getFeatures(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return [
          'Até 5 metas ativas',
          'Mapa numerológico básico',
          'Acesso ao calendário lunar',
          'Diário de gratidão simples',
        ];
      case SubscriptionPlan.plus:
        return [
          'Tudo do Essencial, mais:',
          'Metas ilimitadas',
          'Mapa numerológico completo',
          '1 Sugestão de jornada por IA/mês',
          'Integração Google Calendar (em breve)',
          'Customização do dashboard',
        ];
      case SubscriptionPlan.premium:
        return [
          'Tudo do Desperta, mais:',
          'IA Ilimitada (Assistente e Jornadas)',
          'Insights diários personalizados',
          'Relatórios avançados de progresso',
          'Suporte prioritário',
          'Acesso antecipado a novos recursos',
        ];
    }
  }
}
