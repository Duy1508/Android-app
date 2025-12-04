# CẤU TRÚC FIRESTORE CẦN THIẾT

## 📋 Tổng quan
File này mô tả cấu trúc Firestore collections và fields cần thiết cho tính năng Follow và Notifications.

---

## 🔥 COLLECTIONS VÀ CẤU TRÚC

### 1. Collection: `users` (Đã có, cần cập nhật)

**Cấu trúc document:**
```javascript
users/{userId}
{
  email: string,
  name: string,
  avatarUrl: string | null,
  bio: string,
  followersCount: number,    // ⭐ MỚI - Số người theo dõi
  followingCount: number,    // ⭐ MỚI - Số người đang theo dõi
  createdAt: Timestamp
}
```

**Indexes cần tạo:**
- Không cần index đặc biệt cho collection này

**Lưu ý:**
- Các user cũ có thể không có `followersCount` và `followingCount`
- Code sẽ tự động xử lý với giá trị mặc định là 0
- Khi follow/unfollow, counters sẽ tự động được cập nhật

---

### 2. Collection: `followers` (Đã có, cần đảm bảo đúng cấu trúc)

**Cấu trúc document:**
```javascript
followers/{followerId_followingId}
{
  followerId: string,       // ID của người theo dõi
  followingId: string,       // ID của người được theo dõi
  createdAt: Timestamp
}
```

**Indexes cần tạo:**
1. **Composite Index cho query followers:**
   - Collection: `followers`
   - Fields: `followingId` (Ascending), `createdAt` (Descending)
   - Query scope: Collection

2. **Composite Index cho query following:**
   - Collection: `followers`
   - Fields: `followerId` (Ascending), `createdAt` (Descending)
   - Query scope: Collection

**Lưu ý:**
- Document ID format: `{followerId}_{followingId}`
- Mỗi follow relationship là một document riêng biệt
- Khi unfollow, document sẽ bị xóa

---

### 3. Collection: `notifications` (⭐ MỚI - Cần tạo)

**Cấu trúc document:**
```javascript
notifications/{notificationId}
{
  userId: string,           // ID của người nhận thông báo
  type: string,             // 'follow', 'like', 'comment'
  fromUserId: string,       // ID của người thực hiện hành động
  fromUserName: string,     // Tên người gửi (để hiển thị nhanh)
  fromUserAvatar: string,   // Avatar người gửi (để hiển thị nhanh)
  postId: string | null,     // ID của post (null nếu là follow)
  isRead: boolean,          // Đã đọc chưa
  createdAt: Timestamp
}
```

**Indexes cần tạo:**
1. **Composite Index cho query notifications:**
   - Collection: `notifications`
   - Fields: `userId` (Ascending), `createdAt` (Descending)
   - Query scope: Collection

2. **Composite Index cho query unread notifications:**
   - Collection: `notifications`
   - Fields: `userId` (Ascending), `isRead` (Ascending)
   - Query scope: Collection

**Lưu ý:**
- Document ID sẽ được tự động tạo bởi Firestore (sử dụng `.add()`)
- `fromUserName` và `fromUserAvatar` được lưu để tránh phải query thêm từ collection `users`
- `postId` có thể null nếu notification không liên quan đến post (ví dụ: follow)

---

## 🛠️ CÁCH TẠO INDEXES TRONG FIRESTORE

### Cách 1: Tự động (Khuyến nghị)
1. Chạy app và thực hiện các query
2. Firebase Console sẽ hiển thị link để tạo index
3. Click vào link và tạo index

### Cách 2: Thủ công trong Firebase Console
1. Vào Firebase Console → Firestore Database
2. Click vào tab "Indexes"
3. Click "Create Index"
4. Chọn collection và thêm các fields theo yêu cầu
5. Click "Create"

---

## 📝 RULES CẦN THIẾT (Security Rules)

### Collection: `followers`
```javascript
match /followers/{followId} {
  // Chỉ cho phép đọc nếu là follower hoặc following
  allow read: if request.auth != null && 
    (resource.data.followerId == request.auth.uid || 
     resource.data.followingId == request.auth.uid);
  
  // Chỉ cho phép tạo nếu followerId là current user
  allow create: if request.auth != null && 
    request.resource.data.followerId == request.auth.uid;
  
  // Chỉ cho phép xóa nếu followerId là current user
  allow delete: if request.auth != null && 
    resource.data.followerId == request.auth.uid;
}
```

### Collection: `notifications`
```javascript
match /notifications/{notificationId} {
  // Chỉ cho phép đọc notifications của chính mình
  allow read: if request.auth != null && 
    resource.data.userId == request.auth.uid;
  
  // Không cho phép tạo trực tiếp (chỉ qua service)
  allow create: if false;
  
  // Chỉ cho phép update isRead của chính mình
  allow update: if request.auth != null && 
    resource.data.userId == request.auth.uid &&
    request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['isRead']);
  
  // Chỉ cho phép xóa notifications của chính mình
  allow delete: if request.auth != null && 
    resource.data.userId == request.auth.uid;
}
```

### Collection: `users`
```javascript
match /users/{userId} {
  // Cho phép đọc tất cả users
  allow read: if request.auth != null;
  
  // Chỉ cho phép update counters và thông tin của chính mình
  allow update: if request.auth != null && 
    userId == request.auth.uid;
}
```

---

## ✅ CHECKLIST SETUP

- [ ] Đảm bảo collection `users` có fields `followersCount` và `followingCount`
- [ ] Tạo collection `notifications` (nếu chưa có)
- [ ] Tạo index cho `followers` collection (2 indexes)
- [ ] Tạo index cho `notifications` collection (2 indexes)
- [ ] Cập nhật Security Rules cho các collections
- [ ] Test follow/unfollow functionality
- [ ] Test notifications creation
- [ ] Test notifications display

---

## 🚀 MIGRATION CHO USERS CŨ

Nếu bạn đã có users trong database mà chưa có `followersCount` và `followingCount`, bạn có thể:

### Option 1: Tự động tính toán (Khuyến nghị)
Code sẽ tự động xử lý với giá trị mặc định là 0. Khi user follow/unfollow, counters sẽ được cập nhật đúng.

### Option 2: Migration script (Nếu cần)
Chạy script để tính toán và cập nhật counters cho tất cả users:

```javascript
// Firebase Functions hoặc script riêng
const usersRef = admin.firestore().collection('users');
const followersRef = admin.firestore().collection('followers');

const users = await usersRef.get();
for (const userDoc of users.docs) {
  const userId = userDoc.id;
  
  // Đếm followers
  const followersSnapshot = await followersRef
    .where('followingId', '==', userId)
    .get();
  
  // Đếm following
  const followingSnapshot = await followersRef
    .where('followerId', '==', userId)
    .get();
  
  // Cập nhật
  await userDoc.ref.update({
    followersCount: followersSnapshot.size,
    followingCount: followingSnapshot.size,
  });
}
```

---

## 📌 LƯU Ý QUAN TRỌNG

1. **Counters có thể không chính xác 100%** nếu có nhiều operations đồng thời, nhưng sẽ được đồng bộ dần
2. **Notifications được tạo tự động** khi có follow action
3. **Không cần tạo notifications thủ công** - service sẽ tự động xử lý
4. **Indexes là bắt buộc** cho performance tốt với large datasets

---

## 🎯 NEXT STEPS

Sau khi setup Firestore structure:
1. Chạy app và test follow/unfollow
2. Kiểm tra notifications được tạo đúng
3. Kiểm tra counters được cập nhật
4. Test với nhiều users để đảm bảo scalability

