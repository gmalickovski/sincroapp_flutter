import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart'; // NOVO import

class ContactListItem extends StatelessWidget {
  final ContactModel contact;
  final bool isSelected;
  final bool
      showSelectionIndicator; // If true, shows check/circle. If false, shows actions.
  final VoidCallback? onTap;
  final VoidCallback? onBlock;
  final VoidCallback? onDelete;
  final Widget? customTrailing; // NOVO: Allows custom button (e.g., "Add")

  const ContactListItem({
    super.key,
    required this.contact,
    this.isSelected = false,
    this.showSelectionIndicator = false,
    this.onTap,
    this.onBlock,
    this.onDelete,
    this.customTrailing,
  });

  // Constructor for Picker Mode (visual selection, no block/delete usually)
  const ContactListItem.picker({
    super.key,
    required this.contact,
    required this.isSelected,
    required this.onTap,
  })  : showSelectionIndicator = true,
        onBlock = null,
        onDelete = null,
        customTrailing = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: isSelected && showSelectionIndicator
            ? Border.all(color: AppColors.primary, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar Area
                _buildAvatar(),

                const SizedBox(width: 16),

                // Info Area (Dual Line)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Username (Highlighted)
                      Text(
                        '@${contact.username}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primaryText,
                                  fontWeight: FontWeight.bold, // Highlighted
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Full Name (Smaller, Muted)
                      Text(
                        contact.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.secondaryText,
                              fontSize: 13, // Slight override for hierarchy
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Actions, Selection, or Custom Trailing
                if (customTrailing != null)
                  customTrailing!
                else if (showSelectionIndicator)
                  _buildSelectionIndicator()
                else
                  _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    // Separate logic to extract first/last name for avatar if displayName is full name
    String firstName = '';
    String lastName = '';

    if (contact.displayName.isNotEmpty) {
      final parts = contact.displayName.split(' ');
      firstName = parts.isNotEmpty ? parts.first : '';
      lastName = parts.length > 1 ? parts.last : '';
    }

    return UserAvatar(
      photoUrl: contact.photoUrl,
      firstName: firstName,
      lastName: lastName,
      radius:
          20, // 48px size -> 24 radius, but layout had 48px box. 24 is closer to 48px diam.
    );
  }

  Widget _buildSelectionIndicator() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.tertiaryText,
          width: 2,
        ),
        color: isSelected ? AppColors.primary : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onBlock != null)
          IconButton(
            onPressed: onBlock,
            icon: Icon(
              contact.status == 'blocked' ? Icons.block : Icons.block_outlined,
              color: contact.status == 'blocked'
                  ? Colors.redAccent
                  : AppColors.secondaryText,
            ),
            tooltip: contact.status == 'blocked'
                ? 'Desbloquear Contato'
                : 'Bloquear Contato',
            splashRadius: 20,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: AppColors.secondaryText),
            tooltip: 'Remover Contato',
            splashRadius: 20,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            style: IconButton.styleFrom(
              hoverColor: Colors.redAccent.withValues(alpha: 0.1),
            ),
          ),
        ],
      ],
    );
  }
}
