// lib/features/settings/presentation/tabs/integrations_settings_tab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class IntegrationsSettingsTab extends StatelessWidget {
  const IntegrationsSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_outlined, size: 60, color: AppColors.secondaryText),
          SizedBox(height: 16),
          Text(
            'Integrações em breve...',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Conecte o SincroApp com suas ferramentas favoritas.',
            style: TextStyle(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
