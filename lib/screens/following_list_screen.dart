import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowingListScreen extends StatelessWidget {
  final String userId;
  const FollowingListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Đang theo dõi')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('following')
            .where('followerId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final following = snapshot.data!.docs;

          if (following.isEmpty) {
            return const Center(child: Text('Bạn chưa theo dõi ai'));
          }

          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              final followingDoc = following[index];
              final followingId = followingDoc['followingId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followingId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const ListTile(title: Text('Người dùng'));
                  }
                  final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
                  final username = userData['username'] ?? 'Ẩn danh';
                  final avatarUrl = userData['avatarUrl'] ?? '';

                  return ListTile(
                    leading: avatarUrl.isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(username),
                    // không có onTap → nhấn vào không làm gì
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
