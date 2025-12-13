import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'groups_chat_screen.dart'; // màn hình chat nhóm

class GroupListScreen extends StatefulWidget {
  final String currentUserId;
  const GroupListScreen({super.key, required this.currentUserId});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  String? currentUsername;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      setState(() {
        currentUsername = doc.data()?['username'] ?? widget.currentUserId;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi load username: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || currentUsername == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách nhóm'),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: currentUsername) // lọc theo username
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
                  lastSenderId != currentUsername &&
                  !lastMessageReadBy.contains(currentUsername);

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
                        currentUserId: widget.currentUserId,
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