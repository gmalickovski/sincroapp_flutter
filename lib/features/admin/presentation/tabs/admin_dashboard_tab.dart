// lib/features/admin/presentation/tabs/admin_dashboard_tab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:intl/intl.dart';

class AdminDashboardTab extends StatefulWidget {
  final UserModel userData;

  const AdminDashboardTab({
    super.key,
    required this.userData,
  });

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return StreamBuilder<Map<String, dynamic>>(
      stream: _firestoreService.getAdminStatsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoadingSpinner());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar estatísticas',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 16),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'Nenhum dado disponível',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          );
        }

        final stats = snapshot.data!;
        final int totalUsers = stats['totalUsers'] ?? 0;
        final int freeUsers = stats['freeUsers'] ?? 0;
        final int plusUsers = stats['plusUsers'] ?? 0;
        final int premiumUsers = stats['premiumUsers'] ?? 0;
        final int activeSubscriptions = stats['activeSubscriptions'] ?? 0;
        final double mrr = stats['estimatedMRR'] ?? 0.0;
        final double arr = mrr * 12;

        final int paidUsers = plusUsers + premiumUsers;
        final double conversionRate =
            totalUsers > 0 ? (paidUsers / totalUsers) * 100 : 0.0;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Força rebuild do stream
          },
          child: ListView(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            children: [
              // Header com informações principais
              _buildMainStatsRow(
                totalUsers: totalUsers,
                mrr: mrr,
                arr: arr,
                conversionRate: conversionRate,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 24),

              // Breakdown por plano
              _buildPlanBreakdown(
                freeUsers: freeUsers,
                plusUsers: plusUsers,
                premiumUsers: premiumUsers,
                totalUsers: totalUsers,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 24),

              // Status de assinaturas
              _buildSubscriptionStatus(
                activeSubscriptions: activeSubscriptions,
                expiredSubscriptions: stats['expiredSubscriptions'] ?? 0,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 24),

              // Controle do Site (Novo)
              StreamBuilder<Map<String, dynamic>>(
                stream: _firestoreService.getSiteSettingsStream(),
                builder: (context, siteSnapshot) {
                  if (!siteSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final siteData = siteSnapshot.data!;
                  return _SiteControlCard(
                    currentStatus: siteData['status'] ?? 'active',
                    currentPassword: siteData['bypassPassword'] ?? '',
                    onSave: (status, password) async {
                      await _firestoreService.updateSiteSettings(
                        status: status,
                        bypassPassword: password,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Configurações do site atualizadas!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainStatsRow({
    required int totalUsers,
    required double mrr,
    required double arr,
    required double conversionRate,
    required bool isDesktop,
  }) {
    return isDesktop
        ? Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total de Usuários',
                  value: totalUsers.toString(),
                  icon: Icons.people,
                  color: Colors.blue.shade400,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'MRR (Receita Mensal)',
                  value: _currencyFormat.format(mrr),
                  icon: Icons.attach_money,
                  color: Colors.green.shade400,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'ARR (Receita Anual)',
                  value: _currencyFormat.format(arr),
                  icon: Icons.trending_up,
                  color: Colors.purple.shade400,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Taxa de Conversão',
                  value: '${conversionRate.toStringAsFixed(1)}%',
                  icon: Icons.percent,
                  color: Colors.orange.shade400,
                ),
              ),
            ],
          )
        : Column(
            children: [
              _buildStatCard(
                title: 'Total de Usuários',
                value: totalUsers.toString(),
                icon: Icons.people,
                color: Colors.blue.shade400,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'MRR (Receita Mensal)',
                value: _currencyFormat.format(mrr),
                icon: Icons.attach_money,
                color: Colors.green.shade400,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'ARR (Receita Anual)',
                value: _currencyFormat.format(arr),
                icon: Icons.trending_up,
                color: Colors.purple.shade400,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Taxa de Conversão',
                value: '${conversionRate.toStringAsFixed(1)}%',
                icon: Icons.percent,
                color: Colors.orange.shade400,
              ),
            ],
          );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBreakdown({
    required int freeUsers,
    required int plusUsers,
    required int premiumUsers,
    required int totalUsers,
    required bool isDesktop,
  }) {
    final freePercentage =
        totalUsers > 0 ? (freeUsers / totalUsers) * 100 : 0.0;
    final plusPercentage =
        totalUsers > 0 ? (plusUsers / totalUsers) * 100 : 0.0;
    final premiumPercentage =
        totalUsers > 0 ? (premiumUsers / totalUsers) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Distribuição por Plano',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPlanRow(
            planName: 'Sincro Essencial (Gratuito)',
            count: freeUsers,
            percentage: freePercentage,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          _buildPlanRow(
            planName: 'Sincro Desperta',
            count: plusUsers,
            percentage: plusPercentage,
            color: Colors.blue.shade400,
          ),
          const SizedBox(height: 16),
          _buildPlanRow(
            planName: 'Sincro Sinergia (Premium)',
            count: premiumUsers,
            percentage: premiumPercentage,
            color: Colors.purple.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRow({
    required String planName,
    required int count,
    required double percentage,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        final titleStyle = TextStyle(
          color: AppColors.primaryText,
          fontSize: isNarrow ? 15 : 16,
        );
        final valueStyle = TextStyle(
          color: color,
          fontSize: isNarrow ? 15 : 16,
          fontWeight: FontWeight.bold,
        );

        Widget header;
        if (isNarrow) {
          // Em telas estreitas, empilha para evitar overflow
          header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(planName, style: titleStyle),
              const SizedBox(height: 6),
              Text(
                '$count usuários (${percentage.toStringAsFixed(1)}%)',
                style: valueStyle,
              ),
            ],
          );
        } else {
          header = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count usuários (${percentage.toStringAsFixed(1)}%)',
                style: valueStyle,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionStatus({
    required int activeSubscriptions,
    required int expiredSubscriptions,
    required bool isDesktop,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Status de Assinaturas',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  label: 'Ativas',
                  count: activeSubscriptions,
                  icon: Icons.check_circle,
                  color: Colors.green.shade400,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  label: 'Expiradas',
                  count: expiredSubscriptions,
                  icon: Icons.cancel,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteControlCard extends StatefulWidget {
  final String currentStatus;
  final String currentPassword;
  final Function(String, String) onSave;

  const _SiteControlCard({
    required this.currentStatus,
    required this.currentPassword,
    required this.onSave,
  });

  @override
  State<_SiteControlCard> createState() => _SiteControlCardState();
}

class _SiteControlCardState extends State<_SiteControlCard> {
  late String _selectedStatus;
  late TextEditingController _passwordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _passwordController = TextEditingController(text: widget.currentPassword);
  }

  @override
  void didUpdateWidget(covariant _SiteControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus != widget.currentStatus) {
      _selectedStatus = widget.currentStatus;
    }
    if (oldWidget.currentPassword != widget.currentPassword) {
      _passwordController.text = widget.currentPassword;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_ethernet, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Controle de Acesso do Site',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive layout: Column on mobile, Row on desktop
              if (constraints.maxWidth < 800) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusDropdown(),
                    const SizedBox(height: 16),
                    _buildPasswordInput(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildStatusDropdown()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildPasswordInput()),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: Column(
                      children: [
                        const SizedBox(height: 28),
                        _buildSaveButton(),
                      ],
                    )),
                  ],
                );
              }
            },
          ),
          if (_selectedStatus != 'active') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade400, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O site está em modo restrito. Visitantes serão redirecionados. Use a senha definida para acessar a versão normal.',
                      style: TextStyle(
                          color: Colors.orange.shade400, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status do Site',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              isExpanded: true,
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: AppColors.primaryText),
              items: const [
                DropdownMenuItem(
                  value: 'active',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('Ativo (Landing Page)'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'maintenance',
                  child: Row(
                    children: [
                      Icon(Icons.build,
                          color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text('Manutenção'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'construction',
                  child: Row(
                    children: [
                      Icon(Icons.construction,
                          color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('Em Construção'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Senha de Acesso (Bypass)',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          style: const TextStyle(color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'Senha para ver o site...',
            hintStyle:
                const TextStyle(color: AppColors.secondaryText),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () async {
                setState(() => _isLoading = true);
                await widget.onSave(
                  _selectedStatus,
                  _passwordController.text,
                );
                setState(() => _isLoading = false);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Salvar'),
      ),
    );
  }
}
