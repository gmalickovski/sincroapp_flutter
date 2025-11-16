// lib/features/goals/presentation/widgets/ai_suggestion_modal.dart
// (Arquivo existente, código completo RE-ATUALIZADO e CORRIGIDO)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
// ATUALIZADO: Importa o UserModel correto
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/ai_service.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
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
      // Garante que o estado volte para fetching a cada tentativa
      _state = AiModalState.fetchingContext;
      _errorMessage = '';
    });
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception("Usuário não autenticado.");
      }

      final firestoreService = FirestoreService();
      // Busca dados em paralelo
      final userFuture = firestoreService.getUserData(userId);
      final tasksFuture = firestoreService.getRecentTasks(userId,
          limit: 20); // Buscar tarefas recentes

      final user = await userFuture;
      if (user == null) {
        throw Exception("Não foi possível carregar os dados do usuário.");
      }

      _userModel = user;

      // --- CORREÇÃO AQUI ---
      // Usar user.nomeAnalise e user.dataNasc corretamente
      // O NumerologyEngine espera a data como String 'dd/MM/yyyy', que user.dataNasc já é.
      final engine = NumerologyEngine(
        nomeCompleto: user.nomeAnalise,
        dataNascimento: user.dataNasc,
      );
      // --- FIM DA CORREÇÃO ---

      _numerologyResult = engine.calcular();

      if (_numerologyResult == null) {
        // Trata o caso de nome ou data inválidos para o cálculo
        throw Exception(
            "Não foi possível calcular dados de numerologia. Verifique nome e data de nascimento.");
      }

      // Espera pelas tarefas ANTES de mudar o estado para 'initial'
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
      // A chamada para AIService.generateSuggestions já foi corrigida
      // na resposta anterior para usar os modelos corretos internamente.
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
      // Procura pelo título e data para identificar unicamente
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
      return dateString; // Retorna a string original se o parse falhar
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcula tamanho dinâmico baseado no teclado
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasKeyboard = bottomInset > 0;

    // Usa DraggableScrollableSheet sempre, mas ajusta os tamanhos dinamicamente
    return DraggableScrollableSheet(
      initialChildSize: hasKeyboard ? 0.95 : 0.6,
      // Reduz a altura mínima quando teclado não está visível para permitir colapso maior
      minChildSize: hasKeyboard ? 0.95 : 0.35,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: hasKeyboard ? const [0.95] : const [0.6, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildContent(),
              ),
              // Só mostra o rodapé se houver sugestões
              if (_state == AiModalState.suggestions) _buildSuggestionsFooter(),
            ],
          ),
        );
      },
    );
  }

  // ----- Widgets internos (_buildHeader, _buildContent, etc.) -----
  // Nenhuma alteração necessária nestes widgets internos,
  // pois eles lidam apenas com os estados (_state, _errorMessage, _suggestions)
  // e não diretamente com os modelos UserModel ou TaskModel.
  // Cole o código completo deles da resposta anterior aqui se precisar.

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text(
                "Sugestões da IA",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.tertiaryText),
            iconSize: 24,
            onPressed: () => Navigator.of(context).pop(),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CustomLoadingSpinner(),
          const SizedBox(height: 24),
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
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.5), // red-500
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444), // red-500
              size: 48,
            ),
            const SizedBox(height: 20),
            const Text(
              "Ocorreu um Erro",
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _state == AiModalState.error && _suggestions.isEmpty
                  ? _fetchContextData
                  : _handleGenerate,
              child: const Text(
                "Tentar Novamente",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
        const SizedBox(height: 16),
        const Text(
          "Quebre sua meta em marcos inteligentes",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
            letterSpacing: -0.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 4.0), // padding mínimo apenas para respirar
          child: Text(
            "A IA analisará seu contexto para sugerir os melhores passos e datas. Adicione detalhes para sugestões mais precisas.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
        const Spacer(),
        _buildInitialFooterInput(),
      ],
    );
  }

  Widget _buildInitialFooterInput() {
    final bool _isGenerating = _state == AiModalState.loadingAi;
    final currentLength = _additionalInfoController.text.length;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: Padding(
          // Ajuste: adiciona padding lateral de respiro igual ao painel assistente (20)
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contador de caracteres à esquerda, acima do TextField
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  '$currentLength/$_characterLimit caracteres',
                  style: const TextStyle(
                    color: AppColors.tertiaryText,
                    fontSize: 12,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _additionalInfoController,
                      onSubmitted: (_) => _handleGenerate(),
                      onChanged: (_) => setState(() {}), // Atualiza contador
                      maxLines: null,
                      minLines: 1,
                      maxLength: _characterLimit,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 15,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Adicione contexto para a IA (opcional)...',
                        hintStyle: const TextStyle(
                          color: AppColors.tertiaryText,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        counterText: '', // Remove contador padrão do TextField
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isGenerating ? null : _handleGenerate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            "Selecione os marcos que deseja adicionar:",
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              final isSelected = _selectedSuggestions.any((s) =>
                  s['title'] == suggestion['title'] &&
                  s['date'] == suggestion['date']);

              return InkWell(
                onTap: () => _toggleSelection(suggestion),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.border.withValues(alpha: 0.3),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox
                      Container(
                        width: 32,
                        constraints: const BoxConstraints(minHeight: 32),
                        alignment: Alignment.topLeft,
                        margin: const EdgeInsets.only(right: 12.0, top: 2.0),
                        child: Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              _toggleSelection(suggestion);
                            },
                            checkColor: Colors.black,
                            activeColor: AppColors.primary,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      // Texto
                      Expanded(
                        child: Text(
                          suggestion['title']!,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                      // Data
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB923C).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFB923C).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Color(0xFFFB923C), // orange-400
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(suggestion['date']!),
                              style: const TextStyle(
                                color: Color(0xFFFB923C), // orange-400
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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

  Widget _buildSuggestionsFooter() {
    return Container(
      // Remove padding horizontal para alinhar com novo layout full width
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão Voltar
          TextButton(
            onPressed: () {
              setState(() {
                _state = AiModalState.initial;
                _suggestions = [];
                _selectedSuggestions = [];
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondaryText,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new, size: 16),
                SizedBox(width: 8),
                Text(
                  "Voltar",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Botão Adicionar
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              disabledBackgroundColor: AppColors.border.withValues(alpha: 0.3),
            ),
            onPressed: _selectedSuggestions.isEmpty
                ? null
                : () {
                    widget.onAddSuggestions(_selectedSuggestions);
                    Navigator.of(context).pop();
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_task, size: 20),
                const SizedBox(width: 10),
                Text(
                  "Adicionar (${_selectedSuggestions.length})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} // Fim da classe _AiSuggestionModalState
