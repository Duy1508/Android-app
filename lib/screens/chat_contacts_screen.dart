import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/follow_service.dart';
import 'chat_thread_screen.dart';

class ChatContactsScreen extends StatefulWidget {
  const ChatContactsScreen({super.key});

  @override
  State<ChatContactsScreen> createState() => _ChatContactsScreenState();
}

class _ChatContactsScreenState extends State<ChatContactsScreen> {
  final FollowService _followService = FollowService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<List<_ChatContact>> _buildContacts(
    List<String> contactIds,
    Set<String> pinnedIds,
  ) async {
    final futures = contactIds.map((id) async {
      final doc = await _firestore.collection('users').doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final displayName = (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : data['email'] as String? ?? 'Người dùng';
      return _ChatContact(
        userId: id,
        name: displayName,
        avatarUrl: data['avatarUrl'] as String?,
        bio: data['bio'] as String? ?? '',
        isPinned: pinnedIds.contains(id),
      );
    }).toList();

    final contacts = (await Future.wait(
      futures,
    )).whereType<_ChatContact>().toList();

    contacts.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return contacts;
  }

  Future<void> _togglePin(String contactId, bool isPinned) async {
    final user = _currentUser;
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    await docRef.update({
      'pinnedChatContacts': isPinned
          ? FieldValue.arrayRemove([contactId])
          : FieldValue.arrayUnion([contactId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập để xem danh bạ.')),
      );
    }

    final userId = user.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Trò chuyện')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(
              child: Text('Không tìm thấy thông tin người dùng.'),
            );
          }

          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final pinnedList = List<String>.from(
            userData['pinnedChatContacts'] ?? const [],
          );
          final pinnedSet = pinnedList.toSet();

          return StreamBuilder<QuerySnapshot>(
            stream: _followService.getFollowingStream(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('Bạn chưa theo dõi ai để trò chuyện.'),
                );
              }

              final followingIds = snapshot.data!.docs
                  .map(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['followingId'],
                  )
                  .whereType<String>()
                  .toSet()
                  .toList();

              if (followingIds.isEmpty) {
                return const Center(
                  child: Text('Chưa có người nào trong danh sách trò chuyện.'),
                );
              }

              return FutureBuilder<List<_ChatContact>>(
                future: _buildContacts(followingIds, pinnedSet),
                builder: (context, contactsSnapshot) {
                  if (contactsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final contacts = contactsSnapshot.data ?? [];

                  if (contacts.isEmpty) {
                    return const Center(
                      child: Text('Không tìm thấy danh bạ hợp lệ.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: contacts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              contact.avatarUrl != null &&
                                  contact.avatarUrl!.isNotEmpty
                              ? NetworkImage(contact.avatarUrl!)
                              : null,
                          child:
                              contact.avatarUrl == null ||
                                  contact.avatarUrl!.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(contact.name),
                        subtitle: contact.bio.isNotEmpty
                            ? Text(
                                contact.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: IconButton(
                          icon: Icon(
                            contact.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            color: contact.isPinned
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          onPressed: () =>
                              _togglePin(contact.userId, contact.isPinned),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatThreadScreen(
                                contactId: contact.userId,
                                contactName: contact.name,
                                contactAvatarUrl: contact.avatarUrl,
                              ),
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
        },
      ),
    );
  }
}

class _ChatContact {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String bio;
  final bool isPinned;

  _ChatContact({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.isPinned,
  });
}
