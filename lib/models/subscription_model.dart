// lib/models/subscription_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum para os 3 níveis de plano do SincroApp
enum SubscriptionPlan {
  free, // Sincro Essencial (Gratuito)
  plus, // Sincro Desperta (Intermediário)
  premium, // Sincro Sinergia (Premium)
}

/// Status da assinatura
enum SubscriptionStatus {
  active, // Ativa e válida
  expired, // Expirou
  cancelled, // Cancelada pelo usuário
  trial, // Período de teste
}

/// Ciclo de cobrança
enum BillingCycle {
  monthly,
  annual,
}

/// Modelo de assinatura do usuário
class SubscriptionModel {
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final BillingCycle billingCycle; // Novo campo
  final DateTime? validUntil; // null = permanente (free ou vitalício)
  final DateTime startedAt;
  final int aiSuggestionsUsed; // Contador mensal
  final int aiSuggestionsLimit; // Limite do plano
  final DateTime? lastAiReset; // Última vez que resetou o contador

  const SubscriptionModel({
    required this.plan,
    required this.status,
    this.billingCycle = BillingCycle.monthly, // Default
    this.validUntil,
    required this.startedAt,
    this.aiSuggestionsUsed = 0,
    required this.aiSuggestionsLimit,
    this.lastAiReset,
  });

  /// Cria assinatura gratuita padrão
  factory SubscriptionModel.free() {
    return SubscriptionModel(
      plan: SubscriptionPlan.free,
      status: SubscriptionStatus.active,
      billingCycle: BillingCycle.monthly,
      validUntil: null, // Gratuito não expira
      startedAt: DateTime.now().toUtc(),
      aiSuggestionsUsed: 0,
      aiSuggestionsLimit: 0, // Essencial não tem IA
      lastAiReset: DateTime.now().toUtc(),
    );
  }

  /// Converte de Firestore
  factory SubscriptionModel.fromFirestore(Map<String, dynamic> data) {
    final planName = data['plan'] ?? 'free';
    final plan = SubscriptionPlan.values.firstWhere(
      (e) => e.name == planName,
      orElse: () => SubscriptionPlan.free,
    );
    return SubscriptionModel(
      plan: plan,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'active'),
        orElse: () => SubscriptionStatus.active,
      ),
      billingCycle: BillingCycle.values.firstWhere(
        (e) => e.name == (data['billingCycle'] ?? 'monthly'),
        orElse: () => BillingCycle.monthly,
      ),
      validUntil: data['validUntil'] != null
          ? (data['validUntil'] as Timestamp).toDate().toUtc()
          : null,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate().toUtc()
          : DateTime.now().toUtc(),
      aiSuggestionsUsed: data['aiSuggestionsUsed'] ?? 0,
      aiSuggestionsLimit:
          data['aiSuggestionsLimit'] ?? PlanLimits.getAiLimit(plan),
      lastAiReset: data['lastAiReset'] != null
          ? (data['lastAiReset'] as Timestamp).toDate().toUtc()
          : null,
    );
  }

  /// Converte para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'plan': plan.name,
      'status': status.name,
      'billingCycle': billingCycle.name,
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'startedAt': Timestamp.fromDate(startedAt),
      'aiSuggestionsUsed': aiSuggestionsUsed,
      'aiSuggestionsLimit': aiSuggestionsLimit,
      'lastAiReset':
          lastAiReset != null ? Timestamp.fromDate(lastAiReset!) : null,
    };
  }

  /// Verifica se a assinatura está ativa e válida
  bool get isActive {
    if (status != SubscriptionStatus.active &&
        status != SubscriptionStatus.trial) {
      return false;
    }

    // Se não tem data de validade, é permanente
    if (validUntil == null) return true;

    // Verifica se ainda não expirou
    return DateTime.now().toUtc().isBefore(validUntil!);
  }

  /// Verifica se precisa resetar contador de IA (mensal)
  bool get needsAiReset {
    if (lastAiReset == null) return true;

    final now = DateTime.now().toUtc();
    final lastReset = lastAiReset!;

    // Se passou 1 mês desde o último reset
    return now.year > lastReset.year ||
        (now.year == lastReset.year && now.month > lastReset.month);
  }

  /// Verifica se pode usar IA
  bool get canUseAI {
    if (!isActive) return false;

    // Apenas Sincro Sinergia tem IA ilimitada
    if (plan == SubscriptionPlan.premium) return true;

    // Sincro Desperta: verifica limite (1 por mês)
    if (plan == SubscriptionPlan.plus) {
      return aiSuggestionsUsed < aiSuggestionsLimit;
    }

    // Sincro Essencial: sem IA
    return false;
  }

  /// Retorna quantas sugestões de IA ainda tem disponível
  int get aiSuggestionsRemaining {
    // Sinergia: ilimitado
    if (plan == SubscriptionPlan.premium) return 999;

    // Desperta: retorna quanto sobra do limite mensal
    if (plan == SubscriptionPlan.plus) {
      return (aiSuggestionsLimit - aiSuggestionsUsed)
          .clamp(0, aiSuggestionsLimit);
    }

    // Essencial: sem IA
    return 0;
  }

  /// Copia com modificações
  SubscriptionModel copyWith({
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    BillingCycle? billingCycle,
    DateTime? validUntil,
    DateTime? startedAt,
    int? aiSuggestionsUsed,
    int? aiSuggestionsLimit,
    DateTime? lastAiReset,
  }) {
    return SubscriptionModel(
      plan: plan ?? this.plan,
      status: status ?? this.status,
      billingCycle: billingCycle ?? this.billingCycle,
      validUntil: validUntil ?? this.validUntil,
      startedAt: startedAt ?? this.startedAt,
      aiSuggestionsUsed: aiSuggestionsUsed ?? this.aiSuggestionsUsed,
      aiSuggestionsLimit: aiSuggestionsLimit ?? this.aiSuggestionsLimit,
      lastAiReset: lastAiReset ?? this.lastAiReset,
    );
  }
}

/// Limites de features por plano
class PlanLimits {
  // Limites de Metas/Jornadas
  static const int freeMaxGoals = 5; // Essencial: até 5 metas
  static const int plusMaxGoals = -1; // Desperta: ilimitado
  static const int premiumMaxGoals = -1; // Sinergia: ilimitado

  // Limites de Sugestões de IA (marcos de jornada)
  static const int freeAiSuggestions = 0; // Essencial: sem IA
  static const int plusAiSuggestions = 1; // Desperta: 1 por mês
  static const int premiumAiSuggestions = -1; // Sinergia: ilimitado

  /// Retorna limite de metas para o plano
  static int getGoalsLimit(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return freeMaxGoals;
      case SubscriptionPlan.plus:
        return plusMaxGoals;
      case SubscriptionPlan.premium:
        return premiumMaxGoals;
    }
  }

  /// Retorna limite de sugestões IA para o plano
  static int getAiLimit(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return freeAiSuggestions;
      case SubscriptionPlan.plus:
        return plusAiSuggestions;
      case SubscriptionPlan.premium:
        return premiumAiSuggestions;
    }
  }

  /// Retorna o nome amigável do plano
  static String getPlanName(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Sincro Essencial';
      case SubscriptionPlan.plus:
        return 'Sincro Desperta';
      case SubscriptionPlan.premium:
        return 'Sincro Sinergia';
    }
  }

  /// Retorna o preço mensal do plano (em reais)
  static double getPlanPrice(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 0.0;
      case SubscriptionPlan.plus:
        return 19.90; // Sincro Desperta
      case SubscriptionPlan.premium:
        return 39.90; // Sincro Sinergia
    }
  }

  /// Retorna o preço anual do plano (em reais) com 20% de desconto
  static double getAnnualPrice(SubscriptionPlan plan) {
    final monthlyPrice = getPlanPrice(plan);
    if (monthlyPrice == 0) return 0.0;
    
    // 12 meses com 20% de desconto
    // Preço Anual = Mensal * 12 * 0.8
    return monthlyPrice * 12 * 0.8;
  }

  /// Features disponíveis por plano
  static bool hasFeature(SubscriptionPlan plan, String feature) {
    switch (feature) {
      // Metas ilimitadas: Desperta e Sinergia
      case 'unlimited_goals':
        return plan != SubscriptionPlan.free;

      // Mapa numerológico completo: Desperta e Sinergia
      case 'full_numerology_map':
        return plan != SubscriptionPlan.free;

      // Assistente IA completo: apenas Sinergia
      case 'ai_assistant':
        return plan == SubscriptionPlan.premium;

      // Sugestões de marcos de jornada: Desperta (limitado) e Sinergia (ilimitado)
      case 'ai_journey_suggestions':
        return plan != SubscriptionPlan.free;

      // Insights diários personalizados: apenas Sinergia
      case 'daily_insights':
        return plan == SubscriptionPlan.premium;

      // Integração Google Calendar: Desperta e Sinergia
      case 'google_calendar':
        return plan != SubscriptionPlan.free;

      // Customização do dashboard: Desperta e Sinergia
      case 'dashboard_customization':
        return plan != SubscriptionPlan.free;

      // Tags e filtros avançados: Desperta e Sinergia
      case 'advanced_filters':
        return plan != SubscriptionPlan.free;

      default:
        return true; // Features básicas disponíveis para todos
    }
  }
}
