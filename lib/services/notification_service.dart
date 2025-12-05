import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _notificationsRef => _firestore.collection('notifications');
  CollectionReference get _usersRef => _firestore.collection('users');

  /// Tạo notification mới
  Future<void> createNotification({
    required String userId,
    required String type,
    required String fromUserId,
    String? postId,
  }) async {
    try {
      // Không tạo notification cho chính mình
      if (userId == fromUserId) return;

      // Lấy thông tin người gửi
      final fromUserDoc = await _usersRef.doc(fromUserId).get();
      if (!fromUserDoc.exists) return;

      final fromUserData = fromUserDoc.data() as Map<String, dynamic>?;
      if (fromUserData == null) return;

      // Tạo notification
      await _notificationsRef.add({
        'userId': userId,
        'type': type, // 'follow', 'like', 'comment'
        'fromUserId': fromUserId,
        'fromUserName': fromUserData['name'] ?? 'Người dùng',
        'fromUserAvatar': fromUserData['avatarUrl'] ?? '',
        'postId': postId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Lỗi khi tạo notification: $e');
    }
  }

  /// Lấy danh sách notifications của user (Stream)
  Stream<QuerySnapshot> getNotificationsStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Đánh dấu notification là đã đọc
  Future<void> markAsRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Đánh dấu tất cả notifications là đã đọc
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Lấy số lượng notifications chưa đọc (Stream)
  Stream<int> getUnreadCountStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Lấy số lượng notifications chưa đọc (Future)
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  /// Xóa notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef.doc(notificationId).delete();
  }
}
