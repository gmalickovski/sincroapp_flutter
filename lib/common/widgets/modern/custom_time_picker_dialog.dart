import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

enum _TimePickerMode { hour, minute }

class CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePickerDialog({
    super.key, 
    required this.initialTime,
  });

  @override
  State<CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late TimeOfDay _selectedTime;
  _TimePickerMode _mode = _TimePickerMode.hour;
  
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late FocusNode _hourFocus;
  late FocusNode _minuteFocus;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
    
    _hourController = TextEditingController(text: _selectedTime.hour.toString().padLeft(2, '0'));
    _minuteController = TextEditingController(text: _selectedTime.minute.toString().padLeft(2, '0'));
    
    _hourFocus = FocusNode();
    _minuteFocus = FocusNode();
    
    _hourFocus.addListener(() {
      if (_hourFocus.hasFocus) {
        _handleModeChanged(_TimePickerMode.hour);
        _hourController.selection = TextSelection(baseOffset: 0, extentOffset: _hourController.text.length);
      }
    });
    
    _minuteFocus.addListener(() {
      if (_minuteFocus.hasFocus) {
        _handleModeChanged(_TimePickerMode.minute);
        _minuteController.selection = TextSelection(baseOffset: 0, extentOffset: _minuteController.text.length);
      }
    });
  }
  
  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _handleTimeChanged(TimeOfDay newTime) {
    setState(() {
      _selectedTime = newTime;
    });
    // Update text fields if they are not focused (i.e. change came from Dial)
    
    if (!_hourFocus.hasFocus) {
      _hourController.text = newTime.hour.toString().padLeft(2, '0');
    }
    if (!_minuteFocus.hasFocus) {
      _minuteController.text = newTime.minute.toString().padLeft(2, '0');
    }
  }

  void _handleModeChanged(_TimePickerMode mode) {
    setState(() {
      _mode = mode;
    });
  }
  
  void _onHourChanged(String value) {
    final int? newHour = int.tryParse(value);
    if (newHour != null && newHour >= 0 && newHour < 24) {
      setState(() {
        _selectedTime = _selectedTime.replacing(hour: newHour);
      });
      if (value.length == 2) {
        _minuteFocus.requestFocus();
      }
    }
  }

  void _onMinuteChanged(String value) {
    final int? newMinute = int.tryParse(value);
    if (newMinute != null && newMinute >= 0 && newMinute < 60) {
      setState(() {
        _selectedTime = _selectedTime.replacing(minute: newMinute);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 312,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildTimeDisplay(),
            const SizedBox(height: 24),
            SizedBox(
              height: 280,
              child: _ClockDial(
                selectedTime: _selectedTime,
                mode: _mode,
                onTimeChanged: _handleTimeChanged,
                onModeChanged: (mode) {
                   _handleModeChanged(mode);
                   if (mode == _TimePickerMode.minute) {
                     // Optionally focus minute field? Usually annoying if Dialing. 
                   }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        const Text(
          "Selecione o horário",
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, color: AppColors.primary),
          onPressed: () => Navigator.pop(context, _selectedTime),
        ),
      ],
    );
  }

  Widget _buildTimeDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDisplayItem(_hourController, _hourFocus, _TimePickerMode.hour, _onHourChanged),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            ":",
            style: TextStyle(
              fontSize: 56,
              height: 1,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText.withOpacity(0.9),
            ),
          ),
        ),
        _buildDisplayItem(_minuteController, _minuteFocus, _TimePickerMode.minute, _onMinuteChanged),
      ],
    );
  }

  Widget _buildDisplayItem(
    TextEditingController controller, 
    FocusNode focusNode, 
    _TimePickerMode mode,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = _mode == mode;
    
    return GestureDetector(
      onTap: () {
        _handleModeChanged(mode);
        focusNode.requestFocus();
      },
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: TextStyle(
            fontSize: 56,
            height: 1,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primary : AppColors.primaryText,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ClockDial extends StatefulWidget {
  final TimeOfDay selectedTime;
  final _TimePickerMode mode;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final ValueChanged<_TimePickerMode>? onModeChanged; // Make optional

  const _ClockDial({
    required this.selectedTime,
    required this.mode,
    required this.onTimeChanged,
    this.onModeChanged,
  });

  @override
  State<_ClockDial> createState() => _ClockDialState();
}

class _ClockDialState extends State<_ClockDial> {
  // Logic to handle Pan/Tap
  
  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    _updateTimeFromOffset(details.localPosition, size);
  }
  
  void _handleTapUp(TapUpDetails details, Size size) {
    _updateTimeFromOffset(details.localPosition, size);
    // Auto advance if needed, e.g. from Hour to Minute after tap
    if (widget.mode == _TimePickerMode.hour && widget.onModeChanged != null) {
       // Debounce slightly or just switch
       Future.delayed(const Duration(milliseconds: 300), () {
          widget.onModeChanged!(_TimePickerMode.minute);
       });
    }
  }

  void _updateTimeFromOffset(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    // Angle in radians. 
    // At top (12/00): -pi/2. At right (3/15): 0. At bottom: pi/2. At left: pi/-pi.
    double angle = atan2(dy, dx);
    
    // Convert to clock-wise degrees starting from 12 o'clock (Top)
    angle += pi / 2;
    if (angle < 0) angle += 2 * pi;
    
    if (widget.mode == _TimePickerMode.hour) {
       _updateHour(angle, dx * dx + dy * dy, size.width / 2);
    } else {
       _updateMinute(angle);
    }
  }

  void _updateHour(double angle, double distSq, double radius) {
    // Check if inner or outer ring
    // Standard Material: Outer radius ~ R, Inner radius ~ 0.7R (approx)
    // DistSq is squared distance.
    final double dist = sqrt(distSq);
    final bool isInner = dist < radius * 0.70; 
    
    // 12 hours segments -> 30 degrees (pi/6) each.
    // Round to nearest segment
    int sector = (angle / (pi / 6)).round() % 12;
    // Sector 0 = 12, Sector 1 = 1, etc.
    // If it's sector 0, it means 12 or 00.
    
    int hour;
    if (isInner) {
      // Inner ring: 13, 14, ..., 00
      if (sector == 0) hour = 0;
      else hour = sector + 12;
    } else {
      // Outer ring: 1, 2, ..., 12
      if (sector == 0) hour = 12; 
      else hour = sector;
    }
    
    // Clamp 0-23 just in case
    if (hour == 24) hour = 0; // Should handle cleanly
    
    if (hour != widget.selectedTime.hour) {
       HapticFeedback.selectionClick();
       widget.onTimeChanged(widget.selectedTime.replacing(hour: hour));
    }
  }

  void _updateMinute(double angle) {
    // 60 minutes -> 6 degrees (pi/30) each.
    int minute = (angle / (pi / 30)).round() % 60;
    
    if (minute != widget.selectedTime.minute) {
       HapticFeedback.selectionClick();
       widget.onTimeChanged(widget.selectedTime.replacing(minute: minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: (d) => _handlePanUpdate(d, size),
          onTapUp: (d) => _handleTapUp(d, size),
          child: CustomPaint(
            size: size,
            painter: _DialPainter(
              time: widget.selectedTime,
              mode: widget.mode,
            ),
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  final TimeOfDay time;
  final _TimePickerMode mode;
  
  _DialPainter({required this.time, required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    
    // Draw Background
    final bgPaint = Paint()..color = AppColors.background; 
    canvas.drawCircle(center, radius, bgPaint);
    
    // Draw Numbers & Selector based on Mode
    if (mode == _TimePickerMode.hour) {
      _drawHours(canvas, center, radius);
    } else {
      _drawMinutes(canvas, center, radius);
    }
    
    // Draw Center Dot
    canvas.drawCircle(center, 4, Paint()..color = AppColors.primary);
  }
  
  void _drawHours(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final outerR = radius * 0.82;
    final innerR = radius * 0.55;
    
    final selectedHour = time.hour;
    
    // Selector
    double selectorAngle;
    double selectorLen;
    
    if (selectedHour == 0 || selectedHour > 12) {
       // Inner
       selectorLen = innerR;
       int sector = (selectedHour == 0) ? 0 : (selectedHour - 12);
       selectorAngle = (sector * 30) * pi / 180;
    } else {
       // Outer
       selectorLen = outerR;
       int sector = (selectedHour == 12) ? 0 : selectedHour; 
       selectorAngle = (sector * 30) * pi / 180;
    }
    
    _drawSelector(canvas, center, selectorAngle, selectorLen);

    // Draw Numbers
    final styleNormal = const TextStyle(color: Colors.white, fontSize: 16);
    final styleSelected = const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold);
    final styleSmall = const TextStyle(color: AppColors.secondaryText, fontSize: 13);
    
    // Outer: 1-12
    for (int i = 1; i <= 12; i++) {
        final angle = (i % 12) * 30 * pi / 180;
        final x = center.dx + outerR * sin(angle);
        final y = center.dy - outerR * cos(angle);
        
        final isSelected = (selectedHour == i) || (selectedHour == 12 && i==12); 
        
        textPainter.text = TextSpan(
           text: i.toString(), 
           style: isSelected ? styleSelected : styleNormal
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
    
    // Inner: 13-00
    for (int i = 1; i <= 12; i++) {
        final displayNum = (i == 12) ? "00" : "${i + 12}";
        final value = (i == 12) ? 0 : (i + 12);
        
        final angle = (i % 12) * 30 * pi / 180;
        final x = center.dx + innerR * sin(angle);
        final y = center.dy - innerR * cos(angle);
        
        final isSelected = (selectedHour == value);
        
        textPainter.text = TextSpan(
           text: displayNum, 
           style: isSelected ? styleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold) : styleSmall
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }
  
  void _drawMinutes(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final r = radius * 0.82;
    
    // Selector
    // 0 is top.
    final angle = (time.minute * 6) * pi / 180;
    _drawSelector(canvas, center, angle, r);
    
    final style = const TextStyle(color: Colors.white, fontSize: 16);
    final styleSelected = const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold);

    // Draw 00, 05, 10...
    for (int i = 0; i < 60; i += 5) {
       final a = i * 6 * pi / 180;
       final x = center.dx + r * sin(a);
       final y = center.dy - r * cos(a);
       
       final isSelected = (time.minute == i);
       
       textPainter.text = TextSpan(
         text: i.toString().padLeft(2, '0'), 
         style: isSelected ? styleSelected : style
       );
       textPainter.layout();
       textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  void _drawSelector(Canvas canvas, Offset center, double angle, double length) {
    // Line
    final endX = center.dx + length * sin(angle);
    final endY = center.dy - length * cos(angle);
    final endPos = Offset(endX, endY);
    
    final paintLine = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, endPos, paintLine);
    
    final paintCircle = Paint()..color = AppColors.primary;
    canvas.drawCircle(endPos, 16, paintCircle); 
    
    // Small dot for minutes not on 5-step
    if (mode == _TimePickerMode.minute && time.minute % 5 != 0) {
       canvas.drawCircle(endPos, 2, Paint()..color = Colors.white);
    }
  }
  
  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
     return oldDelegate.time != time || oldDelegate.mode != mode;
  }
}
