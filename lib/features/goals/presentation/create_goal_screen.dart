// lib/features/goals/presentation/create_goal_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_bottom_sheet.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class CreateGoalScreen extends StatefulWidget {
  final UserModel userData;
  final Goal? goalToEdit;

  const CreateGoalScreen({
    super.key,
    required this.userData,
    this.goalToEdit,
  });

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
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

  final _supabaseService = SupabaseService();

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();

    final pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CustomEndDatePickerBottomSheet(
            userData: widget.userData,
            initialDate: _targetDate ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
          ),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _targetDate = pickedDate;
      });
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    // 1. Validação do formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 1.1 Checagem de limite de metas por plano
    if (widget.goalToEdit == null) {
      final plan = widget.userData.subscription.plan;
      final int maxGoals = PlanLimits.getGoalsLimit(plan);

      // Se maxGoals for -1, é ilimitado. Se não for -1, verifica o limite.
      if (maxGoals != -1) {
        // Busca número atual de metas do usuário
        final goalsSnapshot =
            await _supabaseService.getActiveGoals(widget.userData.uid);
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

    // 2. Validação da data
    if (_targetDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Por favor, defina uma data alvo para sua jornada.'),
        ),
      );
      return;
    }

    // 3. Prevenir cliques duplos
    if (_isSaving) {
      return;
    }

    // 4. Iniciar o estado de carregamento
    setState(() => _isSaving = true);
    bool isSuccessful = false;

    try {
      if (widget.goalToEdit != null) {
        // Editando jornada existente
        await _supabaseService.updateGoal(Goal(
          id: widget.goalToEdit!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetDate: _targetDate,
          progress: widget.goalToEdit!.progress,
          userId: widget.userData.uid,
          createdAt: widget.goalToEdit!.createdAt,
          subTasks: widget.goalToEdit!.subTasks,
          imageUrl:
              widget.goalToEdit!.imageUrl, // Mantém imagem existente se houver
          category: widget.goalToEdit!.category,
        ));
      } else {
        // Criando nova jornada
        final newGoal = Goal(
          id: '', // Supabase gera ID se vazio
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetDate: _targetDate,
          progress: 0,
          createdAt: DateTime.now(),
          userId: widget.userData.uid,
          subTasks: const [],
          imageUrl: null,
          category: '', // Categoria padrão vazia
        );
        await _supabaseService.addGoal(widget.userData.uid, newGoal);
      }

      // 5. Sucesso
      isSuccessful = true;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: Text(widget.goalToEdit != null
                ? 'Erro ao atualizar a jornada: $e'
                : 'Erro ao criar a jornada: $e'),
          ),
        );
      }
    } finally {
      if (mounted && !isSuccessful) {
        setState(() => _isSaving = false);
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
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.goalToEdit != null ? 'Editar Jornada' : 'Nova Jornada',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false, // 1. Title Left
        automaticallyImplyLeading: false, // Remove default back button
        actions: [
          // 2. Close Button on Right
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        autofillHints: const [], // Prevent browser password save prompt
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(
                          labelText: 'Título da Jornada',
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
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _descriptionController,
                        autofillHints: const [], // Prevent browser password save prompt
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 6,
                        minLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _buildInputDecoration(
                          labelText: 'Descrição',
                          hintText:
                              'Descreva o que você quer alcançar e por que isso é importante para você.',
                        ).copyWith(
                            alignLabelWithHint:
                                true), // 3. Top-Left alignment for label
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
                      const SizedBox(height: 24),

                      // Date Picker
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16.0, horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _targetDate == null && _isSaving
                                    ? Colors.redAccent
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    color: _targetDate != null
                                        ? AppColors.primary
                                        : AppColors.secondaryText),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Data Alvo',
                                        style: TextStyle(
                                          color: AppColors.secondaryText,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _targetDate == null
                                            ? 'Selecionar data'
                                            : DateFormat('dd ' 'MMM' ' yyyy',
                                                    'pt_BR')
                                                .format(_targetDate!),
                                        style: TextStyle(
                                          color: _targetDate == null
                                              ? AppColors.tertiaryText
                                              : Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_targetDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear,
                                        size: 20,
                                        color: AppColors.tertiaryText),
                                    onPressed: () {
                                      setState(() {
                                        _targetDate = null;
                                      });
                                    },
                                  )
                                else
                                  const Icon(Icons.arrow_forward_ios,
                                      size: 16, color: AppColors.tertiaryText),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Error message for date
                      if (_targetDate == null && _isSaving)
                        const Padding(
                          padding: EdgeInsets.only(left: 12.0, top: 6.0),
                          child: Text(
                            'Por favor, defina uma data alvo.',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Bottom Container
            Container(
              padding: const EdgeInsets.all(20),
              // 4. Removed decoration (color/border)
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.goalToEdit != null
                              ? "Atualizar Jornada"
                              : "Salvar Jornada",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
