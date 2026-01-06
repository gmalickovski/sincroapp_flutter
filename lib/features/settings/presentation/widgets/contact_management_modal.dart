// lib/features/settings/presentation/widgets/contact_management_modal.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class ContactManagementModal extends StatefulWidget {
  final String userId;

  const ContactManagementModal({super.key, required this.userId});

  @override
  State<ContactManagementModal> createState() => _ContactManagementModalState();
}

class _ContactManagementModalState extends State<ContactManagementModal>
    with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  late TabController _tabController;

  List<ContactModel> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _supabaseService.getContacts(widget.userId);
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteContact(ContactModel contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Remover Contato?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Deseja remover ${contact.displayName} dos seus contatos?',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabaseService.removeContact(widget.userId, contact.userId);
      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao remover contato.')),
        );
      }
    }
  }

  Future<void> _toggleBlockContact(ContactModel contact) async {
    final isBlocked = contact.status == 'blocked';
    final action = isBlocked ? 'desbloquear' : 'bloquear';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('${isBlocked ? 'Desbloquear' : 'Bloquear'} Contato?',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          'Deseja realmente $action ${contact.displayName}?',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: isBlocked ? AppColors.success : Colors.red),
            child: Text(isBlocked ? 'Desbloquear' : 'Bloquear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (isBlocked) {
        await _supabaseService.unblockContact(widget.userId, contact.userId);
      } else {
        await _supabaseService.blockContact(widget.userId, contact.userId);
      }
      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erro ao $action contato.')),
        );
      }
    }
  }

  @override


  Widget build(BuildContext context) {
    final activeContacts = _contacts.where((c) => c.status == 'active').toList();
    final blockedContacts = _contacts.where((c) => c.status == 'blocked').toList();

    return Dialog(
       backgroundColor: AppColors.cardBackground,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
       child: Container(
         width: 400, // Fixed width for desktop/consistent look
         constraints: BoxConstraints(
           maxHeight: MediaQuery.of(context).size.height * 0.8,
           maxWidth: 500,
         ),
         padding: const EdgeInsets.all(24.0),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             // Header Clean
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(
                   'Meus Contatos', // Changed title as requested "Meus Contatos" instead of "Gerenciar"
                   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 IconButton(
                   icon: const Icon(Icons.close, color: AppColors.secondaryText),
                   onPressed: () => Navigator.of(context).pop(),
                 ),
               ],
             ),
             
             const SizedBox(height: 24),

             // Tabs (Pill Style)
             Container(
               decoration: BoxDecoration(
                 color: AppColors.background,
                 borderRadius: BorderRadius.circular(100), // Pill shape container
               ),
               padding: const EdgeInsets.all(4),
               child: TabBar(
                 controller: _tabController,
                 indicator: BoxDecoration(
                   color: AppColors.primary,
                   borderRadius: BorderRadius.circular(100), // Pill shape indicator
                 ),
                 indicatorSize: TabBarIndicatorSize.tab,
                 dividerColor: Colors.transparent,
                 labelColor: Colors.white,
                 unselectedLabelColor: AppColors.secondaryText,
                 tabs: [
                   Tab(text: 'Ativos (${activeContacts.length})'),
                   Tab(text: 'Bloqueados (${blockedContacts.length})'),
                 ],
               ),
             ),

             const SizedBox(height: 16),

             // Content
             Expanded( // Changed from Flexible to Expanded for better list handling
               child: _isLoading
                   ? const Center(child: CircularProgressIndicator())
                   : TabBarView(
                       controller: _tabController,
                       children: [
                         _buildContactList(activeContacts, isBlockedList: false),
                         _buildContactList(blockedContacts, isBlockedList: true),
                       ],
                     ),
             ),
           ],
         ),
       ),
    );
  }

  Widget _buildContactList(List<ContactModel> contacts, {required bool isBlockedList}) {
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBlockedList ? Icons.block : Icons.people_outline,
              size: 48,
              color: AppColors.secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isBlockedList
                  ? 'Nenhum contato bloqueado'
                  : 'Nenhum contato ativo',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.background,
            child: Text(
              contact.initials,
              style: TextStyle(
                color: isBlockedList ? Colors.red : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            contact.displayName,
            style: TextStyle(
              color: isBlockedList ? AppColors.secondaryText : Colors.white,
              decoration: isBlockedList ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: contact.username.isNotEmpty
              ? Text('@${contact.username}',
                  style: const TextStyle(color: AppColors.secondaryText))
              : null,
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.secondaryText),
            color: AppColors.cardBackground,
            onSelected: (value) {
              if (value == 'delete') _deleteContact(contact);
              if (value == 'block') _toggleBlockContact(contact);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      isBlockedList ? Icons.check_circle_outline : Icons.block,
                      color: isBlockedList ? AppColors.success : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isBlockedList ? 'Desbloquear' : 'Bloquear',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (!isBlockedList)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text('Remover', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
