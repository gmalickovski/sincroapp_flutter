// lib/models/admin_stats_model.dart

import 'package:sincro_app_flutter/models/subscription_model.dart';

/// Modelo de estatísticas para o painel admin
class AdminStatsModel {
  final int totalUsers;
  final int freeUsers;
  final int plusUsers;
  final int premiumUsers;
  final int activeSubscriptions;
  final int expiredSubscriptions;
  final double estimatedMRR; // Monthly Recurring Revenue
  final Map<String, int> usersByMonth; // Usuários cadastrados por mês
  final DateTime lastUpdated;

  const AdminStatsModel({
    required this.totalUsers,
    required this.freeUsers,
    required this.plusUsers,
    required this.premiumUsers,
    required this.activeSubscriptions,
    required this.expiredSubscriptions,
    required this.estimatedMRR,
    required this.usersByMonth,
    required this.lastUpdated,
  });

  /// Cria stats vazio/inicial
  factory AdminStatsModel.empty() {
    return AdminStatsModel(
      totalUsers: 0,
      freeUsers: 0,
      plusUsers: 0,
      premiumUsers: 0,
      activeSubscriptions: 0,
      expiredSubscriptions: 0,
      estimatedMRR: 0.0,
      usersByMonth: {},
      lastUpdated: DateTime.now().toUtc(),
    );
  }

  /// Calcula a porcentagem de usuários por plano
  double get freePercentage =>
      totalUsers > 0 ? (freeUsers / totalUsers) * 100 : 0;
  double get plusPercentage =>
      totalUsers > 0 ? (plusUsers / totalUsers) * 100 : 0;
  double get premiumPercentage =>
      totalUsers > 0 ? (premiumUsers / totalUsers) * 100 : 0;

  /// Total de usuários pagantes
  int get paidUsers => plusUsers + premiumUsers;

  /// Taxa de conversão (free -> paid)
  double get conversionRate =>
      totalUsers > 0 ? (paidUsers / totalUsers) * 100 : 0;

  /// Receita anual estimada (MRR * 12)
  double get estimatedARR => estimatedMRR * 12;

  /// Copia com modificações
  AdminStatsModel copyWith({
    int? totalUsers,
    int? freeUsers,
    int? plusUsers,
    int? premiumUsers,
    int? activeSubscriptions,
    int? expiredSubscriptions,
    double? estimatedMRR,
    Map<String, int>? usersByMonth,
    DateTime? lastUpdated,
  }) {
    return AdminStatsModel(
      totalUsers: totalUsers ?? this.totalUsers,
      freeUsers: freeUsers ?? this.freeUsers,
      plusUsers: plusUsers ?? this.plusUsers,
      premiumUsers: premiumUsers ?? this.premiumUsers,
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      expiredSubscriptions: expiredSubscriptions ?? this.expiredSubscriptions,
      estimatedMRR: estimatedMRR ?? this.estimatedMRR,
      usersByMonth: usersByMonth ?? this.usersByMonth,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Modelo simplificado de usuário para lista admin
class AdminUserListItem {
  final String uid;
  final String email;
  final String fullName;
  final SubscriptionPlan plan;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastAccess;

  const AdminUserListItem({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.plan,
    required this.isActive,
    required this.createdAt,
    this.lastAccess,
  });

  String get planName => PlanLimits.getPlanName(plan);
}
