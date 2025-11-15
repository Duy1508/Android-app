import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowersListScreen extends StatelessWidget {
  final String userId;
  const FollowersListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Người theo dõi')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('followers')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final followers = snapshot.data!.docs;

          if (followers.isEmpty) {
            return const Center(child: Text('Chưa có ai theo dõi'));
          }

          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final followerDoc = followers[index];
              final followerId = followerDoc['userId'] ?? followerDoc.id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(followerId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const ListTile(title: Text('Người dùng'));
                  }
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = userData['name'] ?? 'Ẩn danh';
                  final avatarUrl = userData['avatarUrl'] ?? '';

                  return ListTile(
                    leading: avatarUrl.isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name),
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
