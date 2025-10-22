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
    // O build do modal (aparência) permanece o mesmo
    return Container(
      // Define a altura do modal. 90% da tela é um bom valor.
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Cor de superfície escura
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildContent(),
            ),
          ),
          // Só mostra o rodapé se houver sugestões
          if (_state == AiModalState.suggestions) _buildSuggestionsFooter(),
        ],
      ),
    );
  }

  // ----- Widgets internos (_buildHeader, _buildContent, etc.) -----
  // Nenhuma alteração necessária nestes widgets internos,
  // pois eles lidam apenas com os estados (_state, _errorMessage, _suggestions)
  // e não diretamente com os modelos UserModel ou TaskModel.
  // Cole o código completo deles da resposta anterior aqui se precisar.

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary),
              SizedBox(width: 12),
              Text(
                "Sugestões da IA",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
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
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFCF6679).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCF6679)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFCF6679), size: 40),
            const SizedBox(height: 16),
            const Text(
              "Ocorreu um Erro",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              // Tenta buscar contexto novamente se o erro foi no fetch,
              // ou gerar novamente se o erro foi na IA
              onPressed: _state == AiModalState.error && _suggestions.isEmpty
                  ? _fetchContextData
                  : _handleGenerate,
              child: const Text("Tentar Novamente"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      // Garante que o conteúdo role se for muito grande
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Center(
            // Centraliza o título
            child: Text(
              "Quebre sua meta em marcos inteligentes",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            // Centraliza a descrição
            child: Text(
              "A IA analisará seu contexto para sugerir os melhores passos e datas. Adicione detalhes para sugestões mais precisas.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Adicionar contexto para a IA (opcional):",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _additionalInfoController,
            maxLines: 4,
            maxLength: _characterLimit,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  "Ex: Tenho 2 horas por dia, prefiro tarefas práticas, estou me sentindo desmotivado, etc.",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              counterStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _handleGenerate,
              child: const Text("Gerar Marcos"),
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
        const Text(
          "Selecione os marcos que deseja adicionar:",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Expanded(
          // Garante que a lista não cause overflow
          child: ListView.builder(
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              // Verifica se a sugestão está na lista de selecionados
              final isSelected = _selectedSuggestions.any((s) =>
                  s['title'] == suggestion['title'] &&
                  s['date'] == suggestion['date']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  tileColor: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.grey[800]!,
                    ),
                  ),
                  onTap: () => _toggleSelection(suggestion),
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      _toggleSelection(suggestion);
                    },
                    activeColor: AppColors.primary,
                    checkColor: Colors.black, // Cor do 'check'
                    side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey), // Cor da borda
                  ),
                  title: Text(
                    suggestion['title']!,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(suggestion['date']!),
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // Fundo semi-transparente
        border: Border(
          top: BorderSide(color: Colors.grey[800]!), // Linha divisória sutil
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão Voltar
          TextButton(
              onPressed: () {
                setState(() {
                  // Volta para o estado inicial, limpando as sugestões
                  _state = AiModalState.initial;
                  _suggestions = [];
                  _selectedSuggestions = [];
                  // Não limpa _additionalInfoController para o usuário não redigitar
                });
              },
              child: const Row(
                // Ícone + Texto para clareza
                children: [
                  Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    "Voltar",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              )),
          // Botão Adicionar
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF03DAC6), // Cor secundária vibrante
              foregroundColor: Colors.black, // Texto preto para contraste
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10)), // Bordas arredondadas
            ),
            // Desabilita se nenhuma sugestão estiver selecionada
            onPressed: _selectedSuggestions.isEmpty
                ? null
                : () {
                    widget.onAddSuggestions(_selectedSuggestions);
                    Navigator.of(context).pop(); // Fecha o modal
                  },
            child: Row(
              // Ícone + Texto
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_task, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Adicionar (${_selectedSuggestions.length})",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} // Fim da classe _AiSuggestionModalState
