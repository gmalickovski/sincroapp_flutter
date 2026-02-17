// lib/features/journal/presentation/widgets/journal_entry_card.dart

import 'dart:convert';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/journal/presentation/journal_editor_screen.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final UserModel userData;
  final VoidCallback onDelete;


  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.userData,
    required this.onDelete,
  });

  // Mapeia o ID do humor para o emoji correspondente
  static const Map<int, String> _moodMap = {
    1: '😔',
    2: '😟',
    3: '😐',
    4: '😊',
    5: '😄',
  };

  // Mapeia o número do Dia Pessoal para uma cor de borda
  Color _getBorderColor() {
    switch (entry.personalDay) {
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.yellow.shade400;
      case 4:
        return Colors.lime.shade400;
      case 5:
        return Colors.cyan.shade400;
      case 6:
        return Colors.blue.shade400;
      case 7:
        return Colors.purple.shade400;
      case 8:
        return Colors.pink.shade400;
      case 9:
        return Colors.teal.shade400;
      case 11:
        return Colors.purple.shade300;
      case 22:
        return Colors.indigo.shade300;
      default:
        return AppColors.primary;
    }
  }

  // Constrói o conteúdo rico (QuillEditor) ou Texto Simples (Fallback)
  Widget _buildRichContent() {
    try {
      if (entry.content.isEmpty) return const SizedBox.shrink();

      final json = jsonDecode(entry.content);
      final doc = quill.Document.fromJson(json);

      return AbsorbPointer( // Impede interação (scroll, seleção)
        child: quill.QuillEditor.basic(
          controller: quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: true,
          ),
          focusNode: FocusNode(canRequestFocus: false),
          scrollController: ScrollController(),
          config: const quill.QuillEditorConfig(
            scrollable: false,
            autoFocus: false,
            expands: false,
            padding: EdgeInsets.zero,
            showCursor: false,
            enableInteractiveSelection: false,
            enableSelectionToolbar: false,
          ),
        ),
      );
    } catch (e) {
      // Fallback para texto simples
      return Text(
        entry.content,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 15,
          height: 1.5,
          fontFamily: 'Poppins',
        ),
      );
    }
  }

  Widget _buildCardContent(BuildContext context) {
    final borderColor = _getBorderColor();
    final formattedDate =
        DateFormat("d 'de' MMMM", 'pt_BR').format(entry.createdAt);
    final formattedTime = DateFormat("HH:mm").format(entry.createdAt);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.title != null && entry.title!.isNotEmpty)
                      Text(
                        entry.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '$formattedDate • $formattedTime',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  ],
                ),
              ),
              if (entry.mood != null && _moodMap.containsKey(entry.mood))
                Text(_moodMap[entry.mood]!,
                    style: const TextStyle(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 12),

          // Corpo do Card (Preview Rico)
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: const [0.0, 0.7, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: _buildRichContent(),
            ),
          ),
          const SizedBox(height: 12),

          // Rodapé do Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              VibrationPill(vibrationNumber: entry.personalDay),
              // Wrap in GestureDetector to absorb taps and prevent
              // the parent OpenContainer from navigating away before the
              // popup can open (fixes "deactivated widget" error).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // absorb tap so OpenContainer doesn't fire
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      final isDesktop = MediaQuery.of(context).size.width >= 768;
                      if (isDesktop) {
                         // Use same dialog logic
                         // We need a helper or just re-call the logic. 
                         // Check if we can access the wrapper method.
                         // Actually, I can't access `_openEditor` easily from here if it stays inside `JournalEntryCard` which is stateless,
                         // wait, `_openEditor` IS in the class. I can call it.
                         _openEditor(context);
                      } else {
                         Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => JournalEditorScreen(
                              userData: userData,
                              entry: entry,
                            ),
                          ),
                        );
                      }
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.secondaryText),
                  tooltip: "Opções",
                  color: AppColors.cardBackground,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                          color: AppColors.border, width: 1)),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Editar',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),

                    const PopupMenuDivider(height: 1),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                           Icon(Icons.delete_outline_rounded,
                              color: Colors.red.shade400, size: 20),
                          const SizedBox(width: 8),
                          Text('Excluir',
                              style: TextStyle(color: Colors.red.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _openEditor(BuildContext context) {
    if (kIsWeb ||
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      // Desktop: Open in our new responsive dialog
      showJournalEditorDialog(
        context,
        userData: widget.userData,
        entry: widget.entry,
      );
    } else {
      // Mobile: Use existing OpenContainer logic or simple push if preferred
      // For now, OpenContainer is handled in the build method wrapper.
      // If we are here, it might be triggered by menu.
      // On mobile, let's just push the route conventionally if not using container transform
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => JournalEditorScreen(
              userData: widget.userData,
              entry: widget.entry,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();
    final isDesktop = MediaQuery.of(context).size.width >= 768; // Simple breakpoint

    if (isDesktop) {
      // Desktop: Simple Card with Dialog navigation
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEditor(context),
          borderRadius: BorderRadius.circular(12),
          child: _buildCardContent(context),
        ),
      );
    }

    // Mobile: Container Transform
    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 500),
      transitionType: ContainerTransitionType.fadeThrough,
      closedColor: AppColors.cardBackground,
      openColor: AppColors.background,
      middleColor: AppColors.background,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      openBuilder: (context, closeContainer) {
        return JournalEditorScreen(
          userData: userData,
          entry: entry,
        );
      },
      closedBuilder: (context, openContainer) {
        return _buildCardContent(context);
      },
      tappable: true,
    );
  }
}
