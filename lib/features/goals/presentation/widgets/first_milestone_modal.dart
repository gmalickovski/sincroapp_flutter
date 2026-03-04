// lib/features/goals/presentation/widgets/first_milestone_modal.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';
import 'package:sincro_app_flutter/common/parser/parser_input_field.dart';
import 'package:sincro_app_flutter/common/widgets/modern/schedule_task_sheet.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class FirstMilestoneModal extends StatefulWidget {
  final UserModel userData;
  final Goal goal;
  final bool isDesktop;

  const FirstMilestoneModal({
    super.key,
    required this.userData,
    required this.goal,
    required this.isDesktop,
  });

  static Future<bool?> show(
    BuildContext context, {
    required UserModel userData,
    required Goal goal,
  }) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768.0;
    if (isDesktop) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => FirstMilestoneModal(
          userData: userData,
          goal: goal,
          isDesktop: true,
        ),
      );
    } else {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: FirstMilestoneModal(
            userData: userData,
            goal: goal,
            isDesktop: false,
          ),
        ),
      );
    }
  }

  @override
  State<FirstMilestoneModal> createState() => _FirstMilestoneModalState();
}

class _FirstMilestoneModalState extends State<FirstMilestoneModal> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _supabaseService = SupabaseService();

  bool _isSaving = false;
  ParsedTask? _currentParsedTask;
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _currentParsedTask = TaskParser.parse('');
    _textController.addListener(_onTextChanged);
    // Request focus for the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _currentParsedTask = TaskParser.parse(_textController.text);
    });
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    
    // Future: implement schedule sheet for desktop.
    // Right now using the existing bottom sheet.
    final result = await ScheduleTaskSheet.show(
      context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      userData: widget.userData,
    );

    if (result != null) {
      setState(() {
        _selectedDueDate = result.dateTime; // Use the returned date
      });
    }
  }

  int? _calculatePersonalDay(DateTime? date) {
    if (widget.userData.dataNasc.isEmpty ||
        widget.userData.nomeAnalise.isEmpty ||
        date == null) {
      return null;
    }

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );

    try {
      final dateUtc = date.toUtc();
      final day = engine.calculatePersonalDayForDate(dateUtc);
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleSave() async {
    final text = _currentParsedTask?.cleanText ?? _textController.text;
    if (text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      DateTime? finalDueDateUtc = _selectedDueDate?.toUtc();
      DateTime dateForPersonalDay;

      if (finalDueDateUtc != null) {
        dateForPersonalDay = finalDueDateUtc;
      } else {
        final now = DateTime.now().toLocal();
        dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
      }

      final int? finalPersonalDay = _calculatePersonalDay(dateForPersonalDay);

      final newTask = TaskModel(
        id: '',
        text: text.trim(),
        createdAt: DateTime.now().toUtc(),
        dueDate: finalDueDateUtc,
        journeyId: widget.goal.id,
        journeyTitle: widget.goal.title,
        tags: _currentParsedTask?.tags ?? [],
        personalDay: finalPersonalDay,
      );

      await _supabaseService.addTask(widget.userData.uid, newTask);
      if (mounted) Navigator.of(context).pop(true); // Return success
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: Text('Erro ao criar marco: $e'),
          ),
        );
      }
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop(false);
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      hintText: hintText ?? '',
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
    );
  }

  Widget _buildContent() {
    final hasText = (_currentParsedTask?.cleanText ?? _textController.text).trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.all(widget.isDesktop ? 32.0 : 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Criar Primeiro Marco 🎯',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          if (widget.isDesktop) const SizedBox(height: 8),
          const SizedBox(height: 12),
          const Text(
            'Que tal darmos o primeiro passo? ✨\n\nPara iniciar e acompanhar essa jornada incrível, você só precisa criar pelo menos um marco (uma submeta) para começar com o pé direito!',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Input field 
          ParserInputField(
            controller: _textController,
            focusNode: _focusNode,
            hintText: 'Qual será seu primeiro grande passo? 🚀',
            minLines: 1,
            maxLines: 5,
            onSubmitted: (_) {
              if ((_currentParsedTask?.cleanText ?? _textController.text).trim().isNotEmpty) {
                _handleSave();
              }
            },
          ),
          
          const SizedBox(height: 16),

          // Date Picker
          GestureDetector(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _buildInputDecoration(
                labelText: 'Data Alvo (Opcional)',
              ).copyWith(
                suffixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
              ),
              child: Text(
                _selectedDueDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDueDate!)
                    : 'Selecione a data (opcional)',
                style: TextStyle(
                  color: _selectedDueDate != null
                      ? Colors.white
                      : AppColors.tertiaryText,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: hasText
                ? [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            _textController.clear();
                            setState(() {
                              _currentParsedTask = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Limpar",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: !_isSaving ? _handleSave : null,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(WidgetState.disabled)) {
                                  return AppColors.border;
                                }
                                return AppColors.primary;
                              },
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(WidgetState.disabled)) {
                                  return AppColors.secondaryText;
                                }
                                return Colors.white;
                              },
                            ),
                            elevation: WidgetStateProperty.resolveWith<double>((states) => 0),
                            padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
                              (states) => const EdgeInsets.symmetric(vertical: 12),
                            ),
                            shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
                              return RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              );
                            }),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  "Criar Marco",
                                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _handleCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Fechar",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDesktop) {
      return Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _buildContent(),
        ),
      );
    } else {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _buildContent(),
      );
    }
  }
}
