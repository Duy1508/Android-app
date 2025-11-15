import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'editprofile_screen.dart';
import '../services/follow_service.dart';
import 'followers_list_screen.dart';
import 'following_list_screen.dart';

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
      final isFollowing = await _followService.checkIfFollowing(currentUser!.uid, uid);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.userId != null,
        title: const Text('Trang cá nhân', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? '';
          final email = data['email'] ?? '';
          final bio = data['bio'] ?? '';
          final avatarUrl = data['avatarUrl'];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: avatarUrl != null && avatarUrl != '' ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null || avatarUrl == '' ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                          builder: (context, snapshot) {
                            final followersCount = snapshot.data ?? data['followersCount'] ?? 0;
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
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Người theo dõi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 32),
                        StreamBuilder<int>(
                          stream: _followService.getFollowingCountStream(uid),
                          builder: (context, snapshot) {
                            final followingCount = snapshot.data ?? data['followingCount'] ?? 0;
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
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Đang theo dõi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Actions
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
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black)),
                              child: const Text('Edit Profile', style: TextStyle(color: Colors.black)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // TODO: Navigate to archive
                              },
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black)),
                              child: const Text('View Archive', style: TextStyle(color: Colors.black)),
                            ),
                          ),
                        ],
                      )
                    else
                      StreamBuilder<bool>(
                        stream: _followService.isFollowingStream(currentUser?.uid ?? '', uid),
                        builder: (context, snapshot) {
                          final isFollowing = snapshot.data ?? false;
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                    const Text('Bài viết', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .where('userId', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final postCount = snapshot.data?.docs.length ?? 0;
                        return Text('($postCount)', style: const TextStyle(fontSize: 16, color: Colors.grey));
                      },
                    ),
                  ],
                ),
              ),

              // Danh sách bài viết
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      final error = snapshot.error.toString();
                      final isIndexError = error.contains('index') || error.contains('FAILED_PRECONDITION');

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text(
                                isIndexError ? 'Cần tạo index trong Firestore' : 'Đã xảy ra lỗi',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isIndexError
                                    ? 'Vui lòng kiểm tra Firebase Console để tạo index cần thiết.\nXem file FIX_FIRESTORE_ERRORS.md để biết chi tiết.'
                                    : error,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Chưa có bài viết nào', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }

                    final posts = snapshot.data!.docs;

                    return RefreshIndicator(
                      onRefresh: () async {},
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final postDoc = posts[index];
                          final post = postDoc.data() as Map<String, dynamic>;
                          final content = post['content'] ?? '';
                          final imageUrl = post['imageUrl'];
                          final createdAt = post['createdAt'] != null ? (post['createdAt'] as Timestamp).toDate() : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header với avatar và tên
                                ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: avatarUrl != null && avatarUrl != '' ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null || avatarUrl == '' ? const Icon(Icons.person, size: 20) : null,
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    createdAt != null ? _formatDateTime(createdAt) : '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: currentUser != null && currentUser?.uid == uid
                                      ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
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
                                        if (confirm == true && mounted) {
                                          await postDoc.reference.delete();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Đã xóa bài viết')),
                                          );
                                        }
                                      } else if (value == 'edit') {
                                        final controller = TextEditingController(text: content);
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Sửa bài viết'),
                                            content: TextField(
                                              controller: controller,
                                              maxLines: 5,
                                              decoration: const InputDecoration(
                                                hintText: 'Nhập nội dung mới...',
                                                border: OutlineInputBorder(),
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
                                        if (confirm == true && mounted) {
                                          await postDoc.reference.update({'content': controller.text});
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Đã cập nhật bài viết')),
                                          );
                                        }
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

                                // Nội dung bài viết
                                if (content.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(content, style: const TextStyle(fontSize: 14)),
                                  ),

                                // Hình ảnh
                                if (imageUrl != null && imageUrl != '')
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
                                              child: Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            height: 200,
                                            color: Colors.grey.shade200,
                                            child: const Center(child: CircularProgressIndicator()),
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
          );
        },
      ),
    );
  }
}
