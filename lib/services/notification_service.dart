import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// ✅ Tạo notification mới
  Future<void> createNotification({
    required String userId,       // người nhận
    required String type,         // 'follow', 'like', 'comment'
    required String fromUserId,   // người thực hiện
    String? postId,               // id bài viết (nếu có)
  }) async {
    try {
      // Không tạo notification cho chính mình
      if (userId == fromUserId) return;

      // Lấy thông tin người gửi
      final fromUserDoc = await _usersRef.doc(fromUserId).get();
      if (!fromUserDoc.exists) return;

      final fromUserData = fromUserDoc.data();
      if (fromUserData == null) return;

      // Tạo notification
      await _notificationsRef.add({
        'userId': userId,
        'type': type,
        'fromUserId': fromUserId,
        'fromUserName': fromUserData['name'] ?? 'Người dùng',
        'fromUserAvatar': fromUserData['avatarUrl'] ?? '',
        'postId': postId ?? '',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Lỗi khi tạo notification: $e');
    }
  }

  /// ✅ Lấy danh sách notifications của user (Stream)
  Stream<QuerySnapshot<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ✅ Đánh dấu notification là đã đọc
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('❌ Lỗi khi markAsRead: $e');
    }
  }

  /// ✅ Đánh dấu tất cả notifications là đã đọc
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('❌ Lỗi khi markAllAsRead: $e');
    }
  }

  /// ✅ Lấy số lượng notifications chưa đọc (Stream)
  Stream<int> getUnreadCountStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// ✅ Lấy số lượng notifications chưa đọc (Future)
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Lỗi khi getUnreadCount: $e');
      return 0;
    }
  }

  /// ✅ Xóa notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).delete();
    } catch (e) {
      print('❌ Lỗi khi deleteNotification: $e');
    }
  }
}
