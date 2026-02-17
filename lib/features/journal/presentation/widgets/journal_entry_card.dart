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
import 'package:flutter/foundation.dart'; // For kIsWeb
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

  // Extracts plain text from Quill JSON or returns raw content
  String _getPreviewText() {
    if (entry.content.isEmpty) return 'Nenhum conteúdo.';
    try {
      final json = jsonDecode(entry.content);
      final doc = quill.Document.fromJson(json);
      return doc.toPlainText().trim();
    } catch (e) {
      return entry.content; // Fallback to raw content if JSON parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryDate = entry.createdAt;
    final day = entryDate.day.toString().padLeft(2, '0');
    final month = DateFormat.MMM('pt_BR').format(entryDate).toUpperCase();
    final weekDay = DateFormat.E('pt_BR').format(entryDate).toUpperCase();
    final moodEmoji = _moodMap[entry.mood] ?? '';

    // Define the card content separately so we can reuse it
    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Column
                    Column(
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        Text(
                          month,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          weekDay,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Content Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.title.isNotEmpty
                                      ? entry.title
                                      : 'Sem título',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (moodEmoji.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  moodEmoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getPreviewText(),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions Menu
          Positioned(
            bottom: 0,
            right: 0,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.secondaryText, size: 20),
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border)),
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Platform Check for Interaction
    if (kIsWeb ||
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      // Desktop: InkWell -> Dialog
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEditor(context),
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    } else {
      // Mobile: OpenContainer -> Full Page Transition
      return OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (BuildContext context, VoidCallback _) {
          return JournalEditorScreen(
            userData: userData,
            entry: entry,
          );
        },
        closedElevation: 0,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        closedColor: AppColors.cardBackground, // Match card color
        middleColor: AppColors.cardBackground,
        openColor: AppColors.cardBackground,
        tappable: true,
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return cardContent;
        },
      );
    }
  }

  void _openEditor(BuildContext context) {
      // Desktop: Open in our new responsive dialog
      showJournalEditorDialog(
        context,
        userData: userData,
        entry: entry,
      );

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
