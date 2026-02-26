// lib/features/journal/presentation/widgets/journal_entry_card.dart

import 'dart:convert';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/core/routes/hero_dialog_route.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/journal/presentation/journal_editor_screen.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/journal/presentation/widgets/hoverable_card.dart';

class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final UserModel userData;

  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.userData,
  });

  // ... (Mood Map and getBorderColor remain same)

  // ... (_buildRichContent remains same)

  Color _getBorderColor() {
    switch (entry.mood) {
      case 1:
        return AppColors.moodAwful;
      case 2:
        return AppColors.moodBad;
      case 3:
        return AppColors.moodNeutral;
      case 4:
        return AppColors.moodGood;
      case 5:
        return AppColors.moodGreat;
      default:
        return AppColors.border;
    }
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        VibrationPill(vibrationNumber: entry.personalDay),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // Desktop: Use showDialog for "Floating Modal" (keeps background visible)
    if (isDesktop) {
      return Hero(
        tag: entry.id, // Unique tag for this entry
        // Removed custom flightShuttleBuilder to restore default Hero flight
        child: Material(
          type: MaterialType.transparency,
          child: HoverableCard(
            borderRadius: 12,
            borderColor: borderColor,
            onTap: () {
              Navigator.of(context).push(
                HeroDialogRoute(
                  builder: (context) {
                    return JournalEditorScreen(
                      userData: userData,
                      entry: entry,
                    );
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: AppColors
                    .cardBackground, // Force background color for Desktop
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              constraints: const BoxConstraints(minHeight: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(
                      formattedDate: DateFormat("d 'de' MMMM", 'pt_BR')
                          .format(entry.createdAt),
                      formattedTime:
                          DateFormat("HH:mm").format(entry.createdAt)),
                  const SizedBox(height: 12),
                  _buildBody(),
                  const SizedBox(height: 12),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mobile: OpenContainer logic...
    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      transitionDuration: const Duration(milliseconds: 500),
      openBuilder: (context, _) => JournalEditorScreen(
        userData: userData,
        entry: entry,
      ),
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      closedColor: AppColors.cardBackground,
      openColor: AppColors.cardBackground,
      middleColor: AppColors.cardBackground,
      closedBuilder: (context, openContainer) => HoverableCard(
        borderRadius: 12,
        borderColor: borderColor,
        onTap: openContainer,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          constraints: const BoxConstraints(minHeight: 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(
                  formattedDate: DateFormat("d 'de' MMMM", 'pt_BR')
                      .format(entry.createdAt),
                  formattedTime: DateFormat("HH:mm").format(entry.createdAt)),
              const SizedBox(height: 12),
              _buildBody(),
              const SizedBox(height: 12),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // ... (_buildHeader, _buildBody remain same)

  Widget _buildHeader(
      {required String formattedDate, required String formattedTime}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          formattedDate,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          formattedTime,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (entry.content.isEmpty) return const SizedBox.shrink();

    // 1. Parse Document
    quill.Document? doc;
    try {
      if (entry.content.startsWith('[')) {
        doc = quill.Document.fromJson(jsonDecode(entry.content));
      }
    } catch (_) {
      // Fallback handled below
    }

    // 2. Fallback for Plain Text
    if (doc == null) {
      return Text(
        entry.content,
        maxLines: 8, // Increased line limit
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
      );
    }

    // 3. Extract first few lines (visual lines)
    final root = doc.root;
    final lines = <quill.Line>[];
    int currentChars = 0;
    const int maxChars = 300; // Limit total characters in preview

    // Helper to extract lines from Blocks or direct Line nodes
    void extractLines(quill.Node node) {
      if (lines.length >= 6 || currentChars >= maxChars) return;
      if (node is quill.Line) {
        final text = node.toPlainText().trim();
        if (text.isNotEmpty) {
          lines.add(node);
          currentChars += text.length;
        }
      } else if (node is quill.Block) {
        for (var child in node.children) {
          extractLines(child);
        }
      }
    }

    for (var node in root.children) {
      extractLines(node);
      if (lines.length >= 6 || currentChars >= maxChars) break;
    }

    // 4. Build Widgets
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.title != null && entry.title!.isNotEmpty) ...[
          Text(
            entry.title!,
            maxLines: 3, // Allow wrapping for Title
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...lines.map((line) => _buildLinePreview(line)),
        if (currentChars >= maxChars || lines.length >= 6)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              '...',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
        if (lines.isEmpty && (entry.title == null || entry.title!.isEmpty))
          const Text(
            'Sem conteúdo',
            style: TextStyle(color: AppColors.tertiaryText, fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildLinePreview(quill.Line line) {
    final text = line.toPlainText().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    // Attributes
    final attrs = line.style.attributes;
    final listAttr = attrs['list']?.value;
    final isCheckbox = listAttr == 'checked' || listAttr == 'unchecked';
    final isChecked = listAttr == 'checked';
    final isBullet = listAttr == 'bullet';
    final isOrdered = listAttr == 'ordered';

    // Prefix
    Widget? prefix;
    if (isCheckbox) {
      // Replicating _SincroCheckboxBuilder style
      prefix = Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.only(top: 2, right: 8),
        decoration: BoxDecoration(
          color: isChecked ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: isChecked
                ? AppColors.primary
                : AppColors.secondaryText.withValues(alpha: 0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: isChecked
            ? const Center(
                child: Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              )
            : null,
      );
    } else if (isBullet) {
      prefix = const Padding(
        padding: EdgeInsets.only(top: 6.0, right: 8.0), // Align with text
        child: Icon(Icons.circle, size: 5, color: AppColors.secondaryText),
      );
    } else if (isOrdered) {
      // Simple dot for preview smoothness, handling numbers strictly is complex without index context
      prefix = const Padding(
        padding: EdgeInsets.only(top: 4.0, right: 8.0),
        child: Text("•", style: TextStyle(color: AppColors.secondaryText)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
          bottom: 6.0), // Increased spacing for readablity
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix != null) prefix,
          Expanded(child: _buildRichText(text)),
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    // Regex Patterns
    final tagRegex = RegExp(r'\B#\w+');
    final mentionRegex = RegExp(r'\B@\w+');
    final timeRegex = RegExp(r'\b\d{1,2}:\d{2}\b');

    final spans = <InlineSpan>[];

    text.splitMapJoin(
      RegExp(r'(\B#\w+)|(\B@\w+)|(\b\d{1,2}:\d{2}\b)'),
      onMatch: (m) {
        final match = m.group(0)!;
        Color color = AppColors.secondaryText;
        FontWeight weight = FontWeight.normal;

        if (tagRegex.hasMatch(match)) {
          color = AppColors.secondaryAccent; // Purple for tags
          weight = FontWeight.w600;
        } else if (mentionRegex.hasMatch(match)) {
          color = AppColors.primary; // Primary for mentions
          weight = FontWeight.bold;
        } else if (timeRegex.hasMatch(match)) {
          color = AppColors.primary; // Primary for time
          weight = FontWeight.w600;
        }

        spans.add(TextSpan(
          text: match,
          style: TextStyle(
              color: color, fontWeight: weight, fontFamily: 'Poppins'),
        ));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(
          text: n,
          style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              fontFamily: 'Poppins'),
        ));
        return '';
      },
    );

    return RichText(
      maxLines: 3, // Allow logical line to wrap up to 3 times
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}
