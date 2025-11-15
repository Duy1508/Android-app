import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmController = TextEditingController();
  String error = '';
  String success = '';

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@gmail\.com$');
    return emailRegex.hasMatch(email);
  }

  bool isValidPassword(String password) {
    final passRegex = RegExp(r'^(?=.*[A-Z])[a-zA-Z0-9]{6,12}$');
    return passRegex.hasMatch(password);
  }

  void register() async {
    final email = emailController.text.trim();
    final pass = passController.text.trim();
    final confirm = confirmController.text.trim();

    setState(() {
      error = '';
      success = '';
    });

    if (!isValidEmail(email)) {
      setState(() => error = 'Email không hợp lệ (ví dụ:xzy@gmail.com)');
      return;
    }

    if (!isValidPassword(pass)) {
      setState(() => error = 'Mật khẩu phải từ 6–12 ký tự, ít nhất 1 chữ cái viết hoa');
      return;
    }

    if (pass != confirm) {
      setState(() => error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: pass);

      // ✅ Tạo hồ sơ người dùng trong Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'name': '',
          'avatarUrl': null,
          'bio': '',
          'followersCount': 0,
          'followingCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() => success = 'Đăng ký thành công!');
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      });
    } catch (e) {
      setState(() => error = 'Lỗi: ${e.toString()}');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
            TextField(controller: confirmController, obscureText: true, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: register, child: const Text('Đăng ký')),
            const SizedBox(height: 10),
            if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
            if (success.isNotEmpty) Text(success, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
