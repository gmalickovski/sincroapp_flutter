import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectUserModal extends StatefulWidget {
  const SelectUserModal({super.key});

  @override
  State<SelectUserModal> createState() => _SelectUserModalState();
}

class _SelectUserModalState extends State<SelectUserModal> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  List<UserModel> _allContacts = [];
  List<UserModel> _displayedUsers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _supabaseService.getUserContacts(_currentUserId);
      setState(() {
        _allContacts = contacts;
        _displayedUsers = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _displayedUsers = _allContacts);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _displayedUsers = _allContacts.where((u) {
        return (u.username?.toLowerCase().contains(q) == true) ||
            (u.primeiroNome.toLowerCase().contains(q)) ||
            (u.sobrenome.toLowerCase().contains(q));
      }).toList();
    });
  }

  void _performGlobalSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final globalResults = await _supabaseService.searchUsersByUsername(query);
      setState(() {
        _displayedUsers =
            globalResults.where((u) => u.uid != _currentUserId).toList();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectUser(UserModel user) {
    Navigator.of(context).pop(user);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header — centered title, no X button
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Meus Contatos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por @username ou nome...',
                  hintStyle:
                      const TextStyle(color: AppColors.tertiaryText, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.tertiaryText, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _performGlobalSearch(),
              ),
            ),

            // List
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                        color: AppColors.harmonyPink,
                      ),
                    )
                  : _displayedUsers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Você ainda não tem contatos adicionados.'
                                : 'Nenhum contato encontrado. Pressione Enter para buscar em todos usuários.',
                            style: const TextStyle(
                                color: AppColors.secondaryText, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          itemCount: _displayedUsers.length,
                          itemBuilder: (context, index) {
                            final user = _displayedUsers[index];
                            final displayName =
                                user.nomeAnalise.isNotEmpty
                                    ? user.nomeAnalise
                                    : '${user.primeiroNome} ${user.sobrenome}'
                                        .trim();
                            final username = '@${user.username ?? "user"}';
                            final initials = (user.username?.isNotEmpty == true
                                    ? user.username![0]
                                    : user.primeiroNome[0])
                                .toUpperCase();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _selectUser(user),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.harmonyPink
                                            .withValues(alpha: 0.2),
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: AppColors.harmonyPink,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              username,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                color: AppColors.secondaryText,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.white24, size: 24),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Footer — "Fechar" button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.cardBackground,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Fechar',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
