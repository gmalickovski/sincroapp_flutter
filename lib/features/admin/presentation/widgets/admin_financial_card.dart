import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class AdminFinancialCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isDesktop;

  const AdminFinancialCard({
    super.key,
    required this.stats,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return StreamBuilder<Map<String, dynamic>>(
      stream: firestoreService.getAdminFinancialSettingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoadingSpinner(size: 24));
        }

        final settings = snapshot.data ?? {};
        
        // --- Extração de Dados ---
        final double mrr = (stats['estimatedMRR'] ?? 0.0).toDouble();
        final int totalUsers = (stats['totalUsers'] ?? 0).toInt();
        final int stripeSubscribers = (stats['stripeSubscribers'] ?? 0).toInt();
        final int storeSubscribers = (stats['storeSubscribers'] ?? 0).toInt();
        // Estimativa de receita por fonte (proporcional ao número de assinantes se não tivermos valor exato)
        final int totalPaid = stripeSubscribers + storeSubscribers;
        final double stripeRevenue = totalPaid > 0 ? (mrr * (stripeSubscribers / totalPaid)) : 0.0;
        final double storeRevenue = totalPaid > 0 ? (mrr * (storeSubscribers / totalPaid)) : 0.0;

        // --- Configurações ---
        final double stripeFeePercent = (settings['stripeFeePercent'] ?? 3.99).toDouble();
        final double stripeFixedFee = (settings['stripeFixedFee'] ?? 0.39).toDouble();
        final double storeFeePercent = (settings['storeFeePercent'] ?? 15.0).toDouble();
        final double aiCostPerUser = (settings['aiCostPerUser'] ?? 0.50).toDouble();
        final double cacPerUser = (settings['cacPerUser'] ?? 5.00).toDouble();
        final double fixedCosts = (settings['fixedCosts'] ?? 100.00).toDouble();
        final double taxRate = (settings['taxRate'] ?? 6.0).toDouble();

        // --- Cálculos ---
        // 1. Taxas de Processamento
        final double stripeFees = (stripeRevenue * (stripeFeePercent / 100)) + (stripeSubscribers * stripeFixedFee);
        final double storeFees = storeRevenue * (storeFeePercent / 100);
        final double totalProcessingFees = stripeFees + storeFees;

        // 2. Custos Variáveis
        final double totalAiCost = totalUsers * aiCostPerUser; // Custo IA baseada em todos usuários (ou ajustar para ativos)
        // CAC: Assumindo que CAC é um custo mensal amortizado ou investimento mensal
        // O usuário pediu "gasto em market por click por usuario... versos quantos clientes vão me gerar".
        // Vamos simplificar como: Investimento Marketing Estimado = CAC * Novos Usuários (estimado como 10% da base ou fixo?)
        // Para simplificar a visualização mensal, vamos usar CAC * (Total Users * 0.1) como "Crescimento" ou apenas mostrar o custo unitário.
        // O usuário pediu "valor médio gasto por usuario".
        // Vamos considerar o CAC como um custo operacional mensal diluído ou investimento.
        // Vou usar: Custo Marketing = CAC * (Total Users * 0.05) (5% churn/growth replacement)
        // Ou melhor, apenas listar o CAC unitário e não deduzir do MRR a menos que seja "Marketing Budget".
        // O usuário disse: "gasto em market... e a partir dai aparece o valor liquido previsto".
        // Então ele quer deduzir. Vamos assumir um budget de marketing baseado no CAC.
        // Vamos assumir aquisição de 5% da base ao mês.
        final double estimatedMarketingCost = (totalUsers * 0.05) * cacPerUser;

        // 3. Impostos
        final double taxes = mrr * (taxRate / 100);

        // 4. Lucro Líquido
        final double totalDeductions = totalProcessingFees + totalAiCost + estimatedMarketingCost + fixedCosts + taxes;
        final double netProfit = mrr - totalDeductions;

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
              const Text(
                'Detalhamento de Custos e Taxas',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              _buildCostRow('Processamento (Stripe/Lojas)', totalProcessingFees, currencyFormat, Colors.orange),
              _buildCostRow('Custos IA (Cloud/Tokens)', totalAiCost, currencyFormat, Colors.purple),
              _buildCostRow('Marketing (CAC Estimado)', estimatedMarketingCost, currencyFormat, Colors.pink),
              _buildCostRow('Impostos (${taxRate.toStringAsFixed(1)}%)', taxes, currencyFormat, Colors.red),
              _buildCostRow('Custos Fixos (Servidor/Outros)', fixedCosts, currencyFormat, Colors.grey),
              
              const Divider(color: AppColors.border, height: 32),
              
              // Métricas Unitárias
              const Text(
                'Métricas Unitárias (KPIs)',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildKpiChip('CAC (Custo Aquisição)', currencyFormat.format(cacPerUser)),
                  _buildKpiChip('Custo IA / Usuário', currencyFormat.format(aiCostPerUser)),
                  _buildKpiChip('LTV Estimado (12m)', currencyFormat.format((mrr / (totalPaid > 0 ? totalPaid : 1)) * 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValueCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double value, NumberFormat format, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.primaryText)),
            ],
          ),
          Text(
            '- ${format.format(value)}',
            style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> currentSettings, FirestoreService service) {
    final stripeFeePercentCtrl = TextEditingController(text: currentSettings['stripeFeePercent']?.toString() ?? '3.99');
    final stripeFixedFeeCtrl = TextEditingController(text: currentSettings['stripeFixedFee']?.toString() ?? '0.39');
    final storeFeePercentCtrl = TextEditingController(text: currentSettings['storeFeePercent']?.toString() ?? '15.0');
    final aiCostCtrl = TextEditingController(text: currentSettings['aiCostPerUser']?.toString() ?? '0.50');
    final cacCtrl = TextEditingController(text: currentSettings['cacPerUser']?.toString() ?? '5.00');
    final fixedCostsCtrl = TextEditingController(text: currentSettings['fixedCosts']?.toString() ?? '100.00');
    final taxRateCtrl = TextEditingController(text: currentSettings['taxRate']?.toString() ?? '6.0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Editar Taxas e Custos', style: TextStyle(color: AppColors.primaryText)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('Taxa Stripe (%)', stripeFeePercentCtrl),
              _buildTextField('Taxa Fixa Stripe (R\$)', stripeFixedFeeCtrl),
              _buildTextField('Taxa Lojas App (%)', storeFeePercentCtrl),
              _buildTextField('Custo IA por Usuário (R\$)', aiCostCtrl),
              _buildTextField('CAC Médio (R\$)', cacCtrl),
              _buildTextField('Custos Fixos Mensais (R\$)', fixedCostsCtrl),
              _buildTextField('Impostos (%)', taxRateCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              service.updateAdminFinancialSettings({
                'stripeFeePercent': double.tryParse(stripeFeePercentCtrl.text) ?? 0,
                'stripeFixedFee': double.tryParse(stripeFixedFeeCtrl.text) ?? 0,
                'storeFeePercent': double.tryParse(storeFeePercentCtrl.text) ?? 0,
                'aiCostPerUser': double.tryParse(aiCostCtrl.text) ?? 0,
                'cacPerUser': double.tryParse(cacCtrl.text) ?? 0,
                'fixedCosts': double.tryParse(fixedCostsCtrl.text) ?? 0,
                'taxRate': double.tryParse(taxRateCtrl.text) ?? 0,
              });
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppColors.primaryText),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.secondaryText),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}
