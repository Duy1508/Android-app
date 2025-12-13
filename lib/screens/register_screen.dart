import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmController = TextEditingController();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();

  bool isLoading = false;
  String error = '';

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool isValidPassword(String password) {
    return RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)[A-Za-z\d]{6,12}$')
        .hasMatch(password);
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final pass = passController.text.trim();
    final confirm = confirmController.text.trim();
    final name = nameController.text.trim();
    final username = usernameController.text.trim();

    setState(() {
      error = '';
      isLoading = true;
    });

    try {
      // ===== VALIDATION =====
      if (!isValidEmail(email)) {
        throw 'Email không hợp lệ';
      }
      if (!isValidPassword(pass)) {
        throw 'Mật khẩu phải 6–12 ký tự, có chữ hoa, chữ thường và số';
      }
      if (pass != confirm) {
        throw 'Mật khẩu xác nhận không khớp';
      }
      if (name.isEmpty || username.isEmpty) {
        throw 'Vui lòng nhập đầy đủ thông tin';
      }

      // ===== CHECK USERNAME (SAFE) =====
      final usernameRef = _db.collection('usernames').doc(username);
      final usernameSnap = await usernameRef.get();

      if (usernameSnap.exists) {
        throw 'Tên người dùng đã tồn tại';
      }

      // ===== FIREBASE AUTH =====
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final uid = cred.user?.uid;
      if (uid == null) throw 'Không tạo được tài khoản';

      // ===== BATCH WRITE =====
      final batch = _db.batch();

      batch.set(_db.collection('users').doc(uid), {
        'uid': uid,
        'email': email,
        'name': name,
        'username': username,
        'avatarUrl': null,
        'bio': '',
        'followersCount': 0,
        'followingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(usernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        error = 'Email đã tồn tại';
      } else if (e.code == 'weak-password') {
        error = 'Mật khẩu quá yếu';
      } else {
        error = e.message ?? 'Lỗi đăng ký';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    confirmController.dispose();
    nameController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
              TextField(controller: confirmController, obscureText: true, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu')),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Họ tên')),
              TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Tên người dùng')),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: isLoading ? null : register,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Đăng ký'),
              ),

              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}