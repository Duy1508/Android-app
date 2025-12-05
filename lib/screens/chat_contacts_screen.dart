import 'dart:async';

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
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<List<String>> _chunkIds(List<String> ids, {int size = 10}) {
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += size) {
      chunks.add(ids.sublist(i, i + size > ids.length ? ids.length : i + size));
    }
    return chunks;
  }

  String _chatIdFor(String otherUserId) {
    final user = _currentUser;
    if (user == null) return '';
    final ids = [user.uid, otherUserId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsersByIds(
    List<String> ids,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final chunk in _chunkIds(ids)) {
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = doc.data();
      }
    }
    return result;
  }

  Future<List<_ChatContact>> _buildContacts(
    List<String> contactIds,
    Set<String> pinnedIds,
  ) async {
    final users = await _fetchUsersByIds(contactIds);
    final chatDocs = await Future.wait(
      contactIds.map((id) async {
        final chatId = _chatIdFor(id);
        if (chatId.isEmpty) return null;
        final doc = await _firestore.collection('chats').doc(chatId).get();
        return doc.exists ? doc : null;
      }),
    );

    final chatMap = <String, DocumentSnapshot>{};
    for (final doc in chatDocs.whereType<DocumentSnapshot>()) {
      chatMap[doc.id] = doc;
    }

    final contacts = users.entries.map((entry) {
      final data = entry.value;
      final displayName = (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : data['email'] as String? ?? 'Người dùng';
      final chatId = _chatIdFor(entry.key);
      final chatDoc = chatMap[chatId];
      final chatData = chatDoc != null
          ? chatDoc.data() as Map<String, dynamic>?
          : null;
      final lastMessage = chatData?['lastMessage'] as String? ?? '';
      final lastMessageSenderId =
          chatData?['lastMessageSenderId'] as String? ?? '';
      final lastMessageReadBy =
          (chatData?['lastMessageReadBy'] as List?)?.cast<String>() ?? const [];
      final updatedAt = chatData?['updatedAt'] as Timestamp?;
      final isUnread =
          lastMessage.isNotEmpty &&
          lastMessageSenderId.isNotEmpty &&
          lastMessageSenderId != _currentUser?.uid &&
          !lastMessageReadBy.contains(_currentUser?.uid);

      return _ChatContact(
        userId: entry.key,
        name: displayName,
        email: data['email'] as String? ?? '',
        avatarUrl: data['avatarUrl'] as String?,
        bio: data['bio'] as String? ?? '',
        isPinned: pinnedIds.contains(entry.key),
        lastMessage: lastMessage,
        lastMessageAt: updatedAt,
        isUnread: isUnread,
      );
    }).toList();

    contacts.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final aTime =
          a.lastMessageAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.lastMessageAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (aTime != bTime) {
        return bTime.compareTo(aTime);
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
                  final filtered = _searchTerm.isEmpty
                      ? contacts
                      : contacts
                            .where(
                              (c) =>
                                  c.name.toLowerCase().contains(_searchTerm) ||
                                  c.email.toLowerCase().contains(_searchTerm) ||
                                  c.bio.toLowerCase().contains(_searchTerm),
                            )
                            .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Không tìm thấy danh bạ hợp lệ.'),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Tìm kiếm người đã theo dõi để chat',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 250),
                              () {
                                setState(
                                  () => _searchTerm = value.toLowerCase(),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final contact = filtered[index];
                            final lastMsg = contact.lastMessage;
                            final subtitle = lastMsg.isNotEmpty
                                ? '${contact.isUnread ? '[Chưa đọc] ' : ''}$lastMsg'
                                : (contact.bio.isNotEmpty
                                      ? contact.bio
                                      : contact.email);
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
                              subtitle: subtitle.isNotEmpty
                                  ? Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: contact.isUnread
                                          ? const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            )
                                          : null,
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
                                onPressed: () => _togglePin(
                                  contact.userId,
                                  contact.isPinned,
                                ),
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
                        ),
                      ),
                    ],
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
  final String email;
  final String? avatarUrl;
  final String bio;
  final bool isPinned;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final bool isUnread;

  _ChatContact({
    required this.userId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    required this.isPinned,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.isUnread,
  });
}
