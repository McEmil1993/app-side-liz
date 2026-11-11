import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'home_screens.dart';
import 'post_pickup_screen.dart';
import 'buyer_route_screen.dart';
import 'shared_screens.dart';
import 'widgets.dart';
import 'auth_screens.dart';

class EasyScrapApp extends StatelessWidget {
  final AppController controller;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;
  const EasyScrapApp({
    super.key,
    required this.controller,
    this.navigatorKey,
    this.messengerKey,
  });
  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'EasyScrap',
      theme: buildTheme(),
      home: Builder(
        builder: (context) {
          final app = AppScope.of(context);
          if (app.starting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (app.startupError != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(app.startupError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: app.initialize,
                        child: const Text('Retry connection'),
                      ),
                      TextButton(
                        onPressed: () {
                          app.startupError = null;
                          app.signOut();
                        },
                        child: const Text('Return to login'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final role = app.role;
          return role == null
              ? const AuthScreen()
              : MobileShell(key: ValueKey(app.user.id), role: role);
        },
      ),
    ),
  );
}

class MobileShell extends StatefulWidget {
  final UserRole role;
  const MobileShell({super.key, required this.role});
  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int index = 0;
  final visited = <int>{0};
  void selectTab(int value) => setState(() {
    index = value;
    visited.add(value);
  });
  @override
  Widget build(BuildContext context) {
    final household = widget.role == UserRole.household;
    final labels = household
        ? ['Home', 'My Pickups', 'Post Scrap', 'Tips', 'Profile']
        : ['Marketplace', 'My Route', 'Collections', 'Messages', 'Profile'];
    final icons = household
        ? [
            Icons.home_outlined,
            Icons.inventory_2_outlined,
            Icons.add_circle_outline,
            Icons.eco_outlined,
            Icons.person_outline,
          ]
        : [
            Icons.storefront_outlined,
            Icons.route_outlined,
            Icons.inventory_2_outlined,
            Icons.chat_bubble_outline,
            Icons.person_outline,
          ];
    final pages = household
        ? <Widget>[
            HouseholdHome(
              onPost: () => selectTab(2),
              onPickups: () => selectTab(1),
            ),
            const PickupsScreen(),
            PostPickupForm(onPublished: () => selectTab(1)),
            const TipsScreen(),
            const ProfileScreen(),
          ]
        : <Widget>[
            const MarketplaceScreen(),
            const BuyerRouteScreen(),
            const CollectionsScreen(),
            const MessagesScreen(),
            const ProfileScreen(),
          ];
    return Scaffold(
      appBar: AppBar(
        title: index == 0
            ? const Row(
                children: [
                  BrandMark(size: 30),
                  SizedBox(width: 9),
                  Text('EasyScrap'),
                ],
              )
            : Text(labels[index]),
        actions: [
          if (AppScope.of(context).connected)
            IconButton(
              tooltip: 'Refresh',
              onPressed: AppScope.of(context).busy
                  ? null
                  : () => perform(context, AppScope.of(context).refresh),
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (AppScope.of(context).busy) const LinearProgressIndicator(),
          if (AppScope.of(context).dataError != null)
            MaterialBanner(
              content: Text(AppScope.of(context).dataError!),
              actions: [
                TextButton(
                  onPressed: () =>
                      perform(context, AppScope.of(context).refresh),
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: IndexedStack(
                    index: index,
                    children: List.generate(
                      pages.length,
                      (i) => visited.contains(i)
                          ? pages[i]
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: selectTab,
        destinations: List.generate(
          5,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}
