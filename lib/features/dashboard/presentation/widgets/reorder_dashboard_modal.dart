// lib/features/dashboard/presentation/widgets/reorder_dashboard_modal.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';

// Mapeia os IDs dos cards para seus nomes de exibição e ícones
const Map<String, Map<String, dynamic>> _cardDisplayData = {
  'goalsProgress': {
    'name': 'Progresso das Jornadas',
    'icon': Icons.flag_outlined
  },
  'focusDay': {'name': 'Foco do Dia', 'icon': Icons.check_circle_outline},
  'vibracaoDia': {'name': 'Vibração do Dia', 'icon': Icons.sunny},
  'bussola': {'name': 'Bússola de Atividades', 'icon': Icons.explore_outlined},
  'vibracaoMes': {'name': 'Vibração do Mês', 'icon': Icons.nightlight_round},
  'vibracaoAno': {'name': 'Vibração do Ano', 'icon': Icons.star_border},
  'arcanoRegente': {
    'name': 'Arcano Regente',
    'icon': Icons.shield_moon_outlined
  },
  'arcanoVigente': {'name': 'Arcano Vigente', 'icon': Icons.shield_moon},
  'cicloVida': {'name': 'Ciclo de Vida', 'icon': Icons.repeat},
};

class ReorderDashboardModal extends StatefulWidget {
  final String userId;
  final List<String> initialOrder;
  final ScrollController? scrollController;
  final Function(bool success) onSaveComplete;

  const ReorderDashboardModal({
    super.key,
    required this.userId,
    required this.initialOrder,
    this.scrollController,
    required this.onSaveComplete,
  });

  @override
  State<ReorderDashboardModal> createState() => _ReorderDashboardModalState();
}

class _ReorderDashboardModalState extends State<ReorderDashboardModal> {
  late List<String> _currentOrder;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = List.from(widget.initialOrder);
    _currentOrder.removeWhere((id) => !_cardDisplayData.containsKey(id));
  }

  Future<void> _onSave() async {
    // Usando a versão com callback, que funcionou para o erro anterior
    final messenger = ScaffoldMessenger.of(context);
    final bool isMountedAtStart = mounted;

    print("ReorderModal: _onSave iniciado. Mounted: $isMountedAtStart");
    if (!isMountedAtStart) return;

    setState(() => _isLoading = true);
    bool success = false;
    try {
      print("ReorderModal: Chamando Firestore update...");
      await _firestoreService.updateUserDashboardOrder(
          widget.userId, _currentOrder);
      print("ReorderModal: Firestore update finalizado com sucesso.");
      success = true;
      if (mounted) {
        print("ReorderModal: Chamando onSaveComplete(true).");
        widget.onSaveComplete(true);
      } else {
        print(
            "ReorderModal: Sucesso no save, mas widget desmontado antes de chamar onSaveComplete.");
      }
    } catch (e, stackTrace) {
      print("ReorderModal: Erro durante save: $e");
      print(stackTrace);
      success = false;
      if (mounted) {
        print("ReorderModal: Mostrando SnackBar de erro.");
        messenger.showSnackBar(SnackBar(
            content: Text('Erro ao salvar: ${e.toString()}'),
            backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        print("ReorderModal: Chamando onSaveComplete(false).");
        widget.onSaveComplete(false);
      } else {
        print("ReorderModal: Erro ocorreu, mas widget desmontado.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2)),
          ),
          // Título e Fechar
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reordenar Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.secondaryText),
                    onPressed: () => widget.onSaveComplete(false))
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Lista
          Flexible(
            child: ReorderableListView.builder(
              scrollController: widget.scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: _currentOrder.length,
              itemBuilder: (context, index) {
                final cardId = _currentOrder[index];
                final cardData = _cardDisplayData[cardId] ??
                    {'name': cardId, 'icon': Icons.drag_indicator};

                // ================== INÍCIO DA CORREÇÃO ==================
                // Retorna o ListTile diretamente e coloca a Key nele.
                // Removemos o wrapper Material.
                return ListTile(
                  key: ObjectKey(cardId), // <<<--- KEY AQUI
                  leading:
                      Icon(cardData['icon'], color: AppColors.secondaryText),
                  title: Text(
                    cardData['name'],
                    style: const TextStyle(color: AppColors.primaryText),
                  ),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle,
                        color: AppColors.secondaryText),
                  ),
                );
                // ================== FIM DA CORREÇÃO ==================
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final String item = _currentOrder.removeAt(oldIndex);
                  _currentOrder.insert(newIndex, item);
                });
              },
              // Adiciona um proxyDecorator para dar feedback visual durante o arraste
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                return Material(
                  color:
                      AppColors.primary.withOpacity(0.1), // Cor de fundo suave
                  elevation: 4.0, // Sombra
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
            ),
          ),
          // Botão Salvar
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
