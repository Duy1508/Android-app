import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Future<Map<String, Map<String, dynamic>>> _fetchUsersByIds(
    List<String> ids,
  ) async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Người theo dõi')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('followers')
            .where('followingId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
              return ListView.builder(
                itemCount: followerIds.length,
                itemBuilder: (context, index) {
                  final followerId = followerIds[index];
                  final user = users[followerId];

                  if (user == null) {
                    return const SizedBox.shrink();
                  }

                  final avatarUrl = user['avatarUrl'] as String? ?? '';
                  final name = user['name'] as String? ?? '';
                  final email = user['email'] as String? ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(name),
                    subtitle: email.isNotEmpty ? Text(email) : null,
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
