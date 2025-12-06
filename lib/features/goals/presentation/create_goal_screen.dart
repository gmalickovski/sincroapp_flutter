// lib/features/goals/presentation/create_goal_screen.dart
import 'dart:async'; // IMPORT ADICIONADO (para TimeoutException)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:image_picker/image_picker.dart'; // Import ImagePicker
import 'package:sincro_app_flutter/services/storage_service.dart'; // Import StorageService
import 'dart:io'; // Import File
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb

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

  // Image Logic
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  String? _existingImageUrl;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();

    // Initialize fields if editing
    if (widget.goalToEdit != null) {
      _titleController.text = widget.goalToEdit!.title;
      _descriptionController.text = widget.goalToEdit!.description;
      _targetDate = widget.goalToEdit!.targetDate;
      _existingImageUrl = widget.goalToEdit!.imageUrl;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // Optimization: Limit size
        maxHeight: 1080,
        imageQuality: 85, // Optimization: Compress
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      // If we are editing and have an existing image, we might want to allow deleting it?
      // For now, clearing selection just reverts to existing (or nothing if we want to support delete).
      // Assuming "Clear" means "Remove selected new image", or "Remove existing image"?
      // Let's assume it removes the current selection or the existing image.
      if (_existingImageUrl != null && _selectedImage == null) {
         // TODO: Implement delete logic if needed, for now just clear local state
         // To support deleting existing image, we'd need a flag or set _existingImageUrl = null
         _existingImageUrl = null;
      }
    });
  }

  final _firestoreService = FirestoreService();

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
      debugPrint('CreateGoalScreen: Data selecionada: $_targetDate');
    } else {
      debugPrint(
          'CreateGoalScreen: Nenhuma data selecionada (pickedDate é null)');
    }
  }

  // --- MÉTODO _handleSave ATUALIZADO ---
  Future<void> _handleSave() async {
    // Fecha qualquer teclado virtual e remove foco dos campos antes de salvar
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

    // 2. Validação da data (movida para cima)
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
    bool isSuccessful = false; // Flag para controlar o bloco 'finally'

    try {
      // Define um tempo limite para a operação de banco de dados
      const Duration firestoreTimeout = Duration(seconds: 15);

      String? finalImageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        finalImageUrl = await _storageService.uploadGoalImage(
          file: _selectedImage!,
          userId: widget.userData.uid,
        );
      }

      if (widget.goalToEdit != null) {
        // Editando jornada existente
        await _firestoreService
            .updateGoal(Goal(
              id: widget.goalToEdit!.id,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              targetDate: _targetDate,
              progress: widget.goalToEdit!.progress,
              userId: widget.userData.uid,
              createdAt: widget.goalToEdit!.createdAt,
              subTasks: widget.goalToEdit!.subTasks,
              imageUrl: finalImageUrl, // Add image URL
            ))
            .timeout(firestoreTimeout); // Adiciona o timeout
      } else {
        // Criando nova jornada
        final dataToSave = {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'targetDate': Timestamp.fromDate(_targetDate!), // Já verificado
          'progress': 0,
          'createdAt': Timestamp.now(),
          'userId': widget.userData.uid,
          'subTasks': [], // Seu fix (correto)
          'imageUrl': finalImageUrl, // Add image URL
        };
        debugPrint(
            'CreateGoalScreen: Salvando nova meta com targetDate: $_targetDate');
        debugPrint('CreateGoalScreen: dataToSave = $dataToSave');
        await _firestoreService
            .addGoal(widget.userData.uid, dataToSave)
            .timeout(firestoreTimeout); // Adiciona o timeout
      }

      // 5. Sucesso: marcar como sucesso e fechar a tela
      isSuccessful = true;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (e) {
      // Erro específico do Firebase (ex: regras de segurança)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content:
                Text('Erro de Firebase: ${e.message ?? "Tente novamente."}'),
          ),
        );
      }
    } on TimeoutException {
      // Erro de Timeout (provavelmente o que está acontecendo)
      // Os logs do ConnectivityManager sugerem isso.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade400,
            content: const Text(
                'Não foi possível conectar. Verifique sua internet e tente novamente.'),
          ),
        );
      }
    } catch (e) {
      // Outro erro inesperado
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
    } finally {
      // 6. Bloco Finally: SEMPRE será executado.
      // Se a operação NÃO foi bem-sucedida, paramos o loading
      // e reativamos o botão.
      if (mounted && !isSuccessful) {
        setState(() => _isSaving = false);
      }
    }
  }
  // --- FIM DA ATUALIZAÇÃO ---

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
            style: const TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                autofillHints: null, // Desabilita autofill
                enableSuggestions: false,
                autocorrect: false,
                enableInteractiveSelection: true,
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

              // --- Image Picker UI ---
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    image: (_selectedImage != null || _existingImageUrl != null)
                        ? DecorationImage(
                            image: _selectedImage != null
                                ? (kIsWeb
                                    ? NetworkImage(_selectedImage!.path)
                                    : FileImage(File(_selectedImage!.path))
                                        as ImageProvider)
                                : NetworkImage(_existingImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (_selectedImage == null && _existingImageUrl == null)
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: AppColors.primary, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'Adicionar Imagem de Capa (Opcional)',
                              style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 14),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  // Stop propagation to parent
                                  _clearImage();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              // -----------------------

              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                autofillHints: null, // Desabilita autofill
                enableSuggestions: false,
                autocorrect: false,
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
              Material(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                child: FormField<DateTime>(
                  validator: (value) {
                    // A validação agora é feita no _handleSave
                    // mas mantemos o feedback visual de erro
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
            onPressed: _isSaving ? null : _handleSave, // Desativa no loading
            label: _isSaving
                ? const CustomLoadingSpinner()
                : Text(
                    widget.goalToEdit != null
                        ? "Atualizar Jornada"
                        : "Salvar Jornada",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
            icon: _isSaving ? null : const Icon(Icons.check),
            backgroundColor: _isSaving
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.primary, // Feedback visual de desativado
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
