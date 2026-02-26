// lib/features/goals/presentation/widgets/create_goal_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_bottom_sheet.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class CreateGoalDialog extends StatefulWidget {
  final UserModel userData;
  final Goal? goalToEdit;

  const CreateGoalDialog({
    super.key,
    required this.userData,
    this.goalToEdit,
  });

  /// Shows as a modal bottom sheet on mobile, styled like MobileFilterSheet
  static Future<bool?> showAsBottomSheet(
    BuildContext context, {
    required UserModel userData,
    Goal? goalToEdit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _GoalFormBottomSheet(
          userData: userData,
          goalToEdit: goalToEdit,
        ),
      ),
    );
  }

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

    setState(() => _isSaving = true);

    try {
      if (widget.goalToEdit != null) {
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
          id: '', // Supabase gera UUID
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetDate: _targetDate,
          progress: 0,
          createdAt: DateTime.now(),
          userId: widget.userData.uid,
          subTasks: const [],
          imageUrl: null,
          category: '',
        );

        await _supabaseService.addGoal(widget.userData.uid, newGoal);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: Text(widget.goalToEdit != null
                ? 'Erro ao atualizar a jornada: $e'
                : 'Erro ao criar a jornada: $e'),
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
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Fixed at top)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.goalToEdit != null
                        ? 'Editar Jornada'
                        : 'Criar Nova Jornada',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.secondaryText),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Scrollable Content (Flexible)
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          autofillHints: const [], // Prevent browser password save prompt
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
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
                          autofillHints: const [], // Prevent browser password save prompt
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          maxLines: 5,
                          minLines: 3,
                          maxLength: 500,
                          decoration: _buildInputDecoration(
                            labelText: 'Descrição',
                            hintText:
                                'O que você quer alcançar com essa jornada? Quais são seus objetivos?',
                          ).copyWith(
                              alignLabelWithHint:
                                  true), // Fixed: Top-Left Alignment
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

                        // Clean Date Picker for Desktop
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
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_targetDate!)
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
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 3. Button (Fixed at bottom)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.goalToEdit != null
                              ? "Atualizar Jornada"
                              : "Salvar Jornada",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Sheet version for Mobile ───────────────────────────────────────
class _GoalFormBottomSheet extends StatefulWidget {
  final UserModel userData;
  final Goal? goalToEdit;

  const _GoalFormBottomSheet({
    required this.userData,
    this.goalToEdit,
  });

  @override
  State<_GoalFormBottomSheet> createState() => _GoalFormBottomSheetState();
}

class _GoalFormBottomSheetState extends State<_GoalFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _targetDate;
  bool _isSaving = false;
  final _supabaseService = SupabaseService();

  // Track original values to know if edits were made
  late String _originalTitle;
  late String _originalDesc;
  DateTime? _originalDate;

  @override
  void initState() {
    super.initState();
    if (widget.goalToEdit != null) {
      _originalTitle = widget.goalToEdit!.title;
      _originalDesc = widget.goalToEdit!.description;
      _originalDate = widget.goalToEdit!.targetDate;
      
      _titleController.text = _originalTitle;
      _descriptionController.text = _originalDesc;
      _targetDate = _originalDate;
    } else {
      _originalTitle = '';
      _originalDesc = '';
      _originalDate = null;
    }

    // Add listeners to rebuild footer when text changes
    _titleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _hasEdits {
    return _titleController.text.trim() != _originalTitle ||
           _descriptionController.text.trim() != _originalDesc ||
           _targetDate != _originalDate;
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CustomEndDatePickerBottomSheet(
          userData: widget.userData,
          initialDate: _targetDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        ),
      ),
    );
    if (pickedDate != null) {
      setState(() => _targetDate = pickedDate);
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isSaving || _targetDate == null) {
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

    // Plan limit check
    if (widget.goalToEdit == null) {
      final plan = widget.userData.subscription.plan;
      final int maxGoals = PlanLimits.getGoalsLimit(plan);
      if (maxGoals != -1) {
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

    setState(() => _isSaving = true);

    try {
      if (widget.goalToEdit != null) {
        await _supabaseService.updateGoal(Goal(
          id: widget.goalToEdit!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetDate: _targetDate,
          progress: widget.goalToEdit!.progress,
          userId: widget.userData.uid,
          createdAt: widget.goalToEdit!.createdAt,
          subTasks: widget.goalToEdit!.subTasks,
          imageUrl: widget.goalToEdit!.imageUrl,
          category: widget.goalToEdit!.category,
        ));
      } else {
        final newGoal = Goal(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetDate: _targetDate,
          progress: 0,
          createdAt: DateTime.now(),
          userId: widget.userData.uid,
          subTasks: const [],
          imageUrl: null,
          category: '',
        );
        await _supabaseService.addGoal(widget.userData.uid, newGoal);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: Text(widget.goalToEdit != null
                ? 'Erro ao atualizar a jornada: $e'
                : 'Erro ao criar a jornada: $e'),
          ),
        );
      }
    }
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
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content height
        children: [
          // ─── Header ───
          Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
            child: Text(
              widget.goalToEdit != null ? 'Editar Meta' : 'Criar Nova Meta',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),

          // ─── Form Content ───
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      autofillHints: const [],
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: _buildInputDecoration(
                        labelText: 'Título da Meta *',
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
                      autofillHints: const [],
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: 4,
                      minLines: 2,
                      maxLength: 500,
                      decoration: _buildInputDecoration(
                        labelText: 'Descrição',
                        hintText: 'O que você quer alcançar com essa meta?',
                      ).copyWith(alignLabelWithHint: true),
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
                    const SizedBox(height: 24), // Extra bottom padding for scrolling logic
                  ],
                ),
              ),
            ),
          ),

          // ─── Dynamic Footer Buttons ───
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
                },
                child: _hasEdits
                    ? Row(
                        key: const ValueKey('ActionButtons'),
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(), // Cancel simply pops
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("Cancelar",
                                    style: TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins')),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _handleSave,
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => AppColors.primary),
                                  foregroundColor: WidgetStateProperty.resolveWith<Color>((states) => Colors.white),
                                  elevation: WidgetStateProperty.resolveWith<double>((states) => 0),
                                  padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
                                      (states) => const EdgeInsets.symmetric(vertical: 12)),
                                  shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: Colors.white, width: 2), 
                                      );
                                    }
                                    return RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: AppColors.primary, width: 2),
                                    );
                                  }),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(
                                        widget.goalToEdit != null ? "Atualizar" : "Salvar",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 48,
                        key: const ValueKey('CloseButton'),
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.cardBackground,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Fechar",
                              style: TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins')),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
