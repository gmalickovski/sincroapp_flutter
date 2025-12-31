// lib/features/tasks/presentation/widgets/tag_selection_modal.dart
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';

class TagSelectionModal extends StatefulWidget {
  final String userId;
  // --- REMOVIDO: onTagSelected callback ---

  const TagSelectionModal({
    super.key,
    required this.userId,
    // required this.onTagSelected, // Removido
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

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() {
    // (Mantida a lógica de buscar tags recentes ou de 'getTags')
    _tagsFuture = _supabaseService.getRecentTasks(widget.userId).then((tasks) {
      final tagSet = <String>{};
      for (var task in tasks) {
        tagSet.addAll(task.tags);
      }
      final tagList = tagSet.toList();
      tagList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return tagList;
    });
    // Se você tem um getTags() que retorna List<String>, use:
    // _tagsFuture = _firestoreService.getTags(widget.userId);
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
    final sanitizedTag = StringSanitizer.toSimpleTag(tagName);
    if (sanitizedTag.isEmpty) return;

    setState(() {
      _isLoadingCreate = true;
    });

    try {
      // Opcional: Salva a nova tag no backend (se você tiver um createTag)
      // await _firestoreService.createTag(widget.userId, sanitizedTag);

      // --- INÍCIO DA MUDANÇA ---
      // Retorna a nova tag sanitizada via pop
      if (mounted) Navigator.of(context).pop(sanitizedTag);
      // --- FIM DA MUDANÇA ---
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
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: AppColors.primary.withValues(alpha: 0.2),
              hoverColor: AppColors.primary.withValues(alpha: 0.1),
              onTap: () {
                setState(() {
                  _isCreatingNewTag = true;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Criar nova Tag',
                        style: TextStyle(
                          color: AppColors.primary,
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
                  child: CircularProgressIndicator(color: AppColors.primary));
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
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      splashColor: AppColors.primary.withValues(alpha: 0.2),
                      hoverColor: AppColors.primary.withValues(alpha: 0.1),
                      onTap: () {
                        // --- INÍCIO DA MUDANÇA ---
                        // Retorna a tag (já sanitizada) via pop
                        Navigator.of(context).pop(tagName);
                        // --- FIM DA MUDANÇA ---
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.label_outline, // Ícone de Tag
                                color: AppColors.secondaryText),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tagName,
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 16,
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
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isLoadingCreate
                  ? null
                  : () {
                      setState(() {
                        _isCreatingNewTag = false;
                        _newTagController.clear();
                      });
                    },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoadingCreate ? null : _handleCreateTag,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  : const Text('Salvar Tag'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16, top: 8),
            child: Text(
              _isCreatingNewTag ? 'Nova Tag' : 'Selecionar Tag',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Flexible(
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
        ],
      ),
    );
  }
}
