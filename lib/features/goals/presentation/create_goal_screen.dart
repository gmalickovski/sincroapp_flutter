// lib/features/goals/presentation/create_goal_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class CreateGoalScreen extends StatefulWidget {
  final UserModel userData;

  const CreateGoalScreen({super.key, required this.userData});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
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
      lastDate: DateTime.now()
          .add(const Duration(days: 365 * 10)), // 10 anos no futuro
    );
    if (pickedDate != null) {
      setState(() {
        _targetDate = pickedDate;
      });
    }
  }

  Future<void> _handleSave() async {
    // Valida o formulário e verifica se já não está salvando
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
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: const Text('Erro ao criar a jornada. Tente novamente.'),
        ),
      );
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
    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: const CloseButton(color: AppColors.secondaryText),
        title: const Text('Nova Jornada',
            style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            TextFormField(
              controller: _titleController,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Título da Jornada',
                labelStyle: TextStyle(color: AppColors.secondaryText),
                hintText: 'Ex: Conquistar a Vaga de Desenvolvedor',
                hintStyle: TextStyle(color: AppColors.tertiaryText),
                border: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, insira um título.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                labelStyle: TextStyle(color: AppColors.secondaryText),
                hintText:
                    'Descreva o que você quer alcançar e por que isso é importante para você.',
                hintStyle: TextStyle(color: AppColors.tertiaryText),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, insira uma descrição.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleSave,
        label: _isSaving
            ? const CustomLoadingSpinner()
            : const Text("Salvar Jornada"),
        icon: _isSaving ? null : const Icon(Icons.check),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
