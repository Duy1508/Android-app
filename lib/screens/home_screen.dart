import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const Center(child: Text('Home')),
    const Center(child: Text('Post')),
    const Center(child: Text('Friend')),
    const Center(child: Text('Notifications')),
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
              icon: const Icon(Icons.settings),
              tooltip: 'Cài đặt',
              onPressed: _openLogoutMenu,
            ),
          ],
        );
      case 4:
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) => setState(() => selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friend'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Thông báo'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
