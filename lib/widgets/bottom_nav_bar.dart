import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final notificationService = NotificationService();

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      onTap: onTap,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat',), //const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search',),
        const BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Post'),
        //const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat',),
        BottomNavigationBarItem(
          icon: currentUser != null
              ? StreamBuilder<int>(
                  stream: notificationService.getUnreadCountStream(
                    currentUser.uid,
                  ),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications),
                        if (unreadCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
              : const Icon(Icons.notifications),
          label: 'Thông báo',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
