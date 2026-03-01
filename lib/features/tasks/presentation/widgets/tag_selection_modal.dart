// lib/features/tasks/presentation/widgets/tag_selection_modal.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class TagSelectionModal extends StatefulWidget {
  final String userId;
  final List<String> initialSelectedTags;

  const TagSelectionModal({
    super.key,
    required this.userId,
    this.initialSelectedTags = const [],
  });

  @override
  State<TagSelectionModal> createState() => _TagSelectionModalState();
}

class _TagSelectionModalState extends State<TagSelectionModal> {
  late Future<List<String>> _tagsFuture;
  final SupabaseService _supabaseService = SupabaseService();

  final _newTagController = TextEditingController();
  bool _isCreatingNewTag = false;
  bool _isLoadingCreate = false;
  String? _tempSelectedTag;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() {
    _tagsFuture = _supabaseService.getRecentTasks(widget.userId).then((tasks) {
      final tagSet = <String>{};
      for (var task in tasks) {
        tagSet.addAll(task.tags);
      }
      final tagList = tagSet.toList();
      tagList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return tagList;
    });
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTag() async {
    final tagName = _newTagController.text.trim();
    if (tagName.isEmpty) return;

    // Sanitiza a tag para o formato padrão (minúsculo, sem hífen)
    final sanitizedTag = tagName.trim();
    if (sanitizedTag.isEmpty) return;

    setState(() {
      _isLoadingCreate = true;
    });

    try {
      // Retorna a nova tag sanitizada via pop
      if (mounted) Navigator.of(context).pop(sanitizedTag);
    } catch (e) {
      debugPrint("Erro ao criar tag: $e");
      setState(() {
        _isLoadingCreate = false;
      });
    }
  }

  Widget _buildTagList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Item para Criar Nova Tag ---
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.harmonyPink.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: AppColors.harmonyPink.withValues(alpha: 0.2),
              hoverColor: AppColors.harmonyPink.withValues(alpha: 0.1),
              onTap: () {
                setState(() {
                  _isCreatingNewTag = true;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.harmonyPink),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Criar nova Tag',
                        style: TextStyle(
                          color: AppColors.harmonyPink,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // --- Lista de Tags Existentes ---
        FutureBuilder<List<String>>(
          future: _tagsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.harmonyPink));
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Nenhuma tag encontrada. Crie sua primeira!',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              );
            }

            final tags = snapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: tags.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tagName = tags[index];
                final isSelected = _tempSelectedTag == tagName;

                return Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.harmonyPink.withValues(alpha: 0.2)
                        : AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: AppColors.harmonyPink, width: 2)
                        : Border.all(color: Colors.transparent, width: 2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      splashColor: AppColors.harmonyPink.withValues(alpha: 0.2),
                      hoverColor: AppColors.harmonyPink.withValues(alpha: 0.1),
                      onTap: () {
                        setState(() {
                          _tempSelectedTag = _tempSelectedTag == tagName ? null : tagName;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.label_outline,
                                color: isSelected ? AppColors.harmonyPink : AppColors.secondaryText),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tagName,
                                style: TextStyle(
                                  color: isSelected ? AppColors.harmonyPink : AppColors.primaryText,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreateTagForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Qual o nome da sua nova Tag?',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newTagController,
          autofocus: true,
          autofillHints: const [], // Prevent browser password save prompt
          style: const TextStyle(color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'Ex: Trabalho',
            hintStyle: const TextStyle(color: AppColors.secondaryText),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.harmonyPink, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }


  Widget _buildFooter() {
    if (_isCreatingNewTag) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _isLoadingCreate
                      ? null
                      : () {
                          setState(() {
                            _isCreatingNewTag = false;
                            _newTagController.clear();
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Voltar",
                      style: TextStyle(
                          color: AppColors.secondaryText,
                          fontFamily: 'Poppins')),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoadingCreate ? null : _handleCreateTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.harmonyPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoadingCreate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Salvar Tag",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins')),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_tempSelectedTag != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _tempSelectedTag = null;
                    });
                    Navigator.of(context).pop(null);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Limpar",
                      style: TextStyle(
                          color: AppColors.secondaryText,
                          fontFamily: 'Poppins')),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_tempSelectedTag);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.harmonyPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Confirmar",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default "Fechar" state
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.cardBackground,
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Fechar",
              style: TextStyle(
                  color: AppColors.secondaryText, fontFamily: 'Poppins')),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Standardized)
          Padding(
            padding: const EdgeInsets.only(
                top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: Center(
              child: Text(
                _isCreatingNewTag ? 'Nova Tag' : 'Selecionar Tag',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child:
                    _isCreatingNewTag ? _buildCreateTagForm() : _buildTagList(),
              ),
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }
}
