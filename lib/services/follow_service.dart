import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Collection references
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
      await _followersRef.doc(docId).set({
        'followerId': followerId,
        'followingId': followingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _updateCounters(followerId, followingId, increment: true);

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
      await _followersRef.doc(docId).delete();
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

  /// Stream trạng thái follow
  Stream<bool> isFollowingStream(String followerId, String followingId) {
    if (followerId == followingId) return Stream.value(false);
    final docId = '${followerId}_$followingId';
    return _followersRef.doc(docId).snapshots().map((doc) => doc.exists);
  }

  /// Stream danh sách followers của một user (ai theo dõi user này)
  Stream<QuerySnapshot> getFollowersStream(String userId) {
    return _followersRef
        .where('followingId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream danh sách following của một user (user này theo dõi ai)
  Stream<QuerySnapshot> getFollowingStream(String userId) {
    return _followersRef
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Lấy số lượng followers
  Future<int> getFollowersCount(String userId) async {
    final snapshot =
    await _followersRef.where('followingId', isEqualTo: userId).get();
    return snapshot.docs.length;
  }

  /// Lấy số lượng following
  Future<int> getFollowingCount(String userId) async {
    final snapshot =
    await _followersRef.where('followerId', isEqualTo: userId).get();
    return snapshot.docs.length;
  }

  /// Stream số lượng followers
  Stream<int> getFollowersCountStream(String userId) {
    return _followersRef
        .where('followingId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream số lượng following
  Stream<int> getFollowingCountStream(String userId) {
    return _followersRef
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Cập nhật counters trong users document
  Future<void> _updateCounters(
      String followerId,
      String followingId, {
        required bool increment,
      }) async {
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