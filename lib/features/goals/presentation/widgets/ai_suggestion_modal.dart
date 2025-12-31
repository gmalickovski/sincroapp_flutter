// lib/features/goals/presentation/widgets/ai_suggestion_modal.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/ai_service.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

enum AiModalState {
  fetchingContext,
  initial,
  loadingAi,
  suggestions,
  error,
}

class AiSuggestionModal extends StatefulWidget {
  final Goal goal;
  final Function(List<Map<String, String>> suggestions) onAddSuggestions;

  const AiSuggestionModal({
    super.key,
    required this.goal,
    required this.onAddSuggestions,
  });

  @override
  State<AiSuggestionModal> createState() => _AiSuggestionModalState();
}

class _AiSuggestionModalState extends State<AiSuggestionModal> {
  AiModalState _state = AiModalState.fetchingContext;
  String _errorMessage = '';
  final _additionalInfoController = TextEditingController();
  final int _characterLimit = 300;

  UserModel? _userModel;
  NumerologyResult? _numerologyResult;
  List<TaskModel> _userTasks = [];

  List<Map<String, String>> _suggestions = [];
  List<Map<String, String>> _selectedSuggestions = [];

  @override
  void initState() {
    super.initState();
    _fetchContextData();
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _fetchContextData() async {
    setState(() {
      _state = AiModalState.fetchingContext;
      _errorMessage = '';
    });
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception("Usuário não autenticado.");
      }

      final supabaseService = SupabaseService();
      final userFuture = supabaseService.getUserData(userId);
      final tasksFuture = supabaseService.getRecentTasks(userId, limit: 20);

      final user = await userFuture;
      if (user == null) {
        throw Exception("Não foi possível carregar os dados do usuário.");
      }

      _userModel = user;

      final engine = NumerologyEngine(
        nomeCompleto: user.nomeAnalise,
        dataNascimento: user.dataNasc,
      );

      _numerologyResult = engine.calcular();

      if (_numerologyResult == null) {
        throw Exception(
            "Não foi possível calcular dados de numerologia. Verifique nome e data de nascimento.");
      }

      _userTasks = await tasksFuture;

      setState(() {
        _state = AiModalState.initial;
      });
    } catch (e) {
      setState(() {
        _state = AiModalState.error;
        _errorMessage = "Erro ao buscar dados de contexto: ${e.toString()}";
      });
    }
  }

  Future<void> _handleGenerate() async {
    if (_userModel == null || _numerologyResult == null) return;

    setState(() {
      _state = AiModalState.loadingAi;
      _errorMessage = '';
    });

    try {
      final result = await AIService.generateSuggestions(
        goal: widget.goal,
        user: _userModel!,
        numerologyResult: _numerologyResult!,
        userTasks: _userTasks,
        additionalInfo: _additionalInfoController.text,
      );

      setState(() {
        _suggestions = result;
        _selectedSuggestions = List.from(result);
        _state = AiModalState.suggestions;
      });
    } catch (e) {
      setState(() {
        _state = AiModalState.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _toggleSelection(Map<String, String> suggestion) {
    setState(() {
      final index = _selectedSuggestions.indexWhere((s) =>
          s['title'] == suggestion['title'] && s['date'] == suggestion['date']);
      if (index >= 0) {
        _selectedSuggestions.removeAt(index);
      } else {
        _selectedSuggestions.add(suggestion);
      }
    });
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString); // YYYY-MM-DD
      return DateFormat('dd/MM').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppColors.cardBackground,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isMobile: true),
                  Expanded(
                    child: _buildContent(),
                  ),
                  if (_state == AiModalState.suggestions) _buildSuggestionsFooter(isMobile: true),
                ],
              ),
            ),
          );
        }

        // Desktop Layout
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.3),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(isMobile: false),
                    Expanded(
                      child: _buildContent(),
                    ),
                    if (_state == AiModalState.suggestions) _buildSuggestionsFooter(isMobile: false),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text(
                "Sugestões da IA",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.tertiaryText),
            onPressed: () => Navigator.of(context).pop(),
            // REMOVED STYLE: Cleaner generic close icon
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case AiModalState.fetchingContext:
        return _buildLoadingState(
            "Buscando seu histórico para personalizar...");
      case AiModalState.loadingAi:
        return _buildLoadingState(
            "Aguarde, a IA está analisando a melhor rota...");
      case AiModalState.error:
        return _buildErrorState();
      case AiModalState.initial:
        return _buildInitialState();
      case AiModalState.suggestions:
        return _buildSuggestionsList();
    }
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CustomLoadingSpinner(size: 40),
            const SizedBox(height: 32),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Ocorreu um Erro",
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _state == AiModalState.error && _suggestions.isEmpty
                    ? _fetchContextData
                    : _handleGenerate,
                child: const Text(
                  "Tentar Novamente",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Quebre sua meta em\nmarcos inteligentes",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "A IA analisará seu contexto para sugerir os melhores passos e datas. Adicione detalhes para sugestões mais precisas.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildInitialFooterInput(),
      ],
    );
  }

  Widget _buildInitialFooterInput() {
    final bool isGenerating = _state == AiModalState.loadingAi;
    final currentLength = _additionalInfoController.text.length;

    return Container(
      padding: const EdgeInsets.all(24),
      // No decoration to make elements float on background
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              '$currentLength/$_characterLimit caracteres',
              style: const TextStyle(
                color: AppColors.tertiaryText,
                fontSize: 12,
              ),
            ),
          ),
          
          TextField(
            controller: _additionalInfoController,
            onSubmitted: (_) => _handleGenerate(),
            onChanged: (_) => setState(() {}),
            maxLines: null,
            minLines: 1,
            maxLength: _characterLimit,
            textInputAction: TextInputAction.send,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Adicione contexto (opcional)...',
              hintStyle: const TextStyle(
                color: AppColors.tertiaryText,
                fontSize: 16,
              ),
              filled: true,
              fillColor: AppColors.background,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Full width Button (Floating look)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
              ),
              onPressed: isGenerating ? null : _handleGenerate,
              child: isGenerating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Ver sugestões",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Text(
            "Selecione os marcos que deseja adicionar:",
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: _suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              final isSelected = _selectedSuggestions.any((s) =>
                  s['title'] == suggestion['title'] &&
                  s['date'] == suggestion['date']);

              return InkWell(
                onTap: () => _toggleSelection(suggestion),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(top: 2, right: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.tertiaryText,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion['title']!,
                              style: TextStyle(
                                color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 12, color: AppColors.tertiaryText),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(suggestion['date']!),
                                    style: const TextStyle(
                                      color: AppColors.tertiaryText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsFooter({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _state = AiModalState.initial;
                  _suggestions = [];
                  _selectedSuggestions = [];
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Voltar", style: TextStyle(color: AppColors.secondaryText)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _selectedSuggestions.isEmpty
                  ? null
                  : () {
                      widget.onAddSuggestions(_selectedSuggestions);
                      Navigator.of(context).pop();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                "Adicionar (${_selectedSuggestions.length})",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
