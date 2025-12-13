import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_thread_screen.dart';

class FollowingListScreen extends StatelessWidget {
  final String userId;
  const FollowingListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đang theo dõi'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('followers') // ✅ đồng bộ với FollowService
              .where('followerId', isEqualTo: userId)
              .orderBy('createdAt', descending: true) // có thể cần index
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Bạn chưa theo dõi ai'));
            }

            final docs = snapshot.data!.docs;

            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colorScheme.outline.withOpacity(0.3)),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final followingId = data['followingId'] as String?;

                if (followingId == null || followingId.isEmpty) {
                  return const ListTile(title: Text('Người dùng'));
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(followingId)
                      .get(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircleAvatar(child: Icon(Icons.person)),
                        title: Text('Đang tải...'),
                      );
                    }
                    if (!userSnap.hasData || !userSnap.data!.exists) {
                      return const ListTile(title: Text('Người dùng'));
                    }

                    final u = userSnap.data!.data() as Map<String, dynamic>;
                    final username = (u['username'] as String?)?.trim();
                    final name = (u['name'] as String?)?.trim();
                    final email = (u['email'] as String?)?.trim();
                    final avatarUrl = (u['avatarUrl'] as String?)?.trim();

                    final displayName = (username?.isNotEmpty == true)
                        ? username!
                        : (name?.isNotEmpty == true)
                        ? name!
                        : (email ?? 'Ẩn danh');

                    return ListTile(
                      leading: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                          : CircleAvatar(
                        backgroundColor: colorScheme.surfaceVariant,
                        child: Icon(Icons.person,
                            color: colorScheme.onSurface),
                      ),
                      title: Text(displayName,
                          style: Theme.of(context).textTheme.bodyLarge),
                      subtitle: (email != null && email.isNotEmpty)
                          ? Text(email, maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatThreadScreen(
                              contactId: followingId,
                              contactName: displayName,
                              contactAvatarUrl: avatarUrl,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}