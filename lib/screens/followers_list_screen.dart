import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'profile_screen.dart';

class FollowersListScreen extends StatelessWidget {
  final String userId;

  const FollowersListScreen({Key? key, required this.userId}) : super(key: key);

  // Chunk an iterable into fixed-size lists to use with whereIn (max 10).
  List<List<String>> _chunkIds(List<String> ids, {int size = 10}) {
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += size) {
      chunks.add(ids.sublist(i, i + size > ids.length ? ids.length : i + size));
    }
    return chunks;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsersByIds(List<String> ids) async {
    final result = <String, Map<String, dynamic>>{};
    for (final chunk in _chunkIds(ids)) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = doc.data();
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Người theo dõi'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('followers')
              .where('followingId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Chưa có người theo dõi nào'));
            }

            final followerIds = snapshot.data!.docs
                .map((doc) => (doc.data() as Map<String, dynamic>)['followerId'])
                .whereType<String>()
                .toList();

            if (followerIds.isEmpty) {
              return const Center(child: Text('Chưa có người theo dõi nào'));
            }

            return FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: _fetchUsersByIds(followerIds),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = userSnapshot.data ?? {};
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: followerIds.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colorScheme.outline.withOpacity(0.3)),
                  itemBuilder: (context, index) {
                    final followerId = followerIds[index];
                    final user = users[followerId];

                    if (user == null) {
                      return const SizedBox.shrink();
                    }

                    final username = (user['username'] as String?)?.trim();
                    final name = (user['name'] as String?)?.trim();
                    final email = (user['email'] as String?)?.trim();
                    final avatarUrl = (user['avatarUrl'] as String?)?.trim();

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
                          ? Text(email,
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: followerId),
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
