import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comment_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  String? get postId => null;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final posts = snapshot.data!.docs;

          if (posts.isEmpty) return const Center(child: Text('Chưa có bài viết'));

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postDoc = posts[index];
              final post = postDoc.data() as Map<String, dynamic>;
              final likes = List<String>.from(post['likes'] ?? []);
              final postUserId = post['userId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(postUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const ListTile(title: Text(''));
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = userData['name'] ?? 'Ẩn danh';
                  final avatarUrl = userData['avatarUrl'];

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300), // viền xám
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: avatarUrl != null && avatarUrl != ''
                              ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                              : const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(name),
                          subtitle: Text(
                            post['createdAt'] != null
                                ? (post['createdAt'] as Timestamp).toDate().toString()
                                : '',
                          ),
                          trailing: currentUser != null && currentUser.uid == postUserId
                              ? PopupMenuButton<String>(
                            tooltip: 'Menu',
                            color: Colors.white, // ✅ nền trắng cho toàn bộ menu
                            onSelected: (value) async {
                              if (value == 'edit') {
                                // Mở dialog sửa nội dung
                                final TextEditingController editController =
                                TextEditingController(text: postDoc['content']); // nội dung cũ

                                final newContent = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Sửa bài viết'),
                                      content: TextField(
                                        controller: editController,
                                        maxLines: 5,
                                        decoration: const InputDecoration(
                                          hintText: 'Nhập nội dung mới...',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Hủy', style: TextStyle(color: Colors.black)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context, editController.text.trim());
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Lưu'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (newContent != null && newContent.isNotEmpty) {
                                  await FirebaseFirestore.instance
                                      .collection('posts')
                                      .doc(postDoc.id)
                                      .update({'content': newContent});

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Đã cập nhật bài viết')),
                                  );
                                }
                              }

                              if (value == 'delete') {
                                await FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(postDoc.id)
                                    .delete();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã xóa bài viết')),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20, color: Colors.black),
                                    SizedBox(width: 8),
                                    Text('Sửa bài viết', style: TextStyle(color: Colors.black)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 20, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Xóa bài viết', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          )

                              : null,
                        ),
                        if (post['imageUrl'] != null && post['imageUrl'] != '')
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(post['imageUrl'], fit: BoxFit.cover),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(post['content'] ?? ''),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  likes.contains(currentUser?.uid)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  if (currentUser == null) return;
                                  final uid = currentUser.uid;
                                  if (likes.contains(uid)) {
                                    likes.remove(uid);
                                  } else {
                                    likes.add(uid);
                                  }
                                  await postDoc.reference.update({
                                    'likes': likes,
                                  });
                                },
                              ),


                              Text('${likes.length}'),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.comment_outlined),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommentScreen(postId: postDoc.id),
                                    ),
                                  );
                                },
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(postDoc.id)
                                    .collection('comments')
                                    .snapshots(),
                                builder: (context, commentSnapshot) {
                                  final commentCount = commentSnapshot.data?.docs.length ?? 0;
                                  return Text(
                                    '$commentCount',
                                    style: const TextStyle(fontSize: 14),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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