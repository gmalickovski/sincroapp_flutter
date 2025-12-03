// lib/features/admin/presentation/tabs/admin_users_tab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/features/admin/presentation/widgets/user_edit_dialog.dart';

class AdminUsersTab extends StatefulWidget {
  final UserModel userData;

  const AdminUsersTab({
    super.key,
    required this.userData,
  });

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _filterPlan = 'all'; // all, free, plus, premium
  Map<String, Map<String, double>> _userCosts = {};
  final double _usdToBrl = 6.0; // Taxa de câmbio fixa para estimativa
  final double _priceInputPer1M = 0.075; // USD
  final double _priceOutputPer1M = 0.30; // USD

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _firestoreService.getAllUsers();
      await _calculateUserCosts(users); // Calcula custos após carregar usuários
      setState(() {
        _allUsers = users;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar usuários: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _calculateUserCosts(List<UserModel> users) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      // Busca todos os logs do mês atual
      // Nota: Em produção com muitos usuários, isso deve ser paginado ou agregado via Cloud Functions
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('ai_usage_logs')
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      final Map<String, Map<String, double>> costs = {};

      for (var doc in logsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        
        // Suporte a logs antigos e novos
        final int inputTokens = data['estimatedInputTokens'] ?? data['estimatedTokens'] ?? 0;
        final int outputTokens = data['estimatedOutputTokens'] ?? 0;

        final double costUSD = (inputTokens * _priceInputPer1M / 1000000) +
            (outputTokens * _priceOutputPer1M / 1000000);
        final double costBRL = costUSD * _usdToBrl;

        if (!costs.containsKey(userId)) {
          costs[userId] = {'today': 0.0, 'month': 0.0};
        }

        costs[userId]!['month'] = (costs[userId]!['month'] ?? 0.0) + costBRL;

        if (timestamp.isAfter(startOfDay)) {
          costs[userId]!['today'] = (costs[userId]!['today'] ?? 0.0) + costBRL;
        }
      }

      _userCosts = costs;
    } catch (e) {
      debugPrint('Erro ao calcular custos de IA: $e');
    }
  }

  void _applyFilters() {
    String searchTerm = _searchController.text.toLowerCase();
    _filteredUsers = _allUsers.where((user) {
      // Filtro de busca
      bool matchesSearch = searchTerm.isEmpty ||
          user.email.toLowerCase().contains(searchTerm) ||
          user.primeiroNome.toLowerCase().contains(searchTerm) ||
          user.sobrenome.toLowerCase().contains(searchTerm);

      // Filtro de plano
      bool matchesPlan =
          _filterPlan == 'all' || user.subscription.plan.name == _filterPlan;

      return matchesSearch && matchesPlan;
    }).toList();
  }

  void _showEditDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => UserEditDialog(
        user: user,
        onSave: () {
          _loadUsers(); // Recarrega a lista
        },
      ),
    );
  }

  void _confirmDelete(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Confirmar Exclusão',
            style: TextStyle(color: AppColors.primaryText)),
        content: Text(
          'Tem certeza que deseja deletar o usuário ${user.email}?\n\nEsta ação é irreversível e todos os dados do usuário serão perdidos (GDPR compliance).',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(user);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deletar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserModel user) async {
    try {
      await _firestoreService.deleteUserData(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuário ${user.email} deletado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar usuário: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Column(
      children: [
        // Barra de filtros e busca
        Container(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          // decoration: const BoxDecoration(
          //   color: AppColors.cardBackground,
          //   border: Border(
          //     bottom: BorderSide(color: AppColors.border, width: 1),
          //   ),
          // ),
          child: Column(
            children: [
              // Campo de busca
              TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.primaryText),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou email...',
                  hintStyle: const TextStyle(color: AppColors.secondaryText),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.secondaryText),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _applyFilters());
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _applyFilters()),
              ),
              const SizedBox(height: 16),
              // Filtros de plano
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Todos', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Gratuito', 'free'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Desperta', 'plus'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Sinergia', 'premium'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista de usuários
        Expanded(
          child: _isLoading
              ? const Center(child: CustomLoadingSpinner())
              : _filteredUsers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: AppColors.secondaryText),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum usuário encontrado',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.separated(
                        padding: EdgeInsets.all(isDesktop ? 24 : 16),
                        itemCount: _filteredUsers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserCard(user, isDesktop);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _filterPlan == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterPlan = value;
          _applyFilters();
        });
      },
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
        width: 1,
      ),
    );
  }

  Widget _buildUserCard(UserModel user, bool isDesktop) {
    final planColor = _getPlanColor(user.subscription.plan);
    final bool isActiveSubscription = user.subscription.isActive;
    
    final costs = _userCosts[user.uid] ?? {'today': 0.0, 'month': 0.0};
    final costToday = costs['today']!;
    final costMonth = costs['month']!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActiveSubscription
              ? planColor.withValues(alpha: 0.3)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nome + Menu de 3 pontos
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${user.primeiroNome} ${user.sobrenome}',
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
                  color: AppColors.cardBackground,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(user);
                    } else if (value == 'delete') {
                      _confirmDelete(user);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.primary, size: 20),
                          SizedBox(width: 12),
                          Text('Editar', style: TextStyle(color: AppColors.primaryText)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                          const SizedBox(width: 12),
                          const Text('Excluir', style: TextStyle(color: AppColors.primaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Body: Avatar + Dados
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar (esquerda, menor)
                CircleAvatar(
                  radius: 24,
                  backgroundColor: planColor.withValues(alpha: 0.2),
                  child: user.photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            user.photoUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, color: planColor, size: 24),
                          ),
                        )
                      : Icon(Icons.person, color: planColor, size: 24),
                ),
                const SizedBox(width: 12),
                // Dados (direita, ocupa espaço restante)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Badges: Custos IA + Plano + Status
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildCostBadge('Hoje', costToday, Colors.green),
                          _buildCostBadge('Mês', costMonth, Colors.blue),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: planColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: planColor, width: 1),
                            ),
                            child: Text(
                              user.planDisplayName,
                              style: TextStyle(
                                color: planColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isActiveSubscription)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red, width: 1),
                              ),
                              child: const Text(
                                'EXPIRADA',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (user.isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.primary, width: 1),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBadge(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_money, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: R\$ ${value.toStringAsFixed(4)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPlanColor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return Colors.grey.shade400;
      case SubscriptionPlan.plus:
        return Colors.blue.shade400;
      case SubscriptionPlan.premium:
        return Colors.purple.shade400;
    }
  }
}
