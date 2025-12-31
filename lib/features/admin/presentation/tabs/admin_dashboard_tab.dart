// lib/features/admin/presentation/tabs/admin_dashboard_tab.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart'; // MIGRATED
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/admin/presentation/widgets/admin_financial_card.dart';

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
  final SupabaseService _supabaseService = SupabaseService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = _supabaseService.getAdminStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1000;

    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoadingSpinner());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }

        final stats = snapshot.data ?? {};
        final int totalUsers = stats['totalUsers'] ?? 0;
        final int freeUsers = stats['freeUsers'] ?? 0;
        final int plusUsers = stats['plusUsers'] ?? 0;
        final int premiumUsers = stats['premiumUsers'] ?? 0;
        final int activeSubscriptions = stats['activeSubscriptions'] ?? 0;
        final double mrr = (stats['estimatedMRR'] ?? 0.0).toDouble();
        final double arr = mrr * 12;

        final int paidUsers = plusUsers + premiumUsers;
        final double conversionRate =
            totalUsers > 0 ? (paidUsers / totalUsers) * 100 : 0.0;

        return RefreshIndicator(
          onRefresh: () async {
            _refreshStats();
            await _statsFuture;
          },
          child: ListView(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            children: [
              // 1. KPI Cards Row
              _buildKpiGrid(
                totalUsers: totalUsers,
                mrr: mrr,
                arr: arr,
                conversionRate: conversionRate,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 32),

              // 2. Financial Analysis
              // Note: AdminFinancialCard may need migration if it fetches data, checking that next.
              // For now passing stats map which should be compatible if keys match.
              AdminFinancialCard(stats: stats, isDesktop: isDesktop),
              const SizedBox(height: 32),

              // 3. Charts & Breakdown Row
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildPlanDistributionChart(
                        free: freeUsers,
                        plus: plusUsers,
                        premium: premiumUsers,
                        total: totalUsers,
                        isDesktop: isDesktop,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: _buildSubscriptionStatus(
                        active: activeSubscriptions,
                        expired: stats['expiredSubscriptions'] ?? 0,
                      ),
                    ),
                  ],
                )
              else ...[
                _buildPlanDistributionChart(
                  free: freeUsers,
                  plus: plusUsers,
                  premium: premiumUsers,
                  total: totalUsers,
                  isDesktop: isDesktop,
                ),
                const SizedBox(height: 24),
                _buildSubscriptionStatus(
                  active: activeSubscriptions,
                  expired: stats['expiredSubscriptions'] ?? 0,
                ),
              ],

              const SizedBox(height: 32),

              // 4. Site Control
              _buildSiteControlSection(isDesktop),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiGrid({
    required int totalUsers,
    required double mrr,
    required double arr,
    required double conversionRate,
    required bool isDesktop,
  }) {
    final cards = [
      _buildStatCard(
        title: 'Total Usuários',
        value: totalUsers.toString(),
        icon: Icons.people_alt_outlined,
        color: Colors.blue,
        trend: '+12% este mês', // Placeholder trend
        trendUp: true,
      ),
      _buildStatCard(
        title: 'MRR (Mensal)',
        value: _currencyFormat.format(mrr),
        icon: Icons.attach_money,
        color: Colors.green,
        trend: '+5% este mês',
        trendUp: true,
      ),
      _buildStatCard(
        title: 'ARR (Anual)',
        value: _currencyFormat.format(arr),
        icon: Icons.trending_up,
        color: Colors.purple,
        trend: 'Projeção',
        trendUp: true,
      ),
      _buildStatCard(
        title: 'Conversão',
        value: '${conversionRate.toStringAsFixed(1)}%',
        icon: Icons.pie_chart_outline,
        color: Colors.orange,
        trend: 'Média do setor: 3%',
        trendUp: conversionRate > 3,
      ),
    ];

    
    if (isDesktop) {
       return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: c))).toList(),
       );
    } else {
       // Grid layout for mobile (2x2) is often better than single column for KPIs
       return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          children: cards,
       );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    required bool trendUp,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              // Trend indicator removed for cleaner look or simpler approach on mobile
              // Re-adding if needed
            ],
          ),
          /* const SizedBox(height: 12), */
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPlanDistributionChart({
    required int free,
    required int plus,
    required int premium,
    required int total,
    required bool isDesktop,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Distribuição de Planos',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          if (isDesktop)
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: total > 0 ? RepaintBoundary(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildPieSections(free, plus, premium, total),
                        ),
                      ),
                    ) : const Center(child: Text("Sem dados")),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem('Essencial (Free)', free, Colors.grey.shade400),
                        const SizedBox(height: 12),
                        _buildLegendItem('Desperta (Plus)', plus, Colors.blue.shade400),
                        const SizedBox(height: 12),
                        _buildLegendItem('Sinergia (Premium)', premium, Colors.purple.shade400),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 200,
                  child: total > 0 ? RepaintBoundary(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildPieSections(free, plus, premium, total),
                      ),
                    ),
                  ) : const Center(child: Text("Sem dados")),
                ),
                const SizedBox(height: 24),
                _buildLegendItem('Essencial (Free)', free, Colors.grey.shade400),
                const SizedBox(height: 12),
                _buildLegendItem('Desperta (Plus)', plus, Colors.blue.shade400),
                const SizedBox(height: 12),
                _buildLegendItem('Sinergia (Premium)', premium, Colors.purple.shade400),
              ],
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(int free, int plus, int premium, int total) {
    if (total == 0) return [];
    
    return [
      if (free > 0)
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: free.toDouble(),
          title: '${((free / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (plus > 0)
        PieChartSectionData(
          color: Colors.blue.shade400,
          value: plus.toDouble(),
          title: '${((plus / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (premium > 0)
        PieChartSectionData(
          color: Colors.purple.shade400,
          value: premium.toDouble(),
          title: '${((premium / total) * 100).toStringAsFixed(0)}%',
          radius: 60, // Highlight premium
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSubscriptionStatus({required int active, required int expired}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status das Assinaturas',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildStatusRow('Ativas', active, Colors.green),
          const SizedBox(height: 16),
          _buildStatusRow('Expiradas / Canceladas', expired, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteControlSection(bool isDesktop) {
    // Usando FutureBuilder ou StreamBuilder do Supabase
    return StreamBuilder<Map<String, dynamic>>(
      stream: _supabaseService.getSiteSettingsStream(),
      builder: (context, siteSnapshot) {
        if (!siteSnapshot.hasData) return const SizedBox.shrink();
        final siteData = siteSnapshot.data!;
        return _SiteControlCard(
          currentStatus: siteData['status'] ?? 'active',
          currentPassword: siteData['bypassPassword'] ?? '',
          isDesktop: isDesktop,
          onSave: (status, password) async {
            await _supabaseService.updateSiteSettings(
              status: status,
              bypassPassword: password,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configurações atualizadas!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _SiteControlCard extends StatefulWidget {
  final String currentStatus;
  final String currentPassword;
  final bool isDesktop;
  final Function(String, String) onSave;

  const _SiteControlCard({
    required this.currentStatus,
    required this.currentPassword,
    required this.isDesktop,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_ethernet, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                'Controle de Acesso (Site)',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (widget.isDesktop)
            Row(
              children: [
                Expanded(
                  child: _buildStatusField(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPasswordField(),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const SizedBox(height: 28),
                    _buildSaveButton(),
                  ],
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _buildSaveButton(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status', style: TextStyle(color: AppColors.secondaryText)),
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
                DropdownMenuItem(value: 'active', child: Text('Ativo (Online)')),
                DropdownMenuItem(value: 'maintenance', child: Text('Manutenção')),
                DropdownMenuItem(value: 'construction', child: Text('Em Construção')),
              ],
              onChanged: (v) => setState(() => _selectedStatus = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Senha Bypass', style: TextStyle(color: AppColors.secondaryText)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          style: const TextStyle(color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'Senha...',
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              await widget.onSave(_selectedStatus, _passwordController.text);
              setState(() => _isLoading = false);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: _isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Salvar', style: TextStyle(color: Colors.white)),
    );
  }
}
