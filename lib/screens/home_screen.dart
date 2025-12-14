import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'post_screen.dart';
import 'feed_screen.dart';
import 'notifications_screen.dart';
import 'chat_contacts_screen.dart';
import 'package:myapp/widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  double _fabScale = 1.0;

  final List<Widget> pages = const [
    FeedScreen(),
    ChatContactsScreen(),
    PostScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  PreferredSizeWidget? _buildAppBar() {
    switch (selectedIndex) {
      case 0:
        return AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Trang chủ'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Tìm kiếm',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
          ],
        );
      case 2:
        return AppBar(
          title: const Text('Đăng bài'),
          backgroundColor: Colors.white,
          elevation: 0,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Nếu chưa đăng nhập → quay về WelcomeScreen
    if (currentUser == null) {
      return const WelcomeScreen();
    }

    return Stack(
      children: [
        Scaffold(
          appBar: _buildAppBar(),
          body: pages[selectedIndex],
          bottomNavigationBar: BottomNavBar(
            currentIndex: selectedIndex,
            onTap: (index) => setState(() => selectedIndex = index),
          ),
        ),
        // Nút FAB đăng bài
        Positioned(
          bottom: 34,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTapDown: (_) {
                setState(() => _fabScale = 1.1);
              },
              onTapUp: (_) {
                setState(() {
                  _fabScale = 1.0;
                  selectedIndex = 2; // mở PostScreen
                });
              },
              onTapCancel: () {
                setState(() => _fabScale = 1.0);
              },
              child: AnimatedScale(
                scale: _fabScale,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      )
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
