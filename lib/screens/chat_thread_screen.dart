import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class ChatThreadScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String? contactAvatarUrl;

  const ChatThreadScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.contactAvatarUrl,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  String? _selectedMessageId;

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _chatId {
    final user = _currentUser;
    if (user == null) return '';
    final ids = [user.uid, widget.contactId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _sendMessage() async {
    final user = _currentUser;
    if (user == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final chatDoc = _firestore.collection('chats').doc(_chatId);

      await chatDoc.collection('messages').add({
        'text': text,
        'senderId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
      });

      await chatDoc.set({
        'participants': [user.uid, widget.contactId],
        'lastMessage': text,
        'lastMessageSenderId': user.uid,
        'lastMessageReadBy': [user.uid],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await NotificationService().createNotification(
        userId: widget.contactId,
        type: 'message',
        fromUserId: user.uid,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gửi tin nhắn: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markMessagesAsRead(
      List<QueryDocumentSnapshot> messages,
      String userId,
      ) async {
    if (messages.isEmpty) return;

    final batch = _firestore.batch();
    bool hasUpdate = false;

    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String? ?? '';
      final readBy = (data['readBy'] as List?)?.cast<String>() ?? [];

      if (senderId != userId && !readBy.contains(userId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
        hasUpdate = true;
      }
    }

    if (hasUpdate) {
      await batch.commit();
      await _firestore.collection('chats').doc(_chatId).set({
        'lastMessageReadBy': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true));
      if (mounted) setState(() {});
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // reverse: true => vị trí 0 là cuối danh sách
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập để trò chuyện.')),
      );
    }

    final userId = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.contactAvatarUrl != null &&
                  (widget.contactAvatarUrl ?? '').isNotEmpty
                  ? NetworkImage(widget.contactAvatarUrl!)
                  : null,
              child: (widget.contactAvatarUrl ?? '').isEmpty
                  ? Icon(Icons.person, color: colorScheme.onSurface)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.contactName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
          Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];
                _markMessagesAsRead(messages, userId);
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                if (messages.isEmpty) {
                  return const Center(child: Text('Hãy bắt đầu cuộc trò chuyện!'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final text = data['text'] as String? ?? '';
                    final senderId = data['senderId'] as String? ?? '';
                    final isMe = senderId == userId;
                    final createdAt = data['createdAt'] as Timestamp?;
                    final readBy = (data['readBy'] as List?)?.cast<String>() ?? [];
                    final isSelected = _selectedMessageId == messages[index].id;

                    // Tính ngày header (qua ngày mới)
                    DateTime? currentDate = createdAt?.toDate();
                    DateTime? nextDate;
                    if (index < messages.length - 1) {
                      final nextData =
                      messages[index + 1].data() as Map<String, dynamic>;
                      final nextCreatedAt = nextData['createdAt'] as Timestamp?;
                      nextDate = nextCreatedAt?.toDate();
                    }
                    final showDateHeader = currentDate != null &&
                        (nextDate == null ||
                            currentDate.day != nextDate.day ||
                            currentDate.month != nextDate.month ||
                            currentDate.year != nextDate.year);

                    return Column(
                      children: [
                        if (showDateHeader && currentDate != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(currentDate),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMessageId =
                                isSelected ? null : messages[index].id;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? const LinearGradient(
                                  colors: [
                                    Color(0xFFA5D6A7),
                                    Color(0xFF81C784)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                    : null,
                                color: isMe ? null : colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft:
                                  Radius.circular(isMe ? 12 : 0),
                                  bottomRight:
                                  Radius.circular(isMe ? 0 : 12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Trạng thái đọc (đoạn 1-1: người kia đã đọc)
                                      if (isMe)
                                        Text(
                                          readBy.any((id) => id != userId)
                                              ? 'Đã đọc'
                                              : 'Đã gửi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe
                                                ? Colors.white.withOpacity(0.8)
                                                : colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      if (createdAt != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('HH:mm')
                                              .format(createdAt.toDate()),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe
                                                ? Colors.white.withOpacity(0.8)
                                                : colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isSelected && createdAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy HH:mm')
                                            .format(createdAt.toDate()),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isMe
                                              ? Colors.white.withOpacity(0.8)
                                              : colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withOpacity(0.3),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _isSending
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
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
