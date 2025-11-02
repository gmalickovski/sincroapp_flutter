// lib/common/widgets/custom_time_picker_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class CustomTimePickerModal extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePickerModal({super.key, required this.initialTime});

  @override
  State<CustomTimePickerModal> createState() => _CustomTimePickerModalState();
}

class _CustomTimePickerModalState extends State<CustomTimePickerModal> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  // --- ALTERAÇÃO: Variáveis para rastrear os índices atuais ---
  late int _currentHourIndex;
  late int _currentMinuteIndex;
  // --- FIM DA ALTERAÇÃO ---

  final double _itemHeight = 60.0;
  // --- ALTERAÇÃO: Reduzido o wheelHeight para dar espaço para os botões ---
  final double _wheelHeight = 60.0 * 3; // Eram 5 itens
  // --- FIM DA ALTERAÇÃO ---

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    // --- ALTERAÇÃO: Define os índices iniciais ---
    _currentHourIndex = _selectedHour;
    _currentMinuteIndex = _selectedMinute;

    _hourController =
        FixedExtentScrollController(initialItem: _currentHourIndex);
    _minuteController =
        FixedExtentScrollController(initialItem: _currentMinuteIndex);
    // --- FIM DA ALTERAÇÃO ---
  }

  /// Função helper para animar a roda
  void _animateWheel(
      FixedExtentScrollController controller, int jump, int itemCount) {
    if (!controller.hasClients) return;

    final int newIndex =
        (controller.selectedItem + jump).clamp(0, itemCount - 1);

    if (newIndex != controller.selectedItem) {
      controller.animateToItem(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToIndex(FixedExtentScrollController controller, int index) {
    if (controller.hasClients) {
      controller.animateToItem(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // --- ALTERAÇÃO: Altura ajustada para o novo layout ---
      height: 480,
      // --- FIM DA ALTERAÇÃO ---
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: AppColors.tertiaryText,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Título
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Selecionar horário", // (Já estava consistente)
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryText, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Spinners
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildWheel(
                    controller: _hourController,
                    itemCount: 24,
                    // --- ALTERAÇÃO: Passa o índice atual ---
                    currentIndex: _currentHourIndex,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedHour = index;
                        _currentHourIndex = index; // Atualiza o índice
                        HapticFeedback.lightImpact();
                      });
                      _scrollToIndex(
                          _hourController, index); // Centraliza ao mudar
                    },
                    isHour: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      ":",
                      style: TextStyle(
                        color: AppColors.primaryText.withOpacity(0.7),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildWheel(
                    controller: _minuteController,
                    itemCount: 60,
                    // --- ALTERAÇÃO: Passa o índice atual ---
                    currentIndex: _currentMinuteIndex,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMinute = index;
                        _currentMinuteIndex = index; // Atualiza o índice
                        HapticFeedback.lightImpact();
                      });
                      _scrollToIndex(
                          _minuteController, index); // Centraliza ao mudar
                    },
                    isHour: false,
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: AppColors.border, height: 1),
          // Botões de Ação
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0 + 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final newTime = TimeOfDay(
                          hour: _selectedHour, minute: _selectedMinute);
                      Navigator.pop(context, newTime);
                    },
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom)
        ],
      ),
    );
  }

  // --- ALTERAÇÃO GERAL: _buildWheel agora inclui setas ---
  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
    required int currentIndex, // Índice atual para lógica de UI
    required bool isHour,
  }) {
    // Define se os botões de seta estão habilitados
    final bool isAtStart = currentIndex == 0;
    final bool isAtEnd = currentIndex == (itemCount - 1);

    return SizedBox(
      width: 90, // Largura da coluna
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Seta para Cima
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            iconSize: 32.0,
            color: isAtStart
                ? AppColors.tertiaryText // Cor desabilitada
                : AppColors.primaryText, // Cor habilitada
            onPressed: isAtStart
                ? null // Desabilita o botão
                : () => _animateWheel(controller, -1, itemCount),
          ),

          // A Roda (Spinner)
          SizedBox(
            width: 90, // Largura da coluna
            height: _wheelHeight, // Usa a altura definida
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: _itemHeight, // Usa a altura definida
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onSelectedItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  final bool isSelected = (index == currentIndex);
                  final text = index.toString().padLeft(2, '0');

                  return Container(
                    height: _itemHeight,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      width: double.infinity,
                      height: _itemHeight * 0.8,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent, // Fundo roxo
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryText
                                  .withOpacity(0.6), // Texto branco ou opaco
                          fontSize: isSelected ? 24 : 20, // Ajuste de tamanho
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
                childCount: itemCount,
              ),
            ),
          ),

          // Seta para Baixo
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 32.0,
            color: isAtEnd
                ? AppColors.tertiaryText // Cor desabilitada
                : AppColors.primaryText, // Cor habilitada
            onPressed: isAtEnd
                ? null // Desabilita o botão
                : () => _animateWheel(controller, 1, itemCount),
          ),
        ],
      ),
    );
  }
  // --- FIM DA ALTERAÇÃO ---
}
