import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class CommentScreen extends StatefulWidget {
  final String postId;

  const CommentScreen({super.key, required this.postId});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final NotificationService _notificationService = NotificationService();

  String? _postUserId;
  String? _replyingToCommentId;

  @override
  void initState() {
    super.initState();
    _loadPostInfo();
  }

  Future<void> _loadPostInfo() async {
    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();

    if (postDoc.exists) {
      final postData = postDoc.data() as Map<String, dynamic>;
      setState(() {
        _postUserId = postData['userId'];
      });
    }
  }

  Future<void> _submitComment() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _commentController.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': currentUser.uid,
        'text': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Thông báo cho chủ bài viết (khác mình)
      if (_postUserId != null && _postUserId != currentUser.uid) {
        await _notificationService.createNotification(
          userId: _postUserId!,
          type: 'comment',
          fromUserId: currentUser.uid,
          postId: widget.postId,
        );
      }

      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _submitReply(String commentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _replyController.text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .add({
        'userId': currentUser.uid,
        'content': _replyController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .snapshots(),
          builder: (context, snapshot) {
            final commentCount = snapshot.data?.docs.length ?? 0;
            return Text('Bình luận ($commentCount)');
          },
        ),
      ),
      body: Column(
        children: [
          // Danh sách bình luận
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                final comments = snapshot.data?.docs ?? [];

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('Chưa có bình luận nào',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('Hãy là người đầu tiên bình luận!',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final commentDoc = comments[index];
                    final comment = commentDoc.data() as Map<String, dynamic>;
                    final userId = comment['userId'];
                    final text = comment['text'] ?? '';
                    final createdAt = comment['createdAt'] != null
                        ? (comment['createdAt'] as Timestamp).toDate()
                        : null;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }

                        final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                        final userName = userData['name'] ?? 'Ẩn danh';
                        final avatarUrl = userData['avatarUrl'];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          elevation: 0,
                          color: Colors.grey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: avatarUrl != null &&
                                        avatarUrl != ''
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null || avatarUrl == ''
                                        ? const Icon(Icons.person, size: 20)
                                        : null,
                                  ),
                                  title: Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(text,
                                          style:
                                          const TextStyle(fontSize: 14)),
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Nút trả lời
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _replyingToCommentId = commentDoc.id;
                                    });
                                  },
                                  child: const Text('Trả lời'),
                                ),

                                // Ô nhập reply (chỉ hiển thị khi đang trả lời comment này)
                                if (_replyingToCommentId == commentDoc.id)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16, right: 16, bottom: 8),
                                    child: Column(
                                      children: [
                                        TextField(
                                          controller: _replyController,
                                          decoration: const InputDecoration(
                                            hintText: 'Nhập phản hồi...',
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _submitReply(commentDoc.id),
                                              child: const Text('Gửi'),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _replyingToCommentId = null;
                                                });
                                              },
                                              child: const Text('Hủy'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                // Danh sách reply
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('posts')
                                      .doc(widget.postId)
                                      .collection('comments')
                                      .doc(commentDoc.id)
                                      .collection('replies')
                                      .orderBy('createdAt')
                                      .snapshots(),
                                  builder: (context, replySnapshot) {
                                    if (!replySnapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final replies =
                                        replySnapshot.data!.docs;

                                    if (replies.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                      const NeverScrollableScrollPhysics(),
                                      itemCount: replies.length,
                                      itemBuilder: (context, i) {
                                        final replyData = replies[i].data()
                                        as Map<String, dynamic>;
                                        final replyText =
                                            replyData['content'] ?? '';
                                        final replyUserId =
                                            replyData['userId'] ?? '';
                                        final replyCreatedAt =
                                        replyData['createdAt'] is Timestamp
                                            ? (replyData['createdAt']
                                        as Timestamp)
                                            .toDate()
                                            : null;

                                        return FutureBuilder<
                                            DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(replyUserId)
                                              .get(),
                                          builder:
                                              (context, replyUserSnapshot) {
                                            final replyUserName =
                                            replyUserSnapshot.hasData &&
                                                replyUserSnapshot
                                                    .data!.exists
                                                ? (replyUserSnapshot
                                                .data!
                                                .data()
                                            as Map<String,
                                                dynamic>)['name'] ??
                                                'Ẩn danh'
                                                : 'Ẩn danh';

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 48, right: 12, top: 4),
                                              child: Row(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.subdirectory_arrow_right,
                                                      size: 16,
                                                      color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Text(
                                                          '$replyUserName: $replyText',
                                                          style:
                                                          const TextStyle(
                                                              fontSize:
                                                              13),
                                                        ),
                                                        if (replyCreatedAt !=
                                                            null)
                                                          Text(
                                                            _formatDateTime(
                                                                replyCreatedAt),
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
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
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Ô nhập bình luận
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                          BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _submitComment,
                      tooltip: 'Gửi bình luận',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
