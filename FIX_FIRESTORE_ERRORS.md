# 🔧 HƯỚNG DẪN SỬA LỖI FIRESTORE

## ❌ LỖI PHỔ BIẾN NHẤT

### Lỗi: "The query requires an index"
```
FAILED_PRECONDITION: The query requires an index. 
You can create it here: https://console.firebase.google.com/...
```

**Nguyên nhân:** Khi sử dụng `where()` kết hợp với `orderBy()` trên các field khác nhau, Firestore cần composite index.

---

## ✅ CÁCH SỬA LỖI

### Cách 1: Tự động tạo index (Khuyến nghị)

1. **Chạy app và thực hiện action gây lỗi**
   - Ví dụ: Xem profile, xem notifications, follow user

2. **Kiểm tra Console/Log**
   - Lỗi sẽ hiển thị link để tạo index
   - Link có dạng: `https://console.firebase.google.com/...`

3. **Click vào link**
   - Link sẽ mở Firebase Console
   - Click "Create Index"
   - Đợi index được tạo (có thể mất vài phút)

4. **Chạy lại app**
   - Index đã được tạo, lỗi sẽ biến mất

---

### Cách 2: Tạo index thủ công

Vào **Firebase Console** → **Firestore Database** → **Indexes** → **Create Index**

#### Index 1: Posts Collection
- **Collection ID:** `posts`
- **Fields to index:**
  1. `userId` - Ascending
  2. `createdAt` - Descending
- **Query scope:** Collection

#### Index 2: Followers Collection (Followers)
- **Collection ID:** `followers`
- **Fields to index:**
  1. `followingId` - Ascending
  2. `createdAt` - Descending
- **Query scope:** Collection

#### Index 3: Followers Collection (Following)
- **Collection ID:** `followers`
- **Fields to index:**
  1. `followerId` - Ascending
  2. `createdAt` - Descending
- **Query scope:** Collection

#### Index 4: Notifications Collection
- **Collection ID:** `notifications`
- **Fields to index:**
  1. `userId` - Ascending
  2. `createdAt` - Descending
- **Query scope:** Collection

#### Index 5: Notifications Collection (Unread)
- **Collection ID:** `notifications`
- **Fields to index:**
  1. `userId` - Ascending
  2. `isRead` - Ascending
- **Query scope:** Collection

---

## 📋 DANH SÁCH QUERIES CẦN INDEX

### 1. Profile Screen - Posts
```dart
FirebaseFirestore.instance
    .collection('posts')
    .where('userId', isEqualTo: uid)
    .orderBy('createdAt', descending: true)
```
**Index cần:** `posts` - `userId` (Asc), `createdAt` (Desc)

### 2. Follow Service - Get Followers
```dart
_followersRef
    .where('followingId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
```
**Index cần:** `followers` - `followingId` (Asc), `createdAt` (Desc)

### 3. Follow Service - Get Following
```dart
_followersRef
    .where('followerId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
```
**Index cần:** `followers` - `followerId` (Asc), `createdAt` (Desc)

### 4. Notification Service - Get Notifications
```dart
_notificationsRef
    .where('userId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
```
**Index cần:** `notifications` - `userId` (Asc), `createdAt` (Desc)

### 5. Notification Service - Get Unread Count
```dart
_notificationsRef
    .where('userId', isEqualTo: userId)
    .where('isRead', isEqualTo: false)
```
**Index cần:** `notifications` - `userId` (Asc), `isRead` (Asc)

---

## 🚨 CÁC LỖI KHÁC

### Lỗi: Permission Denied
```
PERMISSION_DENIED: Missing or insufficient permissions
```

**Cách sửa:**
1. Vào Firebase Console → Firestore Database → Rules
2. Cập nhật Security Rules (xem `FIRESTORE_STRUCTURE.md`)
3. Đảm bảo user đã đăng nhập

### Lỗi: Collection not found
```
NOT_FOUND: No document to update
```

**Cách sửa:**
1. Đảm bảo collection đã được tạo
2. Kiểm tra tên collection có đúng không
3. Kiểm tra document ID có đúng không

### Lỗi: Field not found
```
INVALID_ARGUMENT: Field not found
```

**Cách sửa:**
1. Kiểm tra field name có đúng không
2. Đảm bảo document có field đó
3. Sử dụng `??` để xử lý null values

---

## ⚡ TIPS

1. **Luôn kiểm tra link trong error message** - Firebase tự động tạo link để tạo index
2. **Đợi index được build** - Index có thể mất vài phút để build
3. **Kiểm tra status của index** - Vào Firebase Console → Indexes để xem status
4. **Test sau khi tạo index** - Chạy lại app để đảm bảo lỗi đã được sửa

---

## 🔍 KIỂM TRA INDEX STATUS

1. Vào Firebase Console
2. Firestore Database → Indexes
3. Xem danh sách indexes
4. Status:
   - ✅ **Enabled** - Index đã sẵn sàng
   - ⏳ **Building** - Đang tạo index (đợi vài phút)
   - ❌ **Error** - Có lỗi, cần kiểm tra lại

---

## 📝 CHECKLIST

- [ ] Đã tạo index cho `posts` collection
- [ ] Đã tạo index cho `followers` collection (2 indexes)
- [ ] Đã tạo index cho `notifications` collection (2 indexes)
- [ ] Tất cả indexes đã có status "Enabled"
- [ ] Đã test lại app và không còn lỗi
- [ ] Đã cập nhật Security Rules (nếu cần)

---

## 💡 NẾU VẪN GẶP LỖI

1. **Kiểm tra Firebase Console** - Xem có error messages không
2. **Kiểm tra Logs** - Xem chi tiết lỗi trong console
3. **Kiểm tra Internet** - Đảm bảo có kết nối internet
4. **Restart app** - Đóng và mở lại app
5. **Clear cache** - Xóa cache của app (nếu cần)

---

## 🆘 LIÊN HỆ

Nếu vẫn gặp lỗi sau khi làm theo hướng dẫn:
1. Copy toàn bộ error message
2. Chụp màn hình Firebase Console
3. Gửi thông tin để được hỗ trợ

