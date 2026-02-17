// lib/common/parser/parser_input_field.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';
import 'package:sincro_app_flutter/common/parser/parser_text_controller.dart';
import 'package:sincro_app_flutter/common/parser/parser_popup.dart';

/// Callback para buscar sugestões por tipo de chave.
typedef ParserSearchCallback = Future<List<ParserSuggestion>> Function(
    ParserKeyType type, String query);

/// Campo de texto unificado com popup de sugestões para #tags, @contatos e !metas.
class ParserInputField extends StatefulWidget {
  final ParserTextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final Function(String) onSubmitted;
  final int? maxLines;
  final InputDecoration? decoration;
  final TextCapitalization textCapitalization;

  /// Callback para buscar sugestões quando um trigger é detectado.
  /// Se null, o popup não será exibido para nenhum tipo.
  final ParserSearchCallback? onSearch;

  /// Callback quando uma sugestão é selecionada.
  final Function(ParserKeyType type, ParserSuggestion suggestion)? onSuggestionSelected;

  const ParserInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = '',
    required this.onSubmitted,
    this.maxLines = 1,
    this.decoration,
    this.textCapitalization = TextCapitalization.none,
    this.onSearch,
    this.onSuggestionSelected,
  });

  @override
  State<ParserInputField> createState() => _ParserInputFieldState();
}

class _ParserInputFieldState extends State<ParserInputField> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  List<ParserSuggestion> _suggestions = [];
  bool _isLoading = false;
  ParserKeyType? _activeType;

  Timer? _debounce;
  String? _currentSearchTerm;
  int? _triggerStartIndex;

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
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !widget.focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    if (!widget.focusNode.hasFocus) return;
    if (widget.onSearch == null) return;

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

    if (trigger != null) {
      _showSuggestions(trigger);
      return;
    }

    _removeOverlay();
  }

  void _showSuggestions(ParserTrigger trigger) {
    if (_currentSearchTerm == trigger.query &&
        _activeType == trigger.type &&
        _overlayEntry != null) return;

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

    int replaceEnd;
    if (_currentSearchTerm != null) {
      replaceEnd = _triggerStartIndex! + 1 + _currentSearchTerm!.length;
    } else {
      replaceEnd = widget.controller.selection.baseOffset;
      if (replaceEnd == -1) return;
    }

    final text = widget.controller.text;
    final triggerChar = text[_triggerStartIndex!]; // #, @, ou !
    final value = suggestion.label;

    if (replaceEnd > text.length) replaceEnd = text.length;

    // Substitui trigger+query por trigger+valor + espaço
    final newText =
        text.replaceRange(_triggerStartIndex!, replaceEnd, '$triggerChar$value ');

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(
        TextPosition(offset: _triggerStartIndex! + value.length + 2),
      ),
    );

    // Notifica o callback externo
    widget.onSuggestionSelected?.call(suggestion.type, suggestion);

    _removeOverlay();
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 250,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: Offset.zero,
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
        style: const TextStyle(color: Colors.white),
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
