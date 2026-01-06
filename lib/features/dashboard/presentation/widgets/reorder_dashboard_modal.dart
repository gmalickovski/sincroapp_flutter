// lib/features/dashboard/presentation/widgets/reorder_dashboard_modal.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

// Mapeia os IDs dos cards para seus nomes de exibição e ícones
const Map<String, Map<String, dynamic>> _cardDisplayData = {
  'goalsProgress': {
    'name': 'Progresso das Jornadas',
    'icon': Icons.flag_outlined
  },
  'focusDay': {'name': 'Foco do Dia', 'icon': Icons.check_circle_outline},
  'vibracaoDia': {'name': 'Dia Pessoal', 'icon': Icons.sunny},
  'sincroflow': {'name': 'Sincroflow', 'icon': Icons.hub_outlined}, // ATUALIZADO
  'vibracaoMes': {'name': 'Mês Pessoal', 'icon': Icons.nightlight_round},
  'vibracaoAno': {'name': 'Ano Pessoal', 'icon': Icons.star_border},
  'cicloVida': {'name': 'Ciclo de Vida', 'icon': Icons.repeat},
  'diaNatalicio': {'name': 'Dia Natalício', 'icon': Icons.cake},
  // Novos cards numerológicos (planos pagos)
  'numeroDestino': {
    'name': 'Número de Destino',
    'icon': Icons.explore_outlined,
  },
  'numeroExpressao': {
    'name': 'Número de Expressão',
    'icon': Icons.face_outlined,
  },
  'numeroMotivacao': {
    'name': 'Número da Motivação',
    'icon': Icons.favorite_border,
  },
  'numeroImpressao': {
    'name': 'Número de Impressão',
    'icon': Icons.visibility_outlined,
  },
  'numeroPsiquico': {
    'name': 'Número Psíquico',
    'icon': Icons.bubble_chart_outlined,
  },
  'missaoVida': {
    'name': 'Missão de Vida',
    'icon': Icons.flag_outlined,
  },
  'talentoOculto': {
    'name': 'Talento Oculto',
    'icon': Icons.auto_awesome,
  },
  'aptidoesProfissionais': {
    'name': 'Aptidões Profissionais',
    'icon': Icons.work_outline,
  },
  'respostaSubconsciente': {
    'name': 'Resposta Subconsciente',
    'icon': Icons.psychology_outlined,
  },
  // Listas e relacionamentos
  'licoesCarmicas': {
    'name': 'Lições Kármicas',
    'icon': Icons.menu_book_outlined,
  },
  'debitosCarmicos': {
    'name': 'Débitos Kármicos',
    'icon': Icons.balance_outlined,
  },
  'tendenciasOcultas': {
    'name': 'Tendências Ocultas',
    'icon': Icons.visibility_off_outlined,
  },
  'desafios': {
    'name': 'Desafios',
    'icon': Icons.warning_amber_outlined,
  },
  'momentosDecisivos': {
    'name': 'Momentos Decisivos',
    'icon': Icons.timelapse,
  },
  'harmoniaConjugal': {
    'name': 'Harmonia Conjugal',
    'icon': Icons.favorite_border,
  },
  'diasFavoraveis': {
    'name': 'Dias Favoráveis',
    'icon': Icons.event_available,
  },
};

class ReorderDashboardModal extends StatefulWidget {
  final String userId;
  final List<String> initialOrder;
  final List<String> initialHidden;
  final ScrollController? scrollController;
  final Function(bool success) onSaveComplete;
  // Opcional: permite passar a lista de chaves disponíveis no dashboard atual
  // (se não fornecida, o modal usa todo o catálogo de _cardDisplayData)
  final List<String>? availableKeys;

  const ReorderDashboardModal({
    super.key,
    required this.userId,
    required this.initialOrder,
    this.initialHidden = const [],
    this.scrollController,
    required this.onSaveComplete,
    this.availableKeys,
  });

  @override
  State<ReorderDashboardModal> createState() => _ReorderDashboardModalState();
}

class _ReorderDashboardModalState extends State<ReorderDashboardModal> {
  late List<String> _currentOrder;
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  late Set<String> _hidden; // controla cards ocultos durante a edição

  @override
  void initState() {
    super.initState();
    _currentOrder = List.from(widget.initialOrder);
    
    // ATUALIZAÇÃO: Se 'bussola' ainda estiver salvo, migrar para 'sincroflow' visualmente
    if (_currentOrder.contains('bussola')) {
      final index = _currentOrder.indexOf('bussola');
      _currentOrder[index] = 'sincroflow';
    }

    // 1) Mantém apenas IDs conhecidos no catálogo
    _currentOrder.removeWhere((id) => !_cardDisplayData.containsKey(id));
    // 2) Garante que TODOS os cards do catálogo (ou os disponíveis informados)
    //    apareçam no modal, adicionando os que não constam na ordem salva.
    final List<String> catalog =
        widget.availableKeys ?? _cardDisplayData.keys.toList();
    for (final id in catalog) {
      if (_cardDisplayData.containsKey(id) && !_currentOrder.contains(id)) {
        _currentOrder.add(id);
      }
    }
    // 3) Filtra o conjunto de ocultos para conter apenas IDs válidos
    _hidden = {...widget.initialHidden};
    
    // Migração de ocultos também
    if (_hidden.contains('bussola')) {
        _hidden.remove('bussola');
        _hidden.add('sincroflow');
    }

    _hidden.removeWhere((id) => !_cardDisplayData.containsKey(id));
  }

  Future<void> _onSave() async {
    // Usando a versão com callback, que funcionou para o erro anterior
    final messenger = ScaffoldMessenger.of(context);
    final bool isMountedAtStart = mounted;

    debugPrint("ReorderModal: _onSave iniciado. Mounted: $isMountedAtStart");
    if (!isMountedAtStart) return;

    setState(() => _isLoading = true);
    try {
      debugPrint("ReorderModal: Chamando Supabase update...");
      
      await _supabaseService.updateUserData(widget.userId, {
        'dashboardCardOrder': _currentOrder,
        'dashboardHiddenCards': _hidden.toList(),
      });
      
      debugPrint("ReorderModal: Supabase update finalizado com sucesso.");
      if (mounted) {
        debugPrint("ReorderModal: Chamando onSaveComplete(true).");
        widget.onSaveComplete(true);
      } else {
        debugPrint(
            "ReorderModal: Sucesso no save, mas widget desmontado antes de chamar onSaveComplete.");
      }
    } catch (e, stackTrace) {
      debugPrint("ReorderModal: Erro durante save: $e");
      debugPrint("StackTrace: $stackTrace");
      if (mounted) {
        debugPrint("ReorderModal: Mostrando SnackBar de erro.");
        messenger.showSnackBar(SnackBar(
            content: Text('Erro ao salvar: ${e.toString()}'),
            backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        debugPrint("ReorderModal: Chamando onSaveComplete(false).");
        widget.onSaveComplete(false);
      } else {
        debugPrint("ReorderModal: Erro ocorreu, mas widget desmontado.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Container mas agora pensado para Dialog
    return Container(
      constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8), // Limita altura e largura
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // REMOVIDO: Handle (barra cinza)

          // Título centralizado e Fechar
          Padding(
            padding:
                const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 // Título
                 const Text('Organizar Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                 // Fechar
                 IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.secondaryText),
                    onPressed: () => widget.onSaveComplete(false),
                    tooltip: 'Fechar',
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Lista
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true, // Importante para Dialog com Column min
              buildDefaultDragHandles: false,
              scrollController: widget.scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
              itemCount: _currentOrder.length,
              itemBuilder: (context, index) {
                final cardId = _currentOrder[index];
                final cardData = _cardDisplayData[cardId] ??
                    {'name': cardId, 'icon': Icons.drag_indicator};

                final bool isHidden = _hidden.contains(cardId);

                // Item com ícone do card, título, botão de ocultar e alça de arrastar
                return ListTile(
                  key: ValueKey(cardId),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle de arraste (6 pontos) – só inicia drag ao tocar nele
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator,
                          color: AppColors.secondaryText
                              .withValues(alpha: isHidden ? 0.35 : 0.8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        cardData['icon'],
                        color: isHidden
                            ? AppColors.secondaryText.withValues(alpha: 0.4)
                            : AppColors.secondaryText,
                      ),
                    ],
                  ),
                  title: Text(
                    cardData['name'],
                    style: TextStyle(
                      color: AppColors.primaryText
                          .withValues(alpha: isHidden ? 0.5 : 1.0),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: isHidden ? 'Mostrar card' : 'Ocultar card',
                    icon: Icon(
                      isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: isHidden ? AppColors.secondaryText : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isHidden) {
                          _hidden.remove(cardId);
                        } else {
                          _hidden.add(cardId);
                        }
                      });
                    },
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final String item = _currentOrder.removeAt(oldIndex);
                  _currentOrder.insert(newIndex, item);
                });
              },
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                return Material(
                  color: AppColors.cardBackground,
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
            ),
          ),
          // Botão Salvar (Pill)
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)), // Pilula
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar Ordem',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
