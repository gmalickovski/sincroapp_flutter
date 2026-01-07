// lib/common/widgets/contact_picker_modal.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_button.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/contacts/presentation/add_contact_modal.dart';

class ContactPickerModal extends StatefulWidget {
  final List<String> preSelectedUsernames;
  final Function(List<String> selectedUsernames) onSelectionChanged;
  final DateTime currentDate; // Required for compatibility check
  final Function(DateTime newDate)? onDateChanged; // If compatibility suggests a new date

  const ContactPickerModal({
    super.key,
    this.preSelectedUsernames = const [],
    required this.onSelectionChanged,
    required this.currentDate,
    this.onDateChanged,
  });

  @override
  State<ContactPickerModal> createState() => _ContactPickerModalState();
}

class _ContactPickerModalState extends State<ContactPickerModal> {
  final SupabaseService _supabaseService = SupabaseService();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;
  
  // State
  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  Set<String> _selectedUsernames = {};
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  
  // Compatibility
  bool _calculatingCompatibility = false;
  double _compatibilityScore = 1.0;
  String _compatibilityStatus = 'good'; // good, bad
  List<DateTime> _suggestedDates = [];

  @override
  void initState() {
    super.initState();
    _selectedUsernames = widget.preSelectedUsernames.toSet();
    _fetchContacts();
    
    // Initial calc if pre-selected
    if (_selectedUsernames.isNotEmpty) {
      _calculateCompatibility();
    }
  }

  void _fetchContacts() async {
    final contacts = await _supabaseService.getContacts(_currentUserId);
    if (mounted) {
      setState(() {
        // Filter only active contacts
        _contacts = contacts.where((c) => c.status == 'active').toList();
        _filteredContacts = _contacts;
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts
            .where((c) =>
                (c.displayName?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
                (c.username?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  void _toggleContact(ContactModel contact) {
    if (contact.username == null) return;
    
    setState(() {
      if (_selectedUsernames.contains(contact.username)) {
        _selectedUsernames.remove(contact.username);
      } else {
        _selectedUsernames.add(contact.username!);
      }
    });
    
    // Notify parent immediately
    widget.onSelectionChanged(_selectedUsernames.toList());
    
    // Recalculate compatibility
    _calculateCompatibility();
  }

  void _calculateCompatibility() async {
     setState(() {
       _calculatingCompatibility = true;
       _suggestedDates = [];
     });

     try {
       // Need IDs for compatibility calc, but we have usernames selected.
       // Convert usernames to IDs using the loaded contact list
       final selectedIds = _contacts
           .where((c) => _selectedUsernames.contains(c.username))
           .map((c) => c.userId)
           .toList();
           
       if (selectedIds.isEmpty) {
         setState(() {
           _compatibilityScore = 1.0;
           _compatibilityStatus = 'good';
           _calculatingCompatibility = false;
         });
         return;
       }

       final result = await _supabaseService.checkCompatibility(
         contactIds: selectedIds,
         date: widget.currentDate,
         currentUserId: _currentUserId,
       );

       if (mounted) {
         setState(() {
           _compatibilityScore = (result['score'] as num).toDouble();
           _compatibilityStatus = result['status'] as String;
           _suggestedDates = (result['suggestions'] as List<dynamic>?)?.cast<DateTime>() ?? [];
           _calculatingCompatibility = false;
         });
       }
     } catch (e) {
       debugPrint('Error calculating compatibility: $e');
       if (mounted) setState(() => _calculatingCompatibility = false);
     }
  }
  
  void _openAddContactModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddContactModal(),
    ).then((_) {
      // Refresh contacts on return
      _fetchContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground, // STANDARD COLOR
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.tertiaryText),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'Meus Contatos', // TITLE UPDATED
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton( // Check button to confirm/close
                icon: const Icon(Icons.check, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Search & Add
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _filterContacts,
                  decoration: InputDecoration(
                    hintText: 'Buscar nos meus contatos',
                    hintStyle: const TextStyle(color: AppColors.secondaryText),
                    prefixIcon: const Icon(Icons.search, color: AppColors.tertiaryText),
                    filled: true,
                    fillColor: AppColors.background, // Contrast inside card
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30), // PILL SHAPE
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: const TextStyle(color: AppColors.secondaryText),
                    prefixIcon: const Icon(Icons.search, color: AppColors.tertiaryText),
                    filled: true,
                    fillColor: AppColors.background, // Contrast inside card
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30), // PILL SHAPE
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  autofillHints: null, // Hack to disable password manager
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: 12),
              // ADD USER BUTTON
              InkWell(
                onTap: _openAddContactModal,
                borderRadius: BorderRadius.circular(30), // ROUND
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle, // ROUND BUTTON
                  ),
                  child: const Icon(Icons.person_add_alt, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Contacts List
          Expanded(
            child: _contacts.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: AppColors.tertiaryText),
                      const SizedBox(height: 16),
                      const Text(
                        'Você ainda não tem contatos.',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                      TextButton(
                        onPressed: _openAddContactModal, 
                        child: const Text('Buscar novas pessoas', style: TextStyle(color: AppColors.primary))
                      ),
                    ],
                  )
                )
              : ListView.separated(
                  itemCount: _filteredContacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final isSelected = _selectedUsernames.contains(contact.username);
                    return ListTile(
                      onTap: () => _toggleContact(contact),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.contact,
                        child: Text(contact.displayName?[0].toUpperCase() ?? '?'),
                      ),
                      title: Text(
                        contact.displayName ?? 'Sem nome',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '@${contact.username}',
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : const Icon(Icons.circle_outlined, color: AppColors.tertiaryText),
                    );
                  },
                ),
          ),
          
          // Compatibility Widget Area
          if (_selectedUsernames.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            _buildCompatibilitySection(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCompatibilitySection() {
    if (_calculatingCompatibility) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(8.0),
        child: LinearProgressIndicator(color: AppColors.primary),
      ));
    }
    
    final bool isBad = _compatibilityStatus == 'bad' || _compatibilityScore < 0.6;
    final Color statusColor = isBad ? Colors.redAccent : Colors.greenAccent;
    final String statusText = isBad ? 'Ruim' : 'Boa';
    final int percentage = (_compatibilityScore * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.tertiaryText, size: 20),
            const SizedBox(width: 8),
            Text(
              'Sinergia do grupo: ',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            Text(
              '$percentage% ($statusText)',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        
        if (isBad && _suggestedDates.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Datas melhores:',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestedDates.map((date) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    backgroundColor: AppColors.cardBackground,
                    labelStyle: const TextStyle(color: Colors.white),
                    label: Text(DateFormat('dd/MM').format(date)),
                    avatar: const Icon(Icons.calendar_today, size: 14, color: Colors.greenAccent),
                    onPressed: () {
                      if (widget.onDateChanged != null) {
                        widget.onDateChanged!(date);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          )
        ]
      ],
    );
  }
}
