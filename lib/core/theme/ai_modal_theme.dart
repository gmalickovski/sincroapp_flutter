import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

/// Unified theme and components for AI Analysis Modals
/// Used by: ProfessionalAptitudeModal, LoveCompatibilityModal
class AIModalTheme {
  AIModalTheme._(); // Private constructor

  // === COLORS ===
  static const Color backgroundDark = Color(0xFF1A2F38);
  static const Color cyanAccent = Colors.cyan;
  static const Color pinkAccent = Color(0xFFEC4899);

  // === SPACING ===
  static const EdgeInsets desktopPadding = EdgeInsets.all(24);
  static const EdgeInsets mobilePadding = EdgeInsets.all(20);
  static const double borderRadius = 24.0;
  static const double inputBorderRadius = 16.0;

  // === MODAL DECORATION ===
  static BoxDecoration get modalDecoration => BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
      );

  // === HEADER ===
  /// Builds a standardized modal header with title, icon, and close/back button
  static Widget buildHeader({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onClose,
    VoidCallback? onBack,
    bool showBackButton = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back button (left)
          if (showBackButton && onBack != null)
            Positioned(
              left: 0,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 20),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Voltar',
              ),
            ),
          // Centered Title + Icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: iconColor, size: 24),
            ],
          ),
          // Close button (right)
          Positioned(
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 22),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Fechar',
            ),
          ),
        ],
      ),
    );
  }

  // === CLOSE BUTTON ===
  /// Standardized close button for modal headers
  static Widget closeButton({
    required VoidCallback onPressed,
    Color color = Colors.white70,
    double size = 22,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(Icons.close, color: color, size: size),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: 'Fechar',
      ),
    );
  }

  // === BACK BUTTON ===
  /// Standardized back button for modal headers
  static Widget backButton({
    required VoidCallback onPressed,
    Color color = Colors.white70,
    double size = 20,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: color, size: size),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: 'Voltar',
      ),
    );
  }

  // === TABS ===
  /// Builds pill-style tabs (e.g., Dados / Resultado)
  static TabBar buildTabs({
    required TabController controller,
    List<String> labels = const ['Dados', 'Resultado'],
    Color activeColor = AppColors.primary,
  }) {
    return TabBar(
      controller: controller,
      indicatorColor: activeColor,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      splashBorderRadius: BorderRadius.circular(50),
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: activeColor.withOpacity(0.2),
        border: Border.all(color: activeColor),
      ),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      tabs: labels.map((label) => Tab(text: label)).toList(),
    );
  }

  // === INPUT DECORATION ===
  /// Standardized input field decoration
  static InputDecoration inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Color iconColor = Colors.cyan,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      helperText: helperText,
      helperStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(color: iconColor, width: 2),
      ),
      prefixIcon: Icon(prefixIcon, color: iconColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  // === PRIMARY BUTTON ===
  /// Pill-shaped primary action button
  static Widget primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Color backgroundColor = Colors.cyan,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          isLoading ? 'Analisando...' : label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputBorderRadius),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // === RESULT HEADER ===
  /// Gradient header card for AI analysis results
  static Widget resultHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Color primaryColor = Colors.cyan,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.8),
            primaryColor.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === SCORE RING ===
  /// Circular score indicator
  static Widget scoreRing({
    required int score,
    required String label,
    required Color color,
    double size = 150,
  }) {
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              // Progress ring
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Score text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === QUOTE BOX ===
  /// Styled quote/mantra container
  static Widget quoteBox(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.format_quote, size: 24, color: Colors.cyan.shade300),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.cyan.shade100,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Icon(Icons.format_quote, size: 24, color: Colors.cyan.shade300),
        ],
      ),
    );
  }

  // === INFO BOX ===
  /// Informational container with icon
  static Widget infoBox({
    required String text,
    IconData icon = Icons.info_outline,
    Color color = Colors.cyan,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // === SCORE LABEL ===
  /// Text badge for score category (Excelente, Bom, etc)
  static Widget scoreLabel({
    required String text,
    required Color color,
  }) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}
