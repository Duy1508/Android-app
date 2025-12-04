# ⚡ SỬA LỖI FIRESTORE NHANH

## 🚨 Lỗi: "The query requires an index"

### Cách sửa nhanh nhất:

1. **Chạy app** và thực hiện action gây lỗi (xem profile, notifications, etc.)

2. **Kiểm tra Console/Log** - Sẽ có link để tạo index:
   ```
   https://console.firebase.google.com/...
   ```

3. **Click vào link** → Firebase Console sẽ mở → Click **"Create Index"**

4. **Đợi 2-5 phút** để index được build

5. **Chạy lại app** - Lỗi sẽ biến mất! ✅

---

## 📋 Các Index cần tạo (nếu không có link tự động):

### 1. Posts Collection
- Collection: `posts`
- Fields: `userId` (Ascending), `createdAt` (Descending)

### 2. Followers Collection (2 indexes)
- Collection: `followers`
- Index 1: `followingId` (Ascending), `createdAt` (Descending)
- Index 2: `followerId` (Ascending), `createdAt` (Descending)

### 3. Notifications Collection (2 indexes)
- Collection: `notifications`
- Index 1: `userId` (Ascending), `createdAt` (Descending)
- Index 2: `userId` (Ascending), `isRead` (Ascending)

---

## 🔍 Kiểm tra Index Status:

1. Vào **Firebase Console** → **Firestore Database** → **Indexes**
2. Xem status:
   - ✅ **Enabled** = Sẵn sàng
   - ⏳ **Building** = Đang tạo (đợi thêm)
   - ❌ **Error** = Có lỗi

---

## 💡 Tips:

- App sẽ tự động hiển thị thông báo lỗi rõ ràng nếu thiếu index
- Luôn click vào link trong error message (cách nhanh nhất)
- Đợi index build xong trước khi test lại

---

Xem chi tiết trong file `FIX_FIRESTORE_ERRORS.md`

