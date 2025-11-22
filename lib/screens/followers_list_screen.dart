import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowersListScreen extends StatelessWidget {
  final String userId;

  const FollowersListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Người theo dõi')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('followers')
            .doc(userId)
            .collection('userFollowers')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final followers = snapshot.data!.docs;
          if (followers.isEmpty) {
            return const Center(child: Text('Chưa có người theo dõi nào'));
          }
          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final followerId = followers[index].id;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followerId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return Container();
                  final user =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          user['avatarUrl'] != null && user['avatarUrl'] != ''
                          ? NetworkImage(user['avatarUrl'])
                          : null,
                      child:
                          user['avatarUrl'] == null || user['avatarUrl'] == ''
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(user['name'] ?? ''),
                    subtitle: Text(user['email'] ?? ''),
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
