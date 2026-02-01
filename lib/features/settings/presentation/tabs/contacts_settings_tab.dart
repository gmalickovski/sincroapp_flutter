
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/contact_list_item.dart';
import 'package:sincro_app_flutter/features/settings/presentation/widgets/settings_header.dart';
import 'package:sincro_app_flutter/features/settings/presentation/widgets/settings_section_title.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart';
import 'package:sincro_app_flutter/features/contacts/presentation/add_contact_modal.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart'; // We use UserModel internally for richer data if needed, but list uses ContactModel
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:share_plus/share_plus.dart';

class ContactsSettingsTab extends StatefulWidget {
  final UserModel userData;

  const ContactsSettingsTab({super.key, required this.userData});

  @override
  State<ContactsSettingsTab> createState() => _ContactsSettingsTabState();
}

class _ContactsSettingsTabState extends State<ContactsSettingsTab> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      // Fetching ContactModel list (which includes active & blocked usually depending on service implementation, 
      // but getContacts returns all user_contacts entries usually or we might need to adjust logic).
      // The current service getContacts returns ALL contacts in the user_contacts table.
      final contacts = await _supabaseService.getContacts(widget.userData.uid);
      
      // Sort alphabetically by displayName
      contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts
            .where((c) =>
                c.displayName.toLowerCase().contains(query.toLowerCase()) ||
                c.username.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _openAddContactModal() {
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(
        existingContactIds: _contacts.map((c) => c.userId).toList(),
      ),
    ).then((result) {
      // Refresh list if needed (result not strictly passed currently in dialog, but we could)
      // For now, always refresh
      _fetchContacts(); 
    });
  }

  Future<void> _toggleBlockContact(ContactModel contact) async {
    try {
      if (contact.status == 'blocked') {
         await _supabaseService.unblockContact(widget.userData.uid, contact.userId);
         _showFeedback('Contato desbloqueado.');
      } else {
         await _supabaseService.blockContact(widget.userData.uid, contact.userId);
         _showFeedback('Contato bloqueado.');
      }
      _fetchContacts(); // Refresh list to update status UI
    } catch (e) {
      _showFeedback('Erro ao atualizar contato.', isError: true);
    }
  }

  Future<void> _deleteContact(ContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Contato?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Deseja remover @${contact.username} da sua lista? Você não receberá mais compartilhamentos desta pessoa.',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.removeContact(widget.userData.uid, contact.userId);
        _showFeedback('Contato removido.');
        _fetchContacts();
      } catch (e) {
        _showFeedback('Erro ao remover contato.', isError: true);
      }
    }
  }

  void _shareProfile() {
    // Generate a deep link or just share text for now
    Share.share(
      'Me adicione no Sincro App! Meu usuário é @${widget.userData.username ?? ""}',
      subject: 'Convite Sincro App',
    );
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Header Section
        SettingsHeader(userData: widget.userData),

        const SizedBox(height: 24),

        // 2. Subtitle "Meus Contatos"
        const SettingsSectionTitle(title: 'Meus Contatos'),

        // 3. Search Bar + Add Button
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: _filterContacts,
                decoration: InputDecoration(
                  hintText: 'Pesquisar contatos...',
                  hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                  prefixIcon: const Icon(Icons.search, color: AppColors.tertiaryText),
                  filled: true,
                  fillColor: const Color(0xFF111827), // Darker background to match form inputs elsewhere
                  // Theme defines borders, but we can rely on defaults or slight overrides if needed
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                autofillHints: const [], // Create clean state for browser
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.text,
              ),
            ),
            const SizedBox(width: 12),
            
            // Add Button (Floating Modal Trigger)
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _openAddContactModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_add_alt_1, color: Colors.white),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 4. Contact List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredContacts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        return ContactListItem(
                          contact: contact,
                          onTap: () {}, // No generic tap action defined in specs, keeps list interactive feel
                          onBlock: () => _toggleBlockContact(contact),
                          onDelete: () => _deleteContact(contact),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: AppColors.tertiaryText.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Nenhum contato encontrado',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}
