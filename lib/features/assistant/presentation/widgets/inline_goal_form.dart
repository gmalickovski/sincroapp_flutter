// lib/features/assistant/presentation/widgets/inline_goal_form.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class InlineGoalForm extends StatefulWidget {
  final UserModel userData;
  final String? prefilledTitle;
  final String? prefilledDescription;
  final DateTime? prefilledTargetDate;
  final List<String>? prefilledSubtasks;
  final Function(Goal) onSave;
  final VoidCallback? onCancel;

  const InlineGoalForm({
    super.key,
    required this.userData,
    this.prefilledTitle,
    this.prefilledDescription,
    this.prefilledTargetDate,
    this.prefilledSubtasks,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<InlineGoalForm> createState() => _InlineGoalFormState();
}

class _InlineGoalFormState extends State<InlineGoalForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.prefilledTitle ?? '');
    _descriptionController = TextEditingController(text: widget.prefilledDescription ?? '');
    _targetDate = widget.prefilledTargetDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();

    final pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return CustomEndDatePickerDialog(
          userData: widget.userData,
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
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate() || _isSaving || _targetDate == null || _milestones.isEmpty) {
      if (_targetDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Por favor, defina uma data alvo para sua jornada.'),
          ),
        );
      } else if (_milestones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Adicione pelo menos 1 marco para sua jornada.'),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Create the goal object
      final goal = Goal(
        id: '', // Will be set by Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        targetDate: _targetDate,
        progress: 0,
        userId: widget.userData.uid,
        createdAt: DateTime.now(),
        subTasks: _milestones.map((title) => SubTask(
          id: DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString(),
          title: title,
          isCompleted: false,
        )).toList(),
      );

      widget.onSave(goal);
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

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
      hintText: hintText ?? '',
      hintStyle: const TextStyle(color: AppColors.tertiaryText, fontSize: 13),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Criar Nova Jornada',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.secondaryText, size: 18),
                    onPressed: widget.onCancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofillHints: null,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(color: Colors.white, fontSize: 14),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              autofillHints: null,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              minLines: 2,
              maxLength: 500,
              decoration: _buildInputDecoration(
                labelText: 'Descrição',
                hintText: 'O que você quer alcançar com essa jornada?',
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
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.secondaryText, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _targetDate == null
                              ? 'Definir Data Alvo *'
                              : 'Data Alvo: ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_targetDate!)}',
                          style: TextStyle(
                            color: _targetDate == null ? AppColors.secondaryText : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.secondaryText, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // --- SEÇÃO DE MARCOS (MILESTONES) ---
            const Text(
              'Marcos da Jornada *',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildMilestonesInput(),
            if (_milestones.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Adicione pelo menos 1 marco para sua jornada.',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            // -------------------------------------

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check, color: Colors.white, size: 18),
                label: Text(
                  _isSaving ? "Salvando..." : "Salvar Jornada",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Lógica e UI dos Marcos ---
  final List<String> _milestones = [];
  final TextEditingController _milestoneController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializa marcos apenas uma vez se a lista estiver vazia e houver preenchimento
    if (_milestones.isEmpty && widget.prefilledSubtasks != null && widget.prefilledSubtasks!.isNotEmpty) {
      _milestones.addAll(widget.prefilledSubtasks!);
    }
  }

  Widget _buildMilestonesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _milestoneController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  labelText: 'Novo Marco',
                  hintText: 'Ex: Ler 10 páginas',
                ).copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onFieldSubmitted: (_) => _addMilestone(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addMilestone,
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              tooltip: 'Adicionar Marco',
            ),
          ],
        ),
        if (_milestones.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _milestones.asMap().entries.map((entry) {
              final index = entry.key;
              final milestone = entry.value;
              return Chip(
                label: Text(milestone, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppColors.cardBackground,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.secondaryText),
                onDeleted: () {
                  setState(() {
                    _milestones.removeAt(index);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _addMilestone() {
    final text = _milestoneController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _milestones.add(text);
        _milestoneController.clear();
      });
    }
  }
  // -----------------------------
}
