import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final emailController = TextEditingController();
  final passController = TextEditingController();
  String error = '';

  void login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Mật khẩu không đúng. Vui lòng thử lại.';
          break;
        case 'user-not-found':
          message = 'Tài khoản không tồn tại.';
          break;
        case 'invalid-email':
          message = 'Email không hợp lệ.';
          break;
        case 'invalid-credential':
          message = 'Thông tin đăng nhập không hợp lệ hoặc đã hết hạn.';
          break;
        case 'too-many-requests':
          message = 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.';
          break;
        default:
          message = 'Đăng nhập thất bại: ${e.message}';
      }
      setState(() => error = message);
    } catch (e) {
      setState(() => error = 'Lỗi không xác định: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Nhập email',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
                hintText: 'Nhập mật khẩu',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: login,
                child: const Text('Đăng nhập', style: TextStyle(color: Colors.white)),
              ),
            ),
            if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {},
              child: const Text('Quên mật khẩu?', style: TextStyle(color: Color(0xFFBDBDBD))),
            ),
          ],
        ),
      ),
    );
  }
}
