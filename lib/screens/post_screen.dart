import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final TextEditingController _contentController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('post_images/$fileName.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Future<void> _submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _contentController.text.trim().isEmpty) return;

    setState(() => _isUploading = true);

    String imageUrl = '';
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
    }

    await FirebaseFirestore.instance.collection('posts').add({
      'userId': user.uid,
      'content': _contentController.text.trim(),
      'imageUrl': imageUrl,
      'likes': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _isUploading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng bài viết')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Bạn đang nghĩ gì?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Chọn ảnh từ thư viện'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Đăng bài'),
            ),
          ],
        ),
      ),
    );
  }
}
