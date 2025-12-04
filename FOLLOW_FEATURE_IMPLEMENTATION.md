# HƯỚNG DẪN TRIỂN KHAI TÍNH NĂNG THEO DÕI VÀ THÔNG BÁO

## 📋 TỔNG QUAN
Triển khai hệ thống theo dõi (follow/unfollow) với thông báo real-time khi có người theo dõi bạn.

---

## 🗂️ CẤU TRÚC FIRESTORE CẦN TẠO

### 1. Collection `followers` (đã có, cần cải thiện)
```
followers/{followerId_followingId}
{
  followerId: "userId1",      // Người theo dõi
  followingId: "userId2",     // Người được theo dõi
  createdAt: Timestamp
}
```

### 2. Collection `notifications` (MỚI)
```
notifications/{notificationId}
{
  userId: "userId",           // Người nhận thông báo
  type: "follow",             // "follow", "like", "comment", etc.
  fromUserId: "userId",       // Người thực hiện hành động
  fromUserName: "Tên người dùng",
  fromUserAvatar: "url",
  postId: null,               // null nếu là follow, postId nếu là like/comment
  isRead: false,
  createdAt: Timestamp
}
```

### 3. Collection `users` - CẬP NHẬT
Thêm các trường:
```
users/{userId}
{
  email: "...",
  name: "...",
  avatarUrl: "...",
  bio: "...",
  followersCount: 0,          // Số người theo dõi
  followingCount: 0,          // Số người đang theo dõi
  createdAt: Timestamp
}
```

---

## 📝 CÁC BƯỚC TRIỂN KHAI

### BƯỚC 1: Tạo Service/Helper cho Follow System
**File:** `lib/services/follow_service.dart`
- Hàm `followUser(followerId, followingId)`
- Hàm `unfollowUser(followerId, followingId)`
- Hàm `checkIfFollowing(followerId, followingId)`
- Hàm `getFollowers(userId)` - Stream
- Hàm `getFollowing(userId)` - Stream
- Hàm `getFollowersCount(userId)`
- Hàm `getFollowingCount(userId)`
- **Tự động cập nhật counters** khi follow/unfollow
- **Tự động tạo notification** khi follow

### BƯỚC 2: Tạo Service cho Notifications
**File:** `lib/services/notification_service.dart`
- Hàm `createNotification(userId, type, fromUserId, ...)`
- Hàm `getNotifications(userId)` - Stream
- Hàm `markAsRead(notificationId)`
- Hàm `markAllAsRead(userId)`
- Hàm `getUnreadCount(userId)` - Stream

### BƯỚC 3: Cập nhật Profile Screen
**File:** `lib/screens/profile_screen.dart`
- Sử dụng `FollowService` thay vì code trực tiếp
- Hiển thị số followers/following
- Hiển thị danh sách followers/following (có thể click để xem)
- Cải thiện UI button Follow/Unfollow

### BƯỚC 4: Tạo Notifications Screen
**File:** `lib/Feature/NotificationsScreen.dart` hoặc `lib/screens/notifications_screen.dart`
- StreamBuilder để hiển thị notifications real-time
- Phân loại: Follow, Like, Comment
- Mark as read khi click vào notification
- Navigate đến profile/post tương ứng
- Pull to refresh
- Empty state khi không có thông báo

### BƯỚC 5: Cập nhật Home Screen
**File:** `lib/screens/home_screen.dart`
- Thay placeholder Notifications bằng NotificationsScreen thực tế
- Thêm badge số thông báo chưa đọc trên icon

### BƯỚC 6: Cập nhật Bottom Navigation Bar
**File:** `lib/widgets/bottom_nav_bar.dart`
- Thêm badge hiển thị số thông báo chưa đọc trên icon notifications
- Sử dụng StreamBuilder để cập nhật real-time

### BƯỚC 7: Tạo Followers/Following List Screen (Tùy chọn)
**File:** `lib/screens/followers_list_screen.dart`
**File:** `lib/screens/following_list_screen.dart`
- Hiển thị danh sách người theo dõi/đang theo dõi
- Có thể follow/unfollow từ danh sách này
- Navigate đến profile khi click

### BƯỚC 8: Cập nhật User Registration
**File:** `lib/screens/register_screen.dart`
- Thêm `followersCount: 0` và `followingCount: 0` khi tạo user mới

### BƯỚC 9: Tạo Cloud Functions (Tùy chọn - Nâng cao)
**File:** `functions/index.js` (nếu dùng Firebase Functions)
- Tự động tạo notification khi có follow
- Tự động cập nhật counters
- Gửi push notification (nếu cần)

---

## 🔧 CHI TIẾT KỸ THUẬT

### Follow Service Logic:
```dart
Future<void> followUser(String followerId, String followingId) async {
  // 1. Kiểm tra không follow chính mình
  if (followerId == followingId) return;
  
  // 2. Kiểm tra đã follow chưa
  final docId = '${followerId}_$followingId';
  final doc = await followersRef.doc(docId).get();
  if (doc.exists) return;
  
  // 3. Tạo follow document
  await followersRef.doc(docId).set({
    'followerId': followerId,
    'followingId': followingId,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  // 4. Cập nhật counters (sử dụng transaction)
  await _updateCounters(followerId, followingId, increment: true);
  
  // 5. Tạo notification
  await notificationService.createNotification(
    userId: followingId,
    type: 'follow',
    fromUserId: followerId,
  );
}
```

### Notification Service Logic:
```dart
Future<void> createNotification({
  required String userId,
  required String type,
  required String fromUserId,
  String? postId,
}) async {
  // 1. Lấy thông tin người gửi
  final fromUserDoc = await usersRef.doc(fromUserId).get();
  final fromUserData = fromUserDoc.data();
  
  // 2. Tạo notification
  await notificationsRef.add({
    'userId': userId,
    'type': type,
    'fromUserId': fromUserId,
    'fromUserName': fromUserData?['name'] ?? '',
    'fromUserAvatar': fromUserData?['avatarUrl'] ?? '',
    'postId': postId,
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
```

### Update Counters (Transaction):
```dart
Future<void> _updateCounters(
  String followerId,
  String followingId,
  {required bool increment}
) async {
  final batch = FirebaseFirestore.instance.batch();
  
  // Cập nhật followingCount của follower
  final followerRef = usersRef.doc(followerId);
  batch.update(followerRef, {
    'followingCount': FieldValue.increment(increment ? 1 : -1),
  });
  
  // Cập nhật followersCount của following
  final followingRef = usersRef.doc(followingId);
  batch.update(followingRef, {
    'followersCount': FieldValue.increment(increment ? 1 : -1),
  });
  
  await batch.commit();
}
```

---

## 🎨 UI/UX SUGGESTIONS

1. **Profile Screen:**
   - Hiển thị số followers/following có thể click
   - Button Follow/Unfollow có animation
   - Loading state khi đang xử lý

2. **Notifications Screen:**
   - Group notifications theo ngày
   - Avatar của người gửi
   - Icon khác nhau cho từng loại (follow, like, comment)
   - Swipe to mark as read
   - Pull to refresh

3. **Badge trên Bottom Nav:**
   - Hiển thị số thông báo chưa đọc
   - Màu đỏ nổi bật
   - Animation khi có thông báo mới

---

## 📦 DEPENDENCIES CẦN THIẾT

Tất cả dependencies đã có sẵn:
- ✅ `firebase_auth`
- ✅ `cloud_firestore`
- ✅ `firebase_storage`

Không cần thêm package mới!

---

## ✅ CHECKLIST TRIỂN KHAI

- [ ] Tạo `lib/services/follow_service.dart`
- [ ] Tạo `lib/services/notification_service.dart`
- [ ] Cập nhật `profile_screen.dart` sử dụng FollowService
- [ ] Hoàn thiện `NotificationsScreen.dart`
- [ ] Cập nhật `home_screen.dart` với NotificationsScreen
- [ ] Thêm badge vào `bottom_nav_bar.dart`
- [ ] Cập nhật `register_screen.dart` với counters
- [ ] Test follow/unfollow
- [ ] Test notifications real-time
- [ ] Test counters update
- [ ] Test edge cases (follow chính mình, follow 2 lần, etc.)

---

## 🚀 BƯỚC TIẾP THEO

Bạn muốn tôi bắt đầu triển khai từ bước nào? Tôi có thể:
1. Tạo các service files (FollowService, NotificationService)
2. Cập nhật Profile Screen
3. Hoàn thiện Notifications Screen
4. Tất cả các bước trên

Hãy cho tôi biết bạn muốn bắt đầu từ đâu!

