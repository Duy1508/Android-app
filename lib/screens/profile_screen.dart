import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'editprofile_screen.dart';
import '../services/follow_service.dart';
import 'followers_list_screen.dart';
import 'following_list_screen.dart';
import 'package:flutter/services.dart';
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

  Future<bool> isCurrentUserFollower(String postOwnerId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    if (currentUserId == postOwnerId) return true;
    final docId = '${currentUserId}_$postOwnerId';
    final doc = await FirebaseFirestore.instance
        .collection('followers')
        .doc(docId)
        .get();
    return doc.exists;
  }

  void _openLogoutMenu() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
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
                // Cập nhật các field cho phép
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
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .delete();
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.userId != null,
        title: const Text('Trang cá nhân', style: TextStyle(color: Colors.black)),
        centerTitle: true,
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
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final username = (data['username'] ?? '') as String;
          final email = (data['email'] ?? '') as String;
          final bio = (data['bio'] ?? '') as String;
          final avatarUrl = data['avatarUrl'] as String?;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Username làm tên chính
                    Text(
                      '@$username',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(bio, textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    // Followers & Following
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                                    builder: (_) => FollowersListScreen(userId: uid),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  Text(
                                    followersCount.toString(),
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Người theo dõi',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 32),
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
                                    builder: (_) => FollowingListScreen(userId: uid),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  Text(
                                    followingCount.toString(),
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Đang theo dõi',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

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
                                side: const BorderSide(color: Colors.black),
                              ),
                              child: const Text('Chỉnh sửa',
                                  style: TextStyle(color: Colors.black)),
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
                                        content: Text('Đã sao chép link hồ sơ!')),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black),
                              ),
                              child: const Text('Chia sẻ trang cá nhân',
                                  style: TextStyle(color: Colors.black)),
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

              // Header "Bài viết"
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

              // Danh sách bài viết
              Expanded(
                child: FutureBuilder<bool>(
                  future: isCurrentUserFollower(uid),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snap.data!) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Chỉ những người theo dõi mới có thể xem bài viết này.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot>(
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
                                                    style:
                                                    TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                          : null,
                                    ),

                                    if (content.isNotEmpty)
                                      Padding(
                                        padding:
                                        const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(content,
                                            style: const TextStyle(fontSize: 14)),
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
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                height: 200,
                                                color: Colors.grey.shade300,
                                                child: const Center(
                                                  child: Icon(Icons.broken_image,
                                                      color: Colors.grey),
                                                ),
                                              );
                                            },
                                            loadingBuilder:
                                                (context, child, progress) {
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
                    );
                  },
                ),
              ),
            ],
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
}
