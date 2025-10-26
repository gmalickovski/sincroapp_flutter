// -----------------------------------------------------------------
// ARQUIVO ATUALIZADO: custom_month_year_picker.dart
// (Com layout de duas colunas)
// -----------------------------------------------------------------
import 'package:flutter/material.dart';
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
  late List<String> _months; // Lista de nomes dos meses
  late ScrollController _yearScrollController;
  late ScrollController _monthScrollController; // Controller para os meses

  final double _itemHeight = 50.0; // Altura padrão para itens de lista

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month; // Meses são 1-12

    // Gera a lista de anos
    _years = List<int>.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );

    // Gera a lista de meses abreviados
    _months = List.generate(12, (index) {
      return DateFormat('MMM', 'pt_BR')
          .format(DateTime(2000, index + 1)) // Ano não importa
          .toUpperCase();
    });

    // Calcula índices iniciais
    int initialYearIndex =
        _years.indexOf(_selectedYear).clamp(0, _years.length - 1);
    int initialMonthIndex =
        (_selectedMonth - 1).clamp(0, 11); // Meses 0-11 internamente

    // Inicializa controllers com offset para centralizar (aproximadamente)
    _yearScrollController = ScrollController(
        initialScrollOffset: (initialYearIndex * _itemHeight) -
            _itemHeight * 1.5); // Tenta centralizar
    _monthScrollController = ScrollController(
        initialScrollOffset: (initialMonthIndex * _itemHeight) -
            _itemHeight * 1.5); // Tenta centralizar

    // Scroll para os itens selecionados após o build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(_yearScrollController, initialYearIndex);
      _scrollToIndex(_monthScrollController, initialMonthIndex);
    });
  }

  // Função helper para scroll animado
  void _scrollToIndex(ScrollController controller, int index) {
    if (controller.hasClients) {
      // Calcula o offset para tentar centralizar o item
      // (alturaContainer / 2) - (alturaItem / 2) + (index * alturaItem)
      // Considerando alturaContainer ~ 150 (3 * _itemHeight)
      final targetOffset =
          (index * _itemHeight) - (_itemHeight * 1.0); // Ajuste fino aqui

      controller.animateTo(
        targetOffset.clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _yearScrollController.dispose();
    _monthScrollController.dispose(); // Dispose do novo controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Altura ajustada para o novo layout
      height: 380, // Pode precisar de ajuste fino
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
              "Selecione Mês e Ano",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryText, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: AppColors.border),

          // <-- LAYOUT ALTERADO PARA Row COM DUAS COLUNAS -->
          Expanded(
            child: Row(
              children: [
                // Coluna Esquerda: Meses
                Expanded(
                  child: _buildScrollableList(
                    controller: _monthScrollController,
                    itemCount: _months.length,
                    itemBuilder: (context, index) {
                      final monthValue = index + 1; // 1-12
                      final monthName = _months[index];
                      final isSelected = monthValue == _selectedMonth;
                      return _buildListItem(
                        text: monthName,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedMonth = monthValue;
                          });
                          _scrollToIndex(_monthScrollController, index);
                        },
                      );
                    },
                  ),
                ),

                // Divisor Vertical
                const VerticalDivider(width: 1, color: AppColors.border),

                // Coluna Direita: Anos
                Expanded(
                  child: _buildScrollableList(
                    controller: _yearScrollController,
                    itemCount: _years.length,
                    itemBuilder: (context, index) {
                      final year = _years[index];
                      final isSelected = year == _selectedYear;
                      return _buildListItem(
                        text: year.toString(),
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedYear = year;
                          });
                          _scrollToIndex(_yearScrollController, index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // <-- FIM DO LAYOUT ALTERADO -->

          const Divider(color: AppColors.border, height: 1),
          // Botões de Ação
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context), // Retorna null
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(
                        color: AppColors.primaryText,
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
        ],
      ),
    );
  }

  // Widget helper para criar as listas de scroll
  Widget _buildScrollableList({
    required ScrollController controller,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return SizedBox(
      // Define uma altura explícita para o ListView funcionar dentro do Expanded/Row
      height: double.infinity, // Ocupa toda a altura disponível na Row
      child: ListView.builder(
        controller: controller,
        itemCount: itemCount,
        itemExtent: _itemHeight, // Usa a altura definida
        itemBuilder: itemBuilder,
      ),
    );
  }

  // Widget helper para criar os itens da lista (Mês ou Ano)
  Widget _buildListItem({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.primaryText,
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
