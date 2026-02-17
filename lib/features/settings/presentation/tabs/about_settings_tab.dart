import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../common/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSettingsTab extends StatefulWidget {
  const AboutSettingsTab({super.key});

  @override
  State<AboutSettingsTab> createState() => _AboutSettingsTabState();
}

class _AboutSettingsTabState extends State<AboutSettingsTab> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/icon_app2.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.apps,
                        size: 50,
                        color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sincro App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versão ${_packageInfo.version} (Build ${_packageInfo.buildNumber})',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.tertiaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Sobre'),
        _buildInfoTile(
          title: 'Site Oficial',
          subtitle: 'sincroapp.com.br',
          icon: Icons.public,
          onTap: () => _launchUrl('https://sincroapp.com.br'),
        ),
        _buildInfoTile(
          title: 'Termos de Uso',
          subtitle: 'Leia via navegador',
          icon: Icons.description_outlined,
          onTap: () => _launchUrl('https://sincroapp.com.br/termos'),
        ),
        _buildInfoTile(
          title: 'Política de Privacidade',
          subtitle: 'Leia via navegador',
          icon: Icons.privacy_tip_outlined,
          onTap: () => _launchUrl('https://sincroapp.com.br/privacidade'),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Desenvolvimento'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Desenvolvido com ❤️ e IA por Studio MLK.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            '© ${DateTime.now().year} Sincro App. Todos os direitos reservados.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.tertiaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.tertiaryText,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.tertiaryText, fontSize: 13),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.tertiaryText),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
