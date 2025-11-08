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
      appBar: AppBar(title: Text('Đăng nhập')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email')),
            TextField(controller: passController, obscureText: true, decoration: InputDecoration(labelText: 'Mật khẩu')),
            SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: Text('Đăng nhập')),
            if (error.isNotEmpty) Text(error, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
