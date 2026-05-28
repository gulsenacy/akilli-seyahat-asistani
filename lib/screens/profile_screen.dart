import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'favorites_screen.dart'; 
import 'edit_profile_screen.dart';
import 'route_detail_screen.dart';
import 'my_routes_screen.dart';
import '../widgets/glass_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;
  String? _displayName;
  List<String> _categories = [];
  String? _profilePhotoUrl; // Firebase Storage URL
  
  // Real stats data
  int _routeCount = 0;
  int _favoriteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _displayName = user!.displayName ?? (user!.email?.split('@')[0].toUpperCase() ?? "GEZGİN");

      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      
      // Fetch Counts
      final routesSnap = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('routes').get();
      final favsSnap = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('favorites').get();
      
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _routeCount = routesSnap.size;
            _favoriteCount = favsSnap.size;
            _categories = List<String>.from(data['categories'] ?? []);
            // URL tabanlı fotoğraf (Firebase Storage)
            _profilePhotoUrl = data['profilePhotoUrl'] as String?;
          });
        }
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  // 🔥 ÇIKIŞ ONAY PENCERESİ
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Çıkış Yap", style: TextStyle(color: BrandColors.textDark, fontWeight: FontWeight.bold)),
          content: Text("Uygulamadan çıkmak istediğinize emin misiniz?", style: TextStyle(color: BrandColors.textDark.withOpacity(0.7))),
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
                    label: "Çıkış Yap",
                    color: Colors.redAccent,
                    height: 48,
                    onPressed: () async {
                      Navigator.pop(context);
                      await _signOut();
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

  Widget _buildUsageGuideContent() {
    return Column(
      children: [
        Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.only(bottom: 24)),
        const Text("Uygulama Nasıl Kullanılır?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: BrandColors.textDark)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              _buildGuideItem(Icons.category_outlined, "1. Kategori Seç", "Ana ekrandan gitmek istediğin yerlerin kategorilerini belirle."),
              _buildGuideItem(Icons.place_outlined, "2. Mekanları Belirle", "Mekanlar sayfasından seçtiğin alanlardaki yerleri listene ekle."),
              _buildGuideItem(Icons.save_outlined, "3. Rotanı Kaydet", "Seçtiğin mekanları şık bir rotaya dönüştür ve isimlendir."),
              _buildGuideItem(Icons.explore_outlined, "4. Keşfe Başla", "Rotalarım sayfasından rotanı aç ve Konya'yı gezmeye başla!"),
            ],
          ),
        ),
      ],
    );
  }

  void _showUsageGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: _buildUsageGuideContent(),
      ),
    );
  }

  Widget _buildGuideItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BrandColors.seljukTurquoise.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: BrandColors.seljukTurquoise, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BrandColors.textDark)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 GELİŞMİŞ İLETİŞİM (CONTACT) PANELİ
  void _showContactInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.only(bottom: 24)),
            const Text("Bize Ulaş", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: BrandColors.textDark)),
            const SizedBox(height: 8),
            const Text("Soruların için her zaman buradayız!", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            
            _buildContactCard(Icons.email_outlined, "E-posta", "destek@akilliseyahat.com"),
            _buildContactCard(Icons.language, "Web Sitemiz", "www.akilliseyahat.com"),
            _buildContactCard(Icons.camera_alt_outlined, "Instagram", "@akilliseyahat"),
            
            const SizedBox(height: 16),
            const Text("Versiyon: 1.0.4", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String title, String value) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: BrandColors.seljukTurquoise.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: BrandColors.seljukTurquoise, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: BrandColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Profil", style: BrandTypography.h2),
        centerTitle: true,
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: GlassBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 56), // AppBar spacing
            // ── Zarif başlık alt çizgisi (home screen ile aynı) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      BrandColors.accentSand.withOpacity(0.0),
                      BrandColors.accentSand.withOpacity(0.6),
                      BrandColors.seljukTurquoise.withOpacity(0.4),
                      BrandColors.accentSand.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  
                  // 🔥 1. ANA PROFİL KARTI (DÜZENLEME ENTEGRELİ)
                  FadeSlideUp(
                    child: Stack(
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle, 
                                  border: Border.all(color: BrandColors.seljukTurquoise.withOpacity(0.5), width: 2)
                                ),
                                child: CircleAvatar(
                                  radius: 42, 
                                  backgroundColor: BrandColors.seljukTurquoise.withOpacity(0.1),
                                  backgroundImage: (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                                      ? NetworkImage(_profilePhotoUrl!) as ImageProvider
                                      : null,
                                  child: (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                                    ? const Icon(Icons.person, size: 45, color: BrandColors.seljukTurquoise) 
                                    : null,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(_displayName ?? "Yükleniyor...", style: BrandTypography.h2),
                              const SizedBox(height: 10),
                              
                              // ROZETLER (KATEGORİLER)
                              if (_categories.isNotEmpty)
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  alignment: WrapAlignment.center,
                                  children: _categories.map((category) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: BrandColors.seljukTurquoise.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: BrandColors.seljukTurquoise.withOpacity(0.2)),
                                      ),
                                      child: Text(category, style: BrandTypography.caption),
                                    );
                                  }).toList().cast<Widget>(),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12, right: 12,
                          child: IconButton(
                            icon: const Icon(Icons.edit_note, color: BrandColors.seljukTurquoise, size: 28),
                            onPressed: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                              if (result == true) _loadProfileData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  
                  // 🔥 2. İSTATİSTİK PANELI (TIKLANABİLİR & KÜÇÜK)
                  FadeSlideUp(
                    delay: const Duration(milliseconds: 100),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard("Rotalarım", _routeCount, Icons.map_outlined, () {
                           Navigator.push(context, MaterialPageRoute(builder: (context) => const MyRoutesScreen()));
                        })),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard("Favorilerim", _favoriteCount, Icons.favorite_border_rounded, () {
                           Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen()));
                        })),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔥 4. AYARLAR & DESTEK
                  FadeSlideUp(
                    delay: const Duration(milliseconds: 300),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Column(
                        children: [
                          _buildMenuRow(Icons.help_outline_rounded, "Kullanım Kılavuzu", _showUsageGuide, hasDivider: true),
                          _buildMenuRow(Icons.contact_support_outlined, "Bize Ulaş", _showContactInfo),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 🔥 5. ÇIKIŞ YAP (GLASS BUTON)
                  FadeSlideUp(
                    delay: const Duration(milliseconds: 500),
                    child: GlassButton(
                      label: "Çıkış Yap",
                      icon: Icons.logout_rounded,
                      color: Colors.red.shade600.withOpacity(0.8),
                      textColor: Colors.redAccent,
                      onPressed: _showLogoutDialog,
                    ),
                  ),
                  const SizedBox(height: 120), // 🔥 NAVBAR ÇAKIŞMASINI ÖNLEYEN GÜVENLİ ALAN
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 YENİ: BİRLEŞİK MENÜ ELEMANI
  Widget _buildMenuRow(IconData icon, String title, VoidCallback onTap, {bool hasDivider = false}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, color: BrandColors.seljukTurquoise, size: 22),
                const SizedBox(width: 14),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: BrandColors.textDark)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (hasDivider)
          Divider(color: Colors.grey.withOpacity(0.1), height: 1, thickness: 1),
      ],
    );
  }
  // 🔥 İSTATİSTİK KARTI WİDGETI
  Widget _buildStatCard(String label, int value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BrandColors.seljukTurquoise, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value.toString(), style: BrandTypography.h2.copyWith(height: 1)),
                Text(label, style: BrandTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}