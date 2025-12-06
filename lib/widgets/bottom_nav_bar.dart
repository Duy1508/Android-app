import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

        // Chat tab
        BottomNavigationBarItem(
          icon: currentUser != null
              ? StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadChats = 0;
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final lastSender = data['lastMessageSenderId'] as String?;
                  final readBy = (data['lastMessageReadBy'] as List?)?.cast<String>() ?? const [];
                  if (lastSender != null &&
                      lastSender.isNotEmpty &&
                      lastSender != currentUser.uid &&
                      !readBy.contains(currentUser.uid)) {
                    unreadChats++;
                  }
                }
              }
              return _buildIconWithBadge(Icons.chat_bubble_outline, unreadChats);
            },
          )
              : const Icon(Icons.chat_bubble_outline),
          label: 'Chat',
        ),

        const BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Post'),

        // Notifications tab
        BottomNavigationBarItem(
          icon: currentUser != null
              ? StreamBuilder<int>(
            stream: notificationService.getUnreadCountStream(currentUser.uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return _buildIconWithBadge(Icons.notifications, unreadCount);
            },
          )
              : const Icon(Icons.notifications),
          label: 'Thông báo',
        ),

        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Widget _buildIconWithBadge(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : count.toString(),
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
  }
}
