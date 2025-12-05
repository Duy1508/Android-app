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

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  static const int _chatTabIndex = 3;

  final List<Widget> pages = [
    const FeedScreen(), // Trang chủ hiển thị bài viết
    const ChatContactsScreen(), //const SearchScreen(),
    const PostScreen(), // Trang đăng bài
    //const ChatContactsScreen(), // Danh bạ chat
    const NotificationsScreen(), // Màn hình thông báo
    const ProfileScreen(),
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
              tooltip: 'Tìm Kiếm',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Cài đặt',
              onPressed: _openLogoutMenu,
            ),
          ],
        );
      case _chatTabIndex:
        return null; // ChatContactsScreen đã có AppBar riêng
      case 4:
        return null; // NotificationsScreen đã có AppBar riêng
      case 5:
        return null; // ❌ Không cần AppBar vì ProfileScreen đã có riêng
      default:
        return AppBar(
          title: const Text(''),
          backgroundColor: Colors.white,
          elevation: 0,
        );
    }
  }

  void _openLogoutMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
      ),
    );
  }
}