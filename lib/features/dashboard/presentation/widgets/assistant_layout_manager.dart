import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class AssistantLayoutManager extends StatefulWidget {
  final Widget child;
  final Widget assistant;
  final bool isAiSidebarOpen;
  final VoidCallback onToggleAiSidebar; // For Desktop
  final bool isMobile; // To explicitly control mode if needed

  const AssistantLayoutManager({
    super.key,
    required this.child,
    required this.assistant,
    required this.isAiSidebarOpen,
    required this.onToggleAiSidebar,
    this.isMobile = false,
  });

  @override
  State<AssistantLayoutManager> createState() => _AssistantLayoutManagerState();
}

class _AssistantLayoutManagerState extends State<AssistantLayoutManager> {
  late PageController _pageController;
  double _swipeProgress = 0.0; // 0.0 (App) to 1.0 (Assistant)

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_pageController.hasClients) {
      final progress = _pageController.page ?? 0.0;
      if (progress != _swipeProgress) {
        setState(() {
          _swipeProgress = progress;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // Background (Assistant is functionally on the right/page 1)
        PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          children: [
            // Page 0: Main App (with Scale Effect)
            AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                 // Calculate progress even if controller isn't attached yet (fallback 0)
                 double progress = 0.0;
                 if (_pageController.hasClients && _pageController.position.haveDimensions) {
                    progress = _pageController.page ?? 0.0;
                 }
                return Transform.scale(
                  scale: 1.0 - (progress * 0.1), // Scales down to 0.9
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(progress * 24),
                    child: widget.child,
                  ),
                );
              },
            ),
            // Page 1: Assistant
            widget.assistant,
          ],
        ),
        
        // Interactive Handle Animation
        // The handle should move LEFT as the swipe progresses (progress 0 -> 1)
        // Position = ScreenWidth - (progress * ScreenWidth) ?? No, that would move all the way to left.
        // User wants the "button to come along".
        // Let's bind the 'right' position to the swipe.
        AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
             double progress = 0.0;
             if (_pageController.hasClients && _pageController.position.haveDimensions) {
                progress = _pageController.page ?? 0.0;
             }
             
             // If fully open (1.0), hide handle or keep it?
             // Usually handles vanish or morph. Let's make it fade out after 50%.
             if (progress > 0.9) return const SizedBox.shrink();

             final screenWidth = MediaQuery.of(context).size.width;
             // Moves from right:0 to right:screenWidth (following the page)
             // But the assistant page comes IN from the right.
             // If we attach it to the "edge" of the assistant page.
             // Page 1 is at Offset(screenWidth, 0) initially.
             // As we swipe left, Page 1 Offset goes to (0,0).
             // We want the handle to be on the LEFT edge of Page 1?
             // No, the user said "button subtle on lateral... comes together".
             
             // Let's position it relative to the progress.
             // right: (progress * screenWidth) would make it travel across the screen.
             // Let's add a slight clamp so it doesn't fly off if overscrolled.
             
             return Positioned(
               right: (progress * screenWidth).clamp(0.0, screenWidth),
               top: 0,
               bottom: 0,
               child: Opacity(
                 opacity: (1.0 - progress).clamp(0.0, 1.0), // Fade out as it opens
                 child: Center(
                   child: _PulsingIndicator(),
                 ),
               ),
             );
          },
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Main Content (Pushes)
        Expanded(
          child: widget.child,
        ),
        
        // Vertical Divider (Desktop Only)
        if (widget.isAiSidebarOpen)
          Container(
            width: 1,
            color: AppColors.border.withValues(alpha: 0.1), // Subtle divider
          ),

        // Sidebar (Animated Width)
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubicEmphasized,
          width: widget.isAiSidebarOpen ? 450 : 0, // 450px width for sidebar
          child: ClipRect( // Clips content when width is 0
             child: OverflowBox(
               minWidth: 450,
               maxWidth: 450,
               alignment: Alignment.centerLeft,
               child: Container(
                 decoration: const BoxDecoration(
                   color: Colors.transparent, // Fix: Make sidebar background transparent
                   borderRadius: BorderRadius.only(
                     topLeft: Radius.circular(24),
                     bottomLeft: Radius.circular(24),
                   ),
                   // Optional: Border only if needed, but if transparent, maybe not?
                   // User wants "flutuando no mesmo fundo do sistema do app".
                   // If transparent, it shows whatever is BEHIND it.
                   // In Desktop layout, the Sidebar is adjacent to content.
                   // Is there a background behind the main Row?
                   // Usually Scaffold background. So transparent means it shows Scaffold background.
                   // If we want it "floating", the AssistantPanel inside should be self-contained.
                 ),
                 child: widget.assistant,
               ),
             ),
          ),
        ),
      ],
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  const _PulsingIndicator();

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 4,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primaryAccent,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
             BoxShadow(color: AppColors.primaryAccent.withValues(alpha: 0.5), blurRadius: 4),
          ]
        ),
      ),
    );
  }
}
