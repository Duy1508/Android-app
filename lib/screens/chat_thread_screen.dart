import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  String? _selectedMessageId;
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isSending = false;

  @override
  void dispose() {
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

      // 1) Lưu message vào sub-collection
      await chatDoc.collection('messages').add({
        'text': text,
        'senderId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user.uid], // người gửi mặc định đã đọc
      });

      // 2) Cập nhật thông tin chat
      await chatDoc.set({
        'participants': [user.uid, widget.contactId],
        'lastMessage': text,
        'lastMessageSenderId': user.uid,
        'lastMessageReadBy': [user.uid],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) Tạo notification cho người nhận
      final notificationService = NotificationService();
      await notificationService.createNotification(
        userId: widget.contactId,     // người nhận tin nhắn
        type: 'message',
        fromUserId: user.uid,
      );

      // 4) Xóa nội dung trong TextField
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi tin nhắn: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }


  Future<void> _markMessagesAsRead(
      List<QueryDocumentSnapshot> messages,
      String userId,
      ) async {
    int count = 0;
    final batch = _firestore.batch();
    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String? ?? '';
      if (senderId == userId) continue;
      final readBy = (data['readBy'] as List?)?.cast<String>() ?? [];
      if (readBy.contains(userId)) continue;
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([userId]),
      });
      count++;
      if (count >= 20) break; // tránh batch quá lớn mỗi lần build
    }

    if (count > 0) {
      await batch.commit();
      // đồng bộ trạng thái đọc với chat doc cho badge
      final chatDoc = _firestore.collection('chats').doc(_chatId);
      await chatDoc.set({
        'lastMessageReadBy': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true));
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
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
              backgroundImage:
              widget.contactAvatarUrl != null &&
                  widget.contactAvatarUrl!.isNotEmpty
                  ? NetworkImage(widget.contactAvatarUrl!)
                  : null,
              child:
              widget.contactAvatarUrl == null ||
                  widget.contactAvatarUrl!.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.contactName, overflow: TextOverflow.ellipsis),
            ),
          ],
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Hãy bắt đầu cuộc trò chuyện!'),
                  );
                }

                final messages = snapshot.data!.docs;
                // Đánh dấu đã đọc cho các tin nhắn chưa đọc của đối phương
                _markMessagesAsRead(messages, userId);

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final text = messageData['text'] as String? ?? '';
                    final senderId = messageData['senderId'] as String? ?? '';
                    final isMe = senderId == userId;
                    final createdAt = messageData['createdAt'] as Timestamp?;
                    final readBy = (messageData['readBy'] as List?)?.cast<String>() ?? [];
                    final isReadByOther = isMe && readBy.contains(widget.contactId);

                    final messageDate = createdAt?.toDate();

                    // --- Separator ngày ---
                    String? separatorLabel;
                    bool showSeparator = false;
                    if (messageDate != null) {
                      separatorLabel = DateFormat('dd/MM').format(messageDate);
                      if (index == messages.length - 1) {
                        showSeparator = true;
                      } else {
                        final prevData = messages[index + 1].data() as Map<String, dynamic>;
                        final prevCreatedAt = prevData['createdAt'] as Timestamp?;
                        if (prevCreatedAt != null) {
                          final prevDate = prevCreatedAt.toDate();
                          if (prevDate.day != messageDate.day ||
                              prevDate.month != messageDate.month ||
                              prevDate.year != messageDate.year) {
                            showSeparator = true;
                          }
                        }
                      }
                    }

                    // --- Hiển thị giờ nếu cách tin trước ≥ 5 phút ---
                    bool showTime = false;
                    if (index == messages.length - 1) {
                      showTime = true; // tin đầu tiên luôn hiển thị giờ
                    } else {
                      final prevData = messages[index + 1].data() as Map<String, dynamic>;
                      final prevCreatedAt = prevData['createdAt'] as Timestamp?;
                      if (prevCreatedAt != null && createdAt != null) {
                        final prevDate = prevCreatedAt.toDate();
                        final diff = prevDate.difference(messageDate!).inMinutes.abs();
                        if (diff >= 5) {
                          showTime = true;
                        }
                      }
                    }

                    return Column(
                      children: [
                        if (showSeparator && separatorLabel != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              separatorLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        if (showTime && messageDate != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              DateFormat('HH:mm').format(messageDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMessageId = _selectedMessageId == messages[index].id
                                  ? null
                                  : messages[index].id;
                            });
                          },
                          child: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                // Hiển thị giờ:phút chính xác khi tin nhắn được chọn
                                if (_selectedMessageId == messages[index].id && createdAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.blueAccent : Colors.grey.shade200,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(12),
                                        topRight: const Radius.circular(12),
                                        bottomLeft: Radius.circular(isMe ? 12 : 0),
                                        bottomRight: Radius.circular(isMe ? 0 : 12),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            isReadByOther ? 'Đã đọc' : 'Đã gửi',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isMe ? Colors.white70 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
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
                      : IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.blueAccent,
                    ),
                    onPressed: _sendMessage,
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