import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết bài viết')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Bài viết không tồn tại'));
          }

          final post = snapshot.data!.data() as Map<String, dynamic>;
          final content = post['content'] ?? '';
          final imageUrl = post['imageUrl'];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null && imageUrl != '')
                  Image.network(imageUrl, fit: BoxFit.cover),
                const SizedBox(height: 12),
                Text(content, style: const TextStyle(fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );
  }
}
