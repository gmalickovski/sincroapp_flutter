// lib/features/admin/presentation/tabs/admin_users_tab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart'; // MIGRATED
import 'package:sincro_app_flutter/features/admin/presentation/widgets/user_edit_dialog.dart';
import 'package:intl/intl.dart';

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
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  Map<String, int> _userUsage = {}; // Armazena uso de tokens por usuário
  bool _isLoading = true;
  String _filterPlan = 'all'; // all, free, plus, premium
  final double _usdToBrl = 6.0;

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
      // Usando SupabaseService agora
      final users = await _supabaseService.getAllUsers();
      final usage = await _supabaseService.getUserTokenUsageMap();
      
      setState(() {
        _allUsers = users;
        _userUsage = usage;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar usuários (Supabase): $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          'Tem certeza que deseja deletar o usuário ${user.email}?\n\nEsta ação apagará todos os dados do banco (GDPR).',
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
      await _supabaseService.deleteUserData(user.uid);
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
        // Barra de filtros e busca (Repaginada)
        Container(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.primaryText),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome ou email...',
                        hintStyle: const TextStyle(color: AppColors.secondaryText),
                        prefixIcon:
                            const Icon(Icons.search, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: AppColors.secondaryText),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) => setState(() => _applyFilters()),
                    ),
                  ),
                  if (isDesktop) const SizedBox(width: 16),
                ],
              ),
              const SizedBox(height: 16),
              // Filtros de plano (Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Todos', 'all', Icons.people),
                    const SizedBox(width: 8),
                    _buildFilterChip('Gratuito', 'free', Icons.person_outline),
                    const SizedBox(width: 8),
                    _buildFilterChip('Desperta', 'plus', Icons.star_border),
                    const SizedBox(width: 8),
                    _buildFilterChip('Sinergia', 'premium', Icons.diamond_outlined),
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: AppColors.secondaryText.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text(
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
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 8),
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

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final bool isSelected = _filterPlan == value;
    return InkWell(
      onTap: () {
        setState(() {
          _filterPlan = value;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondaryText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, bool isDesktop) {
    final planColor = _getPlanColor(user.subscription.plan);
    final bool isActiveSubscription = user.subscription.isActive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
           BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)
           )
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEditDialog(user),
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Main Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 40, 16), // Right padding for menu button
                child: Row(
                  children: [
                    // Avatar Area using unified UserAvatar
                    Hero(
                      tag: 'avatar_${user.uid}',
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: planColor, width: 2),
                        ),
                        child: UserAvatar(
                          photoUrl: user.photoUrl,
                          firstName: user.primeiroNome,
                          lastName: user.sobrenome,
                          radius: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Info Area
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (user.primeiroNome.isEmpty && user.sobrenome.isEmpty) 
                                     ? 'Usuário Sem Nome' 
                                     : '${user.primeiroNome} ${user.sobrenome}',
                                  style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.isAdmin)
                                 Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('ADMIN', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                 )
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              _buildMiniBadge(
                                user.planDisplayName, 
                                planColor, 
                                isActive: isActiveSubscription
                              ),
                              if (user.subscription.systemPlan != null)
                                 _buildMiniBadge('Sistema (Manual)', Colors.amber.shade700, isActive: true),
                              
                               if (!isActiveSubscription)
                                 _buildMiniBadge('Expirado', Colors.red, isActive: true),
                               
                               if (_userUsage.containsKey(user.uid) && _userUsage[user.uid]! > 0)
                                  _buildMiniBadge('${NumberFormat.compact().format(_userUsage[user.uid])} Tokens', Colors.purple, isActive: true),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Positioned Action Menu at top-right
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.secondaryText, size: 20),
                  padding: EdgeInsets.zero,
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
                          Text('Editar Dados', style: TextStyle(color: AppColors.primaryText)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                          const SizedBox(width: 12),
                          const Text('Excluir Usuário', style: TextStyle(color: AppColors.primaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color, {bool isActive = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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
