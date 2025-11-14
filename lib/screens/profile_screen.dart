import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'editprofile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  late final String uid;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    uid = widget.userId ?? currentUser!.uid;
    if (widget.userId != null) {
      checkFollowing();
    }
  }

  Future<void> checkFollowing() async {
    final docId = '${currentUser!.uid}_$uid';
    final doc = await FirebaseFirestore.instance.collection('followers').doc(docId).get();
    setState(() => isFollowing = doc.exists);
  }

  Future<void> toggleFollow() async {
    final docId = '${currentUser!.uid}_$uid';
    final ref = FirebaseFirestore.instance.collection('followers').doc(docId);

    if (isFollowing) {
      await ref.delete();
    } else {
      await ref.set({
        'followerId': currentUser!.uid,
        'followingId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() => isFollowing = !isFollowing);
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
                      backgroundImage: avatarUrl != null && avatarUrl != ''
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl == ''
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(bio, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
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
                              child: const Text('Edit Profile', style: TextStyle(color: Colors.black)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // TODO: Chuyển sang trang lưu trữ
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black),
                              ),
                              child: const Text('View Archive', style: TextStyle(color: Colors.black)),
                            ),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: toggleFollow,
                        child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final posts = snapshot.data!.docs;

                    if (posts.isEmpty) {
                      return const Center(child: Text('Chưa có bài viết nào'));
                    }

                    return ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final postDoc = posts[index];
                        final post = postDoc.data() as Map<String, dynamic>;
                        final content = post['content'] ?? '';
                        final imageUrl = post['imageUrl'];
                        final createdAt = post['createdAt'] != null
                            ? (post['createdAt'] as Timestamp).toDate()
                            : null;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(name),
                                subtitle: Text(createdAt != null ? createdAt.toString() : ''),
                                trailing: currentUser != null && currentUser?.uid == uid
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
                              if (imageUrl != null && imageUrl != '')
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(imageUrl, fit: BoxFit.cover),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(content),
                              ),
                            ],
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
}
