import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final currentUser = FirebaseAuth.instance.currentUser;

  // Helpers: text + icon + color theo loại thông báo
  String _getNotificationMessage(String type, String fromUserName) {
    switch (type) {
      case 'follow':
        return '$fromUserName đã theo dõi bạn';
      case 'like':
        return '$fromUserName đã thích bài viết của bạn';
      case 'comment':
        return '$fromUserName đã bình luận bài viết của bạn';
      default:
        return '$fromUserName đã tương tác với bạn';
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
      default:
        return Colors.grey;
    }
  }

  // Định dạng thời gian kiểu tương đối
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

  // Khi chạm vào thông báo: mark read + điều hướng
  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final notifId = notification['id'] as String?;
    final isRead = notification['isRead'] == true;
    final type = notification['type'] as String? ?? '';
    final fromUserId = notification['fromUserId'] as String?;
    final postId = notification['postId'] as String?;

    if (!isRead && notifId != null) {
      await _notificationService.markAsRead(notifId);
    }

    if (type == 'follow' && fromUserId != null && fromUserId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: fromUserId)),
      );
      return;
    }

    if (postId != null && postId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
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
          // Nút đánh dấu tất cả là đã đọc (chỉ hiện khi có thông báo chưa đọc)
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationService.getNotificationsStream(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Lỗi truy vấn (ví dụ cần tạo index)
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
                          ? 'Vui lòng vào Firebase Console tạo index cho truy vấn notifications.\n(Where userId + orderBy createdAt)'
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có thông báo nào', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: () async => Future.value(), // Stream tự cập nhật
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final doc = notifications[index];
                final data = doc.data();

                final isRead = data['isRead'] == true;
                final type = (data['type'] ?? '') as String;
                final fromUserName = (data['fromUserName'] ?? 'Người dùng') as String;
                final fromUserAvatar = (data['fromUserAvatar'] ?? '') as String;
                final createdAt = data['createdAt'] is Timestamp
                    ? (data['createdAt'] as Timestamp).toDate()
                    : null;

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    await _notificationService.deleteNotification(doc.id);
                  },
                  child: InkWell(
                    onTap: () => _handleNotificationTap({...data, 'id': doc.id}),
                    child: Container(
                      color: isRead ? Colors.white : Colors.blue.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Avatar hoặc icon theo loại
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _getNotificationColor(type),
                            backgroundImage: (fromUserAvatar.isNotEmpty)
                                ? NetworkImage(fromUserAvatar)
                                : null,
                            child: (fromUserAvatar.isEmpty)
                                ? Icon(_getNotificationIcon(type), color: Colors.white, size: 24)
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Nội dung + thời gian
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getNotificationMessage(type, fromUserName),
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(createdAt),
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Chấm xanh cho chưa đọc
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
}
