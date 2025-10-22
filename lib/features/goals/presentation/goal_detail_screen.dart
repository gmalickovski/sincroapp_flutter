// lib/features/goals/presentation/goal_detail_screen.dart
// (Código completo e CORRIGIDO - Removido 'size' do CustomLoadingSpinner)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Importa foundation para debugPrint
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importa intl para formatação de data
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
// Importa o CustomLoadingSpinner
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/ai_suggestion_modal.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal initialGoal;
  final UserModel userData;

  const GoalDetailScreen({
    super.key,
    required this.initialGoal,
    required this.userData,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Goal
      _currentGoal; // Estado local para gerenciar a meta atual e suas subTasks
  bool _isLoading = false; // Estado para feedback de salvamento

  // Constantes de layout
  static const double kDesktopBreakpoint = 768.0;
  static const double kMaxContentWidth = 800.0;

  @override
  void initState() {
    super.initState();
    debugPrint("GoalDetailScreen: initState iniciado.");
    try {
      // Inicializa _currentGoal com os dados recebidos
      _currentGoal = widget.initialGoal;
      // Logs para verificar os dados recebidos
      debugPrint(
          "GoalDetailScreen: initialGoal atribuído com sucesso. ID: ${_currentGoal.id}");
      debugPrint("GoalDetailScreen: Título: ${_currentGoal.title}");
      debugPrint("GoalDetailScreen: Descrição: ${_currentGoal.description}");
      debugPrint("GoalDetailScreen: Categoria: ${_currentGoal.category}");
      debugPrint(
          "GoalDetailScreen: Nº SubTasks: ${_currentGoal.subTasks.length}");
      // Log das SubTasks individuais (útil para depurar dados)
      // for(var i = 0; i < _currentGoal.subTasks.length; i++) {
      //   debugPrint("  SubTask[$i]: ID=${_currentGoal.subTasks[i].id}, Title=${_currentGoal.subTasks[i].title}, Completed=${_currentGoal.subTasks[i].isCompleted}, Deadline=${_currentGoal.subTasks[i].deadline}");
      // }
    } catch (e, s) {
      debugPrint(
          "GoalDetailScreen: ERRO AO ACESSAR initialGoal no initState: $e");
      debugPrint("GoalDetailScreen: StackTrace: $s");
      // Em caso de erro ao acessar initialGoal, definimos um estado inválido ou padrão
      // para evitar crashes no build. Aqui, criamos um Goal "dummy" com erro.
      _currentGoal = Goal(
        id: widget.initialGoal.id ??
            'error-id', // Tenta usar o ID original se possível
        title: 'Erro ao Carregar Meta',
        description: 'Não foi possível carregar os detalhes desta jornada.',
        progress: 0,
        createdAt: DateTime.now(),
        userId: widget.userData.uid ?? 'unknown-user',
        subTasks: [], // Lista vazia para evitar erros de iteração
      );
      // Poderia também navegar de volta ou mostrar um Dialog de erro.
    }
  }

  // --- FUNÇÃO PARA ABRIR O MODAL DA IA ---
  void _openAiSuggestions() {
    if (_isLoading) return; // Previne abrir modal se já estiver carregando
    debugPrint("GoalDetailScreen: Abrindo modal de sugestões da IA...");

    // Mostra o modal a partir da base da tela
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que o modal ocupe mais altura
      backgroundColor: Colors
          .transparent, // Fundo transparente para container interno arredondado
      builder: (ctx) {
        // Retorna o widget do modal, passando a meta atual e o callback
        return AiSuggestionModal(
          goal: _currentGoal,
          onAddSuggestions: (suggestions) {
            // Esta função é chamada quando o usuário confirma no modal
            debugPrint(
                "GoalDetailScreen: Recebeu ${suggestions.length} sugestões do modal.");
            _addSuggestionsAsSubtasks(
                suggestions); // Chama a função para salvar
          },
        );
      },
    );
  }

  // --- FUNÇÃO PARA ADICIONAR AS SUGESTÕES COMO SUBTASKS ---
  Future<void> _addSuggestionsAsSubtasks(
      List<Map<String, String>> suggestions) async {
    // Verifica se há sugestões para adicionar
    if (suggestions.isEmpty) {
      debugPrint(
          "GoalDetailScreen: Nenhuma sugestão selecionada para adicionar.");
      return;
    }

    // Ativa o indicador de loading
    setState(() {
      _isLoading = true;
    });
    debugPrint(
        "GoalDetailScreen: Adicionando ${suggestions.length} subtasks sugeridas...");

    try {
      // Converte cada mapa de sugestão em um objeto SubTask
      final newSubTasks = suggestions.map((sug) {
        DateTime? deadline;
        try {
          // Tenta converter a string de data 'YYYY-MM-DD' para DateTime
          deadline = DateTime.parse(sug['date']!);
        } catch (e) {
          // Se falhar (formato inválido, etc.), loga o erro e deixa deadline como null
          debugPrint(
              "GoalDetailScreen: Erro ao fazer parse da data da IA: ${sug['date']} - $e");
          deadline = null;
        }

        // Cria a instância de SubTask
        return SubTask(
          id: FirebaseFirestore.instance
              .collection('temp')
              .doc()
              .id, // Gera ID único temporário
          title: sug['title'] ?? 'Marco sem título', // Fallback para título
          isCompleted: false, // Começa como não concluída
          deadline: deadline, // Data parseada ou null
        );
      }).toList();

      // Combina a lista existente com as novas subtarefas
      final updatedSubTasks = List<SubTask>.from(_currentGoal.subTasks)
        ..addAll(newSubTasks);
      // Cria o objeto Goal atualizado
      final updatedGoal = _currentGoal.copyWith(subTasks: updatedSubTasks);

      // Salva a meta atualizada no Firestore
      debugPrint("GoalDetailScreen: Salvando meta atualizada no Firestore...");
      await _firestoreService
          .updateGoal(updatedGoal); // Usa o método que aceita Goal

      // Atualiza o estado da UI e desativa o loading
      setState(() {
        _currentGoal = updatedGoal;
        _isLoading = false;
      });
      debugPrint("GoalDetailScreen: Subtasks adicionadas e estado atualizado.");

      // Mostra feedback de sucesso (se o widget ainda estiver montado)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Marcos adicionados com sucesso!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e, s) {
      // Captura erro e stack trace
      debugPrint("GoalDetailScreen: ERRO ao salvar os marcos sugeridos: $e");
      debugPrint("GoalDetailScreen: StackTrace: $s");
      // Desativa o loading em caso de erro
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      // Mostra feedback de erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao salvar os marcos: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FUNÇÃO PARA MARCAR/DESMARCAR SUBTASK ---
  Future<void> _toggleSubTask(SubTask subTaskToToggle) async {
    // Encontra o índice da subtarefa na lista atual
    final index =
        _currentGoal.subTasks.indexWhere((s) => s.id == subTaskToToggle.id);
    // Se não encontrar, sai da função
    if (index == -1) {
      debugPrint(
          "GoalDetailScreen: Subtask ${subTaskToToggle.id} não encontrada para toggle.");
      return;
    }
    debugPrint(
        "GoalDetailScreen: Toggling Subtask ID: ${subTaskToToggle.id} para ${!subTaskToToggle.isCompleted}");

    // Cria a subtarefa com o estado invertido
    final updatedSubTask =
        subTaskToToggle.copyWith(isCompleted: !subTaskToToggle.isCompleted);
    // Cria uma cópia modificável da lista de subtarefas
    final updatedSubTasks = List<SubTask>.from(_currentGoal.subTasks);
    // Substitui a subtarefa antiga pela nova na lista
    updatedSubTasks[index] = updatedSubTask;
    // Cria a meta atualizada com a nova lista
    final updatedGoal = _currentGoal.copyWith(subTasks: updatedSubTasks);

    // Atualiza a UI imediatamente (atualização otimista)
    setState(() {
      _currentGoal = updatedGoal;
    });

    // Tenta salvar a meta atualizada no Firestore
    try {
      await _firestoreService.updateGoal(updatedGoal);
      debugPrint(
          "GoalDetailScreen: Subtask ${subTaskToToggle.id} atualizada no Firestore.");
    } catch (e, s) {
      // Se o salvamento falhar
      debugPrint(
          "GoalDetailScreen: ERRO ao atualizar subtask ${subTaskToToggle.id}: $e");
      debugPrint("GoalDetailScreen: StackTrace: $s");
      // Reverte a mudança na UI
      final originalSubTasks = List<SubTask>.from(_currentGoal.subTasks);
      originalSubTasks[index] = subTaskToToggle; // Volta ao estado original
      if (mounted)
        setState(() {
          _currentGoal = _currentGoal.copyWith(subTasks: originalSubTasks);
        });
      // Mostra erro para o usuário
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao salvar atualização do marco: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FUNÇÃO PARA DELETAR SUBTASK ---
  Future<void> _deleteSubTask(SubTask subTaskToDelete) async {
    debugPrint(
        "GoalDetailScreen: Tentando deletar Subtask ID: ${subTaskToDelete.id}");
    // Mostra diálogo de confirmação
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirmar Exclusão',
              style: TextStyle(color: AppColors.primaryText)),
          content: const Text('Tem certeza que deseja excluir este marco?',
              style: TextStyle(color: AppColors.secondaryText)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.secondaryText)),
              onPressed: () =>
                  Navigator.of(context).pop(false), // Retorna false
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent), // Cor vermelha
              child: const Text('Excluir'),
              onPressed: () => Navigator.of(context).pop(true), // Retorna true
            ),
          ],
        );
      },
    );

    // Se o usuário confirmou
    if (confirmed == true) {
      debugPrint("GoalDetailScreen: Confirmação de deleção recebida.");
      setState(() {
        _isLoading = true;
      }); // Ativa loading
      try {
        // Cria nova lista sem a subtarefa a ser deletada
        final updatedSubTasks = List<SubTask>.from(_currentGoal.subTasks)
          ..removeWhere((s) => s.id == subTaskToDelete.id);
        // Cria meta atualizada
        final updatedGoal = _currentGoal.copyWith(subTasks: updatedSubTasks);

        debugPrint(
            "GoalDetailScreen: Salvando meta após deleção da subtask...");
        // Salva no Firestore
        await _firestoreService.updateGoal(updatedGoal);

        // Atualiza UI e desativa loading
        if (mounted) {
          setState(() {
            _currentGoal = updatedGoal;
            _isLoading = false;
          });
        }
        debugPrint(
            "GoalDetailScreen: Subtask ${subTaskToDelete.id} deletada com sucesso.");

        // Feedback de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Marco excluído.'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e, s) {
        // Se falhar ao salvar
        debugPrint("GoalDetailScreen: ERRO ao excluir marco: $e");
        debugPrint("GoalDetailScreen: StackTrace: $s");
        if (mounted)
          setState(() {
            _isLoading = false;
          }); // Desativa loading
        // Feedback de erro
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao excluir marco: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    } else {
      debugPrint("GoalDetailScreen: Deleção cancelada pelo usuário.");
    }
  }

  // --- FUNÇÃO PARA ABRIR EDIÇÃO DE SUBTASK (PLACEHOLDER) ---
  void _editSubTask(SubTask subTask) {
    debugPrint(
        "GoalDetailScreen: Botão Editar pressionado para Subtask ID: ${subTask.id}");
    // Mostra mensagem temporária
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edição de marco em breve!')),
    );
    // TODO: Implementar modal de edição para SubTask
    // Ex: showModalBottomSheet(context: context, builder: (_) => EditSubTaskModal(subTask: subTask));
  }

  @override
  Widget build(BuildContext context) {
    // --- LOG NO BUILD ---
    // Tratamento caso initState falhe em inicializar _currentGoal
    if (_currentGoal == null) {
      debugPrint("GoalDetailScreen: ERRO no build - _currentGoal é null!");
      return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
          body: const Center(
              child: Text(
                  "Erro Crítico: Não foi possível carregar os dados da jornada.",
                  style: TextStyle(color: Colors.red))));
    }
    debugPrint(
        "GoalDetailScreen: Build iniciado para Goal ID: ${_currentGoal.id}");

    // Calcula o progresso baseado nas subtasks atuais
    final completedSubTasks =
        _currentGoal.subTasks.where((s) => s.isCompleted).length;
    final totalSubTasks = _currentGoal.subTasks.length;
    final progress = totalSubTasks > 0
        ? (completedSubTasks / totalSubTasks * 100).round()
        : 0;
    debugPrint("GoalDetailScreen: Progresso calculado: $progress%");

    // Estrutura principal da tela
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        // Usa Stack para sobrepor o loading spinner
        children: [
          // Conteúdo principal rolável
          LayoutBuilder(
            // Para responsividade (desktop vs mobile)
            builder: (context, constraints) {
              debugPrint("GoalDetailScreen: LayoutBuilder build.");
              final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
              // Define paddings baseados no tamanho da tela
              final double horizontalPadding = isDesktop ? 24.0 : 12.0;
              // Padding da lista pode ser diferente em desktop
              final double listHorizontalPadding = isDesktop ? 0 : 12.0;

              return SafeArea(
                // Evita que o conteúdo fique sob a status bar/notch
                child: CustomScrollView(
                  // Permite AppBar fixa e conteúdo rolável
                  slivers: [
                    // AppBar que fica fixa no topo
                    SliverAppBar(
                      backgroundColor:
                          AppColors.background, // Fundo igual ao Scaffold
                      elevation: 0, // Sem sombra
                      pinned: true, // Mantém a AppBar visível ao rolar
                      leading: const BackButton(
                          color: AppColors.primary), // Botão voltar
                      title: const Text('Detalhes da Jornada',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                      centerTitle: true, // Centraliza título (opcional)
                    ),
                    // Card com informações da meta
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding, vertical: 8.0),
                        child: isDesktop
                            ? Center(
                                // Centraliza o card em telas grandes
                                child: ConstrainedBox(
                                  // Limita a largura máxima
                                  constraints: const BoxConstraints(
                                      maxWidth: kMaxContentWidth),
                                  child: _GoalInfoCard(
                                      goal: _currentGoal, progress: progress),
                                ),
                              )
                            : _GoalInfoCard(
                                goal: _currentGoal,
                                progress: progress), // Tamanho normal em mobile
                      ),
                    ),
                    // Cabeçalho da seção de marcos ("Marcos da Jornada" + Botão IA)
                    SliverToBoxAdapter(
                      child: Padding(
                        // Padding alinhado com o conteúdo da lista abaixo
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding + (isDesktop ? 0 : 4),
                            24.0,
                            horizontalPadding,
                            16.0),
                        child: isDesktop
                            ? Center(
                                // Centraliza em desktop
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: kMaxContentWidth),
                                  child: _buildMilestonesHeader(),
                                ),
                              )
                            : _buildMilestonesHeader(), // Normal em mobile
                      ),
                    ),
                    // Log antes de construir a lista de SubTasks
                    SliverToBoxAdapter(child: Builder(builder: (context) {
                      debugPrint(
                          "GoalDetailScreen: Construindo lista de SubTasks (${_currentGoal.subTasks.length} itens)...");
                      return const SizedBox
                          .shrink(); // Widget vazio apenas para log
                    })),
                    // Renderiza a lista de SubTasks (Marcos)
                    isDesktop
                        ? SliverToBoxAdapter(
                            // Usa Adapter para permitir centralização
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxWidth: kMaxContentWidth),
                                // Chama o widget que retorna um Column (não-sliver)
                                child: _buildSubTasksListWidget(
                                    subTasks: _currentGoal.subTasks,
                                    horizontalPadding: listHorizontalPadding),
                              ),
                            ),
                          )
                        : _buildSubTasksListSliver(
                            // Usa SliverList diretamente para mobile
                            subTasks: _currentGoal.subTasks,
                            horizontalPadding: listHorizontalPadding),

                    // Espaçamento extra no final para o FAB não cobrir o último item
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              );
            },
          ),
          // Indicador de Loading (sobrepõe todo o conteúdo)
          if (_isLoading)
            Container(
              color: Colors.black
                  .withOpacity(0.6), // Fundo escuro semi-transparente
              child: const Center(
                // Usa o CustomLoadingSpinner sem o parâmetro 'size'
                child: CustomLoadingSpinner(),
              ),
            ),
        ],
      ),
      // FAB Comentado para evitar conflito com GoalsScreen e porque a IA é o método principal agora
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () { /* TODO: Adicionar marco manualmente */ },
      //   label: const Text('Novo Marco'),
      //   icon: const Icon(Icons.add),
      //   backgroundColor: AppColors.primary,
      //   foregroundColor: Colors.white,
      //   heroTag: 'fab_goal_detail', // Tag ÚNICA e DIFERENTE da GoalsScreen
      // ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  // Constrói o cabeçalho da seção de marcos
  Widget _buildMilestonesHeader() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween, // Alinha itens nas pontas
      crossAxisAlignment: CrossAxisAlignment.center, // Alinha verticalmente
      children: [
        // Título da seção
        const Text(
          'Marcos da Jornada',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        // Botão para chamar a IA
        TextButton.icon(
          onPressed: _openAiSuggestions, // Chama a função correta
          icon: const Icon(Icons.auto_awesome,
              color: AppColors.primary, size: 20), // Ícone um pouco maior
          label: const Text('Sugerir com IA',
              style: TextStyle(
                  color: AppColors.primary, fontSize: 14)), // Ajusta fonte
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6), // Ajusta padding
            tapTargetSize:
                MaterialTapTargetSize.shrinkWrap, // Reduz área de toque extra
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(6)), // Borda levemente arredondada
            // backgroundColor: AppColors.primary.withOpacity(0.1) // Fundo sutil (opcional)
          ),
        ),
      ],
    );
  }

  // Constrói a lista de marcos para layout Desktop (retorna um Widget normal)
  Widget _buildSubTasksListWidget(
      {required List<SubTask> subTasks, required double horizontalPadding}) {
    debugPrint(
        "GoalDetailScreen: _buildSubTasksListWidget chamado com ${subTasks.length} subtasks.");
    if (subTasks.isEmpty) {
      // Mensagem para quando não há marcos
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: 64.0, horizontal: 20), // Aumenta padding vertical
          child: Text(
              'Nenhum marco adicionado ainda.\nUse o botão ✨ "Sugerir com IA" para começar!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 16,
                  height: 1.5) // Melhora legibilidade
              ),
        ),
      );
    }

    // Retorna uma coluna com os cards
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal:
              horizontalPadding), // Padding lateral (geralmente 0 para desktop aqui)
      child: Column(
        children: List.generate(subTasks.length, (index) {
          final subTask = subTasks[index];
          // Cria um Card para cada SubTask
          return Card(
            color: AppColors.cardBackground.withOpacity(0.6),
            elevation: 1.0,
            margin: const EdgeInsets.symmetric(vertical: 5.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            child: CheckboxListTile(
              // ListTile com Checkbox
              contentPadding: const EdgeInsets.only(
                  left: 10.0,
                  right: 4.0,
                  top: 8.0,
                  bottom: 8.0), // Ajusta padding
              title: Text(
                subTask.title,
                style: TextStyle(
                  fontSize: 15,
                  color: subTask.isCompleted
                      ? AppColors.tertiaryText
                      : AppColors.primaryText,
                  decoration:
                      subTask.isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.tertiaryText,
                  decorationThickness: 1.5, // Riscado mais visível
                ),
              ),
              subtitle: subTask.deadline != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Prazo: ${DateFormat('dd/MM/yyyy').format(subTask.deadline!)}',
                        style: const TextStyle(
                            color: AppColors.secondaryText, fontSize: 13),
                      ),
                    )
                  : null,
              value: subTask.isCompleted, // Estado do checkbox
              onChanged: (bool? value) {
                _toggleSubTask(subTask);
              }, // Ação ao clicar no checkbox
              activeColor: AppColors.primary, // Cor do checkbox marcado
              checkColor:
                  AppColors.cardBackground, // Cor do 'V' dentro do checkbox
              controlAffinity:
                  ListTileControlAffinity.leading, // Checkbox no início
              secondary: Row(
                // Botões de ação no final
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botão Editar
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 22, color: AppColors.secondaryText),
                    tooltip: 'Editar Marco',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4.0), // Padding pequeno
                    onPressed: () => _editSubTask(subTask),
                  ),
                  // Botão Excluir
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 22, color: Colors.redAccent),
                    tooltip: 'Excluir Marco',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4.0),
                    onPressed: () => _deleteSubTask(subTask),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Retorna um SliverList para layout Mobile.
  Widget _buildSubTasksListSliver(
      {required List<SubTask> subTasks, required double horizontalPadding}) {
    debugPrint(
        "GoalDetailScreen: _buildSubTasksListSliver chamado com ${subTasks.length} subtasks.");
    if (subTasks.isEmpty) {
      // Mensagem de estado vazio (como no desktop, mas dentro de um Sliver)
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 64.0, horizontal: 20),
            child: Text(
                'Nenhum marco adicionado ainda.\nUse o botão ✨ "Sugerir com IA" para começar!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.secondaryText, fontSize: 16, height: 1.5)),
          ),
        ),
      );
    }

    // Retorna a lista rolável dentro de um padding
    return SliverPadding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding), // Padding lateral da lista
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final subTask = subTasks[index];
            // Reutiliza a mesma lógica de Card do desktop
            return Card(
              color: AppColors.cardBackground.withOpacity(0.6),
              elevation: 1.0,
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.only(
                    left: 10.0, right: 4.0, top: 8.0, bottom: 8.0),
                title: Text(
                  subTask.title,
                  style: TextStyle(
                    fontSize: 15,
                    color: subTask.isCompleted
                        ? AppColors.tertiaryText
                        : AppColors.primaryText,
                    decoration:
                        subTask.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.tertiaryText,
                    decorationThickness: 1.5,
                  ),
                ),
                subtitle: subTask.deadline != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Prazo: ${DateFormat('dd/MM/yyyy').format(subTask.deadline!)}',
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 13),
                        ),
                      )
                    : null,
                value: subTask.isCompleted,
                onChanged: (bool? value) {
                  _toggleSubTask(subTask);
                },
                activeColor: AppColors.primary,
                checkColor: AppColors.cardBackground,
                controlAffinity: ListTileControlAffinity.leading,
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 22, color: AppColors.secondaryText),
                      tooltip: 'Editar Marco',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4.0),
                      onPressed: () => _editSubTask(subTask),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 22, color: Colors.redAccent),
                      tooltip: 'Excluir Marco',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4.0),
                      onPressed: () => _deleteSubTask(subTask),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: subTasks.length, // Define o número de itens
        ),
      ),
    );
  }
} // Fim da classe _GoalDetailScreenState

// --- WIDGET AUXILIAR _GoalInfoCard ---
// (Responsável por exibir o card superior com título, descrição e progresso)
class _GoalInfoCard extends StatelessWidget {
  final Goal goal;
  final int progress; // Recebe o progresso calculado

  const _GoalInfoCard({required this.goal, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Formata a data alvo, se existir
    String formattedDate = goal.targetDate != null
        ? DateFormat('dd/MM/yyyy', 'pt_BR').format(goal.targetDate!)
        : 'Sem prazo';

    return Container(
      padding: const EdgeInsets.all(16), // Padding interno do card
      decoration: BoxDecoration(
        color: AppColors.cardBackground, // Cor de fundo definida nas constantes
        borderRadius: BorderRadius.circular(16), // Bordas arredondadas
        // Sombra suave (opcional)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Alinha texto à esquerda
        children: [
          // Título da Meta
          Text(goal.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), // Espaçamento
          // Descrição (mostra apenas se não estiver vazia)
          if (goal.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(goal.description,
                  style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 15,
                      height: 1.4)), // Espaçamento entre linhas
            ),
          const SizedBox(height: 16), // Aumenta espaço antes da barra
          // Linha com texto "Progresso" e a porcentagem
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // Alinha nas pontas
            children: [
              const Text('Progresso',
                  style:
                      TextStyle(color: AppColors.secondaryText, fontSize: 14)),
              Text('$progress%', // Exibe a porcentagem recebida
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          // Barra de Progresso Linear
          LinearProgressIndicator(
            value: progress / 100.0, // Valor entre 0.0 e 1.0
            backgroundColor:
                AppColors.background.withOpacity(0.7), // Fundo da barra
            color: AppColors.primary, // Cor da barra de progresso
            minHeight: 10, // Altura da barra
            borderRadius:
                BorderRadius.circular(5), // Bordas arredondadas da barra
          ),
          const SizedBox(height: 16),
          // Data Alvo (mostra apenas se definida)
          if (goal.targetDate != null)
            Align(
              // Alinha à direita
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min, // Ocupa espaço mínimo
                children: [
                  const Icon(Icons.calendar_today_outlined, // Ícone diferente
                      size: 14,
                      color: AppColors.tertiaryText),
                  const SizedBox(width: 6),
                  Text("Alvo: $formattedDate",
                      style: const TextStyle(
                          color: AppColors.tertiaryText, fontSize: 13)),
                ],
              ),
            )
        ],
      ),
    );
  }
}
