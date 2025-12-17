import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';
import 'comment_screen.dart';
import 'chat_thread_screen.dart';
import 'groups_chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final currentUser = FirebaseAuth.instance.currentUser;

  String _getNotificationMessage(String type, String fromUserName) {
    switch (type) {
      case 'follow':
        return '$fromUserName đã theo dõi bạn';
      case 'like':
        return '$fromUserName đã thích bài viết của bạn';
      case 'comment':
        return '$fromUserName đã bình luận bài viết của bạn';
      case 'message':
        return '$fromUserName đã gửi cho bạn 1 tin nhắn';
      case 'group_message':
        return '$fromUserName đã gửi 1 tin nhắn trong nhóm';
      default:
        return '$fromUserName có hoạt động mới';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'group_message':
        return Icons.group;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'follow':
        return Colors.blue;
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.orange;
      case 'message':
        return Colors.green;
      case 'group_message':
        return Colors.purple;
      default:
        return Colors.yellow;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    if (!notification['isRead']) {
      await _notificationService.markAsRead(notification['id']);
    }

    final type = notification['type'];
    final fromUserId = notification['fromUserId'];
    final fromUserName = notification['fromUserName']; // nếu bạn lưu kèm tên
    final fromUserAvatar = notification['fromUserAvatar']; // nếu bạn lưu kèm avatar
    final postId = notification['postId'];
    final groupId = notification['groupId'];

    if (type == 'follow') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: fromUserId),
        ),
      );
    } else if (type == 'comment' && postId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommentScreen(postId: postId),
        ),
      );
    } else if (type == 'message') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            contactId: fromUserId,
            contactName: fromUserName ?? 'Người dùng',
            contactAvatarUrl: fromUserAvatar,
          ),
        ),
      );
    } else if (type == 'group_message' && groupId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: groupId,
            currentUserId: currentUser!.uid,
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCountStream(currentUser!.uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();

              return TextButton(
                onPressed: () async {
                  await _notificationService.markAllAsRead(currentUser!.uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc')),
                    );
                  }
                },
                child: const Text('Đánh dấu tất cả'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getNotificationsStream(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            final isIndexError = error.contains('index') ||
                error.contains('FAILED_PRECONDITION');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIndexError
                          ? 'Cần tạo index trong Firestore'
                          : 'Đã xảy ra lỗi',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIndexError
                          ? 'Vui lòng kiểm tra Firebase Console để tạo index cần thiết.\nXem file FIX_FIRESTORE_ERRORS.md để biết chi tiết.'
                          : error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có thông báo nào',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: () async {
              // Stream sẽ tự động cập nhật
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final doc = notifications[index];
                final notification = doc.data() as Map<String, dynamic>;
                final isRead = notification['isRead'] ?? false;
                final type = notification['type'] ?? '';
                final fromUserName = notification['fromUserName'] ?? 'Người dùng';
                final fromUserAvatar = notification['fromUserAvatar'];
                final createdAt = notification['createdAt'] as Timestamp?;

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _notificationService.deleteNotification(doc.id);
                  },
                  child: InkWell(
                    onTap: () => _handleNotificationTap({
                      ...notification,
                      'id': doc.id,
                    }),
                    child: Container(
                      color: isRead ? Colors.white : Colors.blue.shade50,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _getNotificationColor(type),
                            backgroundImage: fromUserAvatar != null && fromUserAvatar != ''
                                ? NetworkImage(fromUserAvatar)
                                : null,
                            child: fromUserAvatar == null || fromUserAvatar == ''
                                ? Icon(
                              _getNotificationIcon(type),
                              color: Colors.white,
                              size: 26,
                            )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getNotificationMessage(type, fromUserName),
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(createdAt.toDate()),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Unread indicator
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
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