// lib/common/widgets/mention_input_field.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/common/widgets/mention_text_editing_controller.dart';

class MentionInputField extends StatefulWidget {
  final MentionTextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final Function(String) onSubmitted;
  final int? maxLines;
  final InputDecoration? decoration;

  const MentionInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = '',
    required this.onSubmitted,
    this.maxLines = 1,
    this.decoration,
  });

  @override
  State<MentionInputField> createState() => _MentionInputFieldState();
}

class _MentionInputFieldState extends State<MentionInputField> {
  final SupabaseService _supabaseService = SupabaseService();
  
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  
  List<UserModel> _suggestions = [];
  bool _isLoading = false;
  
  Timer? _debounce;
  String? _currentSearchTerm;
  int? _mentionStartIndex;

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
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    if (!widget.focusNode.hasFocus) return;

    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.isCollapsed == false) {
       _removeOverlay();
       return;
    }

    final cursorPos = selection.baseOffset;
    
    // Procura o último '@' antes do cursor
    final lastAt = text.lastIndexOf('@', cursorPos - 1);
    
    if (lastAt != -1) {
      // Verifica se é uma menção válida (início do texto ou precedido por espaço/nova linha)
      bool isValidStart = lastAt == 0 || [' ', '\n'].contains(text[lastAt - 1]);
      
      if (isValidStart) {
        final query = text.substring(lastAt + 1, cursorPos);
        // Verifica se contém caracteres proibidos (espaço termina a menção)
        if (!query.contains(' ')) {
          _showSuggestions(query, lastAt);
          return;
        }
      }
    }
    
    _removeOverlay();
  }

  void _showSuggestions(String query, int startIndex) {
    if (_currentSearchTerm == query && _overlayEntry != null) return;
    
    _currentSearchTerm = query;
    _mentionStartIndex = startIndex;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isLoading = true);
    
    try {
      // Se query vazia, pode mostrar recentes ou nada.
      // Aqui vamos buscar autocomplete
      final results = await _supabaseService.searchUsersByUsername(query);
      
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
    _mentionStartIndex = null;
  }

  void _selectUser(UserModel user) {
    if (_mentionStartIndex == null || user.username == null) return;

    final text = widget.controller.text;
    final username = user.username!;
    final cursorPos = widget.controller.selection.baseOffset;
    
    // Substitui @query por @username + espaço
    final newText = text.replaceRange(
      _mentionStartIndex!, 
      cursorPos, 
      '@$username '
    );

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(
        TextPosition(offset: _mentionStartIndex! + username.length + 2), // +2 por causa do @ e espaço
      ),
    );

    _removeOverlay();
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 250, // Largura fixa ou relativa
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 50), // Abaixo do input? Precisa calcular posição do cursor ideally
            // Nota: calcular posição exata do cursor é complexo no Flutter sem usar hacks ou bibliotecas.
            // Para simplificar, vamos mostrar abaixo do TextField (estilo Dropdown)
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.cardBackground,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final user = _suggestions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.contact,
                        child: Text(
                          user.primeiroNome.isNotEmpty ? user.primeiroNome[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                      title: Text(
                        user.username ?? 'Sem user', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${user.primeiroNome} ${user.sobrenome}',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectUser(user),
                    );
                  },
                ),
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
        maxLines: widget.maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: widget.decoration ?? InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: AppColors.secondaryText),
          border: InputBorder.none,
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
