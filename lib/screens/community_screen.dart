import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/glass_background.dart';
import '../widgets/comments_sheet.dart';
import 'post_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  final String? preselectedRouteId;
  final String? preselectedRouteName;

  const CommunityScreen({
    super.key,
    this.preselectedRouteId,
    this.preselectedRouteName,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.preselectedRouteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreatePostSheet(
          preselectedId: widget.preselectedRouteId,
          preselectedName: widget.preselectedRouteName,
        );
      });
    }
  }

  void _showCreatePostSheet({String? preselectedId, String? preselectedName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(
        preselectedRouteId: preselectedId,
        preselectedRouteName: preselectedName,
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
        title: Text('Topluluk', style: BrandTypography.h2),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: BrandColors.seljukTurquoise.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'share_route_fab',
            elevation: 0,
            backgroundColor: BrandColors.seljukTurquoise,
            shape: const CircleBorder(),
            onPressed: () => _showCreatePostSheet(),
            child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
      body: GlassBackground(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    BrandColors.accentSand.withOpacity(0.0),
                    BrandColors.accentSand.withOpacity(0.6),
                    BrandColors.seljukTurquoise.withOpacity(0.4),
                    BrandColors.accentSand.withOpacity(0.0),
                  ], stops: const [0.0, 0.3, 0.7, 1.0]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('community_posts')
                    .orderBy('createdAt', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: BrandColors.seljukTurquoise));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }
                  final posts = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
                    physics: const BouncingScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final data =
                          posts[index].data() as Map<String, dynamic>;
                      final postId = posts[index].id;
                      return FadeSlideUp(
                        delay: Duration(milliseconds: index * 60),
                        child: _PostCard(postId: postId, data: data),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: BrandColors.seljukTurquoise.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: BrandColors.seljukTurquoise.withOpacity(0.2),
                    width: 2),
              ),
              child: const Icon(Icons.people_alt_outlined,
                  size: 60, color: BrandColors.seljukTurquoise),
            ),
            const SizedBox(height: 24),
            Text('Henüz Paylaşım Yok!', style: BrandTypography.h2),
            const SizedBox(height: 12),
            Text(
              'İlk rota paylaşımını sen yap!\nKonya\'daki en iyi rotanı toplulukla paylaş.',
              textAlign: TextAlign.center,
              style: BrandTypography.bodySmall
                  .copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),
            GlassButton(
              label: '🗺️ İlk Rotamı Paylaş',
              onPressed: () => _showCreatePostSheet(),
              width: 220,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GÖNDERI KARTI
// ─────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  const _PostCard({required this.postId, required this.data});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _likeLoading = false;

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _likeLoading) return;
    setState(() => _likeLoading = true);
    final ref = FirebaseFirestore.instance
        .collection('community_posts')
        .doc(widget.postId);
    final likedBy = List<String>.from(widget.data['likedBy'] ?? []);
    final isLiked = likedBy.contains(user.uid);
    try {
      if (isLiked) {
        likedBy.remove(user.uid);
      } else {
        likedBy.add(user.uid);
      }
      await ref.update({'likedBy': likedBy, 'likeCount': likedBy.length});
    } catch (_) {}
    if (mounted) setState(() => _likeLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final likedBy = List<String>.from(widget.data['likedBy'] ?? []);
    final isLiked = user != null && likedBy.contains(user.uid);
    final likeCount = widget.data['likeCount'] ?? 0;
    final userName = widget.data['userName'] ?? 'Gezgin';
    final userPhotoUrl = widget.data['userPhotoUrl'] as String?;
    final routeName = widget.data['routeName'] ?? 'İsimsiz Rota';
    final description = (widget.data['description'] ?? '') as String;
    final placeCount = widget.data['placeCount'] ?? 0;
    final totalKm =
        (widget.data['totalKm'] as num?)?.toDouble() ?? 0.0;
    final isOptimized = widget.data['isOptimized'] == true;
    final imageUrls =
        List<String>.from(widget.data['imageUrls'] ?? []);
    final rating = (widget.data['rating'] as num?)?.toDouble() ?? 0.0;
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final dateStr =
        createdAt != null ? _formatDate(createdAt.toDate()) : 'Yeni';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            postId: widget.postId,
            initialData: widget.data,
          ),
        ),
      ),
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Kullanıcı Başlığı (Header) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        BrandColors.seljukTurquoise.withOpacity(0.15),
                    backgroundImage: (userPhotoUrl != null &&
                            userPhotoUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(userPhotoUrl)
                        : null,
                    child: (userPhotoUrl == null || userPhotoUrl.isEmpty)
                        ? const Icon(Icons.person,
                            size: 22, color: BrandColors.seljukTurquoise)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: BrandTypography.bodyBold),
                        Text(dateStr,
                            style: BrandTypography.bodySmall
                                .copyWith(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (isOptimized)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrandColors.seljukTurquoise.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: BrandColors.seljukTurquoise.withOpacity(0.3)),
                      ),
                      child: const Text('✅ Optimize',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: BrandColors.seljukTurquoise)),
                    ),
                  // Sağ üstte küçük ikon eklenebilir (Seçenekler vb. için yer tutucu)
                  const SizedBox(width: 8),
                  Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),

            // ── 2. Gönderi İçeriği (Yazı/Açıklama) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routeName,
                      style: BrandTypography.h3.copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description,
                        style: BrandTypography.bodyMedium.copyWith(
                            color: BrandColors.textDark.withOpacity(0.85),
                            height: 1.4),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── 3. Fotoğraf Alanı ──
            if (imageUrls.isNotEmpty)
              SizedBox(
                height: 240,
                width: double.infinity,
                child: PageView.builder(
                  itemCount: imageUrls.length,
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: imageUrls[i],
                    fit: BoxFit.cover,
                    memCacheHeight: 800, // 🔥 OPTİMİZASYON: Görüntüyü RAM'de ufaltıp decode eder (10x hız artışı)
                    fadeInDuration: const Duration(milliseconds: 200), // Daha yumuşak geçiş
                    placeholder: (context, url) => Container(
                        color: BrandColors.seljukTurquoise.withOpacity(0.05),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: BrandColors.seljukTurquoise))),
                    errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                  ),
                ),
              ),

            // ── 4. Alt Bilgi (Footer) ──
            if (imageUrls.isEmpty)
              Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (rating > 0)
                          _badge(Icons.star_rounded, '$rating', Colors.amber),
                        _badge(Icons.place_rounded, '$placeCount Mekan',
                            BrandColors.seljukTurquoise),
                        if (totalKm > 0)
                          _badge(Icons.directions_walk_rounded,
                              '~${totalKm.toStringAsFixed(1)} km',
                              BrandColors.accentSand),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => CommentsSheet.show(context, widget.postId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 6),
                          Text('${widget.data['commentCount'] ?? 0}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLiked ? Colors.red.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isLiked ? Colors.red.shade200 : Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red.shade400 : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text('$likeCount',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isLiked
                                      ? Colors.red.shade400
                                      : Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    if (diff.inDays < 7) return '${diff.inDays}g önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

// ─────────────────────────────────────────────
// GÖNDERİ OLUŞTURMA (BottomSheet)
// ─────────────────────────────────────────────
class _CreatePostSheet extends StatefulWidget {
  final String? preselectedRouteId;
  final String? preselectedRouteName;
  const _CreatePostSheet({this.preselectedRouteId, this.preselectedRouteName});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _descController = TextEditingController();
  String? _selectedRouteId;
  String? _selectedRouteName;
  bool _isPosting = false;
  double _rating = 5.0; // Puanlama
  List<Map<String, dynamic>> _userRoutes = [];
  bool _loadingRoutes = true;

  // Fotoğraf
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _selectedRouteId = widget.preselectedRouteId;
    _selectedRouteName = widget.preselectedRouteName;
    _loadUserRoutes();
  }

  Future<void> _loadUserRoutes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('routes')
        .orderBy('createdAt', descending: true)
        .get();
    if (mounted) {
      setState(() {
        _userRoutes = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loadingRoutes = false;
      });
    }
  }

  Future<void> _pickImages() async {
    // Fotoğrafları %30 kaliteye sıkıştırıyoruz (10MB -> 200KB civarına düşer)
    // Bu sayede yükleme ve indirme hızı 10-20 kat artar.
    final List<XFile> picked = await _picker.pickMultiImage(
      imageQuality: 30,
    );
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _selectedImages = picked.take(5).toList();
      });
    }
  }

  Future<List<String>> _uploadImages(String postId) async {
    final List<String> urls = [];
    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final bytes = await _selectedImages[i].readAsBytes();
        
        if (bytes.isEmpty) {
          throw Exception("Fotoğraf okunamadı (0 bayt). Lütfen farklı bir klasör veya galeriden seçin (Xiaomi optimizasyon hatası).");
        }

        debugPrint('📸 Fotoğraf $i Firebase Storage\'a yükleniyor (Boyut: ${bytes.length})');

        final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('community_posts')
            .child(postId)
            .child(fileName);

        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final downloadUrl = await uploadTask.ref.getDownloadURL();
        debugPrint('✅ Fotoğraf $i yüklendi: $downloadUrl');
        urls.add(downloadUrl);
      } catch (e) {
        debugPrint('❌ Fotoğraf $i yükleme hatası: $e');
        throw Exception('Görseller yüklenemedi: $e');
      }
    }
    return urls;
  }

  Future<void> _submitPost() async {
    if (_selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lütfen bir rota seç!'),
          backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _isPosting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Kullanıcı verilerini çek
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final userName = userData['displayName'] ??
          user.displayName ??
          user.email?.split('@')[0] ??
          'Gezgin';
      final userPhotoUrl = userData['profilePhotoUrl'] as String? ?? '';

      // Rota verisini çek
      final routeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('routes')
          .doc(_selectedRouteId)
          .get();
      final routeData = routeDoc.data() ?? {};

      // Post dokümanı referansı oluştur (ID için)
      final docRef =
          FirebaseFirestore.instance.collection('community_posts').doc();

      // Fotoğrafları yükle
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages(docRef.id);
      }

      // Postu kaydet
      await docRef.set({
        'userId': user.uid,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'routeId': _selectedRouteId,
        'routeName': routeData['routeName'] ?? _selectedRouteName ?? 'Rota',
        'description': _descController.text.trim(),
        'placeCount': (routeData['places'] as List?)?.length ?? 0,
        'totalKm': (routeData['totalKm'] as num?)?.toDouble() ?? 0.0,
        'isOptimized': routeData['isOptimized'] == true,
        // Tam rota verisi (kaydetme + harita için)
        'places': routeData['places'] ?? [],
        'placeCoordinates': routeData['placeCoordinates'] ?? [], // ← koordinatlar
        'segmentKms': routeData['segmentKms'] ?? [],
        'startLocationName': routeData['startLocationName'],
        'startLocationLat': routeData['startLocationLat'],
        'startLocationLng': routeData['startLocationLng'],
        // Fotoğraflar
        'imageUrls': imageUrls,
        'likeCount': 0,
        'likedBy': [],
        'commentCount': 0,
        'rating': _rating,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rota paylaşıldı! 🎉',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: BrandColors.seljukTurquoise,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
              ),
              Text('Rota Paylaş', style: BrandTypography.h2),
              const SizedBox(height: 2),
              Text('Rotanı toplulukla paylaş!',
                  style: BrandTypography.bodySmall),
              const SizedBox(height: 18),

              // ── Rota seçimi ──
              Text('Rota Seç *',
                  style: BrandTypography.bodyBold
                      .copyWith(color: BrandColors.seljukTurquoise)),
              const SizedBox(height: 8),
              _loadingRoutes
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: BrandColors.seljukTurquoise))
                  : _userRoutes.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Text(
                              'Henüz rota oluşturmadın.',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : SizedBox(
                          height: 96,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _userRoutes.length,
                            itemBuilder: (context, index) {
                              final route = _userRoutes[index];
                              final rid = route['id'] as String;
                              final rname = route['routeName'] as String? ??
                                  'İsimsiz Rota';
                              final isSelected = _selectedRouteId == rid;
                              final places =
                                  (route['places'] as List?)?.length ?? 0;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedRouteId = rid;
                                  _selectedRouteName = rname;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? BrandColors.seljukTurquoise
                                            .withOpacity(0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: isSelected
                                            ? BrandColors.seljukTurquoise
                                            : Colors.grey.shade200,
                                        width: 1.5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.map_rounded,
                                          size: 18,
                                          color: isSelected
                                              ? BrandColors.seljukTurquoise
                                              : Colors.grey),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 100,
                                        child: Text(rname,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                color: isSelected
                                                    ? BrandColors.seljukTurquoise
                                                    : BrandColors.textDark),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      Text('$places mekan',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
              const SizedBox(height: 16),

              // ── Fotoğraf ekle ──
              Text('Fotoğraf Ekle (opsiyonel)',
                  style: BrandTypography.bodyBold
                      .copyWith(color: BrandColors.textDark.withOpacity(0.7))),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // + butonu
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 76,
                        height: 76,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.shade200,
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded,
                                color: BrandColors.seljukTurquoise, size: 26),
                            const SizedBox(height: 2),
                            Text('Ekle',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: BrandColors.seljukTurquoise,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    // Seçilen fotoğraflar
                    ..._selectedImages.map((xfile) => Stack(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                    image: FileImage(File(xfile.path)),
                                    fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 10,
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                    _selectedImages.remove(xfile)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.redAccent),
                                ),
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Seçilen Puan ──
              Text('Rotaya Puanınız',
                  style: BrandTypography.bodyBold
                      .copyWith(color: BrandColors.textDark.withOpacity(0.7))),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starValue.toDouble()),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        starValue <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // ── Açıklama ──
              Text('Açıklama (opsiyonel)',
                  style: BrandTypography.bodyBold
                      .copyWith(color: BrandColors.textDark.withOpacity(0.7))),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _descController,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(
                      fontSize: 13, color: BrandColors.textDark),
                  decoration: InputDecoration(
                    hintText:
                        'Rotanla ilgili bir şeyler yaz... (ipuçları, öneriler...)',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Butonlar ──
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'İptal',
                      color: Colors.grey.shade400,
                      height: 48,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      label: 'Paylaş 🗺️',
                      height: 48,
                      isLoading: _isPosting,
                      onPressed: _submitPost,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}