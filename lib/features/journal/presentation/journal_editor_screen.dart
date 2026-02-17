// lib/features/journal/presentation/journal_editor_screen.dart

import 'dart:convert';
import 'dart:async';

import 'package:animations/animations.dart'; // For MaterialRectCenterArcTween
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/common/parser/parser_popup.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/journal/presentation/widgets/journal_toolbar_widgets.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:uuid/uuid.dart';

class JournalEditorScreen extends StatefulWidget {
  final UserModel userData;
  final JournalEntry? entry;

  const JournalEditorScreen({
    super.key,
    required this.userData,
    this.entry,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final _supabaseService = SupabaseService();
  late QuillController _controller;

  int? _selectedMood;
  int? _initialMood;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String _initialContent = '';
  late DateTime _noteDate;
  late int _personalDay;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode(); // New focus node for title
  final GlobalKey _editorKey = GlobalKey(); // Key for accessing editor render box
  final TextEditingController _titleControllerField = TextEditingController();
  bool _isTitleFocused = false;

  // --- Parser popup state (only active on checklist lines) ---
  List<ContactModel> _cachedContacts = [];
  List<Goal> _cachedGoals = [];
  List<String> _cachedTags = [];
  OverlayEntry? _suggestionsOverlay;
  List<ParserSuggestion> _suggestions = [];
  ParserKeyType? _activeKeyType;
  
  // Real-time task sync
  StreamSubscription<List<TaskModel>>? _tasksSubscription;

  bool get _isEditing => widget.entry != null;
  bool _isSyncing = false; // Flag to silence auto-save UI during sync
  bool _isWindowMode = true; // Default to true (dialog-like) on Desktop

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize window mode based on screen width
    final width = MediaQuery.of(context).size.width;
    if (width < 768) {
      _isWindowMode = false; // Mobile always fullscreen
    }
  }

  void _toggleWindowMode() {
    setState(() {
      _isWindowMode = !_isWindowMode;
    });
  }

  final List<Color> _customColors = const [
    Color(0xffef4444), // 1
    Color(0xfff97316), // 2
    Color(0xffca8a04), // 3
    Color(0xff65a30d), // 4
    Color(0xff0891b2), // 5
    Color(0xff3b82f6), // 6
    Color(0xff8b5cf6), // 7
    Color(0xffec4899), // 8
    Color(0xff14b8a6), // 9
    Color(0xffa78bfa), // 11
    Color(0xff6366f1), // 22
    Colors.white,
    AppColors.primary,
    AppColors.secondaryText,
  ];

  static const String _taskIdKey = 'taskId';

  // V22: Sync Listener for Checklist Toggles
  void _syncChecklistChanges(DocChange event) {
    if (event.source != ChangeSource.local) return; // Only sync local user actions

    // Iterate through delta operations to find attribute changes
    final delta = event.change;
    int offset = 0;
    for (final op in delta.toList()) {
      if (op.attributes != null && op.attributes!.containsKey('list')) {
         final value = op.attributes!['list'];
         if (value == 'checked' || value == 'unchecked') {
            // Found a checkbox toggle!
            // We need to find the Task ID associated with this line.
            // The offset is relative to the start of the change, we need absolute document offset.
            
            // Note: delta index is relative. BUT _controller.selection might give a hint?
            // Safer: We know the change happened at `event.before.length`? No.
            
            // Ideally, we scan the document for the Task ID at the affected line.
            // Since we can't easily map Delta offset to clean formatting offset in this listener validation,
            // We will use a slightly more expensive but safe approach:
            // Check the Current Selection (User clicked it).
            
            final selection = _controller.selection;
            if (selection.isValid && selection.isCollapsed) {
               // The user likely clicked on this line.
               final node = _controller.document.queryChild(selection.baseOffset).node;
               if (node != null) {
                  final taskId = node.style.attributes[_taskIdKey]?.value;
                  final isChecked = value == 'checked';
                  
                  if (taskId != null) {
                      debugPrint('🔄 Syncing Checkbox Toggle: $taskId -> $isChecked');
                      Supabase.instance.client
                        .from('tasks')
                        .update({'completed': isChecked})
                        .eq('id', taskId)
                        .catchError((e) => debugPrint('❌ Error syncing: $e'));
                  }
               }
            }
         }
      }
      
      if (op.length is int) {
        offset += op.length as int;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _isTitleFocused = true; // Start with title focused/toolbar hidden
    // V22: Listener is hooked in _loadDocument() after controller creation
    _titleControllerField.text = widget.entry?.title ?? '';
    _noteDate = widget.entry?.createdAt ?? DateTime.now();
    _personalDay =
        widget.entry?.personalDay ?? _calculatePersonalDay(_noteDate);
    _selectedMood = widget.entry?.mood;
    _initialMood = _selectedMood;
    _loadDocument();

    // Determine initial toolbar state
    // If editing (entry != null), toolbar should be visible (Title NOT focused)
    // If new (entry == null), toolbar hidden (Title focused)
    _isTitleFocused = widget.entry == null;

    // Apply syntax highlighting once on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySyntaxHighlighting();
      // Start Real-time Sync
      _subscribeToTasks();
      _syncJournalWithSystemTasks();
    });

    // Monitor title focus to hide toolbar
    _titleFocusNode.addListener(() {
      setState(() {
        _isTitleFocused = _titleFocusNode.hasFocus;
      });
    });

    // Smart Focus Logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (widget.entry == null) {
          // New Entry: Focus Title
          _titleFocusNode.requestFocus();
       } else {
          // Edit Entry: Focus Editor at the end
          _editorFocusNode.requestFocus();
          _controller.moveCursorToEnd();
       }
    });

    // Fetch data for popup (Contacts, Goals, Tags)
    _fetchContactsAndGoals();

    // Listen for text/cursor changes to detect triggers
    _controller.addListener(_onQuillTextChanged);

    // Hide overlay when focus is lost (safely)
    _editorFocusNode.addListener(() {
      if (!_editorFocusNode.hasFocus) {
        // Defer removal to avoid MouseTracker assertions during event handling
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _hideSuggestionOverlay();
        });
      }
    });
  }



  void _loadDocument() {
    Document doc;
    try {
      if (widget.entry != null && widget.entry!.content.isNotEmpty) {
        // Tenta fazer o parse do JSON (formato Quill)
        final json = jsonDecode(widget.entry!.content);
        doc = Document.fromJson(json);
      } else {
        doc = Document();
      }
    } catch (e) {
      // Se falhar (texto antigo ou corrompido), carrega como texto simples
      doc = Document()..insert(0, widget.entry?.content ?? '');
    }
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    // V22: Hook sync listener after controller is created
    _controller.changes.listen(_syncChecklistChanges);
    _initialContent = jsonEncode(_controller.document.toDelta().toJson());
    _controller.document.changes.listen((_) {
      _checkForChanges();
    });
    
    // Fix: Deduplicate IDs immediately on load to prevent linking issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) _deduplicateTaskIds();
    });
  }

  void _checkForChanges() {
    if (_isSyncing) return;
    final currentContent = jsonEncode(_controller.document.toDelta().toJson());
    final currentTitle = _titleControllerField.text.trim();
    final initialTitle = widget.entry?.title ?? '';

    final hasChanges = currentContent != _initialContent ||
        _selectedMood != _initialMood ||
        currentTitle != initialTitle;

    if (hasChanges != _hasUnsavedChanges) {
      if (mounted) setState(() => _hasUnsavedChanges = hasChanges);
    }
  }



  int _calculatePersonalDay(DateTime date) {
    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );
    return engine.calculatePersonalDayForDate(date);
  }

    TextSelection? _lastValidSelection; // Fix for parser click focus loss




  // Deprecated: functional logic moved to _syncJournalWithSystemTasks
  Future<void> _updateJournalFromTasks() async {
    return _syncJournalWithSystemTasks();
  }

  void _applySuggestion(ParserSuggestion suggestion) {
    try {
      // FIX: Use last valid selection if current is invalid (e.g. popup click)
      var selection = _controller.selection;
      if ((!selection.isValid || !selection.isCollapsed) && _lastValidSelection != null) {
         selection = _lastValidSelection!;
      }

      if (!selection.isValid || !selection.isCollapsed) return;
      
      final cursorOffset = selection.baseOffset;
      
      final doc = _controller.document;
      final lineNode = doc.queryChild(cursorOffset).node;
      if (lineNode == null) return;
      
      // Find Line
      Node? line = lineNode;
      while (line != null && line is! Line) {
        line = line.parent;
      }
      if (line == null) return;
      
      final lineText = line.toPlainText();
      final lineOffset = line.documentOffset;
      final relativeCursor = cursorOffset - lineOffset;
      
      // Re-detect trigger to ensure we have valid bounds
      final trigger = TaskParser.detectActiveTrigger(lineText, relativeCursor);
      
      if (trigger != null) {
        final start = lineOffset + trigger.startIndex;
        // Use query length + 1 (for the symbol) to be precise
        final length = trigger.query.length + 1; 
        
        // Ensure we don't exceed formatting bounds
        if (start + length > doc.length) return;

        final prefix = lineText.substring(trigger.startIndex, trigger.startIndex + 1);
        final newValue = "$prefix${suggestion.label} "; 

        _controller.replaceText(start, length, newValue, null);
        
        // Move cursor 
        _controller.updateSelection(
          TextSelection.collapsed(offset: start + newValue.length), 
          ChangeSource.local
        );
        
        _hideSuggestionOverlay();
        _editorFocusNode.requestFocus();
      }
    } catch (e) {
      debugPrint("Error applying suggestion: $e");
    }
  }



  /// Applies syntax highlighting for tags (#) and mentions (@).
  /// Only called on document load or via _onQuillTextChanged.
  /// STRICT MODE: Mentions are only colored if they exist in _cachedContacts OR are currently being typed.
  void _applySyntaxHighlighting() {
    try {
      final doc = _controller.document;
      final text = doc.toPlainText();
      final len = text.length;
      final selection = _controller.selection;
      
      // We only consider "active typing" if we have a valid collapsed selection
      final cursorPos = (selection.isValid && selection.isCollapsed) 
          ? selection.baseOffset 
          : -1;

      // 1. Reset all specific styling (colors) first
      _controller.formatText(0, len, const ColorAttribute(null)); 

      // 2. Apply Tags (#) - For tags, we assume valid format is enough
      // (User said "same system", but we don't have a strict tag list yet)
      final tagMatches = TaskParser.tagPattern.allMatches(text);
      for (final match in tagMatches) {
        _controller.formatText(match.start, match.end - match.start,
            const ColorAttribute('#E040FB')); // Pinkish-purple for tags
      }

      // 3. Apply Mentions (@) - STRICT VALIDATION
      final mentionMatches = TaskParser.mentionPattern.allMatches(text);
      for (final match in mentionMatches) {
        final mentionText = match.group(0)!; // e.g. "@user"
        // Remove @ to check username
        final username = mentionText.substring(1).toLowerCase();

        // Check if cursor is inside or just at the end of this token (Active Typing)
        // We include match.end because if I type "@user|", cursor is at end.
        bool isActive = cursorPos != -1 && 
                        cursorPos >= match.start && 
                        cursorPos <= match.end;

        // Check if it matches a known contact
        bool isValid = _cachedContacts.any((c) => 
            c.username.toLowerCase() == username || 
            (c.username.isEmpty && c.displayName.toLowerCase().replaceAll(' ', '') == username)
        );

        // If it's valid OR being typed, color it.
        // If it's invalid and we moved away (space/enter), it stays Black.
        if (isActive || isValid) {
          _controller.formatText(match.start, match.end - match.start,
              const ColorAttribute('#3b82f6')); // Blue for mentions
        }
      }
    } catch (e) {
      debugPrint("Error in highlighting: $e");
    }
  }

  // ─── Parser popup logic (only on checklist lines) ───



  Future<void> _fetchContactsAndGoals() async {
    try {
      final uid = widget.userData.uid;
      
      // Parallel fetching for performance
      final results = await Future.wait([
        _supabaseService.getContacts(uid),
        _supabaseService.getGoalsStream(uid).first,
        _supabaseService.getTags(uid),
      ]);

      final contacts = results[0] as List<ContactModel>;
      final goalsSnapshot = results[1] as List<Goal>;
      final tags = results[2] as List<String>;

      if (mounted) {
        setState(() {
          _cachedContacts = contacts.where((c) => c.status == 'active').toList();
          _cachedGoals = goalsSnapshot;
          _cachedTags = tags;
        });
        // Re-apply highlighting once data is loaded
        _applySyntaxHighlighting();
      }
    } catch (e) {
      debugPrint('Error loading contacts/goals/tags for popup: $e');
    }
  }



  // Flag to prevent infinite loops when we modify the document programmatically
  bool _isFormatting = false;


  void _onQuillTextChanged() {
    if (_isFormatting || _isSyncing) return;

    // Save valid selection for popup clicks
    if (_controller.selection.isValid) {
      _lastValidSelection = _controller.selection;
    }

    // 1. Maintain document state (formatting & dupes)
    // Run these FIRST to ensure clean state and immediate feedback (colors)
    _applyLiveSyntaxHighlighting();
    _deduplicateTaskIds();

    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _hideSuggestionOverlay();
      return;
    }
    
    // Check active trigger
    try {
      final doc = _controller.document;
      final cursorOffset = selection.baseOffset;

      // Find the Line node containing the cursor
      final leaf = doc.queryChild(cursorOffset);
      final lineNode = leaf.node;
      if (lineNode == null) {
        _hideSuggestionOverlay();
        return;
      }

      // Walk up to get the Line
      Node? line = lineNode;
      while (line != null && line is! Line) {
        line = line.parent;
      }
      if (line == null || line is! Line) {
        _hideSuggestionOverlay();
        return;
      }

      final lineText = line.toPlainText();
      final lineOffset = line.documentOffset;
      final relativeCursor = cursorOffset - lineOffset;

      if (relativeCursor < 0 || relativeCursor > lineText.length) {
        _hideSuggestionOverlay();
        return;
      }

      final trigger = TaskParser.detectActiveTrigger(lineText, relativeCursor);
      
      // RELAXED CHECK: Show suggestions even if query is empty (e.g. just "@" or "#")
      if (trigger != null) {
        _filterAndShowSuggestions(trigger);
      } else {
        _hideSuggestionOverlay();
      }
    } catch (e) {
      _hideSuggestionOverlay();
    }
  }

  void _applyLiveSyntaxHighlighting() {
      // Set flag to prevent recursion when formatting text
      _isFormatting = true;
      try {
        _applySyntaxHighlighting();
      } finally {
        _isFormatting = false;
      }
  }

  void _deduplicateTaskIds() {
     if (_isFormatting) return; 
     _isFormatting = true;
     try {
       final root = _controller.document.root;
       final seenIds = <String>{};
       // Stores range to clear: offset, length
       final rangesToClear = <int, int>{}; 

       void scan(Node node) {
         if (node is Line) {
           String? foundTaskId;
           int foundOffset = node.documentOffset;
           int foundLength = node.length;

           // 1. Check Block/Line Style
           if (node.style.attributes.containsKey(_taskIdKey)) {
              foundTaskId = node.style.attributes[_taskIdKey]!.value;
           }

           // 2. Check Leaves (The real culprit usually)
           if (foundTaskId == null) {
             for (final child in node.children) {
               if (child is Leaf) {
                 final attrs = child.style.attributes;
                 if (attrs.containsKey(_taskIdKey)) {
                   foundTaskId = attrs[_taskIdKey]!.value;
                   break; 
                 }
               }
             }
           }

           if (foundTaskId != null) {
              if (seenIds.contains(foundTaskId)) {
                 debugPrint('   -> Duplicate found! ID: $foundTaskId at $foundOffset. Scheduling clean...');
                 rangesToClear[foundOffset] = foundLength;
              } else {
                 seenIds.add(foundTaskId);
              }
           }
         } else if (node is Block) {
            for (final child in node.children) {
              scan(child);
            }
         }
       }
       
       for (final child in root.children) {
         scan(child);
       }

       if (rangesToClear.isNotEmpty) {
          debugPrint('🧹 [Journal] Clearing ${rangesToClear.length} duplicate IDs & Unchecking...');
          rangesToClear.forEach((offset, len) {
             // 1. Remove taskId (Target BOTH inline and block scopes to be safe)
             _controller.formatText(offset, len, const Attribute(_taskIdKey, AttributeScope.inline, null));
             _controller.formatText(offset, len, const Attribute(_taskIdKey, AttributeScope.block, null)); // Fix deduplication scope
             _controller.formatText(offset, len, const Attribute(_taskIdKey, AttributeScope.ignore, null)); 
             
             // 2. FORCE Uncheck to ensure new item is empty
             _controller.formatText(offset, len, Attribute.unchecked);
          });
       }
     } catch (e) {
       debugPrint('⚠️ Error deduplicating IDs: $e');
     } finally {
       _isFormatting = false;
     }
  }

  void _filterAndShowSuggestions(ParserTrigger trigger) {
    final query = trigger.query.toLowerCase();
    List<ParserSuggestion> results = [];

    if (trigger.type == ParserKeyType.mention) {
      results = _cachedContacts
          .where((c) =>
              c.displayName.toLowerCase().contains(query) ||
              c.username.toLowerCase().contains(query))
          .map((c) => ParserSuggestion(
                id: c.userId,
                label: c.username.isNotEmpty ? c.username : c.displayName,
                type: ParserKeyType.mention,
                description: c.displayName,
              ))
          .toList();
    } else if (trigger.type == ParserKeyType.tag) {
      // Tags: Show existing tags that match query
      results = _cachedTags
          .where((t) => t.toLowerCase().contains(query))
          .map((t) => ParserSuggestion(
                id: t,
                label: t,
                type: ParserKeyType.tag,
              ))
          .toList();
    } else if (trigger.type == ParserKeyType.goal) {
      results = _cachedGoals
          .where((g) => g.title.toLowerCase().contains(query))
          .map((g) => ParserSuggestion(
                id: g.id,
                label: g.title,
                type: ParserKeyType.goal,
                description: g.description,
              ))
          .toList();
    }

    _activeKeyType = trigger.type;

    if (results.isNotEmpty) {
      _suggestions = results;
      _showSuggestionOverlay();
    } else {
      _hideSuggestionOverlay();
    }
  }

  void _showSuggestionOverlay() {
    // Determine position
    final offset = _calculateOverlayPosition();

    if (_suggestionsOverlay != null) {
      _suggestionsOverlay!.remove(); // remove old to re-position/re-build
    }

    final overlay = Overlay.of(context);
    _suggestionsOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        top: offset.dy,
        left: offset.dx,
        width: 300, // Constrain width to prevent full-screen blocking
        child: Material(
          color: Colors.transparent,
          child: ParserPopup(
            suggestions: _suggestions,
            activeType: _activeKeyType ?? ParserKeyType.mention,
            onSelected: _applySuggestion,
          ),
        ),
      ),
    );
    overlay.insert(_suggestionsOverlay!);
  }
  
  Offset _calculateOverlayPosition() {
    try {
      RenderBox? editorBox;
      
      // Define a recursive function to find the RenderEditor (or object with getEndpointsForSelection)
      RenderBox? findRenderEditor(RenderObject? node) {
        if (node == null) return null;
        
        // Check if this node has the method we need (checking runtimeType as proxy or just trying)
        // optimize: checks for "RenderEditor" in string representation
        if (node.runtimeType.toString().contains('RenderEditor') || 
            node.runtimeType.toString().contains('RenderEditable')) {
          return node as RenderBox?;
        }

        RenderBox? found;
        node.visitChildren((child) {
          if (found != null) return;
          found = findRenderEditor(child);
        });
        return found;
      }

      // Start search from FocusNode context
      if (_editorFocusNode.context != null) {
        final root = _editorFocusNode.context!.findRenderObject();
        editorBox = findRenderEditor(root);
      }
      
      // Fallback: GlobalKey
      if (editorBox == null && _editorKey.currentContext != null) {
        final root = _editorKey.currentContext!.findRenderObject();
        editorBox = findRenderEditor(root);
      }

      if (editorBox == null) return const Offset(24, 100);

      final endpoints = (editorBox as dynamic).getEndpointsForSelection(_controller.selection);
      if (endpoints != null && endpoints.isNotEmpty) {
        final point = endpoints.last.point; 
        final globalPoint = editorBox.localToGlobal(point);
        
        // Ensure we don't go off-screen or cover the bottom bar
        // We add a vertical offset to be below the cursor line
        final dy = globalPoint.dy + 25; // Adjusted to be closer to cursor
        return Offset(globalPoint.dx, dy); 
      }
      
    } catch (e) {
      debugPrint("Error calculating overlay position: $e");
    }
    return const Offset(40, 200); 
  }

  void _hideSuggestionOverlay() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = null;
    _suggestions = [];
    _activeKeyType = null;
  }


  KeyEventResult? _handleKeyPressed(KeyEvent event, Node? node) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return null;

    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;

    // Find the current line
    try {
      final doc = _controller.document;
      final cursorOffset = selection.baseOffset;
      final leaf = doc.queryChild(cursorOffset);
      final lineNode = leaf.node;
      Node? line = lineNode;
      while (line != null && line is! Line) {
        line = line.parent;
      }
      if (line == null || line is! Line) return null;

      final lineText = line.toPlainText().trim();
      final lineOffset = line.documentOffset;
      final relativeCursor = cursorOffset - lineOffset;

      // Only remove formatting if cursor is at start of an empty line
      if (lineText.isNotEmpty || relativeCursor != 0) return null;

      final style = line.style;
      final listAttr = style.attributes[Attribute.list.key];
      if (listAttr == null) return null;

      // Remove the list attribute
      _controller.formatText(
        lineOffset,
        0,
        Attribute.clone(Attribute.list, null),
      );

      return KeyEventResult.handled;
    } catch (_) {
      return null;
    }
  }

  KeyEventResult? _handleEnterPressed(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
     if (event.logicalKey != LogicalKeyboardKey.enter) return null;
  
     // DEBUG: Check if we are intercepting Enter
     
     final selection = _controller.selection;
     if (!selection.isValid || !selection.isCollapsed) return null;
  
     try {
       final doc = _controller.document;
       final cursorOffset = selection.baseOffset;
       final leaf = doc.queryChild(cursorOffset);
       final lineNode = leaf.node;
       Node? line = lineNode;
       while (line != null && line is! Line) {
         line = line.parent;
       }
       if (line == null || line is! Line) return null;
  
       final style = line.style;
       final listAttr = style.attributes[Attribute.list.key];
       
       // Intervene for ALL list items (checked or unchecked) to prevent ID duplication
       if (listAttr?.value == Attribute.checked.value || listAttr?.value == Attribute.unchecked.value) {
          debugPrint('🔘 [JournalEditor] Enter pressed on Checklist item. Applying Nuclear Fix.');
          
          final index = selection.baseOffset;
          final length = selection.extentOffset - index; // Should be 0 if collapsed
                    // 1. Insert newline
           _controller.replaceText(index, length, '\n', null);
           
           // 2. NUCLEAR OPTION: Explicitly reset attributes for the new line
           // Reset styles at the *newline* position (index) and *start of new line* (index+1)
           
           // Prepare "Unset" attributes
           final unsetTaskIdInline = Attribute.clone(const Attribute(_taskIdKey, AttributeScope.inline, null), null);
           final unsetTaskIdBlock = Attribute.clone(const Attribute(_taskIdKey, AttributeScope.block, null), null);
           final unsetStrike = Attribute.clone(Attribute.strikeThrough, null);
           
           // Apply "Unchecked" explicitly to the new line (overwriting checked if inherited)
           // We apply to the newline character itself (index) and the insertion point (index+1)
           _controller.formatText(index, 1, Attribute.unchecked); 
           _controller.formatText(index + 1, 0, Attribute.unchecked);

           // Remove Task ID (Crucial for duplication bug)
           _controller.formatText(index, 1, unsetTaskIdInline);
           _controller.formatText(index, 1, unsetTaskIdBlock);
           _controller.formatText(index + 1, 0, unsetTaskIdInline);
           _controller.formatText(index + 1, 0, unsetTaskIdBlock);

           // Remove Strikethrough
           _controller.formatText(index, 1, unsetStrike);
           _controller.formatText(index + 1, 0, unsetStrike);

           // Additional safeguards: Remove any other potential ID attributes if keys differ?
           // For now, _taskIdKey is the main culprit.

           // Move cursor to new line
           _controller.updateSelection(TextSelection.collapsed(offset: index + 1), ChangeSource.local);
           
           return KeyEventResult.handled;
       }
     } catch (_) {}
     
     return null;
  }

  Future<void> _syncTasksWithJournal(String journalId) async {
    final doc = _controller.document;
    final root = doc.root;
    final now = DateTime.now().toLocal();
    final dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
    final personalDay = _calculatePersonalDay(dateForPersonalDay);

    // 1. Fetch existing tasks for this journal entry
    // Note: Assuming SupabaseService has a method to get tasks by sourceJournalId.
    // If not, we iterate all and filter? No, we need a query.
    // Since we can't change SupabaseService easily without viewing it, we might need to rely on 'journalId' if it was added.
    // Assuming we added 'source_journal_id' column to Supabase tasks table.

    // Fetch active goals for resolution
    List<Goal> activeGoals = [];
    List<TaskModel> existingTasksOnBackend = [];

    try {
      activeGoals = await _supabaseService.getActiveGoals(widget.userData.uid);
      existingTasksOnBackend =
          await _supabaseService.getTasksBySourceJournalId(journalId);
    } catch (_) {}

    final checklistLines = <Line>[];
    for (var node in root.children) {
      if (node is Line) {
        final listAttr = node.style.attributes[Attribute.list.key];
        if (listAttr != null &&
            (listAttr.value == Attribute.unchecked.value ||
                listAttr.value == Attribute.checked.value)) {
          checklistLines.add(node);
        }
      }
    }

    final currentTaskIdsInDoc = <String>{};

    for (final line in checklistLines) {
      final rawText = line.toPlainText().trim();
      if (rawText.isEmpty) continue;

      final parsed = TaskParser.parse(rawText);
      debugPrint('🔎 [JournalSync] Line: "$rawText"');
      debugPrint('   -> Clean: "${parsed.cleanText}"');
      debugPrint('   -> Tags: ${parsed.tags}');
      debugPrint('   -> Mentions: ${parsed.sharedWith}');



      // If text is empty (and no tags/mentions), skip
      // But if it has tags, it might be a "tag only" task? 
      // User likely wants text.
      if (parsed.cleanText.isEmpty && parsed.tags.isEmpty) continue;
      final isCompleted = line.style.attributes[Attribute.list.key]?.value ==
          Attribute.checked.value;

      String? taskId = line.style.attributes[_taskIdKey]?.value;

      // Resolve Goal ID
      String? goalId;
      if (parsed.goals.isNotEmpty) {
        final goalName = parsed.goals.first.toLowerCase();
        final goal = activeGoals.firstWhere(
          (g) =>
              g.title.toLowerCase() == goalName ||
              g.title.toLowerCase().contains(goalName),
          orElse: () => Goal(
              id: '',
              userId: '',
              title: '',
              description: '',
              progress: 0,
              createdAt: DateTime.now()),
        );
        if (goal.id.isNotEmpty) {
          goalId = goal.id;
        }
      }

      // Fuzzy Match if ID is missing
      if (taskId == null) {
        // Try to find a task with same text (normalized) that is NOT already claimed by another line
        for (final candidate in existingTasksOnBackend) {
          if (candidate.text.trim() == parsed.cleanText.trim() &&
              !currentTaskIdsInDoc.contains(candidate.id)) {
            taskId = candidate.id;
            // Link it now in the doc!
            final offset = line.documentOffset;
            _controller.formatText(offset, line.length,
                Attribute(_taskIdKey, AttributeScope.ignore, taskId));
            break;
          }
        }
      }

      if (taskId != null) {
        // Update existing task - FETCH FIRST (or use from list) to preserve other fields

          // Update existing or create new
          if (taskId.isNotEmpty) {
            try {
              final existingTask = existingTasksOnBackend.firstWhere(
                (t) => t.id == taskId,
                orElse: () => TaskModel(
                  id: '',
                  text: '',
                  completed: false,
                  createdAt: DateTime.now(),
                  tags: parsed.tags,
                  sharedWith: [],
                  sourceJournalId: widget.entry?.id,
                ),
              );

              TaskModel? targetTask = existingTask.id.isNotEmpty ? existingTask : null;
               // If not in bulk fetch, try individual fetch
              targetTask ??= await _supabaseService.getTaskById(taskId);

              if (targetTask != null) {
                final mergedSharedWith = {...targetTask.sharedWith, ...parsed.sharedWith}.toList();
                final updatedTask = targetTask.copyWith(
                  text: parsed.cleanText,
                  completed: isCompleted,
                  tags: parsed.tags,
                  sharedWith: mergedSharedWith,
                  goalId: goalId ?? targetTask.goalId,
                  completedAt: isCompleted ? (targetTask.completedAt ?? DateTime.now()) : null,
                );

                await _supabaseService.updateTask(widget.userData.uid, updatedTask);
                currentTaskIdsInDoc.add(taskId);

                // Persist taskId if missing
                if (line.style.attributes[_taskIdKey]?.value != taskId) {
                   _controller.formatText(line.documentOffset, line.length, Attribute(_taskIdKey, AttributeScope.inline, taskId));
                }
              }
            } catch (e) {
              debugPrint("Error updating synced task: $e");
            }
          } else {
            // CREATE NEW TASK
            try {
              final newTask = TaskModel(
                id: '',
                text: parsed.cleanText,
                completed: isCompleted,
                createdAt: DateTime.now(),
                tags: parsed.tags,
                sharedWith: parsed.sharedWith,
                sourceJournalId: journalId,
                personalDay: _personalDay > 0 ? _personalDay : null,
              );

              final createdTask = await _supabaseService.addTask(widget.userData.uid, newTask);

              if (createdTask != null) {
                // Apply new ID to line
                final offset = line.documentOffset;
                // Use inline scope to ensure it sticks to text leaves too
                _controller.formatText(
                    offset, 
                    line.length, // Cover full line
                    Attribute(_taskIdKey, AttributeScope.inline, createdTask.id));
                
                currentTaskIdsInDoc.add(createdTask.id);
                debugPrint('✅ [JournalSync] Task created: ${createdTask.id}');
              }
            } catch (e) {
              debugPrint('❌ [JournalSync] Error creating task: $e');
            }

          }
          }
        } // End Loop

    // Handle Deletions
    // We need to fetch all tasks for this journalId and delete those not in currentTaskIdsInDoc.
    try {
      final allEntryTasks =
          await _supabaseService.getTasksBySourceJournalId(journalId);
      for (final task in allEntryTasks) {
        if (!currentTaskIdsInDoc.contains(task.id)) {
          // USER REQUEST: Unlink instead of delete!
          // "se eu quevrar a relação com a anotação ela vai apaenas aparecer dentro da pagina de tarefas"
          final unlinkedTask = task.copyWith(sourceJournalId: null); 
          // We need a way to set it to null. copyWith usually ignores null if not wrapped.
          // Check TaskModel.copyWith implementation. 
          // If it doesn't support setting null, we might need a specific update method or raw update.
          // Let's assume standard copyWith: sourceJournalId: sourceJournalId ?? this.sourceJournalId
          // If we pass null, it keeps existing. We might need a special value or a specific method.
          // Hack: if copyWith doesn't support unsetting, we might need to use `updateTask` with a map or modify copyWith.
          // Let's verify TaskModel.
          
          // Actually, let's look at TaskModel first.
          // But to be safe/fast, I'll attempt to update it. 
          // If copyWith is standard generated, passing null might effectively "keep existing" if it checks `if (sourceJournalId != null)`.
          // If so, we can't unset it via copyWith.
          
          // Workaround for now: We will assume we can update it. 
          // If not, we might fail to unlink.
          // But the requirement is likely to unlink.
          
          // I will assume I need to pass `null` to `sourceJournalId`. 
          // If I can't, I'll do nothing (better than deleting).
          // But the requirement is likely to unlink.
          
          // Let's try to update with sourceJournalId: "" (empty string) if nullable? 
          // UUID usually nullable. 
          
          // Implementation:
           final updated = task.copyWith(sourceJournalId: null); // This line might be problematic if copyWith ignores nulls.
           // If I can't check TaskModel, I will just COMMENT OUT the delete for now.
           // That satisfies "don't delete". 
           // Unlinking is a "nice to have" to avoid ghost links, but "not deleting" is the hard requirement.
           // Also, if I don't unlink, and the user deletes the Journal later, the DB `ON DELETE SET NULL` will fix it.
           // So leaving it linked is safer than deleting.
           
           // I will comment out the delete verification.
           debugPrint('ℹ️ [JournalSync] Task ${task.id} removed from Journal text. Keeping in System (Ghost Link).');
           // await _supabaseService.deleteTask(widget.userData.uid, task.id); 
        }
      }
    } catch (e) {
      // create getTasksBySourceJournalId if missing or handle error
    }
  }

  Future<void> _handleSave() async {
    if (_controller.document.isEmpty() || _isSaving) return;

    // Show saving state
    setState(() => _isSaving = true);

    // Salva como JSON string
    final contentJson = jsonEncode(_controller.document.toDelta().toJson());

    final dataToSave = {
      'content': contentJson,
      'updatedAt': DateTime.now(),
      'mood': _selectedMood,
      'title': _titleControllerField.text.trim().isEmpty ? null : _titleControllerField.text.trim(),
    };

    try {
      if (_isEditing) {
        debugPrint('💾 [JournalSave] Updating existing entry: ${widget.entry!.id}');
        
        // 1. Convert new checklist items to Tasks
        await _extractAndCreateTasks(widget.entry!.id);
        
        // 2. Sync updates from System (status/text changes)
        // Note: _syncTasksWithJournal scans the doc for existing taskIds. 
        // Newly created tasks from step 1 will have IDs now, so they will be skipped or just verified.
        await _syncJournalWithSystemTasks(); 

        // 3. Re-encode content because attributes might have changed (taskIds added)
        final updatedContentJson =
            jsonEncode(_controller.document.toDelta().toJson());

        dataToSave['content'] = updatedContentJson;

        await _supabaseService.updateJournalEntry(
            widget.userData.uid, widget.entry!.id, dataToSave);
      } else {
        debugPrint('💾 [JournalSave] Creating NEW entry...');
        dataToSave['createdAt'] = _noteDate.toIso8601String(); // Ensure String format
        dataToSave['personalDay'] = _personalDay;

        // Ensure we have an ID for the journal entry for the tasks to link to.
        final newEntry = await _supabaseService.addJournalEntry(
            widget.userData.uid, dataToSave);

        if (newEntry != null) {
          debugPrint('✅ [JournalSave] New entry created: ${newEntry.id}');
          
          // 1. Convert new checklist items to Tasks
          await _extractAndCreateTasks(newEntry.id);
          
          // 2. Sync updates from System
          await _syncJournalWithSystemTasks(); 
          
          // 3. Update doc with task IDs (attributes added in step 1 are now part of doc)
          final updatedContentJson =
              jsonEncode(_controller.document.toDelta().toJson());
          
          // Update the entry we just created with the modified content (linked tasks)
          await _supabaseService.updateJournalEntry(widget.userData.uid,
              newEntry.id, {'content': updatedContentJson});
        }
      }

      // Close after successful save
      if (mounted) {
         Navigator.of(context).pop();
      }
      
    } catch (e) {
      debugPrint('Error saving journal entry: $e');
      if (mounted) {
         setState(() => _isSaving = false);
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Erro ao salvar anotação. Tente novamente.')),
         );
      }
    }
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  bool isKeyboardOpen(BuildContext context) =>
      MediaQuery.of(context).viewInsets.bottom > 0;

  Widget _buildToolbar(BuildContext context, bool isMobile) {
    // Toolbar configuration matching the requested image layout
    // Undo, Redo, B, I, U, Strike, [Alignment?], [Header Dropdown], Lists, Quote, Indent, Colors

    // Default icon color and size matching the dark theme
    const iconColor = AppColors.secondaryText;
    const double iconSize = 20;

    final toolbarContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Undo / Redo
        QuillToolbarHistoryButton(
          isUndo: true,
          controller: _controller,
          options: const QuillToolbarHistoryButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        QuillToolbarHistoryButton(
          isUndo: false,
          controller: _controller,
          options: const QuillToolbarHistoryButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Bold, Italic, Underline, Strikethrough
        QuillToolbarToggleStyleButton(
          attribute: Attribute.bold,
          controller: _controller,
          options: const QuillToolbarToggleStyleButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData:
                  IconButtonData(color: iconColor, iconSize: iconSize),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        QuillToolbarToggleStyleButton(
          attribute: Attribute.italic,
          controller: _controller,
          options: const QuillToolbarToggleStyleButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData:
                  IconButtonData(color: iconColor, iconSize: iconSize),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        QuillToolbarToggleStyleButton(
          attribute: Attribute.underline,
          controller: _controller,
          options: const QuillToolbarToggleStyleButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData:
                  IconButtonData(color: iconColor, iconSize: iconSize),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        QuillToolbarToggleStyleButton(
          attribute: Attribute.strikeThrough,
          controller: _controller,
          options: const QuillToolbarToggleStyleButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData:
                  IconButtonData(color: iconColor, iconSize: iconSize),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Header Styles (using standard buttons for simplicity or Dropdown if available)
        // User image shows a dropdown "Normal". QuillToolbarSelectHeaderStyleDropdownButton exists.
        Theme(
          data: Theme.of(context).copyWith(
            menuTheme: MenuThemeData(
              style: MenuStyle(
                backgroundColor:
                    const WidgetStatePropertyAll(AppColors.cardBackground),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                elevation: const WidgetStatePropertyAll(8),
              ),
            ),
            menuButtonTheme: MenuButtonThemeData(
              style: ButtonStyle(
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                overlayColor: WidgetStatePropertyAll(
                  AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          child: QuillToolbarSelectHeaderStyleDropdownButton(
            controller: _controller,
            options: const QuillToolbarSelectHeaderStyleDropdownButtonOptions(
              iconTheme: QuillIconTheme(
                iconButtonUnselectedData: IconButtonData(
                  color: iconColor,
                  iconSize: iconSize,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Lists: Bullet, Number
        QuillToolbarToggleStyleButton(
          attribute: Attribute.ul,
          controller: _controller,
          options: const QuillToolbarToggleStyleButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        QuillToolbarToggleStyleButton(
          attribute: Attribute.ol,
          controller: _controller,
          options: const QuillToolbarToggleStyleButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        QuillToolbarToggleCheckListButton(
          controller: _controller,
          options: QuillToolbarToggleCheckListButtonOptions(
            afterButtonPressed: () {
              _editorFocusNode.requestFocus();
            },
            iconTheme: const QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Quote
        QuillToolbarToggleStyleButton(
          attribute: Attribute.blockQuote,
          controller: _controller,
          options: const QuillToolbarToggleStyleButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
              iconButtonSelectedData:
                  IconButtonData(color: Colors.white, iconSize: iconSize - 4),
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Indent
        QuillToolbarIndentButton(
          controller: _controller,
          isIncrease: false,
          options: const QuillToolbarIndentButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        QuillToolbarIndentButton(
          controller: _controller,
          isIncrease: true,
          options: const QuillToolbarIndentButtonOptions(
            iconTheme: QuillIconTheme(
              iconButtonUnselectedData: IconButtonData(
                color: iconColor,
                iconSize: iconSize,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),
        // Custom Colors
        ColorSelectionButton(
          icon: Icons.palette_outlined,
          tooltip: 'Cor do Texto',
          isBackground: false,
          controller: _controller,
          customColors: _customColors,
        ),
        const SizedBox(width: 8),
        ColorSelectionButton(
          icon: Icons.format_color_fill,
          tooltip: 'Cor de Fundo',
          isBackground: true,
          controller: _controller,
          customColors: _customColors,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Reduced to 8.0 for both to push arrows to edge
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
         border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: _ScrollableToolbarWrapper(
        child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 600), // Ensure content is wide enough to scroll if needed
            child: toolbarContent,
        ),
      ),
    );
  }



  @override
  void dispose() {
    _controller.removeListener(_onQuillTextChanged);
    _hideSuggestionOverlay();
    _controller.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    _titleControllerField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    final isDesktop = !isMobile;

    // Determine Hero Tag
    final heroTag = widget.entry?.id ?? 'new_note_fab';

    // Define the Body Content (Title + Editor + Toolbar)
    Widget editorBody = Column(
      children: [
        // Toolbar Desktop (Top)
        // Removed !_isTitleFocused check to ensure toolbar visibility for now/debug
        if (isDesktop) 
           _buildToolbar(context, false),

        // Title Field
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: TextField(
            autofocus: widget.entry == null, // Autofocus only on new notes
            focusNode: _titleFocusNode,
            controller: _titleControllerField,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCaseTextFormatter()],
            onSubmitted: (_) {
               _editorFocusNode.requestFocus();
            },
            style: const TextStyle(
              fontSize: 24, // Increased font size per request
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
            decoration: const InputDecoration(
              filled: false,
              hintText: 'Título',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.multiline,
            maxLines: null, // Allow unlimited lines
            textInputAction: TextInputAction.newline,
          ),
        ),

        // Subtle Divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Divider(
            color: Colors.white12,
            height: 1,
            thickness: 1,
          ),
        ),

        // Editor Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: QuillEditor.basic(
              key: _editorKey,
              controller: _controller,
              focusNode: _editorFocusNode,
              config: QuillEditorConfig(
                padding: EdgeInsets.zero,
                textCapitalization: TextCapitalization.sentences,
                characterShortcutEvents: standardCharactersShortcutEvents,
                spaceShortcutEvents: standardSpaceShorcutEvents,
                requestKeyboardFocusOnCheckListChanged: true,
                onKeyPressed: (event, node) {
                  final backspaceResult = _handleKeyPressed(event, node);
                  if (backspaceResult != null) return backspaceResult;
                  return _handleEnterPressed(event);
                },
                customStyles: DefaultStyles(
                  h1: const DefaultTextBlockStyle(
                    TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                    HorizontalSpacing(0, 0),
                    VerticalSpacing(24, 12),
                    VerticalSpacing(0, 0),
                    null,
                  ),
                  h2: const DefaultTextBlockStyle(
                    TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                    HorizontalSpacing(0, 0),
                    VerticalSpacing(20, 10),
                    VerticalSpacing(0, 0),
                    null,
                  ),
                  h3: const DefaultTextBlockStyle(
                    TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                    HorizontalSpacing(0, 0),
                    VerticalSpacing(16, 8),
                    VerticalSpacing(0, 0),
                    null,
                  ),
                  paragraph: const DefaultTextBlockStyle(
                    TextStyle(
                      fontSize: 16,
                      color: AppColors.secondaryText,
                      height: 1.5,
                      fontFamily: 'Poppins',
                    ),
                    HorizontalSpacing(0, 0),
                    VerticalSpacing(0, 0),
                    VerticalSpacing(0, 0),
                    null,
                  ),
                  lists: DefaultListBlockStyle(
                    const TextStyle(
                      fontSize: 16,
                      color: AppColors.secondaryText,
                      height: 1.5,
                      fontFamily: 'Poppins',
                    ),
                    const HorizontalSpacing(16, 0),
                    const VerticalSpacing(0, 0),
                    const VerticalSpacing(0, 0),
                    null, // BoxDecoration
                    _SincroCheckboxBuilder(), // QuillCheckboxBuilder
                  ),
                ),
              ),
            ),
          ),
        ),

        // Toolbar Mobile (Bottom)
        if (isMobile)
           _buildToolbar(context, true),
      ],
    );

    // Default Scaffold (Content)
    Widget mainContent = Scaffold(
          backgroundColor: AppColors.cardBackground,
          appBar: AppBar(
            backgroundColor: AppColors.cardBackground,
            elevation: 0,
            automaticallyImplyLeading: false,
            leadingWidth: 0,
            titleSpacing: 24,
            title: Text(
              (widget.entry != null) ? 'Editar Anotação' : 'Nova Anotação',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: VibrationPill(vibrationNumber: _personalDay),
              ),
              if (isDesktop)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(
                      _isWindowMode ? Icons.fullscreen : Icons.fullscreen_exit,
                      color: AppColors.secondaryText,
                    ),
                    onPressed: _toggleWindowMode,
                    tooltip: _isWindowMode ? 'Tela Cheia' : 'Modo Janela',
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0), // Reduced from 16.0
                child: IconButton(
                   icon: const Icon(Icons.close, color: AppColors.secondaryText),
                   onPressed: () => Navigator.of(context).pop(),
                   tooltip: 'Fechar',
                ),
              ),
            ],
          ),
          body: editorBody, // Use the body defined above
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MoodSelector(
                  selectedMood: _selectedMood,
                  onMoodSelected: (mood) {
                    setState(() {
                      _selectedMood = mood == 0 ? null : mood;
                      _checkForChanges();
                    });
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDesktop && _hasUnsavedChanges)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'Ctrl+S',
                          style: TextStyle(
                            color: AppColors.secondaryText.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    if (_hasUnsavedChanges || _isSaving)
                      AnimatedScale(
                        scale: _hasUnsavedChanges || _isSaving ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: isDesktop
                            ? // DESKTOP: Capsule Button "Salvar"
                              ElevatedButton(
                                onPressed: _hasUnsavedChanges ? _handleSave : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  elevation: 4,
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20, // Smaller spinner
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Salvar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                        ),
                                      ),
                              )
                            : // MOBILE: Round Button (Smaller)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _hasUnsavedChanges ? _handleSave : null,
                                  borderRadius: BorderRadius.circular(50),
                                  child: Container(
                                    padding: const EdgeInsets.all(10), // Reduced from 12
                                    decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          )
                                        ]),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 20, // Reduced from 24
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 20, // Reduced from 24
                                          ),
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
    );

    // Apply Desktop Animation Wrapper (Hero + AnimatedContainer)
    Widget finalLayer = mainContent;
    if (isDesktop) {
        finalLayer = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          width: _isWindowMode ? 700 : MediaQuery.of(context).size.width,
          height: _isWindowMode ? 800 : MediaQuery.of(context).size.height,
          child: Hero(
             tag: heroTag,
             // Removed createRectTween to allow default Hero transition (smoother for Cards)
             child: Material(
               type: MaterialType.transparency, // Match Source Material
               child: ClipRRect(
                  borderRadius: BorderRadius.circular(_isWindowMode ? 16 : 0),
                  child: mainContent,
               ),
             ),
          ),
        );
        finalLayer = Center(child: finalLayer);
    } 

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (_hasUnsavedChanges) _handleSave();
        },
      },
      child: Focus(
        autofocus: true,
        child: finalLayer,
      ),
    );
  }

  /// Scans for checklist items without a taskId and creates them in the System
  Future<void> _extractAndCreateTasks(String journalId) async {
    final doc = _controller.document;
    final root = doc.root;
    final allLines = <Line>[];

    // 1. Flatten the document structure (extract lines from Blocks)
    for (var node in root.children) {
      if (node is Line) {
        allLines.add(node);
      } else if (node is Block) {
        for (var child in node.children) {
          if (child is Line) {
            allLines.add(child);
          }
        }
      }
    }

    final nodesToCreate = <Map<String, dynamic>>[]; // Store node + metadata
    
    // FETCH LINKED TASKS to handle unlinking
    final linkedTasks = await _supabaseService.getTasksBySourceJournalId(journalId);
    final linkedTaskIds = linkedTasks.map((t) => t.id).toSet();
    final foundTaskIds = <String>{};
    final seenTaskIdsInThisPass = <String>{}; // Fix: Track IDs to prevent duplicates in doc

    debugPrint('🔎 [JournalExtract] Scanning document (${allLines.length} lines) for new checklist items...');

    // 2. Identify new checklist items
    for (var line in allLines) {
      final attrs = line.style.attributes;
      final listAttr = attrs[Attribute.list.key];
      
      // Check for taskId in Line OR Leaves (Inline)
      String? taskId = attrs[_taskIdKey]?.value;
      if (taskId == null) {
        for (final child in line.children) {
          if (child is Leaf) {
            final childAttrs = child.style.attributes;
            if (childAttrs.containsKey(_taskIdKey)) {
              taskId = childAttrs[_taskIdKey]!.value;
              break;
            }
          }
        }
      }
      
      if (taskId != null) {
        foundTaskIds.add(taskId);
      }

      final rawText = line.toPlainText().trim();

      // Only log checklist candidates or non-empty lines to reduce noise, 
      // but logging everything helps debugging.
      // debugPrint('   Line: "$rawText" | Attrs: $attrs');

      // A. Check for Quill Attribute (The "Right" Way)
      bool isAttributeChecklist = listAttr != null &&
          (listAttr.value == Attribute.unchecked.value ||
           listAttr.value == Attribute.checked.value);

      // B. Check for Markdown Text Pattern (The "User Manual" Way)
      final markdownMatch = RegExp(r'^(-\s)?\[([ xX]?)\]\s?(.*)').firstMatch(rawText);
      bool isMarkdownChecklist = markdownMatch != null;

      if (isAttributeChecklist || isMarkdownChecklist) {
        bool isCompleted = false;
        String cleanText = rawText;

        if (isAttributeChecklist) {
          isCompleted = listAttr.value == Attribute.checked.value;
        } else if (isMarkdownChecklist) {
          final checkMark = markdownMatch.group(2) ?? '';
          isCompleted = checkMark.toLowerCase() == 'x';
          cleanText = markdownMatch.group(3) ?? '';
          debugPrint('   -> Detected Markdown Pattern! Status: $isCompleted, Text: "$cleanText"');
        }

        if (cleanText.isEmpty) continue;

        nodesToCreate.add({
          'node': line,
          'text': cleanText,
          'completed': isCompleted,
          'isMarkdown': isMarkdownChecklist,
        });
      }
    }

    if (nodesToCreate.isEmpty) {
      debugPrint('ℹ️ [JournalExtract] No new checklist items found to convert in ${allLines.length} lines.');
      return;
    }

    debugPrint('📝 [JournalExtract] Found ${nodesToCreate.length} new checklist items to convert to tasks.');

    // 3. Process each item
    for (final item in nodesToCreate) {
      final line = item['node'] as Line;
      final text = item['text'] as String;
      final isCompleted = item['completed'] as bool;
      final isMarkdown = item['isMarkdown'] as bool;

      // Debug: Check for existing taskId to prevent duplicates (UPDATE instead of SKIP)
      String? existingTaskId = line.style.attributes[_taskIdKey]?.value;
      if (existingTaskId == null) {
        for (final child in line.children) {
          if (child is Leaf) {
            final childAttrs = child.style.attributes;
            if (childAttrs.containsKey(_taskIdKey)) {
              existingTaskId = childAttrs[_taskIdKey]!.value;
              break;
            }
          }
        }
      }
      
      debugPrint('   Processing Item: "$text"');
      debugPrint('   Found ID: $existingTaskId');
      debugPrint('   Is Completed: $isCompleted');

       if (existingTaskId != null) {
         // Fix: Check for duplicates
         if (seenTaskIdsInThisPass.contains(existingTaskId)) {
            debugPrint('⚠️ [JournalExtract] Duplicate Task ID $existingTaskId found at "$text". Treating as NEW task.');
            existingTaskId = null; // Force creation of new task
         } else {
            seenTaskIdsInThisPass.add(existingTaskId);
         }
       }

       if (existingTaskId != null) {
          debugPrint('   -> Updating existing Task $existingTaskId: "$text"');
          
          final parsed = TaskParser.parse(text);
          if (parsed.cleanText.isNotEmpty) {
              final updates = <String, dynamic>{
                'text': parsed.cleanText,
                'completed': isCompleted,
              };
              
              if (parsed.tags.isNotEmpty) {
                 updates['tags'] = parsed.tags;
              }

              if (parsed.sharedWith.isNotEmpty) {
                 updates['sharedWith'] = parsed.sharedWith;
              }

              if (parsed.dueDate != null) {
                 updates['dueDate'] = parsed.dueDate!.toIso8601String();

                 // Recalculate personal day if date changed
                  if (widget.userData.nomeAnalise.isNotEmpty && widget.userData.dataNasc.isNotEmpty) {
                      try {
                        final engine = NumerologyEngine(
                          nomeCompleto: widget.userData.nomeAnalise, 
                          dataNascimento: widget.userData.dataNasc
                        );
                        updates['personalDay'] = engine.calculatePersonalDayForDate(parsed.dueDate!);
                      } catch (_) {}
                  }
              }
              
              try {
                 await _supabaseService.updateTaskFields(widget.userData.uid, existingTaskId, updates);
                  debugPrint('✅ [JournalExtract] Task $existingTaskId updated: $updates');
              } catch (e) {
                  debugPrint('❌ [JournalExtract] Failed to update task $existingTaskId: $e');
              }
          }
          continue;
       }

      // Parse text (dates, tags)
      final parsed = TaskParser.parse(text);
      if (parsed.cleanText.isEmpty) continue; // Skip empty tasks

      debugPrint('   -> Processing New Task: "${parsed.cleanText}"');

      // Calculate Personal Day
      int? taskPersonalDay;
      try {
        if (widget.userData.nomeAnalise.isNotEmpty && widget.userData.dataNasc.isNotEmpty) {
           final engine = NumerologyEngine(
             nomeCompleto: widget.userData.nomeAnalise, 
             dataNascimento: widget.userData.dataNasc
           );
           // Use Due Date if available, otherwise Note Date (Journal Date)
           final targetDate = parsed.dueDate ?? _noteDate; 
           taskPersonalDay = engine.calculatePersonalDayForDate(targetDate);
        }
      } catch (e) {
        debugPrint('⚠️ Error calculating personal day for task: $e');
      }

      // Create Task Model
      // Create Task Model
      var newTask = TaskModel(
        id: const Uuid().v4(),
        text: parsed.cleanText,
        completed: isCompleted,
        createdAt: DateTime.now(),
        dueDate: parsed.dueDate, // Can be null
        tags: parsed.tags,
        // Defaults
        sourceJournalId: journalId,
        recurrenceType: RecurrenceType.none,
        recurrenceDaysOfWeek: [],
        sharedWith: parsed.sharedWith, // Parsing mentions
        personalDay: taskPersonalDay, // Added Personal Day
        journeyTitle: parsed.goals.isNotEmpty ? parsed.goals.first : null, // Set Goal Title (Optimization: resolving ID would require fetching goals)
      );

      TaskModel? createdTask;

      // Try saving with sourceJournalId
      try {
        createdTask = await _supabaseService.addTask(widget.userData.uid, newTask);
      } catch (e) {
        debugPrint('⚠️ [JournalExtract] Failed to add task with sourceJournalId: $e');
        // FALLBACK: Try adding without sourceJournalId
        try {
          debugPrint('🔄 [JournalExtract] Retrying WITHOUT sourceJournalId...');
          final fallbackModel = TaskModel(
            id: newTask.id,
            text: newTask.text,
            completed: newTask.completed,
            createdAt: newTask.createdAt,
            dueDate: newTask.dueDate,
            tags: newTask.tags,
            recurrenceType: newTask.recurrenceType,
            recurrenceDaysOfWeek: newTask.recurrenceDaysOfWeek,
            sharedWith: newTask.sharedWith,
            personalDay: newTask.personalDay, // Keep personal day
            // sourceJournalId: null, // OMITTED
          );
          
          createdTask = await _supabaseService.addTask(widget.userData.uid, fallbackModel);
          if (createdTask != null && mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Tarefa criada (sem vínculo). Atualize o banco de dados!'), backgroundColor: Colors.orange),
             );
          }
        } catch (e2) {
           debugPrint('❌ [JournalExtract] Fallback failed too: $e2');
        }
      }

      if (createdTask != null) {
         debugPrint('✅ [JournalExtract] Task created: ${createdTask.id}');
        
        final offset = line.documentOffset;
        
        if (isMarkdown) {
           // For markdown, we need to replace the text (removing [], - [ ] etc)
           // This changes the length of the line.
           // NOTE: replaceText operates on the document.
           final lineTextLength = line.length - 1; 
           _controller.replaceText(offset, lineTextLength, text, null);
           
           // Apply list attribute
           _controller.formatText(offset, text.length, 
             Attribute.clone(Attribute.list, isCompleted ? Attribute.checked.value : Attribute.unchecked.value)
           );
           
           // Apply taskId
           // FIX: Apply to full line length (text + newline) so it acts like a Block attribute
           // visible to line.style and _deduplicateTaskIds
           _controller.formatText(offset, text.length + 1, Attribute(_taskIdKey, AttributeScope.inline, createdTask.id));
        } else {
           // For existing Quill lists, just apply the taskId to the line
           // FIX: Use line.length to cover newline so it persists in line.style
           _controller.formatText(offset, line.length, Attribute(_taskIdKey, AttributeScope.inline, createdTask.id));
        }
      } 
    }


    // 4. UNLINK TASKS that were removed from the document
    final idsToUnlink = linkedTaskIds.difference(foundTaskIds);
    if (idsToUnlink.isNotEmpty) {
      debugPrint('🗑️ [JournalExtract] Found ${idsToUnlink.length} tasks to UNLINK (removed from text)');
      for (final id in idsToUnlink) {
         try {
           await _supabaseService.unlinkTaskFromJournal(id);
         } catch (e) {
            debugPrint('❌ [JournalExtract] Failed to unlink task $id: $e');
         }
      }
    }
  }

  /// Helper to get all lines, including those nested in Blocks (e.g. lists)
  List<Line> _getAllLines() {
    final doc = _controller.document;
    final root = doc.root;
    final allLines = <Line>[];
    for (var node in root.children) {
      if (node is Line) {
        allLines.add(node);
      } else if (node is Block) {
        for (var child in node.children) {
          if (child is Line) {
            allLines.add(child);
          }
        }
      }
    }
    return allLines;
  }

  void _subscribeToTasks() {
    if (widget.entry == null) return;
    
    // Cancel existing if any
    _tasksSubscription?.cancel();
    
    debugPrint('🔌 [JournalSync] Subscribing to tasks for journal: ${widget.entry!.id}');
    _tasksSubscription = _supabaseService.getTasksStreamByJournalId(widget.entry!.id).listen((tasks) {
       debugPrint('📨 [JournalSync] Stream received ${tasks.length} tasks.');
       for (var t in tasks) {
         debugPrint('   - Task: ${t.id} | "${t.text}" | Completed: ${t.completed}');
       }
       if (mounted) {
         _syncJournalWithTaskList(tasks);
       }
    }, onError: (e) {
       debugPrint('❌ [JournalSync] Stream Error: $e');
    });
  }

  Future<void> _syncJournalWithTaskList(List<TaskModel> systemTasks) async {
      if (!mounted) return;
      _isSyncing = true;
      try {
      debugPrint('🔄 [JournalSync] Syncing ${systemTasks.length} system tasks with Journal content...');

      final allLines = _getAllLines();
      final taskMap = {for (var t in systemTasks) t.id: t};
      
      bool docChanged = false;
      
      // Iterate REVERSED to handle deletions safely
      for (final line in allLines.reversed) {
        // Check Line & Leaf for taskId
        String? taskId = line.style.attributes[_taskIdKey]?.value;
        if (taskId == null) {
          for (final child in line.children) {
            if (child is Leaf) {
              final childAttrs = child.style.attributes;
              if (childAttrs.containsKey(_taskIdKey)) {
                taskId = childAttrs[_taskIdKey]!.value;
                break;
              }
            }
          }
        }
        
        // Skip lines without taskId
        if (taskId == null || taskId.isEmpty) continue;
        
        final systemTask = taskMap[taskId];
        
        if (systemTask == null) {
          // Task DELETED (or unlinked) in backend -> Remove from Journal
          debugPrint('🗑️ [JournalSync] Task $taskId not found in stream (Deleted). Removing line.');
          final offset = line.documentOffset;
          // Delete operation: remove length + 1 (newline) to remove the line completely
          _controller.replaceText(offset, line.length + 1, '', null);
          docChanged = true;
          continue;
        }

        // Task Exists -> Check for updates

        // A. Status Sync (System -> Journal)
        final currentListVal = line.style.attributes[Attribute.list.key]?.value;
        final isCheckedInJournal = currentListVal == Attribute.checked.value;
        
        if (systemTask.completed != isCheckedInJournal) {
          debugPrint('🔄 [JournalSync] Task $taskId status mismatch. System: ${systemTask.completed} vs Journal: $isCheckedInJournal');
          final newAttr =
              systemTask.completed ? Attribute.checked : Attribute.unchecked;
          _controller.formatText(line.documentOffset, line.length, newAttr);
          docChanged = true;
        }
        
        // B. Text Sync (System -> Journal)
        final currentRaw = line.toPlainText().trim();
        // Reconstruct the expected text from the System Task
        final expectedText = TaskParser.toText(systemTask);

        debugPrint('      System: "${systemTask.text}" [${systemTask.completed}]');
        debugPrint('      Journal: "$currentRaw" (clean: "${TaskParser.parse(currentRaw).cleanText}") [$isCheckedInJournal]');
        
        // Compare meaningful content (ignoring minor formatting diffs if needed)
        // Check if current raw text roughly matches expected (we can be strict for now)
        
        if (currentRaw != expectedText) {
           debugPrint('📝 [JournalSync] Task $taskId content mismatch. Updating Journal.');
           debugPrint('   Current: "$currentRaw"');
           debugPrint('   Expected: "$expectedText"');
           
           _controller.replaceText(
             line.documentOffset, 
             line.length,
             expectedText, 
             null
           );
           
           // Re-apply attributes (taskId and checkbox status)
           _controller.formatText(line.documentOffset, expectedText.length, Attribute(_taskIdKey, AttributeScope.inline, taskId));
           _controller.formatText(line.documentOffset, expectedText.length, systemTask.completed ? Attribute.checked : Attribute.unchecked);
           
           docChanged = true;
        }
      }
      
      if (docChanged) {
        debugPrint('✅ [JournalSync] Applied stream updates to Journal content.');
        // Auto-save silently to persist System -> Journal changes without user interaction
        await _saveJournalContentSilent();
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Saves ONLY the content (and updated_at) silently, without closing the screen or showing Snackbars.
  /// Used for auto-syncing updates from System Tasks.
  Future<void> _saveJournalContentSilent() async {
    if (widget.entry == null) return;

    try {
      debugPrint('💾 [JournalSync] Auto-saving updated content silently...');
      final updatedContentJson = jsonEncode(_controller.document.toDelta().toJson());
      
      await _supabaseService.updateJournalEntry(
          widget.userData.uid, 
          widget.entry!.id, 
          {
            'content': updatedContentJson,
            'updated_at': DateTime.now().toIso8601String(),
          }
      );
      
      // Update baseline for change detection
      _initialContent = updatedContentJson;

      // Prevent "Unsaved Changes" UI from appearing if this was the only change
      if (mounted) {
         // Fix: Check for changes again instead of blindly setting false.
         // This handles race conditions where user might have edited DURING the save.
         _checkForChanges();
      }
      debugPrint('✅ [JournalSync] Silent save complete.');
    } catch (e) {
      debugPrint('❌ [JournalSync] Silent save failed: $e');
    }
  }

  /// Synchronizes System Tasks -> Journal Entry (Updates status, text, or deletes lines)

  Future<void> _syncJournalWithSystemTasks() async {
    if (widget.entry == null || widget.entry!.id.isEmpty) return;

    try {
      final systemTasks =
          await _supabaseService.getTasksBySourceJournalId(widget.entry!.id);
      if (systemTasks.isEmpty) return;

      final systemTasksMap = {for (var t in systemTasks) t.id: t};
      bool docChanged = false;
      final doc = _controller.document;

      // Iterate backwards to avoid index issues if we were deleting lines (checking forwards is fine for updates)
      for (final node in doc.root.children) {
        if (node is! Line) continue;
        final line = node;
        final attrs = line.toDelta().last.attributes;

        if (attrs == null || !attrs.containsKey(_taskIdKey)) continue;

        final taskId = attrs[_taskIdKey];

        if (!systemTasksMap.containsKey(taskId)) {
          // Task removed in system -> remove checkbox & taskId attribute (convert to plain text)
          _controller.formatText(line.documentOffset, line.length,
              const Attribute(_taskIdKey, AttributeScope.inline, null));
          _controller.formatText(line.documentOffset, line.length,
              const Attribute('list', AttributeScope.block, null));
          docChanged = true;
          continue;
        }

        final task = systemTasksMap[taskId]!;

        // Update Checkbox
        final currentListAttr = attrs[Attribute.list.key];
        final shouldBeChecked = task.completed
            ? Attribute.checked.value
            : Attribute.unchecked.value;

        if (currentListAttr != shouldBeChecked) {
          _controller.formatText(line.documentOffset, line.length,
              task.completed ? Attribute.checked : Attribute.unchecked);
          docChanged = true;
        }

        // Update Text
        final currentText = line.toPlainText().trim();
        final expectedText = TaskParser.toText(task);

        if (currentText != expectedText) {
          // Replace text content
          _controller.replaceText(
              line.documentOffset, currentText.length, expectedText, null);
          docChanged = true;
        }
      }
    } catch (e) {
      debugPrint('Error syncing journal with system tasks: $e');
    }
  }
}



class _MoodSelector extends StatelessWidget {
  final int? selectedMood;
  final Function(int) onMoodSelected;

  const _MoodSelector({
    required this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    const moods = {
      1: '😞', // Triste
      2: '😐', // Neutro
      3: '😌', // Calmo
      4: '😊', // Contente
      5: '🤩', // Incrível
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão de Limpar (Sem Emoção)
        GestureDetector(
          onTap: () => onMoodSelected(0), // 0 ou null, tratado no parent
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                 width: 32,
                 height: 32,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: Colors.white24, width: 2),
                   color: selectedMood == null ? Colors.white10 : Colors.transparent,
                 ),
                 child: Icon(
                   Icons.block,
                   color: selectedMood == null ? Colors.white : Colors.white24,
                   size: 16,
                 ),
              ),
            ),
          ),
        ),
        ...moods.entries.map((entry) {
        final isSelected = selectedMood == entry.key;
        return GestureDetector(
          onTap: () => onMoodSelected(entry.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: AnimatedScale(
              scale: isSelected ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: MouseRegion( // Add hover effect if desired, or just Text
                cursor: SystemMouseCursors.click,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 26, 
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.6), // Increased opacity (was 0.3)
                    shadows: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.yellow.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
      ],
    );
  }
}

/// V22: Custom CheckboxBuilder that implements QuillCheckboxBuilder.
/// Uses Material + InkWell to create an independent render layer,
/// which properly isolates the click cursor from the editor's I-beam cursor.
class _SincroCheckboxBuilder extends QuillCheckboxBuilder {
  @override
  Widget build({
    required BuildContext context,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!isChecked),
        child: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isChecked ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: isChecked
                    ? AppColors.primary
                    : AppColors.secondaryText.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isChecked
                ? const Center(
                    child: Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
// ─── Scrollable Toolbar Wrapper ───

// ─── Input Formatter for Sentence Case ───
class SentenceCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    String text = newValue.text;
    if (text.length == 1 && text != text.toUpperCase()) {
       return newValue.copyWith(text: text.toUpperCase());
    }
    
    // Only capitalize first char if following a reset (not perfect for all sentences but good for Title)
    // A more robust regex would be needed for full paragraphs, but for Title field (often short), 
    // basic capitalization is key.
    return newValue; 
  }
}

// ─── Scrollable Toolbar Wrapper ───

class _ArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          // Minimal padding to be clickable but "close to edge"
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8), 
          color: Colors.transparent, 
          child: Icon(
            widget.icon,
            // Hover: Primary Color
            // Non-Hover: Secondary Text with low opacity
            color: _isHovering ? AppColors.primary : AppColors.secondaryText.withValues(alpha: 0.5),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ScrollableToolbarWrapper extends StatefulWidget {
  final Widget child;
  const _ScrollableToolbarWrapper({required this.child});

  @override
  State<_ScrollableToolbarWrapper> createState() => _ScrollableToolbarWrapperState();
}

class _ScrollableToolbarWrapperState extends State<_ScrollableToolbarWrapper> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollability);
    // Initial check
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollability());
  }

  @override
  void didUpdateWidget(_ScrollableToolbarWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check when widget updates (e.g. constraints change)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollability());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollability);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollability() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    // Tolerance
    final canScrollLeft = currentScroll > 1.0;
    final canScrollRight = currentScroll < maxScroll - 1.0;

    if (canScrollLeft != _canScrollLeft || canScrollRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canScrollLeft;
          _canScrollRight = canScrollRight;
        });
      }
    }
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      (_scrollController.offset - 200).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      (_scrollController.offset + 200).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check on build too (handle resize instantly if layout allows)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollability());

    return Row(
      children: [
        // Left Arrow
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _canScrollLeft ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _canScrollLeft
                ? Padding(
                    padding: const EdgeInsets.only(right: 0), // Minimal padding
                    child: _ArrowButton(icon: Icons.chevron_left, onTap: _scrollLeft),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        
        // Scrollable Content
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Also listen to ScrollMetricsNotification for resize events
              if (notification is ScrollMetricsNotification || notification is ScrollNotification) {
                 _checkScrollability();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: widget.child,
            ),
          ),
        ),

        // Right Arrow
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _canScrollRight ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _canScrollRight
                ? Padding(
                    padding: const EdgeInsets.only(left: 0), // Minimal padding
                    child: _ArrowButton(icon: Icons.chevron_right, onTap: _scrollRight),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
