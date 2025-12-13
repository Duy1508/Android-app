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

  // Hàm build icon với gradient khi được chọn
  Widget _buildGradientIcon(IconData icon, int index, int currentIndex) {
    if (index == currentIndex) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
        ).createShader(bounds),
        child: Icon(icon, color: Colors.white),
      );
    } else {
      return Icon(icon, color: Colors.black);
    }
  }

  // Hàm build label với gradient khi được chọn
  Widget _buildGradientLabel(String text, int index, int currentIndex) {
    if (index == currentIndex) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
        ).createShader(bounds),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final notificationService = NotificationService();
    final firestore = FirebaseFirestore.instance;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      backgroundColor: Colors.white, // nền trắng
      selectedFontSize: 12,
      unselectedFontSize: 12,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: _buildGradientIcon(Icons.home, 0, currentIndex),
          label: '',
          tooltip: 'Home',
        ),
        BottomNavigationBarItem(
          icon: currentUser != null
              ? StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('chats')
                .where('participants', arrayContains: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadChats = 0;
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastSender = data['lastMessageSenderId'] as String?;
                  final readBy =
                      (data['lastMessageReadBy'] as List?)?.cast<String>() ??
                          const [];
                  if (lastSender != null &&
                      lastSender.isNotEmpty &&
                      lastSender != currentUser.uid &&
                      !readBy.contains(currentUser.uid)) {
                    unreadChats++;
                  }
                }
              }
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildGradientIcon(Icons.chat_bubble_outline, 1, currentIndex),
                  if (unreadChats > 0)
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
                          unreadChats > 99 ? '99+' : unreadChats.toString(),
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
              : _buildGradientIcon(Icons.chat_bubble_outline, 1, currentIndex),
          label: '',
          tooltip: 'Chat',
        ),
        const BottomNavigationBarItem(
          icon: SizedBox(height: 40, width: 40, child: SizedBox()),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: currentUser != null
              ? StreamBuilder<int>(
            stream: notificationService.getUnreadCountStream(currentUser.uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildGradientIcon(Icons.notifications, 3, currentIndex),
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
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
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
              : _buildGradientIcon(Icons.notifications, 3, currentIndex),
          label: '',
          tooltip: 'Thông báo',
        ),
        BottomNavigationBarItem(
          icon: _buildGradientIcon(Icons.person, 4, currentIndex),
          label: '',
          tooltip: 'Profile',
        ),
      ],
    );
  }
}
