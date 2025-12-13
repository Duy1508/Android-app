import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'members_groups_screen.dart'; // đảm bảo đường dẫn đúng

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSending = false;
  String? _selectedMessageId;
  Map<String, dynamic>? _groupData;

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupInfo() async {
    final doc = await _firestore.collection('groups').doc(widget.groupId).get();
    if (doc.exists) {
      setState(() => _groupData = doc.data());
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final groupDoc = _firestore.collection('groups').doc(widget.groupId);

      await groupDoc.collection('messages').add({
        'text': text,
        'senderId': widget.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [widget.currentUserId],
      });

      await groupDoc.set({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': widget.currentUserId,
        'lastMessageReadBy': [widget.currentUserId],
      }, SetOptions(merge: true));

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gửi tin nhắn: $e')),
      );
    } finally {
      setState(() => _isSending = false);
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
      if (count >= 20) break;
    }

    if (count > 0) {
      await batch.commit();
      final groupDoc = _firestore.collection('groups').doc(widget.groupId);
      await groupDoc.set({
        'lastMessageReadBy': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupData?['name'] ?? 'Chat nhóm'),
        backgroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            color: Colors.white, // ✅ nền trắng cho toàn bộ menu
            onSelected: (value) {
              if (value == 'members') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MembersGroupScreen(
                      groupId: widget.groupId,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                ).then((_) => _loadGroupInfo()); // refresh tên nhóm nếu đổi
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'members',
                child: const Text(
                  'Thành viên nhóm',
                  style: TextStyle(color: Colors.black), // ✅ chữ đen
                ),
              ),
            ],
          )

        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Hãy bắt đầu trò chuyện trong nhóm!'),
                  );
                }

                final messages = snapshot.data!.docs;
                _markMessagesAsRead(messages, userId);

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                    messages[index].data() as Map<String, dynamic>;
                    final text = messageData['text'] as String? ?? '';
                    final senderId = messageData['senderId'] as String? ?? '';
                    final isMe = senderId == userId;
                    final createdAt = messageData['createdAt'] as Timestamp?;
                    final readBy =
                        (messageData['readBy'] as List?)?.cast<String>() ?? [];
                    final isSelected = _selectedMessageId == messages[index].id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMessageId =
                          isSelected ? null : messages[index].id;
                        });
                      },
                      child: Align(
                        alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (isSelected && createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  _formatFull(createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Container(
                                margin:
                                const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blueAccent
                                      : Colors.grey.shade200,
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
                                            : Colors.black,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (isMe)
                                      Text(
                                        readBy.length > 1
                                            ? 'Đã đọc bởi ${readBy.length - 1} thành viên'
                                            : 'Đã gửi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    child:
                    CircularProgressIndicator(strokeWidth: 2),
                  )
                      : IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.blueAccent),
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

  String _formatFull(Timestamp ts) {
    final d = ts.toDate();
    return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
