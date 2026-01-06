// lib/common/widgets/contact_picker_modal.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'dart:async';

class ContactPickerModal extends StatefulWidget {
  final String userId;
  final List<String> initialSelectedUsernames;

  const ContactPickerModal({
    super.key,
    required this.userId,
    this.initialSelectedUsernames = const [],
  });

  @override
  State<ContactPickerModal> createState() => _ContactPickerModalState();
}

class _ContactPickerModalState extends State<ContactPickerModal>
    with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  
  late TabController _tabController;
  
  List<ContactModel> _myContacts = [];
  List<UserModel> _searchResults = [];
  final Set<String> _selectedUsernames = {};
  
  bool _isLoadingContacts = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedUsernames.addAll(widget.initialSelectedUsernames);
    _loadMyContacts();
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMyContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final contacts = await _supabaseService.getContacts(widget.userId);
      if (mounted) {
        setState(() {
          _myContacts = contacts.where((c) => c.status == 'active').toList();
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar contatos: $e');
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await _supabaseService.searchUsersByUsername(query);
      if (mounted) {
        setState(() {
          _searchResults = results
              // Remove o próprio usuário da busca
              .where((u) => u.uid != widget.userId)
              .toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggleSelection(String username) {
    setState(() {
      if (_selectedUsernames.contains(username)) {
        _selectedUsernames.remove(username);
      } else {
        _selectedUsernames.add(username);
      }
    });
  }

  Future<void> _addContact(String contactUid) async {
    try {
      await _supabaseService.addContact(widget.userId, contactUid);
      // Recarrega contatos e volta para aba de contatos
      await _loadMyContacts();
      _tabController.animateTo(0);
      _searchController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contato adicionado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao adicionar contato.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Container(
        width: 400, // Fixed width for desktop consistency
        constraints: BoxConstraints(
           maxHeight: MediaQuery.of(context).size.height * 0.8,
           maxWidth: 500,
        ),
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
                  'Adicionar Pessoas',
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
                  color: AppColors.primary, // Standard Purple
                  borderRadius: BorderRadius.circular(100), // Pill shape indicator
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.secondaryText,
                tabs: const [
                  Tab(text: 'Meus Contatos'),
                  Tab(text: 'Buscar Global'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          
          // Search Field (Visible mainly on Search tab, but useful on both maybe?)
          // Vamos deixar visível apenas na aba de busca para não confundir, 
          // ou um filtro local na aba de contatos. 
          // Para simplificar, colocamos dentro do TabBarView ou mudamos dinamicamente.
          // Vamos colocar aqui fora mesmo, mas mudando o hint.
            // Search Field
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou @username...',
                hintStyle: const TextStyle(color: AppColors.secondaryText),
                prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // List Content
            Expanded( // Changed to Expanded
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyContactsList(),
                  _buildGlobalSearchList(),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Button
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_selectedUsernames.toList());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, // Changed to Primary (Purple)
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100), // Pill Shape
                ),
              ),
              child: Text(
                _selectedUsernames.isEmpty 
                    ? 'Concluído' 
                    : 'Adicionar ${_selectedUsernames.length} pessoa(s)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyContactsList() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator(color: AppColors.contact));
    }

    // Filtra localmente se estiver na primeira aba e tiver texto
    final filter = _tabController.index == 0 ? _searchController.text.trim().toLowerCase() : '';
    final filteredContacts = filter.isEmpty 
        ? _myContacts 
        : _myContacts.where((c) => 
            c.username.toLowerCase().contains(filter) || 
            c.displayName.toLowerCase().contains(filter)
          ).toList();

    if (filteredContacts.isEmpty) {
       return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: AppColors.secondaryText.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Nenhum contato encontrado',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            if (_myContacts.isEmpty && filter.isEmpty)
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('Buscar novas pessoas', style: TextStyle(color: AppColors.primary)),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = filteredContacts[index];
        final isSelected = _selectedUsernames.contains(contact.username);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.background,
            child: Text(
              contact.initials,
              style: const TextStyle(color: AppColors.contact, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            contact.displayName,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: contact.username.isNotEmpty 
              ? Text('@${contact.username}', style: const TextStyle(color: AppColors.primary))
              : null,
          trailing: isSelected 
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : const Icon(Icons.circle_outlined, color: AppColors.secondaryText),
          onTap: () {
             if (contact.username.isNotEmpty) {
               _toggleSelection(contact.username);
             }
          },
        );
      },
    );
  }

  Widget _buildGlobalSearchList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: AppColors.contact));
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty 
              ? 'Digite para buscar pessoas' 
              : 'Nenhum usuário encontrado',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isSelected = _selectedUsernames.contains(user.username);
        final isAlreadyContact = _myContacts.any((c) => c.userId == user.uid);
        
        // Nome de exibição
        final fullName = '${user.primeiroNome} ${user.sobrenome}'.trim();
        final displayName = fullName.isNotEmpty ? fullName : user.email;
        final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.background,
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            displayName,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: user.username != null 
              ? Text('@${user.username}', style: const TextStyle(color: AppColors.contact))
              : const Text('Sem username configurado', style: TextStyle(color: Colors.grey)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAlreadyContact)
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: AppColors.secondaryText),
                  onPressed: () => _addContact(user.uid),
                  tooltip: 'Adicionar aos contatos',
                ),
              if (user.username != null)
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: (val) => _toggleSelection(user.username!),
                  shape: const CircleBorder(),
                ),
            ],
          ),
          onTap: () {
            if (user.username != null) {
              _toggleSelection(user.username!);
            }
          },
        );
      },
    );
  }
}
