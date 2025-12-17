import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'editprofile_screen.dart';
import '../services/follow_service.dart';
import 'followers_list_screen.dart';
import 'following_list_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final FollowService _followService = FollowService();
  late final String uid;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    uid = widget.userId ?? currentUser!.uid;
  }

  Future<void> toggleFollow() async {
    if (currentUser == null) return;
    setState(() => isLoading = true);
    try {
      final isFollowing = await _followService.checkIfFollowing(
        currentUser!.uid,
        uid,
      );
      if (isFollowing) {
        await _followService.unfollowUser(currentUser!.uid, uid);
      } else {
        await _followService.followUser(currentUser!.uid, uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openLogoutMenu() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (context) => ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Đăng xuất'),
        onTap: () async {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
          );
        },
      ),
    );
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

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _editPostDialog({
    required String postId,
    required Map<String, dynamic> post,
  }) async {
    final contentController =
    TextEditingController(text: (post['content'] ?? '') as String);
    final imageController =
    TextEditingController(text: (post['imageUrl'] ?? '') as String);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Sửa bài viết'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .update({
                  'content': contentController.text.trim(),
                  'imageUrl': imageController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã cập nhật bài viết')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi cập nhật: $e')),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePost(String postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài viết'),
        content: const Text('Bạn chắc chắn muốn xóa bài viết này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bài viết')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final username = (data['username'] ?? '') as String;
        final email = (data['email'] ?? '') as String;
        final bio = (data['bio'] ?? '') as String;
        final avatarUrl = data['avatarUrl'] as String?;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: widget.userId != null,
            title: Text('@$username', style: const TextStyle(color: Colors.black)),
            centerTitle: false,
            actions: widget.userId == null
                ? [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Cài đặt',
                onPressed: _openLogoutMenu,
              ),
            ]
                : null,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + Stats
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? const Icon(Icons.person, size: 40, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .where('userId', isEqualTo: uid)
                                    .snapshots(),
                                builder: (context, s) {
                                  final postCount = s.data?.docs.length ?? 0;
                                  return _buildStat('Bài viết', postCount);
                                },
                              ),
                              StreamBuilder<int>(
                                stream: _followService.getFollowersCountStream(uid),
                                builder: (context, s) {
                                  final followersCount =
                                      s.data ?? (data['followersCount'] ?? 0) as int;
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FollowersListScreen(userId: uid),
                                        ),
                                      );
                                    },
                                    child: _buildStat('Người theo dõi', followersCount),
                                  );
                                },
                              ),
                              StreamBuilder<int>(
                                stream: _followService.getFollowingCountStream(uid),
                                builder: (context, s) {
                                  final followingCount =
                                      s.data ?? (data['followingCount'] ?? 0) as int;
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FollowingListScreen(userId: uid),
                                        ),
                                      );
                                    },
                                    child: _buildStat('Đang theo dõi', followingCount),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Email dưới avatar
                    Text(email, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    // Bio
                    Text(bio),
                    const SizedBox(height: 16),

                    // Nếu là chính chủ: nút chỉnh sửa + chia sẻ
                    if (widget.userId == null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditProfileScreen(userId: uid),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Colors.black),
                              ),
                              child: const Text('Chỉnh sửa'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final profileUrl = 'https://myapp.com/profile/$uid';
                                await Clipboard.setData(ClipboardData(text: profileUrl));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã sao chép link hồ sơ!'),
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Colors.black),
                              ),
                              child: const Text('Chia sẻ trang cá nhân'),
                            ),
                          ),
                        ],
                      )
                    // Nếu xem profile người khác: nút theo dõi/bỏ theo dõi
                    else
                      StreamBuilder<bool>(
                        stream: _followService.isFollowingStream(
                          currentUser?.uid ?? '',
                          uid,
                        ),
                        builder: (context, s) {
                          final isFollowing = s.data ?? false;
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                isFollowing ? Colors.grey : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                                  : Text(isFollowing ? 'Bỏ theo dõi' : 'Theo dõi'),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const Divider(),

              // Header "Bài viết" + số lượng
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text('Bài viết',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .where('userId', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, s) {
                        final postCount = s.data?.docs.length ?? 0;
                        return Text(
                          '($postCount)',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Danh sách bài viết (ListView/Card, xử lý lỗi & xem thêm/thu gọn)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, s) {
                    if (s.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (s.hasError) {
                      final err = s.error.toString();
                      final isIndexError =
                          err.contains('index') || err.contains('FAILED_PRECONDITION');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text(
                                isIndexError
                                    ? 'Cần tạo index trong Firestore'
                                    : 'Đã xảy ra lỗi',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isIndexError
                                    ? 'Vui lòng kiểm tra Firebase Console để tạo index cần thiết.'
                                    : err,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!s.hasData || s.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Chưa có bài viết nào',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }

                    final posts = s.data!.docs;

                    return RefreshIndicator(
                      onRefresh: () async {},
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final postDoc = posts[index];
                          final post = postDoc.data() as Map<String, dynamic>;
                          final postId = postDoc.id;
                          final content = (post['content'] ?? '') as String;
                          final imageUrl = post['imageUrl'] as String?;
                          final createdAt = post['createdAt'] != null
                              ? (post['createdAt'] as Timestamp).toDate()
                              : null;
                          final isOwner =
                              (currentUser?.uid ?? '') == (post['userId'] ?? '');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header bài viết: avatar + username + menu
                                ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: (avatarUrl == null || avatarUrl.isEmpty)
                                        ? const Icon(Icons.person, size: 20)
                                        : null,
                                  ),
                                  title: Text(
                                    '@$username',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    createdAt != null ? _formatDateTime(createdAt) : '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: isOwner
                                      ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await _editPostDialog(
                                          postId: postId,
                                          post: post,
                                        );
                                      } else if (value == 'delete') {
                                        await _confirmDeletePost(postId);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Sửa bài viết'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Xóa bài viết',
                                                style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                      : null,
                                ),

                                if (content.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: _ExpandableText(content),
                                  ),

                                if (imageUrl != null && imageUrl.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 200,
                                            color: Colors.grey.shade300,
                                            child: const Center(
                                              child: Icon(Icons.broken_image,
                                                  color: Colors.grey),
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return Container(
                                            height: 200,
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Expandable text widget cho nội dung bài viết dài
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText(this.text);

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool expanded = false;
  static const int cutoff = 150; // số ký tự hiển thị ban đầu

  @override
  Widget build(BuildContext context) {
    final showFull = expanded || widget.text.length <= cutoff;
    final displayText = showFull ? widget.text : widget.text.substring(0, cutoff) + '...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: const TextStyle(fontSize: 14),
        ),
        if (widget.text.length > cutoff)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: Colors.blue,
            ),
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(expanded ? 'Thu gọn' : 'Xem thêm'),
          ),
      ],
    );
  }
}
