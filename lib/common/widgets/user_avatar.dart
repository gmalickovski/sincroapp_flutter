// lib/common/widgets/user_avatar.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String firstName;
  final String lastName;
  final double radius;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.firstName,
    required this.lastName,
    this.radius = 20.0,
  });

  String get _initials {
    String firstInitial = firstName.isNotEmpty ? firstName[0] : '';
    String lastInitial = lastName.isNotEmpty ? lastName[0] : '';
    return '$firstInitial$lastInitial'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: AppColors.primary,
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary,
        child: Center(
          // *** CORREÇÃO APLICADA AQUI ***
          child: Text(
            _initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.8,
            ),
          ),
        ),
      );
    }
  }
}
