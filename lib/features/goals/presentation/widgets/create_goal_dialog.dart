// lib/features/goals/presentation/widgets/create_goal_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class CreateGoalDialog extends StatefulWidget {
  final UserModel userData;

  const CreateGoalDialog({super.key, required this.userData});

  @override
  State<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<CreateGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _targetDate;
  bool _isSaving = false;

  final _firestoreService = FirestoreService();

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (pickedDate != null) {
      setState(() {
        _targetDate = pickedDate;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    final dataToSave = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'targetDate':
          _targetDate != null ? Timestamp.fromDate(_targetDate!) : null,
      'progress': 0,
      'createdAt': Timestamp.now(),
      'userId': widget.userData.uid,
    };

    try {
      await _firestoreService.addGoal(widget.userData.uid, dataToSave);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: const Text('Erro ao criar a jornada. Tente novamente.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Criar Nova Jornada',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.secondaryText),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Título da Jornada',
                      labelStyle:
                          const TextStyle(color: AppColors.secondaryText),
                      filled: true,
                      fillColor: AppColors.background.withOpacity(0.5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Por favor, insira um título.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descrição',
                      labelStyle:
                          const TextStyle(color: AppColors.secondaryText),
                      filled: true,
                      fillColor: AppColors.background.withOpacity(0.5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Por favor, insira uma descrição.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    leading: const Icon(Icons.calendar_today,
                        color: AppColors.secondaryText),
                    title: Text(
                      _targetDate == null
                          ? 'Definir Data Alvo (Opcional)'
                          : 'Data Alvo: ${DateFormat('dd/MM/yyyy').format(_targetDate!)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: _targetDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.secondaryText),
                            onPressed: () => setState(() => _targetDate = null))
                        : null,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleSave,
                      icon: _isSaving
                          ? Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.check, color: Colors.white),
                      label: Text(_isSaving ? "Salvando..." : "Salvar Jornada",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
