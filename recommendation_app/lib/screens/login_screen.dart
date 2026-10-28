import 'package:flutter/material.dart';

import '../models/demo_account.dart';
import '../services/auth_controller.dart';

const loginPurple = Color(0xFF6558E8);

class LoginScreen extends StatefulWidget {
  final AuthController auth;

  const LoginScreen({
    super.key,
    required this.auth,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  DemoAccount selectedAccount = DemoAccount.all.first;

  bool showPassword = false;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();

    emailController.text = selectedAccount.email;
    passwordController.text = selectedAccount.id;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void selectAccount(DemoAccount? account) {
    if (account == null) return;

    setState(() {
      selectedAccount = account;
      emailController.text = account.email;
      passwordController.text = account.id;
      error = null;
    });
  }

  Future<void> submitLogin() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    final success = widget.auth.signIn(
      emailController.text,
      passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      loading = false;

      if (!success) {
        error = 'Email hoặc mật khẩu không đúng.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAE8FF),
              Color(0xFFF7F8FC),
              Color(0xFFE7F0FF),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x160F1430),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDFF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        size: 34,
                        color: loginPurple,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Chào mừng trở lại',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đăng nhập để xem sản phẩm và gợi ý '
                      'được cá nhân hóa từ Neo4j.',
                      style: TextStyle(
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Tài khoản demo nhanh',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<DemoAccount>(
                      initialValue: selectedAccount,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: DemoAccount.all.map((account) {
                        return DropdownMenuItem<DemoAccount>(
                          value: account,
                          child: Text(
                            '${account.id} · ${account.email}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: selectAccount,
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'customer001@example.test',
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Mật khẩu',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Tài khoản demo: mật khẩu chính là mã khách hàng, '
                      'ví dụ C001.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: loading ? null : submitLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: loginPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Đây là đăng nhập demo. API và Neo4j vẫn cần '
                      'hoạt động để tải danh mục, sản phẩm và '
                      'gợi ý cá nhân hóa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}