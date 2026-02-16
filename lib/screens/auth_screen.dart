import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  String _mapAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-posta formatı hatalı.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-posta veya şifre yanlış.';
        case 'email-already-in-use':
          return 'Bu e-posta zaten kayıtlı.';
        case 'weak-password':
          return 'Şifre en az 6 karakter olmalı.';
        case 'too-many-requests':
          return 'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.';
      }
    }
    return 'İşlem sırasında hata oluştu.';
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final displayName = _nameCtrl.text.trim();
        if (displayName.isNotEmpty) {
          await cred.user?.updateDisplayName(displayName);
        }
      }
    } catch (e) {
      _toast(_mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "UzFinans",
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLogin
                            ? "E-posta ve şifre ile giriş yap"
                            : "Yeni hesap oluştur",
                        style: TextStyle(color: Colors.black.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => setState(() => _isLogin = true),
                              style: FilledButton.styleFrom(
                                backgroundColor: _isLogin
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Colors.grey.shade100,
                              ),
                              child: const Text("Giriş"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => setState(() => _isLogin = false),
                              style: FilledButton.styleFrom(
                                backgroundColor: !_isLogin
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Colors.grey.shade100,
                              ),
                              child: const Text("Kayıt Ol"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Kullanıcı Adı",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: "E-posta",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? "";
                          if (value.isEmpty) return "E-posta zorunlu";
                          if (!value.contains('@')) {
                            return "Geçerli e-posta gir";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: "Şifre",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? "";
                          if (value.isEmpty) return "Şifre zorunlu";
                          if (!_isLogin && value.length < 6) {
                            return "En az 6 karakter olmalı";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_isLogin ? "Giriş Yap" : "Hesap Oluştur"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
