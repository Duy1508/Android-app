import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? avatarUrl;
  File? _selectedImage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    final data = doc.data();
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _bioController.text = data['bio'] ?? '';
      avatarUrl = data['avatarUrl'];
    }
    setState(() => isLoading = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 75);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final ref = FirebaseStorage.instance.ref().child('avatars').child('${widget.userId}.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  bool _isValidName(String name) {
    final regex = RegExp(r'^[a-zA-ZÀ-ỹ\s]+$');
    return regex.hasMatch(name.trim());
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();

    if (!_isValidName(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên không được chứa ký tự đặc biệt hoặc số')),
      );
      return;
    }

    String? newAvatarUrl = avatarUrl;

    if (_selectedImage != null) {
      newAvatarUrl = await _uploadImage(_selectedImage!);
    }

    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'name': name,
      'bio': _bioController.text,
      'avatarUrl': newAvatarUrl ?? '',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thay đổi thành công')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    ImageProvider<Object>? displayImage;

    if (_selectedImage != null) {
      displayImage = FileImage(_selectedImage!);
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      displayImage = NetworkImage(avatarUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: colorScheme.surfaceVariant,
              backgroundImage: displayImage,
              child: displayImage == null
                  ? Icon(Icons.person, size: 50, color: colorScheme.onSurface)
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text('Thư viện'),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Máy ảnh'),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên người dùng'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Giới thiệu bản thân'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    child: const Text('Lưu thay đổi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}