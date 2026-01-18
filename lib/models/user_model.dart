// lib/models/user_model.dart

import 'package:sincro_app_flutter/models/subscription_model.dart';

class UserModel {
  final String uid;
  final String email;
  final String? photoUrl;
  final String? username; // NOVO: Nome de usuário único para compartilhamento
  final String primeiroNome;
  final String sobrenome;
  final String nomeAnalise;
  final String dataNasc;
  final String plano; // DEPRECATED - usar subscription.plan
  final bool isAdmin;
  final List<String> dashboardCardOrder;
  final List<String> dashboardHiddenCards;
  final SubscriptionModel
      subscription; // NOVO: gerenciamento de planos e features

  UserModel({
    required this.uid,
    required this.email,
    this.photoUrl,
    this.username, // NOVO
    required this.primeiroNome,
    required this.sobrenome,
    required this.nomeAnalise,
    required this.dataNasc,
    required this.plano,
    required this.isAdmin,
    required this.dashboardCardOrder,
    this.dashboardHiddenCards = const [],
    required this.subscription, // NOVO
  });

  // Lista de ordem padrão para novos usuários ou usuários existentes
  static List<String> get defaultCardOrder => [
        'goalsProgress',
        'focusDay',
        'vibracaoDia',
        'bussola',
        'vibracaoMes',
        'vibracaoAno',
        'cicloVida',
        // Novos cards do mapa numerológico completo (planos pagos)
        'numeroDestino',
        'numeroExpressao',
        'numeroMotivacao',
        'numeroImpressao',
        'missaoVida',
        'talentoOculto',
        'respostaSubconsciente',
      ];

  factory UserModel.fromMap(Map<String, dynamic> data) {
    // Lógica para dashboardCardOrder
    final List<dynamic> rawOrder =
        data['dashboardCardOrder'] ?? defaultCardOrder;
    final List<String> cardOrder = rawOrder.cast<String>();

    // Lê lista de ocultos, padrão lista vazia
    final List<String> hiddenCards = (data['dashboardHiddenCards'] is List)
        ? List<String>.from(data['dashboardHiddenCards'])
        : <String>[];

    // Lê dados de subscription
    SubscriptionModel subscription;
    if (data['subscription'] != null && data['subscription'] is Map) {
      subscription = SubscriptionModel.fromMap(
        Map<String, dynamic>.from(data['subscription']),
      );
    } else {
      // Cria subscription free padrão para usuários antigos
      subscription = SubscriptionModel.free();
    }

    return UserModel(
      uid: data['uid'] ?? data['id'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      username: data['username'], // NOVO: pode ser null se usuário ainda não criou
      primeiroNome: data['primeiroNome'] ?? '',
      sobrenome: data['sobrenome'] ?? '',
      nomeAnalise: data['nomeAnalise'] ?? '',
      dataNasc: data['dataNasc'] ?? '',
      plano: data['plano'] ?? 'gratuito',
      isAdmin: data['isAdmin'] ?? false,
      dashboardCardOrder: cardOrder,
      dashboardHiddenCards: hiddenCards,
      subscription: subscription,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'photoUrl': photoUrl,
      'username': username, // NOVO
      'primeiroNome': primeiroNome,
      'sobrenome': sobrenome,
      'nomeAnalise': nomeAnalise,
      'dataNasc': dataNasc,
      'isAdmin': isAdmin,
      'dashboardCardOrder': dashboardCardOrder,
      'dashboardHiddenCards': dashboardHiddenCards,
      'subscription': subscription.toFirestore(), // NOVO
    };
  }

  Map<String, dynamic> toJson() => toFirestore();

  // Método 'copyWith' - Permite criar cópias do usuário modificando apenas alguns campos
  UserModel copyWith({
    String? uid,
    String? email,
    String? photoUrl,
    String? username, // NOVO
    String? primeiroNome,
    String? sobrenome,
    String? nomeAnalise,
    String? dataNasc,
    String? plano,
    bool? isAdmin,
    List<String>? dashboardCardOrder,
    List<String>? dashboardHiddenCards,
    SubscriptionModel? subscription,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username, // NOVO
      primeiroNome: primeiroNome ?? this.primeiroNome,
      sobrenome: sobrenome ?? this.sobrenome,
      nomeAnalise: nomeAnalise ?? this.nomeAnalise,
      dataNasc: dataNasc ?? this.dataNasc,
      plano: plano ?? this.plano,
      isAdmin: isAdmin ?? this.isAdmin,
      dashboardCardOrder: dashboardCardOrder ?? this.dashboardCardOrder,
      dashboardHiddenCards: dashboardHiddenCards ?? this.dashboardHiddenCards,
      subscription: subscription ?? this.subscription,
    );
  }

  // --- HELPERS DE FEATURES ---

  /// Verifica se pode usar recursos de IA
  bool get canUseAI => subscription.canUseAI;

  /// Verifica se pode criar uma nova meta
  bool canCreateGoal(int currentGoalsCount) {
    final limit = PlanLimits.getGoalsLimit(subscription.plan);
    if (limit == -1) return true; // Ilimitado
    return currentGoalsCount < limit;
  }

  /// Verifica se tem acesso a numerologia avançada
  bool get hasAdvancedNumerology =>
      PlanLimits.hasFeature(subscription.plan, 'advanced_numerology');

  /// Verifica se pode customizar dashboard
  bool get canCustomizeDashboard =>
      PlanLimits.hasFeature(subscription.plan, 'dashboard_customization');

  /// Verifica se tem acesso a integrações
  bool get hasIntegrations =>
      PlanLimits.hasFeature(subscription.plan, 'integrations');

  /// Nome amigável do plano
  String get planDisplayName => PlanLimits.getPlanName(subscription.plan);

  /// Sugestões de IA restantes
  int get aiSuggestionsRemaining => subscription.aiSuggestionsRemaining;
}
