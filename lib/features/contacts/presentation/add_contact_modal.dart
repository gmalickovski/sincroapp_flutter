
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';
import 'package:sincro_app_flutter/common/widgets/contact_list_item.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';

class AddContactDialog extends StatefulWidget {
  final List<String> existingContactIds;

  const AddContactDialog({
    super.key,
    this.existingContactIds = const [],
  });

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;
  
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String? _successMessage;
  Timer? _debounce;
  final Set<String> _pendingRequests = {}; // Track locally sent requests in this session

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  void _search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _successMessage = null;
    });

    try {
      final results = await _supabaseService.searchUsersByUsername(trimmedQuery);
      if (mounted) {
        setState(() {
          _searchResults = results.where((u) => u.uid != _currentUserId).toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addContact(UserModel user) async {
    try {
      await _supabaseService.addContact(_currentUserId, user.uid);
      
      final senderData = await _supabaseService.getUserData(_currentUserId);
      final senderName = senderData?.username ?? 'Alguém';
      
      await _supabaseService.sendNotification(
        toUserId: user.uid,
        type: NotificationType.contactRequest,
        title: '📩 Pedido de Sincronia',
        body: '@$senderName quer sincronizar com você!',
        metadata: {'type': 'contact_request', 'from_uid': _currentUserId, 'from_name': senderName},
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Convite enviado para @${user.username}';
          _pendingRequests.add(user.uid);
        });
      }
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMessage = null);
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar convite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Floating centered dialog design
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      insetPadding: const EdgeInsets.all(24), 
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500, // Max width for tablet/desktop
          maxHeight: 600, // Max height
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Adicionar Contato',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.tertiaryText),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Search Input
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar por @username...',
                  hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  // Inherits standard AppTheme input decoration
                ),
                autofillHints: const [], // Explicitly empty to disable autofill
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
              ),
              
              const SizedBox(height: 16),
              
              // Success Feedback
              if (_successMessage != null)
                Container(
                   margin: const EdgeInsets.only(bottom: 16),
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.green.withValues(alpha: 0.15),
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(color: Colors.green.withOpacity(0.5)),
                   ),
                   child: Row(
                     children: [
                       const Icon(Icons.check_circle, color: Colors.green, size: 20),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           _successMessage!,
                           style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                         ),
                       ),
                     ],
                   ),
                ),

              // Results List or Status
              if (_isLoading)
                 const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: CircularProgressIndicator()),
                 )
              else if (_searchResults.isEmpty) 
                 Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(
                      child: Text(
                        _searchController.text.isEmpty 
                            ? 'Digite o nome de usuário para buscar.\nO convite será enviado após sua confirmação.'
                            : 'Nenhum usuário encontrado com esse nome.',
                        style: const TextStyle(color: AppColors.secondaryText),
                        textAlign: TextAlign.center,
                      ),
                    ),
                 )
              else
                   Flexible(
                   child: ListView.builder(
                     shrinkWrap: true,
                     itemCount: _searchResults.length,
                     itemBuilder: (context, index) {
                       final user = _searchResults[index];
                       final contactCandidate = ContactModel.fromUserModel(user);
                       
                       // Check if already a contact or request pending
                       final isAlreadyContact = widget.existingContactIds.contains(user.uid);
                       final isPending = _pendingRequests.contains(user.uid);
                       final showCheck = isAlreadyContact || isPending;

                       return ContactListItem(
                          contact: contactCandidate,
                          onTap: () {}, 
                          customTrailing: showCheck 
                            ? Container(
                                height: 36,
                                width: 36,
                                alignment: Alignment.centerRight, // Align with typical trailing position
                                child: const Icon(
                                  Icons.check, 
                                  color: AppColors.tertiaryText,
                                  size: 24,
                                ),
                              )
                            : SizedBox(
                                height: 40, 
                                width: 40,
                                child: IconButton(
                                  onPressed: () => _addContact(user),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 24),
                                ),
                              ),
                       );
                     },
                   ),
                 ),
            ],
          ),
        ),
      ),
    );
  }
}
