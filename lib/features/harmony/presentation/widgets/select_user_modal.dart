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

  // All contacts (loaded initially)
  List<UserModel> _allContacts = [];
  // Filtered results to display
  List<UserModel> _displayedUsers = [];

  bool _isLoading = true;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _supabaseService.getUserContacts(_currentUserId);
      setState(() {
        _allContacts = contacts;
        _displayedUsers = contacts; // Initially show all contacts
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      // Show all contacts if query is empty
      setState(() {
        _displayedUsers = _allContacts;
      });
      return;
    }

    // 1. Filter local contacts first (Instant)
    final localMatches = _allContacts.where((u) {
      final q = query.toLowerCase();
      return (u.username?.toLowerCase().contains(q) == true) ||
          (u.primeiroNome.toLowerCase().contains(q)) ||
          (u.sobrenome.toLowerCase().contains(q));
    }).toList();

    setState(() {
      _displayedUsers = localMatches;
    });

    // 2. If query is long enough, perform global search (Optional, if we want to find NEW people)
    // For now, based on user request "show contacts I already filter", local filtering is priority.
    // If we want global search mixed in, we'd need to debouce.
    // Assuming user wants to search GLOBAL only if not found in contacts?
    // User said: "Show contacts I already have... and as I type filter them".
    // It doesn't explicitly forbid global search, but prioritizes contacts.
    // Let's keep it simple: Local filter of contacts. If they want to search NEW users, maybe a button or if list is empty?
    // Current imp implements global search on submit. Let's keep global search on submit OR debounce.
    // Let's do: Local Filter immediately. Global Search on "Search" icon or Enter.
  }

  void _performGlobalSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final globalResults = await _supabaseService.searchUsersByUsername(query);
      // Remove self and duplicates (keep existing contact objects if possible or just use new ones)
      // Actually simple list replacement is fine.
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
    // Dynamic Height: Use padding for keyboard + wrap in SingleChildScrollView/Column(min)
    // But we want the LIST to expand.
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
          maxHeight:
              MediaQuery.of(context).size.height * 0.85, // Max height limit
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.tertiaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Selecionar Pessoa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por @username ou nome...',
                  hintStyle: const TextStyle(color: AppColors.secondaryText),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onChanged: _onSearchChanged, // Real-time filtering
                onSubmitted: (_) =>
                    _performGlobalSearch(), // Explicit global search
              ),
            ),

            // Results List
            // Use Flexible/Expanded to allow list to take space up to MaxHeight
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator())
                  : _displayedUsers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Você ainda não tem contatos adicionados.'
                                : 'Nenhum contato encontrado. Pressione Enter para buscar em todos usuários.',
                            style:
                                const TextStyle(color: AppColors.secondaryText),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true, // Allow wrapping if few items
                          padding: const EdgeInsets.all(16),
                          itemCount: _displayedUsers.length,
                          itemBuilder: (context, index) {
                            final user = _displayedUsers[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.2),
                                child: Text(
                                  user.username?[0].toUpperCase() ??
                                      user.primeiroNome[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                user.nomeAnalise.isNotEmpty
                                    ? user.nomeAnalise
                                    : '${user.primeiroNome} ${user.sobrenome}'
                                        .trim(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '@${user.username ?? "user"}',
                                style: const TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.white24),
                              onTap: () => _selectUser(user), // Select on tap
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
