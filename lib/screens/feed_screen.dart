import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comment_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<String> followingIds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Dùng collection 'followers' để lấy những người bạn đang follow
      final snap = await FirebaseFirestore.instance
          .collection('followers')
          .where('followerId', isEqualTo: currentUser.uid)
          .get();

      final ids = snap.docs.map((d) => d['followingId'] as String).toList();
      ids.add(currentUser.uid); // thêm chính mình

      setState(() {
        followingIds = ids;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi load following: $e');
      setState(() => isLoading = false);
    }
  }

  void _showLikesDialog(List<String> likes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Người đã thích'),
        content: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where(
            FieldPath.documentId,
            whereIn: likes.isEmpty ? ['__none__'] : likes, // tránh whereIn rỗng
          )
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Text('Chưa có ai thích bài viết này');
            }
            return SizedBox(
              width: double.maxFinite,
              height: 320,
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = (data['name'] as String?) ?? 'Ẩn danh';
                  final username = (data['username'] as String?) ?? '';
                  final avatarUrl = (data['avatarUrl'] as String?) ?? '';
                  final displayName =
                  username.isNotEmpty ? username : name;

                  return ListTile(
                    leading: avatarUrl.isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(displayName),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (followingIds.isEmpty) {
      return const Center(child: Text('Bạn chưa theo dõi ai'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', whereIn: followingIds)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(child: Text('Chưa có bài viết'));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postDoc = posts[index];
            final post = postDoc.data() as Map<String, dynamic>;
            final likes = List<String>.from(post['likes'] ?? []);
            final postUserId = post['userId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(postUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final userData =
                userSnapshot.data!.data() as Map<String, dynamic>;
                final name = (userData['name'] as String?) ?? 'Ẩn danh';
                final avatarUrl = (userData['avatarUrl'] as String?) ?? '';

                // trạng thái mở rộng nội dung riêng từng card
                bool expanded = false;

                return StatefulBuilder(
                  builder: (context, setStateCard) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: avatarUrl.isNotEmpty
                                ? CircleAvatar(
                              backgroundImage: NetworkImage(avatarUrl),
                            )
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(name),
                            subtitle: Text(
                              post['createdAt'] != null
                                  ? (post['createdAt'] as Timestamp)
                                  .toDate()
                                  .toString()
                                  : '',
                            ),
                            trailing: currentUser != null &&
                                currentUser.uid == postUserId
                                ? PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Xóa bài viết'),
                                      content: const Text(
                                        'Bạn có chắc muốn xóa bài viết này?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Hủy'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Xóa'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await postDoc.reference.delete();
                                  }
                                } else if (value == 'edit') {
                                  final controller = TextEditingController(
                                    text: (post['content'] as String?) ?? '',
                                  );
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
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Hủy'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Lưu'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await postDoc.reference.update({
                                      'content': controller.text,
                                    });
                                  }
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa bài viết'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xóa bài viết'),
                                ),
                              ],
                            )
                                : null,
                          ),
                          if ((post['imageUrl'] as String?)?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  post['imageUrl'] as String,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (post['content'] as String?) ?? '',
                                  maxLines: expanded ? null : 3,
                                  overflow: expanded ? null : TextOverflow.ellipsis,
                                ),
                                // Hiển thị nút dựa trên độ dài nội dung (có thể thay bằng logic đo số dòng nếu cần)
                                if (((post['content'] as String?) ?? '').length > 100)
                                  TextButton(
                                    onPressed: () {
                                      setStateCard(() {
                                        expanded = !expanded;
                                      });
                                    },
                                    child: Text(expanded ? 'Thu gọn' : 'Xem thêm'),
                                  ),
                              ],
                            ),
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
                                GestureDetector(
                                  onTap: () {
                                    if (likes.isNotEmpty) {
                                      _showLikesDialog(likes);
                                    }
                                  },
                                  child: Text(
                                    likes.isEmpty ? '0 lượt thích' : '${likes.length} lượt thích',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.comment_outlined),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CommentScreen(postId: postDoc.id),
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
                                    final commentCount =
                                        commentSnapshot.data?.docs.length ?? 0;
                                    return Text(
                                      '$commentCount',
                                      style: const TextStyle(fontSize: 14),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
