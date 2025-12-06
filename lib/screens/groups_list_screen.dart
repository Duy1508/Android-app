import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'groups_chat_screen.dart'; // màn hình chat nhóm

class GroupListScreen extends StatelessWidget {
  final String currentUserId;
  const GroupListScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách nhóm')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: currentUserId)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Bạn chưa tham gia nhóm nào.'));
          }

          final groups = snapshot.data!.docs;

          return ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = groups[index].data() as Map<String, dynamic>;
              final groupId = groups[index].id;
              final name = data['name'] as String? ?? 'Nhóm';
              final lastMessage = data['lastMessage'] as String? ?? '';
              final lastSenderId = data['lastSenderId'] as String? ?? '';
              final lastMessageReadBy =
                  (data['lastMessageReadBy'] as List?)?.cast<String>() ?? [];
              final isUnread = lastMessage.isNotEmpty &&
                  lastSenderId != currentUserId &&
                  !lastMessageReadBy.contains(currentUserId);

              return ListTile(
                leading: const Icon(Icons.group),
                title: Text(name),
                subtitle: lastMessage.isNotEmpty
                    ? Text(
                  '${isUnread ? "[Chưa đọc] " : ""}$lastMessage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isUnread
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                )
                    : const Text('Chưa có tin nhắn'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupChatScreen(
                        groupId: groupId,
                        currentUserId: currentUserId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}