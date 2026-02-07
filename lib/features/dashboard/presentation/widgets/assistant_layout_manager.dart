import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/agent_peeking_handle.dart';
import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart';

class AssistantLayoutManager extends StatefulWidget {
  final Widget child;
  final Widget assistant;
  final bool isAiSidebarOpen;
  final VoidCallback onToggleAiSidebar; // For Desktop
  final bool isMobile; // To explicitly control mode if needed
  final FabOpacityController? opacityController; // Optional controller for opacity linkage

  const AssistantLayoutManager({
    super.key,
    required this.child,
    required this.assistant,
    required this.isAiSidebarOpen,
    required this.onToggleAiSidebar,
    this.isMobile = false,
    this.opacityController,
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

  bool _isScrolling = false; // Track vertical scroll for transparency
  
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // Background (Assistant is functionally on the right/page 1)
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            // Only use internal scroll tracking if no external controller
            if (widget.opacityController == null) {
              if (notification.metrics.axis == Axis.vertical) {
                if (notification.direction != ScrollDirection.idle) {
                  if (!_isScrolling) setState(() => _isScrolling = true);
                } else {
                  if (_isScrolling) setState(() => _isScrolling = false);
                }
              }
            }
            return false;
          },
          child: PageView(
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
        ),
        
        // Interactive Handle Animation
        AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
             double progress = 0.0;
             if (_pageController.hasClients && _pageController.position.haveDimensions) {
                progress = _pageController.page ?? 0.0;
             }
             
             // If fully open (1.0), hide handle
             if (progress > 0.9) return const SizedBox.shrink();

              // Peeking Handle (Fixed to Right Edge)
              // Only show when closed or partially open
              if (progress > 0.1) return const SizedBox.shrink();

              Widget handle = AgentPeekingHandle(
                opacity: widget.opacityController != null 
                    ? 1.0 // If using controller, handle internal opacity via wrapper
                    : (_isScrolling ? 0.05 : 1.0), 
              );
              
              if (widget.opacityController != null) {
                handle = TransparentFabWrapper(
                  controller: widget.opacityController!,
                  child: handle,
                );
              }

              return Positioned(
                right: 0, 
                // Adjust vertical position
                top: MediaQuery.of(context).size.height * 0.4, 
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        1, 
                        duration: const Duration(milliseconds: 400), 
                        curve: Curves.easeInOutCubicEmphasized
                      );
                    },
                    onHorizontalDragUpdate: (details) {
                       _pageController.position.jumpTo(_pageController.offset - details.delta.dx);
                    },
                    onHorizontalDragEnd: (details) {
                       final velocity = details.primaryVelocity ?? 0;
                       
                       // Snap Logic
                       // If moving Left fast (< -300) OR passed 30% of screen width, open.
                       if (velocity < -300 || _pageController.page! > 0.3) {
                          _pageController.animateToPage(
                            1, 
                            duration: const Duration(milliseconds: 300), 
                            curve: Curves.easeOut
                          );
                       } else {
                          _pageController.animateToPage(
                            0, 
                            duration: const Duration(milliseconds: 300), 
                            curve: Curves.easeOut
                          );
                       }
                    },
                    child: handle,
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
            color: AppColors.border.withValues(alpha: 0.2), // Subtle solid divider
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
