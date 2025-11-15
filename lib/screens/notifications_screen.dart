import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_detail_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUser!.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final notifs = snapshot.data!.docs;

          if (notifs.isEmpty) return const Center(child: Text('Không có thông báo'));

          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final notif = notifs[index].data() as Map<String, dynamic>;
              final type = notif['type'];
              final fromUserId = notif['fromUserId'];
              final postId = notif['postId'];

              String message = '';
              if (type == 'like') message = 'Ai đó đã thích bài viết của bạn';
              if (type == 'comment') message = 'Ai đó đã bình luận bài viết của bạn';
              if (type == 'follow') message = 'Ai đó đã theo dõi bạn';

              return ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(message),
                subtitle: Text(notif['createdAt']?.toDate().toString() ?? ''),
                onTap: () {
                  // ✅ Nếu thông báo liên quan đến bài viết → mở PostDetailScreen
                  if (postId != null && postId != '') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
