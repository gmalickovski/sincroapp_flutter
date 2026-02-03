import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class ModernTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const ModernTimePicker({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
  });

  @override
  State<ModernTimePicker> createState() => _ModernTimePickerState();
}

class _ModernTimePickerState extends State<ModernTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  bool _isInputMode = false;

  final TextEditingController _hourInputController = TextEditingController();
  final TextEditingController _minuteInputController = TextEditingController();
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);

    _syncInputControllers();
  }

  void _syncInputControllers() {
    _hourInputController.text = _selectedHour.toString().padLeft(2, '0');
    _minuteInputController.text = _selectedMinute.toString().padLeft(2, '0');
  }

  void _updateTime() {
    widget.onTimeChanged(TimeOfDay(hour: _selectedHour, minute: _selectedMinute));
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourInputController.dispose();
    _minuteInputController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Digital Clock Display & Mode Switcher
        _buildDigitalClock(),
        
        const SizedBox(height: 24),

        // 2. Picker Area (Wheel or Input based on internal state, but here we keep wheel for visual picking)
        // The user want "Input Mode" visible. 
        // Actually the best UX here is: Big Clock IS the display. Below we show the Wheel.
        // Tapping the clock switches which wheel (Hour or Minute) is highlighted/active (if we want to go super fancy)
        // OR we just keep the two independent wheels as before but make the clock bigger.
        // The request says "deixar o campo de digitação visivel conforme o exemplo". 
        // The example shows a huge "21 : 37" and a dial below.
        // So I will show the Big Clock. Tapping it can optionally open a keyboard, but let's stick to the wheels below for now as it matches the "modern" look user seemed to like earlier, just refining the header.
        // WAIT, if the user says "campo de digitação visivel", maybe they want the KEYBOARD input?
        // "deixar o campo de digitação visivel conforme o exemplo da imagem 3". Image 3 shows a big "21 : 37" and a CLOCK FACE (Dial).
        // My `ModernTimePicker` uses Wheels. I should stick to Wheels but make the Header BIG and INTERACTIVE.
        // And maybe provide a button to switch to keyboard if needed, but the Big Text is key.
        
        SizedBox(
          height: 200,
          child: _isInputMode 
            ? _buildInputManual() // Only if user explicitly toggles to keyboard
            : _buildWheelMode(),
        ),
      ],
    );
  }

  Widget _buildDigitalClock() {
    final hourStr = _selectedHour.toString().padLeft(2, '0');
    final minuteStr = _selectedMinute.toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeDigit(hourStr, true),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            ":",
            style: TextStyle(
              fontSize: 56, 
              height: 1,
              fontWeight: FontWeight.bold, 
              color: AppColors.primaryText
            ),
          ),
        ),
        _buildTimeDigit(minuteStr, false),
        
        // Optional: Keyboard Toggle nearby if needed, but let's keep it clean
        // Maybe a small icon to the side? The previous one had it.
        const SizedBox(width: 16),
        IconButton(
           onPressed: () {
             setState(() {
               _isInputMode = !_isInputMode;
             });
           },
           icon: Icon(
             _isInputMode ? Icons.access_time_filled_rounded : Icons.keyboard,
             color: AppColors.primary,
             size: 28,
           ),
        ),
      ],
    );
  }

  Widget _buildTimeDigit(String value, bool isHour) {
    // If we were implementing "Tap to set mode", we would track _activeComponent (Hour/Minute)
    // For this implementation with Wheels, both are available simultaneously, so no "active" state needed really.
    // However, if we enter InputMode, we might want to highlight.
    
    return GestureDetector(
       onTap: () {
         // If we are in wheel mode, maybe scroll to it? Or just do nothing?
         // If in input mode, focus the right field.
         if (!_isInputMode) {
            setState(() => _isInputMode = true);
         }
       },
       child: Container(
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: _isInputMode ? AppColors.cardBackground : Colors.transparent, // Highlight if editable
           borderRadius: BorderRadius.circular(16),
           border: _isInputMode ? Border.all(color: AppColors.primary) : null,
         ),
         child: Text(
           value,
           style: const TextStyle(
             fontSize: 56,
             height: 1,
             fontWeight: FontWeight.bold,
             color: AppColors.primary, // Always primary for the "Big Clock" feel
           ),
         ),
       ),
    );
  }

  Widget _buildInputManual() {
     // A simpler input mode since the big clock is the display. 
     // Actually, if _isInputMode is true, the Big Clock IS the input?
     // Let's reuse the logic but make it nicer.
     // In _buildDigitalClock, I used Text. If Mode is Input, maybe I should use TextFields THERE?
     // No, let's keep it simple. If Input Mode is ON, we show the previous "Input Mode" UI (TextFields) INSTEAD of the Big Clock?
     // Or below it?
     
     // Let's align with the user request "image 3". Image 3 shows Big Clock AND Dial.
     // Since I have Wheels, I will show Big Clock AND Wheels.
     // And a button to switch to "Keyboard Input" which replaces Wheels with TextFields?
     
     // Let's use the EXISTING _buildInputMode as the "Manual" view.
     return _buildInputModeUI();
  }

  Widget _buildInputModeUI() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTextField(_hourInputController, _hourFocus, (val) {
           final h = int.tryParse(val);
           if (h != null && h >= 0 && h < 24) {
             setState(() => _selectedHour = h);
             _updateTime();
             if (val.length == 2) _minuteFocus.requestFocus();
           }
        }),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(":", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryText)),
        ),
        _buildTextField(_minuteInputController, _minuteFocus, (val) {
           final m = int.tryParse(val);
           if (m != null && m >= 0 && m < 60) {
             setState(() => _selectedMinute = m);
             _updateTime();
           }
        }),
      ],
    );
  }

  Widget _buildWheelMode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildWheel(
          controller: _hourController,
          itemCount: 24,
          onChanged: (val) {
            setState(() => _selectedHour = val);
            _updateTime();
          },
        ),
        const Text(
          ":",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        _buildWheel(
          controller: _minuteController,
          itemCount: 60,
          onChanged: (val) {
            setState(() => _selectedMinute = val);
            _updateTime();
          },
        ),
      ],
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 80,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 50,
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          HapticFeedback.selectionClick();
          onChanged(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) {
             // In the wheel, we highlight the selected item
            final isSelectedState = (itemCount == 24 ? _selectedHour : _selectedMinute) == index;
            
            return Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: isSelectedState ? 28 : 22,
                  color: isSelectedState ? AppColors.primary : AppColors.tertiaryText,
                  fontWeight: isSelectedState ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  // Reusing the TextField builder from previous code, integrated here
  Widget _buildTextField(TextEditingController controller, FocusNode focus, ValueChanged<String> onChanged) {
    // ... (Same as before)
    final bool isFocused = focus.hasFocus;
    return Container(
      width: 90,
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? AppColors.primary : AppColors.border, 
          width: isFocused ? 2.0 : 1.0,
        ),
        boxShadow: isFocused ? [
          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
        ] : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focus,
        autofillHints: const [], // Prevent browser password save prompt
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
        style: const TextStyle(
          fontSize: 36, 
          fontWeight: FontWeight.bold, 
          color: AppColors.primaryText
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "00",
          hintStyle: TextStyle(color: AppColors.tertiaryText.withOpacity(0.3)),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
