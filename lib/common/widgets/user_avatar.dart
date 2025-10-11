import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? name;
  final double radius;

  const UserAvatar({
    super.key,
    this.name,
    this.radius = 18.0,
  });

  String get _initials {
    if (name == null || name!.isEmpty) return '';
    final names = name!.split(' ').where((n) => n.isNotEmpty).toList();
    if (names.length > 1) {
      return '${names.first[0]}${names.last[0]}'.toUpperCase();
    } else {
      return names.first.substring(0, 1).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryAccent.withOpacity(0.3),
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.primaryAccent,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
