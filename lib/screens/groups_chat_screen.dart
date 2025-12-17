import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import 'members_groups_screen.dart';

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
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  String? _selectedMessageId;
  Map<String, dynamic>? _groupData;
  String? _currentUsername;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
    _loadGroupInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupInfo() async {
    final doc = await _firestore.collection('groups').doc(widget.groupId).get();
    if (doc.exists) {
      setState(() => _groupData = doc.data());
    }
  }

  Future<void> _loadCurrentUsername() async {
    try {
      final userDoc =
      await _firestore.collection('users').doc(widget.currentUserId).get();
      setState(() {
        _currentUsername =
            userDoc.data()?['username'] as String? ?? widget.currentUserId;
      });
    } catch (e) {
      debugPrint('Lỗi load username group chat: $e');
    }
  }

  Future<void> _sendGroupMessageNotifications() async {
    try {
      // Lấy dữ liệu nhóm (ưu tiên state hiện tại)
      final data = _groupData ??
          (await _firestore.collection('groups').doc(widget.groupId).get())
              .data();
      if (data == null) return;

      final membersUsernames =
          (data['members'] as List?)?.cast<String>() ?? <String>[];
      if (membersUsernames.isEmpty) return;
      final groupName = data['name'] as String? ?? 'Chat nhóm';

      // Map từ username -> userId (doc.id) để gửi notification
      const chunkSize = 10; // whereIn tối đa 10 phần tử
      for (var i = 0; i < membersUsernames.length; i += chunkSize) {
        final end = (i + chunkSize < membersUsernames.length)
            ? i + chunkSize
            : membersUsernames.length;
        final chunk = membersUsernames.sublist(i, end);

        final snap = await _firestore
            .collection('users')
            .where('username', whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final targetUserId = doc.id;
          if (targetUserId == widget.currentUserId) continue;

          await _notificationService.createNotification(
            userId: targetUserId,
            type: 'group_message', // type riêng cho tin nhắn nhóm
            fromUserId: widget.currentUserId,
            groupId: widget.groupId,
            groupName: groupName,
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi gửi thông báo tin nhắn nhóm: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final groupDoc = _firestore.collection('groups').doc(widget.groupId);
      final senderName = _currentUsername ?? widget.currentUserId;

      await groupDoc.collection('messages').add({
        'text': text,
        'senderId': widget.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [widget.currentUserId],
      });

      await groupDoc.set({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        // dùng username để đồng bộ với GroupListScreen & CreateGroupScreen
        'lastSenderId': senderName,
        'lastMessageReadBy': [senderName],
      }, SetOptions(merge: true));

      // Gửi notification cho các thành viên khác trong nhóm
      await _sendGroupMessageNotifications();

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi tin nhắn: $e')),
        );
      }
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
      final groupDoc = _firestore.collection('groups').doc(widget.groupId);
      final readerName = _currentUsername ?? userId;
      await groupDoc.set({
        // lưu username để GroupListScreen so sánh với currentUsername
        'lastMessageReadBy': FieldValue.arrayUnion([readerName]),
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

  String _formatFull(Timestamp ts) {
    final d = ts.toDate();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_groupData?['name'] ?? 'Chat nhóm'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            color: Colors.white,
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
                ).then((_) => _loadGroupInfo());
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'members',
                child: Text('Thành viên nhóm',
                    style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
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
                final messages = snapshot.data?.docs ?? [];
                _markMessagesAsRead(messages, widget.currentUserId);
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Hãy bắt đầu trò chuyện trong nhóm!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                    messages[index].data() as Map<String, dynamic>;
                    final text = messageData['text'] as String? ?? '';
                    final senderId = messageData['senderId'] as String? ?? '';
                    final isMe = senderId == widget.currentUserId;
                    final createdAt =
                    messageData['createdAt'] as Timestamp?;
                    final readBy =
                        (messageData['readBy'] as List?)?.cast<String>() ?? [];
                    final isSelected =
                        _selectedMessageId == messages[index].id;

                    // Header ngày (qua ngày mới)
                    DateTime? currentDate = createdAt?.toDate();
                    DateTime? nextDate;
                    if (index < messages.length - 1) {
                      final nextData =
                      messages[index + 1].data() as Map<String, dynamic>;
                      final nextCreatedAt =
                      nextData['createdAt'] as Timestamp?;
                      nextDate = nextCreatedAt?.toDate();
                    }
                    final showDateHeader = currentDate != null &&
                        (nextDate == null ||
                            currentDate.day != nextDate.day ||
                            currentDate.month != nextDate.month ||
                            currentDate.year != nextDate.year);

                    return Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader)
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
                              color:
                              isMe ? null : Colors.grey.shade200,
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
                                    // hiển thị đã đọc bởi số thành viên khác (ngoài mình)
                                    readBy.any((id) => id != widget.currentUserId)
                                        ? 'Đã đọc bởi ${readBy.where((id) => id != widget.currentUserId).length} thành viên'
                                        : 'Đã gửi',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Chọn tin để hiện timestamp đầy đủ
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            setState(() {
                              _selectedMessageId =
                              isSelected ? null : messages[index].id;
                            });
                          },
                          child: const SizedBox(height: 0),
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
              border:
              Border(top: BorderSide(color: Colors.grey.shade300)),
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
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                      : Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFA5D6A7),
                          Color(0xFF81C784)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white),
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
