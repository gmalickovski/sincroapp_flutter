// lib/features/subscription/presentation/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/payment_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class SubscriptionScreen extends StatelessWidget {
  final UserModel user;
  const SubscriptionScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final plans = [
      SubscriptionPlan.free,
      SubscriptionPlan.plus,
      SubscriptionPlan.premium,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos e Assinatura'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(user: user),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: plans
                      .map((p) => SizedBox(
                            width: isWide
                                ? (constraints.maxWidth - 32) / 3
                                : constraints.maxWidth,
                            child: _PlanCard(plan: p, user: user),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                _FeatureMatrix(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserModel user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final planName = PlanLimits.getPlanName(user.subscription.plan);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: AppColors.primaryAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Seu plano atual: $planName',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final UserModel user;
  const _PlanCard({required this.plan, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = PlanLimits.getPlanName(plan);
    final price = PlanLimits.getPlanPrice(plan);

    final isCurrent = user.subscription.plan == plan;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.primaryAccent : AppColors.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star,
                  color: plan == SubscriptionPlan.premium
                      ? Colors.amber
                      : AppColors.primaryAccent),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText),
              ),
              const Spacer(),
              if (isCurrent)
                const Chip(
                  label: Text('Atual'),
                  backgroundColor: Color(0x332196F3),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan == SubscriptionPlan.free
                ? 'Gratuito'
                : 'R\$ ${price.toStringAsFixed(2)}/mês',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          _PlanHighlights(plan: plan),
          const SizedBox(height: 12),
          _PlanActionButton(plan: plan, isCurrent: isCurrent, user: user),
        ],
      ),
    );
  }
}

class _PlanHighlights extends StatelessWidget {
  final SubscriptionPlan plan;
  const _PlanHighlights({required this.plan});

  @override
  Widget build(BuildContext context) {
    final goalsLimit = PlanLimits.getGoalsLimit(plan);
    final aiLimit = PlanLimits.getAiLimit(plan);

    String goalsText;
    if (goalsLimit < 0) {
      goalsText = 'Metas ilimitadas';
    } else {
      goalsText = 'Até $goalsLimit metas ativas';
    }

    String aiText;
    if (aiLimit < 0) {
      aiText = 'IA ilimitada (sugestões)';
    } else if (aiLimit == 0) {
      aiText = 'Sem IA (sugestões)';
    } else {
      aiText = '$aiLimit sugestão(ões) de IA/mês';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _li(goalsText, true),
        _li('Mapa numerológico completo',
            PlanLimits.hasFeature(plan, 'full_numerology_map')),
        _li('Sugestões de jornada por IA',
            PlanLimits.hasFeature(plan, 'ai_journey_suggestions')),
        _li('Assistente IA completo',
            PlanLimits.hasFeature(plan, 'ai_assistant')),
        _li('Insights diários personalizados',
            PlanLimits.hasFeature(plan, 'daily_insights')),
        _li('Integração Google Calendar (em breve)',
            PlanLimits.hasFeature(plan, 'google_calendar')),
        _li('Customização do dashboard',
            PlanLimits.hasFeature(plan, 'dashboard_customization')),
        _li('Filtros e tags avançados',
            PlanLimits.hasFeature(plan, 'advanced_filters')),
        const SizedBox(height: 8),
        Text(aiText, style: const TextStyle(color: AppColors.secondaryText)),
      ],
    );
  }

  Widget _li(String text, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: enabled
                    ? AppColors.secondaryText
                    : AppColors.secondaryText.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanActionButton extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final UserModel user;
  const _PlanActionButton({
    required this.plan,
    required this.isCurrent,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check),
        label: const Text('Plano atual'),
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        final service = PaymentService();
        try {
          final ok = await service.purchaseSubscription(
            userId: user.uid,
            plan: plan,
          );
          if (ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Redirecionando para checkout...'),
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
      },
      icon: const Icon(Icons.shopping_cart_checkout),
      label: Text(plan == SubscriptionPlan.plus
          ? 'Assinar Desperta'
          : 'Assinar Sinergia'),
    );
  }
}

class _FeatureMatrix extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = <_FeatureRowData>[
      _FeatureRowData(
        label: 'Metas ativas',
        valueBuilder: (p) {
          final limit = PlanLimits.getGoalsLimit(p);
          return limit < 0 ? 'Ilimitadas' : '$limit';
        },
      ),
      _FeatureRowData(
        label: 'Mapa numerológico completo',
        iconBuilder: (p) =>
            _check(PlanLimits.hasFeature(p, 'full_numerology_map')),
      ),
      _FeatureRowData(
        label: 'Sugestões de jornada (IA)',
        valueBuilder: (p) {
          final limit = PlanLimits.getAiLimit(p);
          if (limit < 0) return 'Ilimitadas';
          if (limit == 0) return '—';
          return '$limit/mês';
        },
      ),
      _FeatureRowData(
        label: 'Assistente IA',
        iconBuilder: (p) => _check(PlanLimits.hasFeature(p, 'ai_assistant')),
      ),
      _FeatureRowData(
        label: 'Insights diários',
        iconBuilder: (p) => _check(PlanLimits.hasFeature(p, 'daily_insights')),
      ),
      _FeatureRowData(
        label: 'Google Calendar (em breve)',
        iconBuilder: (p) => _check(PlanLimits.hasFeature(p, 'google_calendar')),
      ),
      _FeatureRowData(
        label: 'Customização do dashboard',
        iconBuilder: (p) =>
            _check(PlanLimits.hasFeature(p, 'dashboard_customization')),
      ),
      _FeatureRowData(
        label: 'Filtros e tags avançados',
        iconBuilder: (p) =>
            _check(PlanLimits.hasFeature(p, 'advanced_filters')),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Recursos')),
            DataColumn(label: Text('Essencial')),
            DataColumn(label: Text('Desperta')),
            DataColumn(label: Text('Sinergia')),
          ],
          rows: features.map((f) => f.asDataRow()).toList(),
          headingRowColor: WidgetStateProperty.resolveWith(
            (states) => AppColors.border.withOpacity(0.08),
          ),
          dataRowColor: WidgetStateProperty.resolveWith(
            (states) => Colors.transparent,
          ),
        ),
      ),
    );
  }

  static Widget _check(bool enabled) => Icon(
        enabled ? Icons.check : Icons.close,
        color: enabled ? Colors.green : Colors.grey,
        size: 18,
      );
}

class _FeatureRowData {
  final String label;
  final String Function(SubscriptionPlan plan)? valueBuilder;
  final Widget Function(SubscriptionPlan plan)? iconBuilder;

  _FeatureRowData({
    required this.label,
    this.valueBuilder,
    this.iconBuilder,
  });

  DataRow asDataRow() {
    Widget cellFor(SubscriptionPlan p) {
      if (valueBuilder != null) {
        return Text(valueBuilder!(p));
      }
      if (iconBuilder != null) {
        return iconBuilder!(p);
      }
      return const SizedBox.shrink();
    }

    return DataRow(cells: [
      DataCell(Text(label)),
      DataCell(cellFor(SubscriptionPlan.free)),
      DataCell(cellFor(SubscriptionPlan.plus)),
      DataCell(cellFor(SubscriptionPlan.premium)),
    ]);
  }
}
