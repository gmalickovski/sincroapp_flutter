import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static String? currentRoute;
  static Object? routeArguments;

  // Use the custom observer instance
  static final NavigationObserver routeObserver = NavigationObserver();
}

class NavigationObserver extends RouteObserver<ModalRoute<void>> {
  
  void _updateContext(PageRoute route) {
     NavigationService.currentRoute = route.settings.name;
     NavigationService.routeArguments = route.settings.arguments;
    //  debugPrint('NavigationService: Context Updated -> ${route.settings.name}');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _updateContext(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _updateContext(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
       _updateContext(previousRoute);
    }
  }
}
