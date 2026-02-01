// lib/features/settings/presentation/tabs/numerology_settings_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/features/settings/presentation/widgets/settings_section_title.dart';

class NumerologySettingsTab extends StatefulWidget {
  final UserModel userData;
  const NumerologySettingsTab({super.key, required this.userData});

  @override
  State<NumerologySettingsTab> createState() => _NumerologySettingsTabState();
}

class _NumerologySettingsTabState extends State<NumerologySettingsTab> {
  final _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _analysisNameController;
  late TextEditingController _birthDateController;
  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _analysisNameController =
        TextEditingController(text: widget.userData.nomeAnalise);
    _birthDateController = TextEditingController();
    if (widget.userData.dataNasc.isNotEmpty) {
      try {
        _selectedDate =
            DateFormat('dd/MM/yyyy').parse(widget.userData.dataNasc);
        _birthDateController.text =
            DateFormat('dd/MM/yyyy').format(_selectedDate!);
      } catch (e) {
        _selectedDate = null;
        _birthDateController.text = '';
      }
    }
  }

  @override
  void dispose() {
    _analysisNameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _handleSaveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _supabaseService.updateUserData(widget.userData.uid, {
        'nomeAnalise': _analysisNameController.text.trim(),
        'dataNasc': _birthDateController.text,
      });
      _showFeedback('Dados da análise salvos com sucesso!');
    } catch (e) {
      _showFeedback('Erro ao salvar os dados.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Padding is handled by SettingsScreen wrapper for mobile
      // But verify if we need it here. SettingsScreen adds padding 16.0
      // So we don't need excessive padding here.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionTitle(title: 'Dados da Análise'),
          
          Container(
            padding: const EdgeInsets.only(bottom: 24),
            child: const Text(
                'Informações usadas para os cálculos numerológicos.',
                style: TextStyle(color: AppColors.secondaryText)),
          ),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _analysisNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nome Completo (para análise)',
                    labelStyle: const TextStyle(color: AppColors.secondaryText),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.secondaryText),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthDateController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Data de Nascimento',
                    labelStyle: const TextStyle(color: AppColors.secondaryText),
                    prefixIcon: const Icon(Icons.calendar_month_outlined, color: AppColors.secondaryText),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSaveChanges,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Salvar Alterações'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
