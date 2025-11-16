// lib/common/widgets/custom_month_year_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class CustomMonthYearPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomMonthYearPicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomMonthYearPicker> createState() => _CustomMonthYearPickerState();
}

class _CustomMonthYearPickerState extends State<CustomMonthYearPicker> {
  late int _selectedYear;
  late int _selectedMonth;
  late List<int> _years;
  late List<String> _months;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  // --- ALTERAÇÃO: Variáveis para rastrear os índices atuais ---
  late int _currentYearIndex;
  late int _currentMonthIndex;
  // --- FIM DA ALTERAÇÃO ---

  final double _itemHeight = 60.0;
  // --- ALTERAÇÃO: Reduzido o wheelHeight para dar espaço para os botões ---
  final double _wheelHeight = 60.0 * 3; // Eram 5 itens
  // --- FIM DA ALTERAÇÃO ---

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;

    _years = List<int>.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );

    _months = List.generate(12, (index) {
      return DateFormat('MMM', 'pt_BR')
          .format(DateTime(2000, index + 1))
          .toUpperCase();
    });

    // --- ALTERAÇÃO: Define os índices iniciais ---
    _currentYearIndex =
        _years.indexOf(_selectedYear).clamp(0, _years.length - 1);
    _currentMonthIndex = (_selectedMonth - 1).clamp(0, 11);

    _yearController =
        FixedExtentScrollController(initialItem: _currentYearIndex);
    _monthController =
        FixedExtentScrollController(initialItem: _currentMonthIndex);
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
    _yearController.dispose();
    _monthController.dispose();
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
              "Selecionar Mês e Ano",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryText, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Layout de Duas Colunas com Rodas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Coluna Esquerda: Meses
                  Expanded(
                    child: _buildWheel(
                      controller: _monthController,
                      itemCount: _months.length,
                      items: _months,
                      // --- ALTERAÇÃO: Passa o índice atual ---
                      currentIndex: _currentMonthIndex,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedMonth = index + 1;
                          _currentMonthIndex = index; // Atualiza o índice
                          HapticFeedback.lightImpact();
                        });
                        _scrollToIndex(
                            _monthController, index); // Centraliza ao mudar
                      },
                      isMonth: true,
                    ),
                  ),

                  // Coluna Direita: Anos
                  Expanded(
                    child: _buildWheel(
                      controller: _yearController,
                      itemCount: _years.length,
                      items: _years.map((y) => y.toString()).toList(),
                      // --- ALTERAÇÃO: Passa o índice atual ---
                      currentIndex: _currentYearIndex,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedYear = _years[index];
                          _currentYearIndex = index; // Atualiza o índice
                          HapticFeedback.lightImpact();
                        });
                        _scrollToIndex(
                            _yearController, index); // Centraliza ao mudar
                      },
                      isMonth: false,
                    ),
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
                    onPressed: () => Navigator.pop(context),
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
                      final selectedDate =
                          DateTime(_selectedYear, _selectedMonth, 1);
                      Navigator.pop(context, selectedDate);
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
    required List<String> items,
    required ValueChanged<int> onSelectedItemChanged,
    required int currentIndex, // Índice atual para lógica de UI
    required bool isMonth,
  }) {
    // Define se os botões de seta estão habilitados
    final bool isAtStart = currentIndex == 0;
    final bool isAtEnd = currentIndex == (itemCount - 1);

    return SizedBox(
      width: isMonth ? 130 : 100, // Largura da coluna
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
            width: isMonth ? 130 : 100, // Largura da coluna
            height: _wheelHeight, // Altura da área de scroll
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: _itemHeight, // Altura de cada item
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onSelectedItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  final String text = items[index];
                  bool isSelected = (index == currentIndex);

                  return Container(
                    height: _itemHeight,
                    alignment: Alignment.center,
                    child: Container(
                      width: isMonth
                          ? 100
                          : 65, // Largura do fundo (maior para meses)
                      height: _itemHeight *
                          0.8, // Altura um pouco menor que o itemExtent
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
                                  .withValues(alpha: 0.6), // Texto branco ou opaco
                          fontSize: isSelected ? 20 : 18, // Tamanho da fonte
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
