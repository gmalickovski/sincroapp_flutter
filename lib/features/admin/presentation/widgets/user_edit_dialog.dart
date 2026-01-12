// lib/features/admin/presentation/widgets/user_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart'; // MIGRATED
import 'package:intl/intl.dart';

class UserEditDialog extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSave;

  const UserEditDialog({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<UserEditDialog> {
  final SupabaseService _supabaseService = SupabaseService();
  SubscriptionPlan? _selectedSystemPlan;
  late SubscriptionStatus _selectedStatus;
  late DateTime? _validUntil;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSystemPlan = widget.user.subscription.systemPlan;
    _selectedStatus = widget.user.subscription.status;
    _validUntil = widget.user.subscription.validUntil;
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      // Determine effective plan for limits
      final effectivePlan = _selectedSystemPlan ?? widget.user.subscription.stripePlan ?? SubscriptionPlan.free;
      final int aiLimit = PlanLimits.getAiLimit(effectivePlan);

      // Cria nova subscription
      final newSubscription = widget.user.subscription.copyWith(
        systemPlan: _selectedSystemPlan,
        clearSystemPlan: _selectedSystemPlan == null,
        status: _selectedStatus,
        validUntil: _validUntil,
        aiSuggestionsLimit: aiLimit,
      );

      await _supabaseService.updateUserData(
        widget.user.uid,
        {'subscription': newSubscription.toFirestore()},
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário atualizado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar usuário: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ... (Keep existing helpers: _selectValidUntil, etc. if they are outside this block, but I am replacing the build method too)

  Future<void> _selectValidUntil() async {
     final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 anos
      builder: (context, child) {
        return Theme(
           data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                 primary: AppColors.primary,
                 onPrimary: Colors.white,
                 surface: AppColors.cardBackground,
                 onSurface: AppColors.primaryText,
              ),
              dialogBackgroundColor: AppColors.cardBackground,
           ),
           child: child!,
        );
      }
    );

    if (picked != null) {
      setState(() => _validUntil = picked.toUtc());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final stripePlanName = widget.user.subscription.stripePlan != null 
        ? PlanLimits.getPlanName(widget.user.subscription.stripePlan!) 
        : 'Nenhum';
    
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (Same as before)
            Row(
              children: [
                const Icon(Icons.edit, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Editar Usuário (Admin)',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.secondaryText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32, color: AppColors.border),

            // Stripe Plan Info (Read Only)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                   const Icon(Icons.payment, color: Colors.blue, size: 20),
                   const SizedBox(width: 12),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text('Plano Contratado (Stripe)', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                       Text(stripePlanName, style: const TextStyle(color: AppColors.primaryText, fontSize: 14)),
                     ],
                   )
                ],
              ),
            ),

            // System Plan Override
            const Text(
              'Plano no Sistema (Manual Override)',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SubscriptionPlan?>(
              value: _selectedSystemPlan,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: AppColors.primaryText),
              items: [
                const DropdownMenuItem<SubscriptionPlan?>(
                   value: null,
                   child: Text('Usar Plano do Stripe (Automático)'),
                ),
                ...SubscriptionPlan.values.map((plan) {
                  return DropdownMenuItem<SubscriptionPlan?>(
                    value: plan,
                    child: Text(PlanLimits.getPlanName(plan)),
                  );
                }),
              ],
              onChanged: (value) {
                 setState(() => _selectedSystemPlan = value);
              },
            ),
            const SizedBox(height: 16),

            // Status match existing logic
            const Text(
              'Status da Assinatura',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SubscriptionStatus>(
              value: _selectedStatus,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: AppColors.cardBackground,
              style: const TextStyle(color: AppColors.primaryText),
              items: SubscriptionStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(_getStatusName(status)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Validade
            const Text(
              'Válido Até',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectValidUntil,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppColors.secondaryText),
                    const SizedBox(width: 12),
                    Text(
                      _validUntil != null
                          ? dateFormat.format(_validUntil!)
                          : 'Sem data de expiração',
                      style: TextStyle(
                        color: _validUntil != null
                            ? AppColors.primaryText
                            : AppColors.secondaryText,
                      ),
                    ),
                    const Spacer(),
                    if (_validUntil != null)
                      IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.secondaryText, size: 20),
                        onPressed: () {
                          setState(() => _validUntil = null);
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info sobre o plano SELECIONADO (Efetivo)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getPlanInfo(_selectedSystemPlan ?? widget.user.subscription.stripePlan ?? SubscriptionPlan.free),
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
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
                      : const Text(
                          'Salvar',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusName(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Ativa';
      case SubscriptionStatus.expired:
        return 'Expirada';
      case SubscriptionStatus.cancelled:
        return 'Cancelada';
      case SubscriptionStatus.trial:
        return 'Teste';
    }
  }

  String _getPlanInfo(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Gratuito: 5 metas, 10 sugestões IA';
      case SubscriptionPlan.plus:
        return 'Plus: Metas ilimitadas, 100 sugestões IA/mês, R\$19,90/mês';
      case SubscriptionPlan.premium:
        return 'Premium: Tudo ilimitado + integrações, R\$39,90/mês';
    }
  }
}
