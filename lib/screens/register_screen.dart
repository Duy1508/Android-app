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

  // ===== VALIDATION =====
  bool isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  bool isValidPassword(String password) =>
      RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)[A-Za-z\d]{6,12}$').hasMatch(password);

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
      if (!isValidEmail(email)) throw 'Email không hợp lệ';
      if (!isValidPassword(pass)) throw 'Mật khẩu phải 6–12 ký tự, có chữ hoa, chữ thường và số';
      if (pass != confirm) throw 'Mật khẩu xác nhận không khớp';
      if (name.isEmpty || username.isEmpty) throw 'Vui lòng nhập đầy đủ thông tin';

      final usernameRef = _db.collection('usernames').doc(username);
      final usernameSnap = await usernameRef.get();
      if (usernameSnap.exists) throw 'Tên người dùng đã tồn tại';

      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user?.uid;
      if (uid == null) throw 'Không tạo được tài khoản';

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
      batch.set(usernameRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
      await batch.commit();

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red.shade400),
        );
      }
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: emailController, decoration: _inputDecoration('Email', Icons.email)),
              const SizedBox(height: 16),
              TextField(controller: passController, obscureText: true, decoration: _inputDecoration('Mật khẩu', Icons.lock)),
              const SizedBox(height: 16),
              TextField(controller: confirmController, obscureText: true, decoration: _inputDecoration('Xác nhận mật khẩu', Icons.lock_outline)),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: _inputDecoration('Họ tên', Icons.person)),
              const SizedBox(height: 16),
              TextField(controller: usernameController, decoration: _inputDecoration('Tên người dùng', Icons.account_circle)),
              const SizedBox(height: 28),

              InkWell(
                onTap: isLoading ? null : register,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Đăng ký',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
