import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui'; // Cam efekti ve bulanıklık için eklendi
// 🔥 1. DEĞİŞİKLİK: HomeScreen yerine MainNavigatorScreen'i import ediyoruz
import 'main_nav_screen.dart';
import '../widgets/glass_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;

  // 1. GİRİŞ VE KAYIT FONKSİYONU
  Future<void> _submitAuth() async {
    if (!_isLogin && _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şifreler birbiriyle eşleşmiyor!"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        // 🔥 2. DEĞİŞİKLİK: HomeScreen yerine MainNavigatorScreen'e gidiyoruz!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Bir hata oluştu.";
      if (e.code == 'user-not-found') errorMessage = "Bu e-posta ile kayıtlı kullanıcı bulunamadı.";
      else if (e.code == 'wrong-password') errorMessage = "Şifre hatalı.";
      else if (e.code == 'email-already-in-use') errorMessage = "Bu e-posta zaten kullanımda.";
      else if (e.code == 'weak-password') errorMessage = "Şifre çok zayıf (En az 6 karakter olmalı).";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 2. ŞİFRE SIFIRLAMA FONKSİYONU VE EKRANI (Temaya uyarlandı)
  void _showResetPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Şifremi Unuttum", style: TextStyle(color: BrandColors.textDark, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Hesabınıza ait e-posta adresinizi girin. Size bir şifre sıfırlama bağlantısı göndereceğiz.", style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "E-posta Adresi",
                  prefixIcon: const Icon(Icons.email_outlined, color: BrandColors.seljukTurquoise),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: "İptal",
                    color: Colors.grey.shade400,
                    height: 48,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: "Gönder",
                    height: 48,
                    onPressed: () async {
                      String email = resetEmailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen e-posta adresinizi girin!")));
                        return;
                      }

                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Şifre sıfırlama bağlantısı e-postanıza gönderildi! 📩"), backgroundColor: BrandColors.seljukTurquoise),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String error = "Bir hata oluştu.";
                        if (e.code == 'user-not-found') error = "Bu e-posta sistemde kayıtlı değil.";
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.redAccent));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by GlassBackground
      body: GlassBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔥 1. LOGO VE BAŞLIK (PREMIUM MODERN)
                  FadeSlideUp(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                      ),
                      child: const Icon(Icons.explore_rounded, size: 70, color: BrandColors.seljukTurquoise),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideUp(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      children: [
                        Text("Akıllı Seyahat Asistanı", style: BrandTypography.h1, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text("Konya'yı keşfetmeye hazır mısın?", style: BrandTypography.bodyMedium.copyWith(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 🔥 2. GİRİŞ/KAYIT KARTI (GLASS CARD)
                  FadeSlideUp(
                    delay: const Duration(milliseconds: 200),
                    child: GlassCard(
                      padding: const EdgeInsets.all(32.0),
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isLogin ? "Giriş Yap" : "Hesap Oluştur",
                            style: BrandTypography.h2,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
  
                          // E-POSTA (GLASS INPUT)
                          _buildGlassInputField(
                            controller: _emailController,
                            label: "E-posta Adresi",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
  
                          // ŞİFRE (GLASS INPUT)
                          _buildGlassInputField(
                            controller: _passwordController,
                            label: "Şifre",
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                          ),
  
                          // ŞİFREYİ ONAYLA (Sadece Kayıt Olurken)
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _buildGlassInputField(
                              controller: _confirmPasswordController,
                              label: "Şifreyi Onayla",
                              icon: Icons.lock_reset_rounded,
                              isPassword: true,
                            ),
                          ],
  
                          // ŞİFREMİ UNUTTUM
                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showResetPasswordDialog,
                                child: Text(
                                  "Şifremi Unuttum", 
                                  style: BrandTypography.bodySmall.copyWith(fontWeight: FontWeight.w800, color: Colors.grey.shade600),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 32),
  
                          // GİRİŞ YAP / KAYIT OL (PREMIUM GLASS BUTON)
                          GlassButton(
                            label: _isLogin ? "Giriş Yap" : "Kayıt Ol",
                            isLoading: _isLoading,
                            onPressed: _submitAuth,
                          ),
                          const SizedBox(height: 20),
  
                          // EKRAN DEĞİŞTİRME (Giriş <-> Kayıt)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin ? "Hesabın yok mu?" : "Zaten hesabın var mı?", 
                                style: BrandTypography.bodySmall.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _confirmPasswordController.clear();
                                  });
                                },
                                child: Text(
                                  _isLogin ? "Kayıt Ol" : "Giriş Yap", 
                                  style: BrandTypography.bodyMedium.copyWith(color: BrandColors.seljukTurquoise, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 ÖZEL GLASS INPUT TASARIMI
  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 0.8),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: BrandTypography.bodyBold,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: BrandTypography.bodySmall.copyWith(fontWeight: FontWeight.w800, color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: BrandColors.seljukTurquoise, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}