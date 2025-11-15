import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  CollectionReference get _followersRef => _firestore.collection('followers');
  CollectionReference get _usersRef => _firestore.collection('users');

  /// Follow một user
  Future<void> followUser(String followerId, String followingId) async {
    if (followerId == followingId) {
      throw Exception('Không thể theo dõi chính mình');
    }

    final docId = '${followerId}_$followingId';
    final doc = await _followersRef.doc(docId).get();
    if (doc.exists) {
      throw Exception('Đã theo dõi người dùng này');
    }

    try {
      // Tạo document trong collection followers toàn cục
      await _followersRef.doc(docId).set({
        'followerId': followerId,
        'followingId': followingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Thêm vào subcollection của user
      await _usersRef.doc(followingId).collection('followers').doc(followerId).set({
        'userId': followerId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _usersRef.doc(followerId).collection('following').doc(followingId).set({
        'userId': followingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cập nhật counters
      await _updateCounters(followerId, followingId, increment: true);

      // Tạo notification
      await _notificationService.createNotification(
        userId: followingId,
        type: 'follow',
        fromUserId: followerId,
      );
    } catch (e) {
      throw Exception('Lỗi khi theo dõi: $e');
    }
  }

  /// Unfollow một user
  Future<void> unfollowUser(String followerId, String followingId) async {
    final docId = '${followerId}_$followingId';
    final doc = await _followersRef.doc(docId).get();
    if (!doc.exists) {
      throw Exception('Chưa theo dõi người dùng này');
    }

    try {
      // Xóa document trong collection followers toàn cục
      await _followersRef.doc(docId).delete();

      // Xóa trong subcollection
      await _usersRef.doc(followingId).collection('followers').doc(followerId).delete();
      await _usersRef.doc(followerId).collection('following').doc(followingId).delete();

      // Cập nhật counters
      await _updateCounters(followerId, followingId, increment: false);
    } catch (e) {
      throw Exception('Lỗi khi bỏ theo dõi: $e');
    }
  }

  /// Kiểm tra trạng thái follow
  Future<bool> checkIfFollowing(String followerId, String followingId) async {
    if (followerId == followingId) return false;
    final docId = '${followerId}_$followingId';
    final doc = await _followersRef.doc(docId).get();
    return doc.exists;
  }

  Stream<bool> isFollowingStream(String followerId, String followingId) {
    if (followerId == followingId) return Stream.value(false);
    final docId = '${followerId}_$followingId';
    return _followersRef.doc(docId).snapshots().map((doc) => doc.exists);
  }

  /// Lấy danh sách followers
  Stream<QuerySnapshot> getFollowersStream(String userId) {
    return _usersRef.doc(userId).collection('followers').orderBy('createdAt', descending: true).snapshots();
  }

  /// Lấy danh sách following
  Stream<QuerySnapshot> getFollowingStream(String userId) {
    return _usersRef.doc(userId).collection('following').orderBy('createdAt', descending: true).snapshots();
  }

  /// Đếm số lượng followers
  Future<int> getFollowersCount(String userId) async {
    final snapshot = await _usersRef.doc(userId).collection('followers').get();
    return snapshot.docs.length;
  }

  /// Đếm số lượng following
  Future<int> getFollowingCount(String userId) async {
    final snapshot = await _usersRef.doc(userId).collection('following').get();
    return snapshot.docs.length;
  }

  /// Stream số lượng followers
  Stream<int> getFollowersCountStream(String userId) {
    return _usersRef.doc(userId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['followersCount'] ?? 0;
    });
  }

  /// Stream số lượng following
  Stream<int> getFollowingCountStream(String userId) {
    return _usersRef.doc(userId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['followingCount'] ?? 0;
    });
  }

  /// Cập nhật counters
  Future<void> _updateCounters(String followerId, String followingId, {required bool increment}) async {
    final batch = _firestore.batch();

    final followerRef = _usersRef.doc(followerId);
    batch.update(followerRef, {
      'followingCount': FieldValue.increment(increment ? 1 : -1),
    });

    final followingRef = _usersRef.doc(followingId);
    batch.update(followingRef, {
      'followersCount': FieldValue.increment(increment ? 1 : -1),
    });

    await batch.commit();
  }

  /// Lấy thông tin user
  Future<DocumentSnapshot> getUserInfo(String userId) async {
    return await _usersRef.doc(userId).get();
  }
}
