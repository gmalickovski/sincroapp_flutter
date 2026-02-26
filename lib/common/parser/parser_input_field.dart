// lib/common/parser/parser_input_field.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/parser/parser_popup.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';

class ParserInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final Function(String) onSubmitted;
  final int? maxLines;
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextCapitalization textCapitalization;

  /// Callback para buscar sugestões quando um trigger é detectado.
  final Future<List<ParserSuggestion>> Function(ParserKeyType type, String query)?
      onSearch;

  final void Function(ParserKeyType type, ParserSuggestion suggestion)?
      onSuggestionSelected;

  /// Tipos de trigger que estão desativados (serão tratados como texto normal)
  final List<ParserKeyType> disabledTriggers;
  
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;

  const ParserInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = '',
    required this.onSubmitted,
    this.maxLines = 1,
    this.decoration,
    this.style,
    this.textCapitalization = TextCapitalization.none,
    this.onSearch,
    this.onSuggestionSelected,
    this.disabledTriggers = const [],
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
  });

  @override
  State<ParserInputField> createState() => _ParserInputFieldState();
}

class _ParserInputFieldState extends State<ParserInputField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<ParserSuggestion> _suggestions = [];
  bool _isLoading = false;
  ParserKeyType? _activeType;

  Timer? _debounce;
  String? _currentSearchTerm;
  int? _triggerStartIndex;
  bool _isSelectingSuggestion = false; // Flag para evitar remover overlay durante seleção

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !widget.focusNode.hasFocus && !_isSelectingSuggestion) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    if (!widget.focusNode.hasFocus) return;
    if (widget.onSearch == null) return;
    if (_isSelectingSuggestion) return; // Não processar durante seleção

    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _removeOverlay();
      return;
    }

    final cursorPos = selection.baseOffset;
    if (cursorPos <= 0) {
      _removeOverlay();
      return;
    }

    // Usa TaskParser.detectActiveTrigger para detectar qual chave está ativa
    final trigger = TaskParser.detectActiveTrigger(text, cursorPos);

    if (trigger != null && !widget.disabledTriggers.contains(trigger.type)) {
      _showSuggestions(trigger);
      return;
    }

    // Se era um trigger de TAG ativo e agora não é mais (espaço/enter foi digitado),
    // auto-cria a tag. Para @ e !, o texto vira texto normal.
    if (_activeType == ParserKeyType.tag &&
        _triggerStartIndex != null &&
        _currentSearchTerm != null &&
        _currentSearchTerm!.isNotEmpty) {
      // Verifica se o caracter logo após o último query é espaço ou newline
      final expectedEnd = _triggerStartIndex! + 1 + _currentSearchTerm!.length;
      if (cursorPos > expectedEnd) {
        final charAfter = text.length > expectedEnd ? text[expectedEnd] : '';
        if (charAfter == ' ' || charAfter == '\n') {
          // Auto-cria a tag
          final normalizedLabel = TaskParser.normalizeParserKey(
              _currentSearchTerm!, ParserKeyType.tag);
          final newTagSuggestion = ParserSuggestion(
            id: normalizedLabel,
            label: normalizedLabel,
            type: ParserKeyType.tag,
          );
          widget.onSuggestionSelected?.call(ParserKeyType.tag, newTagSuggestion);
        }
      }
    }

    _removeOverlay();
  }

  void _showSuggestions(ParserTrigger trigger) {
    if (_currentSearchTerm == trigger.query &&
        _activeType == trigger.type &&
        _overlayEntry != null) {
      return;
    }

    _currentSearchTerm = trigger.query;
    _triggerStartIndex = trigger.startIndex;
    _activeType = trigger.type;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await _fetchSuggestions(trigger.type, trigger.query);
    });
  }

  Future<void> _fetchSuggestions(ParserKeyType type, String query) async {
    if (widget.onSearch == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await widget.onSearch!(type, query);

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });

        if (_suggestions.isNotEmpty) {
          _updateOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao buscar sugestões ($type): $e');
    }
  }

  void _updateOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _suggestions = [];
    _currentSearchTerm = null;
    _triggerStartIndex = null;
    _activeType = null;
  }

  void _selectSuggestion(ParserSuggestion suggestion) {
    if (_triggerStartIndex == null) return;

    _isSelectingSuggestion = true; // Bloqueia processamento durante seleção

    final text = widget.controller.text;
    final triggerChar = text[_triggerStartIndex!]; // #, @, ou !
    final value = suggestion.label;

    // Calcula o fim da substituição: trigger + query digitada
    int replaceEnd;
    if (_currentSearchTerm != null) {
      replaceEnd = _triggerStartIndex! + 1 + _currentSearchTerm!.length;
    } else {
      replaceEnd = widget.controller.selection.baseOffset;
      if (replaceEnd == -1) {
        _isSelectingSuggestion = false;
        return;
      }
    }

    if (replaceEnd > text.length) replaceEnd = text.length;

    // Substitui trigger+query por trigger+valor + espaço
    final newText = text.replaceRange(
        _triggerStartIndex!, replaceEnd, '$triggerChar$value ');

    // Calcula nova posição do cursor: após trigger + valor + espaço
    final newCursorPos = _triggerStartIndex! + 1 + value.length + 1;

    // Remove overlay ANTES de mudar o texto para evitar conflitos
    _removeOverlay();

    // Atualiza o texto
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(
        TextPosition(offset: newCursorPos),
      ),
    );

    // Notifica o callback externo
    widget.onSuggestionSelected?.call(suggestion.type, suggestion);

    // Re-foca no campo de texto
    widget.focusNode.requestFocus();

    // Libera a flag após um pequeno delay para evitar que _onTextChanged interfira
    Future.delayed(const Duration(milliseconds: 100), () {
      _isSelectingSuggestion = false;
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        // Encontra a caixa de renderização do widget original para checar a posição global
        final renderBox = this.context.findRenderObject() as RenderBox?;
        final screenSize = MediaQuery.of(context).size;
        
        double maxPopupWidth = 280;
        double xOffset = 0;

        if (renderBox != null) {
          final offset = renderBox.localToGlobal(Offset.zero);
          final dx = offset.dx;
          
          // Se o popup estourar a borda direita da tela...
          if (dx + maxPopupWidth > screenSize.width - 16) {
            xOffset = (screenSize.width - 16) - (dx + maxPopupWidth);
            // Evita estourar a borda esquerda
            if (dx + xOffset < 16) {
              xOffset = 16 - dx;
              maxPopupWidth = screenSize.width - 32; 
            }
          }
        }

        return Positioned(
          width: maxPopupWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: Offset(xOffset, 0),
            child: Material(
              color: Colors.transparent,
              child: ParserPopup(
                suggestions: _suggestions,
                activeType: _activeType ?? ParserKeyType.mention,
                onSelected: _selectSuggestion,
                isLoading: _isLoading,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofillHints: const [],
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType ?? (widget.maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        style: widget.style ?? const TextStyle(color: Colors.white),
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(color: AppColors.secondaryText),
              border: InputBorder.none,
            ),
        textCapitalization: widget.textCapitalization,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
