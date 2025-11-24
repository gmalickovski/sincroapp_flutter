// lib/features/goals/presentation/widgets/create_goal_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
// IMPORT ADICIONADO
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class CreateGoalDialog extends StatefulWidget {
  final UserModel userData;
  final Goal? goalToEdit;

  const CreateGoalDialog({
    super.key,
    required this.userData,
    this.goalToEdit,
  });

  @override
  State<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<CreateGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize fields if editing
    if (widget.goalToEdit != null) {
      _titleController.text = widget.goalToEdit!.title;
      _descriptionController.text = widget.goalToEdit!.description;
      _targetDate = widget.goalToEdit!.targetDate;
    }
  }

  final _firestoreService = FirestoreService();

  Future<void> _pickDate() async {
    // Esconde o teclado antes de abrir o seletor de data
    FocusScope.of(context).unfocus();

    final pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        // Chama o seu novo widget de calendário flutuante
        return CustomEndDatePickerDialog(
          userData: widget.userData,
          // Abrir o seletor focado na data atual por padrão (ou na data alvo
          // já definida), assim evitamos pular para o mês seguinte.
          initialDate: _targetDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _targetDate = pickedDate;
      });
      debugPrint('CreateGoalDialog: Data selecionada: $_targetDate');
    } else {
      debugPrint(
          'CreateGoalDialog: Nenhuma data selecionada (pickedDate é null)');
    }
  }

  Future<void> _handleSave() async {
    // Remove foco dos campos para evitar heurísticas de formulário do navegador
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() ||
        _isSaving ||
        _targetDate == null) {
      if (_targetDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Por favor, defina uma data alvo para sua jornada.'),
          ),
        );
      }
      return;
    }

    // Checagem de limite de metas por plano
    if (widget.goalToEdit == null) {
      final plan = widget.userData.subscription.plan;
      final int maxGoals = PlanLimits.getGoalsLimit(plan);
      
      // Se maxGoals for -1, é ilimitado
      if (maxGoals != -1) {
        final goalsSnapshot =
            await FirestoreService().getActiveGoals(widget.userData.uid);
        
        if (goalsSnapshot.length >= maxGoals) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                  'Seu plano permite criar até $maxGoals meta${maxGoals > 1 ? 's' : ''}. Para mais, faça upgrade!'),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      String goalId;
      
      if (widget.goalToEdit != null) {
        goalId = widget.goalToEdit!.id;
        await _firestoreService.updateGoal(Goal(
          id: goalId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetDate: _targetDate,
          progress: widget.goalToEdit!.progress,
          userId: widget.userData.uid,
          createdAt: widget.goalToEdit!.createdAt,
          subTasks: widget.goalToEdit!.subTasks, // Mantém subtasks antigas se existirem (legado)
        ));
      } else {
        // Gerar ID manualmente para usar nas tasks
        final docRef = FirebaseFirestore.instance.collection('users').doc(widget.userData.uid).collection('goals').doc();
        goalId = docRef.id;
        
        final dataToSave = {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'targetDate': _targetDate != null ? Timestamp.fromDate(_targetDate!) : null,
          'userId': widget.userData.uid,
          'progress': 0,
          'createdAt': Timestamp.now(),
          'subTasks': [], // Não salvamos subtasks internas
        };
        
        await docRef.set(dataToSave);
      }

      // Retorna true para indicar sucesso (útil para a tela anterior)
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: Text(widget.goalToEdit != null
                ? 'Erro ao atualizar a jornada. Tente novamente.'
                : 'Erro ao criar a jornada. Tente novamente.'),
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

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      hintText: hintText ?? '',
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.redAccent),
      hintStyle: const TextStyle(color: AppColors.tertiaryText),
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
    );
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
                      Text(
                          widget.goalToEdit != null
                              ? 'Editar Jornada'
                              : 'Criar Nova Jornada',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.secondaryText),
                        // Retorna false para indicar cancelamento
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    autofillHints: null, // Desabilita autofill
                    enableSuggestions: false,
                    autocorrect: false,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: _buildInputDecoration(
                      labelText: 'Título da Jornada *',
                      hintText: 'Ex: Conquistar a Vaga de Desenvolvedor',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 80,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira um título.';
                      }
                      if (value.trim().length < 3) {
                        return 'O título deve ter pelo menos 3 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    autofillHints: null, // Desabilita autofill
                    enableSuggestions: false,
                    autocorrect: false,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 4,
                    minLines: 2,
                    maxLength: 500,
                    decoration: _buildInputDecoration(
                      labelText: 'Descrição',
                      hintText:
                          'O que você quer alcançar com essa jornada? Quais são seus objetivos?',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira uma descrição.';
                      }
                      if (value.trim().length < 10) {
                        return 'A descrição deve ter pelo menos 10 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: _buildInputDecoration(
                        labelText: 'Data Alvo *',
                        errorText: _targetDate == null && _isSaving
                            ? 'Por favor, defina uma data alvo.'
                            : null,
                      ).copyWith(
                        suffixIcon: const Icon(Icons.calendar_today,
                            color: AppColors.primary),
                      ),
                      child: Text(
                        _targetDate != null
                            ? DateFormat('dd/MM/yyyy').format(_targetDate!)
                            : 'Selecione a data de conclusão',
                        style: TextStyle(
                          color: _targetDate != null
                              ? Colors.white
                              : AppColors.tertiaryText,
                          fontSize: 16,
                        ),
                      ),
                    ),
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
                      label: Text(
                          _isSaving
                              ? "Salvando..."
                              : (widget.goalToEdit != null
                                  ? "Atualizar Jornada"
                                  : "Salvar Jornada"),
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
