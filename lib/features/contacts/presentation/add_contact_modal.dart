import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';

class AddContactModal extends StatefulWidget {
  const AddContactModal({super.key});

  @override
  State<AddContactModal> createState() => _AddContactModalState();
}

class _AddContactModalState extends State<AddContactModal> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;
  
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String? _successMessage;

  void _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _successMessage = null;
    });

    try {
      // Find users by username
      final results = await _supabaseService.searchUsersByUsername(query);
      setState(() {
        _searchResults = results.where((u) => u.uid != _currentUserId).toList();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addContact(UserModel user) async {
    try {
      await _supabaseService.addContact(_currentUserId, user.uid);
      
      // Send invitation notification
      await _supabaseService.sendNotification(
        toUserId: user.uid,
        type: NotificationType.contactRequest,
        title: 'Solicitação de Contato',
        body: 'Alguém quer adicionar você aos contatos do Sincro.',
        metadata: {'type': 'contact_request', 'from_uid': _currentUserId},
      );

      setState(() {
        _successMessage = 'Convite enviado para ${user.username}';
        // Remove from list or mark as sent
        _searchResults.removeWhere((u) => u.uid == user.uid);
      });
      
      // Clear message after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMessage = null);
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar convite: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground, // STANDARD COLOR
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85, 
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.tertiaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Adicionar Pessoa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance for back button
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por @username...',
                  hintStyle: const TextStyle(color: AppColors.secondaryText),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background, // Contrast
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30), // PILL SHAPE
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                    onPressed: _search,
                  ),
                ),
                autofillHints: null, // Hack to disable password manager
                enableSuggestions: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
              ),
            ),
            
            if (_successMessage != null)
              Container(
                 margin: const EdgeInsets.all(16),
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.green.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.green),
                 ),
                 child: Text(
                   _successMessage!,
                   style: const TextStyle(color: Colors.green),
                   textAlign: TextAlign.center,
                 ),
              ),

            // Results List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty 
                    ? const Center(
                        child: Text(
                          'Pesquise pelo nome de usuário (@username)',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: CircleAvatar(
                               backgroundColor: AppColors.contact,
                               child: Text(user.username?[0].toUpperCase() ?? '?'),
                            ),
                            title: Text(
                              user.username ?? 'Sem username',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${user.primeiroNome} ${user.sobrenome}',
                              style: const TextStyle(color: AppColors.secondaryText),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _addContact(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                              ),
                              child: const Text('Adicionar'),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
