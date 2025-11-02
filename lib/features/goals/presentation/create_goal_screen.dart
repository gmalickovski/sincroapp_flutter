// lib/features/goals/presentation/create_goal_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
// IMPORT ADICIONADO
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

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

  final _firestoreService = FirestoreService();

  // *** MÉTODO _pickDate ATUALIZADO ***
  Future<void> _pickDate() async {
    // Esconde o teclado antes de abrir o seletor de data
    FocusScope.of(context).unfocus();

    // Substitui o showDatePicker nativo pelo seu Dialog customizado
    final pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return CustomEndDatePickerDialog(
          userData: widget.userData,
          // Use o dia atual por padrão (ou a data alvo já selecionada)
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
      if (widget.goalToEdit != null) {
        await _firestoreService.updateGoal(Goal(
          id: widget.goalToEdit!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetDate: _targetDate,
          progress: widget.goalToEdit!.progress,
          userId: widget.userData.uid,
          createdAt: widget.goalToEdit!.createdAt,
          subTasks: widget.goalToEdit!.subTasks,
        ));
      } else {
        await _firestoreService.addGoal(widget.userData.uid, dataToSave);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
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
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: AppColors.secondaryText),
        title: Text(
            widget.goalToEdit != null ? 'Editar Jornada' : 'Nova Jornada',
            style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                decoration: _buildInputDecoration(
                  labelText: 'Título da Jornada',
                  hintText: 'Ex: Conquistar a Vaga de Desenvolvedor',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80, // limita título para evitar overflow
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
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 5,
                minLines: 3,
                maxLength: 500, // limita descrição
                textCapitalization: TextCapitalization.sentences,
                decoration: _buildInputDecoration(
                  labelText: 'Descrição',
                  hintText:
                      'Descreva o que você quer alcançar e por que isso é importante para você.',
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
              const SizedBox(height: 24),
              // *** SELETOR DE DATA (agora chama o _pickDate atualizado) ***
              Material(
                // Usei a cor de fundo do Card, mas pode ser transparente
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                child: FormField<DateTime>(
                  validator: (value) {
                    if (_targetDate == null) {
                      return 'Por favor, defina uma data alvo para sua meta';
                    }
                    return null;
                  },
                  builder: (FormFieldState<DateTime> state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16.0, horizontal: 12.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: state.hasError
                                    ? Colors.redAccent
                                    : AppColors.border,
                                width: state.hasError ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: AppColors.secondaryText),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _targetDate == null
                                        ? 'Definir Data Alvo'
                                        : 'Data Alvo: ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_targetDate!)}',
                                    style: TextStyle(
                                      color: _targetDate == null
                                          ? AppColors.secondaryText
                                          : Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (_targetDate != null)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _targetDate = null;
                                        state.didChange(null);
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.clear,
                                          color: AppColors.secondaryText),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (state.hasError)
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 12.0, top: 6.0),
                            child: Text(
                              state.errorText!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 100), // Espaço para o botão flutuante
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: _handleSave,
            label: _isSaving
                ? const CustomLoadingSpinner()
                : Text(
                    widget.goalToEdit != null
                        ? "Atualizar Jornada"
                        : "Salvar Jornada",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
            icon: _isSaving ? null : const Icon(Icons.check),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
