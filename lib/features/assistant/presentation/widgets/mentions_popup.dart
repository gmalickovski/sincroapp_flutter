import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class MentionsPopup extends StatelessWidget {
  final List<MentionCandidate> candidates;
  final Function(MentionCandidate) onSelected;
  final VoidCallback onDismiss;

  const MentionsPopup({
    super.key,
    required this.candidates,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // This widget sits above the input field
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: candidates.length,
          separatorBuilder: (_, __) => Divider(
            height: 1, 
            color: Colors.white.withValues(alpha: 0.05)
          ),
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            return ListTile(
              dense: true,
              leading: _buildIcon(candidate.type),
              title: Text(
                candidate.label,
                style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
              ),
              subtitle: candidate.description != null 
                 ? Text(candidate.description!, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10))
                 : null,
              onTap: () => onSelected(candidate),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIcon(MentionType type) {
    switch (type) {
      case MentionType.contact:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          child: const Icon(Icons.person, size: 14, color: Colors.white),
        );
      case MentionType.goal:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
          child: const Icon(Icons.flag, size: 14, color: Colors.white),
        );
    }
  }
}

enum MentionType { contact, goal }

class MentionCandidate {
  final String id;
  final String label;
  final String? description;
  final MentionType type;

  MentionCandidate({
    required this.id, 
    required this.label, 
    required this.type,
    this.description,
  });
}
