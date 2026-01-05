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

  // Variáveis para rastrear os índices atuais
  late int _currentHourIndex;
  late int _currentMinuteIndex;

  // Estado para controlar o modo de entrada (Roda vs Teclado)
  bool _isInputMode = false;

  // Controllers para o modo de texto
  late TextEditingController _hourTextController;
  late TextEditingController _minuteTextController;
  final FocusNode _hourFocusNode = FocusNode();
  final FocusNode _minuteFocusNode = FocusNode();

  final double _itemHeight = 60.0;
  final double _wheelHeight = 60.0 * 3;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    _currentHourIndex = _selectedHour;
    _currentMinuteIndex = _selectedMinute;

    _hourController =
        FixedExtentScrollController(initialItem: _currentHourIndex);
    _minuteController =
        FixedExtentScrollController(initialItem: _currentMinuteIndex);

    // Inicializa controllers de texto
    _hourTextController =
        TextEditingController(text: _selectedHour.toString().padLeft(2, '0'));
    _minuteTextController =
        TextEditingController(text: _selectedMinute.toString().padLeft(2, '0'));

    // Listeners para atualizar o estado ao digitar
    _hourTextController.addListener(_onHourTextChanged);
    _minuteTextController.addListener(_onMinuteTextChanged);
  }

  void _onHourTextChanged() {
    final text = _hourTextController.text;
    final value = int.tryParse(text);
    if (value != null && value >= 0 && value < 24) {
      setState(() {
        _selectedHour = value;
        _currentHourIndex = value;
      });
      // Sincroniza a roda se possível
      if (_hourController.hasClients) {
        _hourController.jumpToItem(value);
      }
    }
  }

  void _onMinuteTextChanged() {
    final text = _minuteTextController.text;
    final value = int.tryParse(text);
    if (value != null && value >= 0 && value < 60) {
      setState(() {
        _selectedMinute = value;
        _currentMinuteIndex = value;
      });
      // Sincroniza a roda se possível
      if (_minuteController.hasClients) {
        _minuteController.jumpToItem(value);
      }
    }
  }

  /// Alterna entre modo roda e modo teclado
  void _toggleInputMode() {
    setState(() {
      _isInputMode = !_isInputMode;
      if (_isInputMode) {
        // Atualiza os textos ao entrar no modo teclado
        _hourTextController.text = _selectedHour.toString().padLeft(2, '0');
        _minuteTextController.text = _selectedMinute.toString().padLeft(2, '0');
        // Foca na hora automaticamente
        Future.delayed(Duration.zero, () {
             _hourFocusNode.requestFocus();
             _hourTextController.selection = TextSelection(baseOffset: 0, extentOffset: _hourTextController.text.length);
        });
      } else {
        // Sincroniza as rodas ao voltar para o modo roda
        if (_hourController.hasClients) _hourController.jumpToItem(_selectedHour);
        if (_minuteController.hasClients)
          _minuteController.jumpToItem(_selectedMinute);
      }
    });
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
    _hourTextController.dispose();
    _minuteTextController.dispose();
    _hourFocusNode.dispose();
    _minuteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520, // Aumentado um pouco para acomodar inputs
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
          // Título e Botão de Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 // Placeholder ou vazio para centralizar o texto se necessário
                 const SizedBox(width: 48), 
                Text(
                  _isInputMode ? "Digitar horário" : "Selecionar horário",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryText, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _toggleInputMode,
                  icon: Icon(
                    _isInputMode ? Icons.access_time_filled_rounded : Icons.keyboard,
                    color: AppColors.primary,
                  ),
                  tooltip: _isInputMode ? "Modo seleção" : "Modo digitação",
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Conteúdo (CrossFade entre Roda e Input)
          Expanded(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isInputMode
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildWheelView(),
              secondChild: _buildInputView(),
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

  /// Constrói a visualização de entrada de texto (Teclado)
  Widget _buildInputView() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimeInput(_hourTextController, _hourFocusNode, (val) {
             if (val.length == 2) _minuteFocusNode.requestFocus();
          }),
          Text(
            ":",
            style: TextStyle(
              color: AppColors.primaryText.withValues(alpha: 0.7),
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          _buildTimeInput(_minuteTextController, _minuteFocusNode, (val) {}),
        ],
      ),
    );
  }

  Widget _buildTimeInput(TextEditingController controller, FocusNode focusNode, Function(String) onChanged) {
    return Container(
      width: 90,
      height: 80,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryText,
        ),
        maxLength: 2,
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
      ),
    );
  }

  /// Constrói a visualização de rodas (Spinners)
  Widget _buildWheelView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildWheel(
            controller: _hourController,
            itemCount: 24,
            currentIndex: _currentHourIndex,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedHour = index;
                _currentHourIndex = index;
                HapticFeedback.lightImpact();
              });
              _scrollToIndex(_hourController, index);
            },
            isHour: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              ":",
              style: TextStyle(
                color: AppColors.primaryText.withValues(alpha: 0.7),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildWheel(
            controller: _minuteController,
            itemCount: 60,
            currentIndex: _currentMinuteIndex,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedMinute = index;
                _currentMinuteIndex = index;
                HapticFeedback.lightImpact();
              });
              _scrollToIndex(_minuteController, index);
            },
            isHour: false,
          ),
        ],
      ),
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
    required int currentIndex,
    required bool isHour,
  }) {
    final bool isAtStart = currentIndex == 0;
    final bool isAtEnd = currentIndex == (itemCount - 1);

    return SizedBox(
      width: 90,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            iconSize: 32.0,
            color: isAtStart ? AppColors.tertiaryText : AppColors.primaryText,
            onPressed: isAtStart
                ? null
                : () => _animateWheel(controller, -1, itemCount),
          ),
          SizedBox(
            width: 90,
            height: _wheelHeight,
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: _itemHeight,
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
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryText.withValues(alpha: 0.6),
                          fontSize: isSelected ? 24 : 20,
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
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 32.0,
            color: isAtEnd ? AppColors.tertiaryText : AppColors.primaryText,
            onPressed: isAtEnd
                ? null
                : () => _animateWheel(controller, 1, itemCount),
          ),
        ],
      ),
    );
  }
}
