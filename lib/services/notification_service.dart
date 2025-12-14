import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Tạo notification mới trong Firestore
  Future<void> createNotification({
    required String userId,
    required String type, // 'follow', 'like', 'comment', 'message'
    required String fromUserId,
    String? postId,
  }) async {
    try {
      if (userId == fromUserId) return;

      final fromUserDoc = await _usersRef.doc(fromUserId).get();
      if (!fromUserDoc.exists) return;

      final fromUserData = fromUserDoc.data();
      if (fromUserData == null) return;

      await _notificationsRef.add({
        'userId': userId,
        'type': type,
        'fromUserId': fromUserId,
        'fromUserName': fromUserData['username'] ?? 'Người dùng', // đổi sang username
        'fromUserAvatar': fromUserData['avatarUrl'] ?? '',
        'postId': postId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Lỗi khi tạo notification: $e');
    }
  }

  /// Lưu token FCM vào Firestore theo userId
  Future<void> saveTokenToUser(String userId, String token) async {
    try {
      await _usersRef.doc(userId).update({'fcmToken': token});
      debugPrint('Đã lưu FCM token cho user $userId');
    } catch (e) {
      debugPrint('Lỗi khi lưu token: $e');
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
    await _notificationsRef.doc(notificationId).update({'isRead': true});
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

  // -----------------------------
  // Firebase Messaging (FCM)
  // -----------------------------

  /// Khởi tạo FCM: xin quyền, lấy token, lưu vào Firestore, lắng nghe các trạng thái
  Future<void> initFCM(BuildContext context, String userId) async {
    try {
      // Xin quyền (iOS + Android 13+)
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Lấy token FCM
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await saveTokenToUser(userId, token);
      }

      // Lắng nghe token thay đổi
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token refreshed: $newToken');
        await saveTokenToUser(userId, newToken);
      });

      // Nhận thông báo khi app đang mở (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Thông báo foreground: ${message.notification?.title}');
        // TODO: hiển thị local notification hoặc snackbar
      });

      // Người dùng bấm thông báo mở app (background → foreground)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Người dùng bấm thông báo: ${message.data}');
        // TODO: điều hướng đến màn hình phù hợp
      });

      // App mở từ trạng thái terminated (cold start)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App mở từ thông báo: ${initialMessage.data}');
        // TODO: điều hướng đến màn hình phù hợp
      }
    } catch (e) {
      debugPrint('Lỗi khi khởi tạo FCM: $e');
    }
  }
}