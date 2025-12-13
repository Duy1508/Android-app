import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import "package:myapp/widgets/bottom_nav_bar.dart";
import 'search_screen.dart';
import 'post_screen.dart';
import 'feed_screen.dart';
import 'notifications_screen.dart';
import 'chat_contacts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  double _fabScale = 1.0;

  final List<Widget> pages = [
    const FeedScreen(),
    const ChatContactsScreen(),
    const PostScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  PreferredSizeWidget? _buildAppBar() {
    if (selectedIndex == 0) {
      return AppBar(
        backgroundColor: Colors.white,
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
    }
    if (selectedIndex == 1 || selectedIndex == 3 || selectedIndex == 4) {
      return null;
    }
    return AppBar(
      title: const Text(''),
      backgroundColor: Colors.white,
      elevation: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
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
        Positioned(
          bottom: 34,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTapDown: (_) {
                setState(() => _fabScale = 1.1); // phóng to khi bấm
              },
              onTapUp: (_) {
                setState(() {
                  _fabScale = 1.0; // trở lại bình thường
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
                  height: 52,
                  width: 52,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
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
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}