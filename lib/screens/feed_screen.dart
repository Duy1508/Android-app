import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comment_screen.dart';
import '../services/notification_service.dart';


class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
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

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Xóa bài viết'),
                                  content: const Text('Bạn có chắc muốn xóa bài viết này?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await postDoc.reference.delete();
                              }
                            } else if (value == 'edit') {
                              final controller = TextEditingController(text: post['content']);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Sửa bài viết'),
                                  content: TextField(
                                    controller: controller,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      hintText: 'Nhập nội dung mới...',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Lưu'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await postDoc.reference.update({'content': controller.text});
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Sửa bài viết'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa bài viết'),
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
                                  // Nếu đã like thì bỏ like
                                  likes.remove(uid);
                                } else {
                                  // Nếu chưa like thì thêm like
                                  likes.add(uid);

                                  // 👉 Tạo thông báo cho chủ bài viết
                                  final notificationService = NotificationService();
                                  await notificationService.createNotification(
                                    userId: postUserId,   // người nhận thông báo
                                    type: 'like',         // loại thông báo
                                    fromUserId: uid,      // người thực hiện like
                                    postId: postDoc.id,   // id bài viết liên quan
                                  );
                                }

                                await postDoc.reference.update({'likes': likes});
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
    );
  }
}