// lib/features/settings/presentation/tabs/numerology_settings_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class NumerologySettingsTab extends StatefulWidget {
  final UserModel userData;
  const NumerologySettingsTab({super.key, required this.userData});

  @override
  State<NumerologySettingsTab> createState() => _NumerologySettingsTabState();
}

class _NumerologySettingsTabState extends State<NumerologySettingsTab> {
  final _firestoreService = FirestoreService();
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
    // Converte a data dd/MM/yyyy para um objeto DateTime e formata para o controller
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
      await _firestoreService.updateUserData(widget.userData.uid, {
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados da Análise',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 16),
            child: Text('Informações usadas para os cálculos numerológicos.',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _analysisNameController,
                  decoration: const InputDecoration(
                      labelText: 'Nome Completo (para análise)'),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthDateController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: const InputDecoration(
                    labelText: 'Data de Nascimento',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSaveChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar Alterações'),
          ),
        ],
      ),
    );
  }
}
