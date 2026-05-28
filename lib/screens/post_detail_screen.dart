import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/glass_background.dart';
import '../widgets/comments_sheet.dart';

const String _kGoogleApiKey = "AIzaSyAbclSR-M23Z9MZZBXaTreBZIednbJXGgc";

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> initialData; // önizleme için — asıl veri Firestore'dan gelir

  const PostDetailScreen(
      {super.key, required this.postId, required this.initialData});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final LatLng _konyaCenter = const LatLng(37.8746, 32.4931);

  // ── Post Verisi ───────────────────────────────────────────────
  bool _isLoadingPost = true;
  Map<String, dynamic> _data = {};

  // ── Kaydetme ──────────────────────────────────────────────────
  bool _isSaving = false;
  bool _isRemoving = false;
  bool _alreadySaved = false;
  String? _savedRouteId;

  // ── Fotoğraf ─────────────────────────────────────────────────
  int _currentImageIndex = 0;

  // ── Harita ───────────────────────────────────────────────────
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  LatLngBounds? _bounds;
  bool _isLoadingMap = false;

  // ── Rota ─────────────────────────────────────────────────────
  List<LatLng?> _placeCoordinates = [];
  List<dynamic> _places = [];
  LatLng? _startLatLng;
  String? _startName;
  bool _isOptimized = false;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
    _applyData(_data); // önizleme verisiyle hızlı yükle
    _fetchFreshData(); // Firestore'dan kesin veriyi çek
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// widget.data veya Firestore'dan gelen veriyi state'e uygular
  void _applyData(Map<String, dynamic> d) {
    _places = List<dynamic>.from(d['places'] ?? []);
    _isOptimized = d['isOptimized'] == true;

    final lat = d['startLocationLat'];
    final lng = d['startLocationLng'];
    if (lat != null && lng != null) {
      _startLatLng = LatLng((lat as num).toDouble(), (lng as num).toDouble());
      _startName = d['startLocationName'] as String?;
    } else {
      _startLatLng = null;
      _startName = null;
    }
  }

  /// Firestore'dan güncel post verisini çek
  Future<void> _fetchFreshData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(widget.postId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        Map<String, dynamic> fresh = doc.data()!;
        
        // Eğer eski bir postsa (places verisi yoksa) orijinal rotadan on-the-fly çek
        if ((fresh['places'] == null || (fresh['places'] as List).isEmpty) &&
            fresh['userId'] != null &&
            fresh['routeId'] != null) {
          try {
            final routeDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(fresh['userId'])
                .collection('routes')
                .doc(fresh['routeId'])
                .get();
            if (routeDoc.exists) {
              final rData = routeDoc.data()!;
              fresh['places'] = rData['places'] ?? [];
              fresh['placeCoordinates'] = rData['placeCoordinates'] ?? [];
              fresh['segmentKms'] = rData['segmentKms'] ?? [];
              fresh['isOptimized'] = rData['isOptimized'] == true;
              
              if (rData['startLocationLat'] != null) {
                fresh['startLocationLat'] = rData['startLocationLat'];
                fresh['startLocationLng'] = rData['startLocationLng'];
                fresh['startLocationName'] = rData['startLocationName'];
              }
            }
          } catch (e) {
            debugPrint("Eski rota kurtarma hatası: $e");
          }
        }

        setState(() {
          _data = fresh;
          _applyData(fresh);
          _isLoadingPost = false;
        });
      } else {
        setState(() => _isLoadingPost = false);
      }
    } catch (e) {
      debugPrint('Post fetch hatası: $e');
      if (mounted) setState(() => _isLoadingPost = false);
    }
    _checkIfAlreadySaved();
    _loadMapMarkers();
  }

  // ─────────────────────────────────────────────────────────────
  // KAYDETME KONTROLÜ
  // ─────────────────────────────────────────────────────────────
  Future<void> _checkIfAlreadySaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('routes')
        .where('savedFrom.postId', isEqualTo: widget.postId)
        .limit(1)
        .get();
    if (mounted) {
      setState(() {
        _alreadySaved = snap.docs.isNotEmpty;
        _savedRouteId = snap.docs.isNotEmpty ? snap.docs.first.id : null;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ROTAYI KAYDET
  // ─────────────────────────────────────────────────────────────
  Future<void> _saveRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('routes')
          .add({
        'routeName': _data['routeName'] ?? 'Kaydedilen Rota',
        'description': '',
        'places': _data['places'] ?? [],
        'placeCoordinates': _data['placeCoordinates'] ?? [],
        'totalKm': (_data['totalKm'] as num?)?.toDouble() ?? 0.0,
        'isOptimized': _data['isOptimized'] == true,
        'segmentKms': _data['segmentKms'] ?? [],
        'startLocationName': _data['startLocationName'],
        'startLocationLat': _data['startLocationLat'],
        'startLocationLng': _data['startLocationLng'],
        'createdAt': FieldValue.serverTimestamp(),
        'savedFrom': {
          'postId': widget.postId,
          'userId': _data['userId'],
          'userName': _data['userName'] ?? 'Gezgin',
        },
      });
      if (mounted) {
        setState(() {
          _isSaving = false;
          _alreadySaved = true;
          _savedRouteId = docRef.id;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Rota kaydedildi ✅  →  Rotalarım › Kaydedilenler',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: BrandColors.seljukTurquoise,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // KAYDEDENDEN ÇIKAR
  // ─────────────────────────────────────────────────────────────
  Future<void> _removeSavedRoute() async {
    if (_savedRouteId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Rotayı Kaldır', style: BrandTypography.h3),
        content: const Text(
            'Bu rota "Kaydedilenler" listenden çıkarılacak. Emin misin?',
            style: TextStyle(color: Colors.grey)),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(children: [
            Expanded(
              child: GlassButton(
                label: 'İptal',
                color: Colors.grey.shade400,
                height: 48,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassButton(
                label: 'Kaldır',
                color: Colors.redAccent,
                height: 48,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isRemoving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('routes')
          .doc(_savedRouteId)
          .delete();
      if (mounted) {
        setState(() {
          _isRemoving = false;
          _alreadySaved = false;
          _savedRouteId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Rota kaydedilenlerden kaldırıldı.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GÖNDERİYİ SİL (KENDİ PAYLAŞIMIYSA)
  // ─────────────────────────────────────────────────────────────
  Future<void> _deleteOwnPost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Gönderiyi Sil', style: BrandTypography.h3),
        content: const Text(
            'Bu gönderi topluluktan ve cihazınızdan kalıcı olarak silinecek. Emin misiniz?',
            style: TextStyle(color: Colors.grey)),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(children: [
            Expanded(
              child: GlassButton(
                label: 'İptal',
                color: Colors.grey.shade400,
                height: 48,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassButton(
                label: 'Sil',
                color: Colors.redAccent,
                height: 48,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirm != true) return;

    // Loading başlatabiliriz ama direkt çıkış da yapabiliriz
    try {
      final postRef = FirebaseFirestore.instance
          .collection('community_posts')
          .doc(widget.postId);

      // 1. Önce alt koleksiyondaki (subcollection) yorumları temizle (Orphaned Data engellemesi)
      final commentsSnap = await postRef.collection('comments').get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in commentsSnap.docs) {
        batch.delete(doc.reference);
      }
      // 2. Postun kendisini sil
      batch.delete(postRef);
      await batch.commit();

      // 3. Storage'daki resimleri sil
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('community_posts')
            .child(widget.postId);
        final listResult = await storageRef.listAll();
        for (var item in listResult.items) {
          await item.delete();
        }
      } catch (e) {
        debugPrint('Resimleri silerken hata: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Gönderi başarıyla silindi.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ));
        Navigator.pop(context); // Ekrana geri dön
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Silinirken hata oluştu: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HARİTA — MARKER VE POLYLİNE
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadMapMarkers() async {
    if (_places.isEmpty) return;
    setState(() => _isLoadingMap = true);

    Set<Marker> tempMarkers = {};
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    List<LatLng?> newCoords = List.filled(_places.length, null);

    void expand(double lat, double lng) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Başlangıç noktası
    if (_startLatLng != null) {
      tempMarkers.add(Marker(
        markerId: const MarkerId('start'),
        position: _startLatLng!,
        infoWindow: InfoWindow(title: '📍 Başlangıç: $_startName'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        zIndex: 2,
      ));
      expand(_startLatLng!.latitude, _startLatLng!.longitude);
    }

    // ── Koordinatları Yükle (Firebase + API Fallback) ─────────
    final stored = List<dynamic>.from(_data['placeCoordinates'] ?? []);

    for (int i = 0; i < _places.length; i++) {
      final name = _places[i].toString();
      bool loadedFromFirebase = false;

      // Firestore'da varsa oradan al
      if (stored.length > i && stored[i] != null) {
        try {
          final c = stored[i];
          final lat = (c['lat'] as num).toDouble();
          final lng = (c['lng'] as num).toDouble();
          final coord = LatLng(lat, lng);
          newCoords[i] = coord;
          final icon = await _numberedMarker(i + 1,
              _isOptimized ? BrandColors.seljukTurquoise : Colors.grey.shade600);
          tempMarkers.add(Marker(
            markerId: MarkerId('p$i'),
            position: coord,
            infoWindow: InfoWindow(title: '${i + 1}. $name'),
            icon: icon,
            zIndex: 1,
          ));
          expand(lat, lng);
          loadedFromFirebase = true;
        } catch (_) {}
      }

      // Firestore'da yoksa veya bozuksa Places API'den çek
      if (!loadedFromFirebase) {
        debugPrint('⚠️ Koordinat yok, Places API kullanılıyor ($name)...');
        try {
          final url =
              'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
              '?input=${Uri.encodeComponent("$name Konya")}'
              '&inputtype=textquery&fields=geometry&key=$_kGoogleApiKey';
          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 8));
          final body = json.decode(res.body);
          if ((body['candidates'] as List?)?.isNotEmpty == true) {
            final loc = body['candidates'][0]['geometry']['location'];
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            final coord = LatLng(lat, lng);
            newCoords[i] = coord;
            final icon = await _numberedMarker(i + 1,
                _isOptimized ? BrandColors.seljukTurquoise : Colors.grey.shade600);
            tempMarkers.add(Marker(
              markerId: MarkerId('p$i'),
              position: coord,
              infoWindow: InfoWindow(title: '${i + 1}. $name'),
              icon: icon,
              zIndex: 1,
            ));
            expand(lat, lng);
          }
        } catch (e) {
          debugPrint('API hatası ($name): $e');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _markers = tempMarkers;
      _placeCoordinates = newCoords;
      _isLoadingMap = false;
    });

    _drawPolyline();

    if (tempMarkers.isNotEmpty && minLat != 90) {
      _bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng));
      Future.delayed(const Duration(milliseconds: 400), () {
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 80));
      });
    }
  }

  void _drawPolyline() {
    final pts = _placeCoordinates.whereType<LatLng>().toList();
    if (pts.isEmpty) return;
    final full = _startLatLng != null ? [_startLatLng!, ...pts] : pts;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: full,
          color: BrandColors.seljukTurquoise,
          width: 4,
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      };
    });
  }

  Future<BitmapDescriptor> _numberedMarker(int n, Color bg) async {
    const w = 80.0, h = 100.0, r = 30.0;
    const cx = w / 2, cy = r + 10;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final path = Path()
      ..moveTo(cx, h - 10)
      ..quadraticBezierTo(cx - r, cy + r, cx - r, cy)
      ..arcToPoint(Offset(cx + r, cy),
          radius: const Radius.circular(r), clockwise: true)
      ..quadraticBezierTo(cx + r, cy + r, cx, h - 10)
      ..close();

    canvas.drawPath(path.shift(const Offset(0, 5)), shadow);
    canvas.drawPath(path, Paint()..color = bg);
    canvas.drawCircle(Offset(cx, cy), r - 6, Paint()..color = Colors.white);

    final fs = n >= 10 ? 24.0 : 28.0;
    final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: fs))
      ..pushStyle(ui.TextStyle(color: bg, fontSize: fs, fontWeight: ui.FontWeight.w900))
      ..addText('$n');
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: w));
    canvas.drawParagraph(para, Offset(0, cy - para.height / 2));

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bd!.buffer.asUint8List(), width: 40, height: 50);
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}dk önce';
    if (d.inHours < 24) return '${d.inHours}sa önce';
    if (d.inDays < 7) return '${d.inDays}g önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userName = _data['userName'] ?? 'Gezgin';
    final userPhoto = _data['userPhotoUrl'] as String?;
    final routeName = _data['routeName'] ?? 'İsimsiz Rota';
    final description = (_data['description'] ?? '') as String;
    final totalKm = (_data['totalKm'] as num?)?.toDouble() ?? 0.0;
    final imageUrls = List<String>.from(_data['imageUrls'] ?? []);
    final ts = _data['createdAt'] as Timestamp?;
    final dateStr = ts != null ? _timeAgo(ts.toDate()) : 'Yeni';
    final isOwnPost =
        FirebaseAuth.instance.currentUser?.uid == _data['userId'];
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(routeName, style: BrandTypography.h3),
        centerTitle: true,
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: BrandColors.seljukTurquoise, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isOwnPost)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 24),
              onPressed: _deleteOwnPost,
            ),
        ],
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: _isLoadingPost
          // ── tam sayfa yüklenme ekranı ──────────────────────────
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: BrandColors.seljukTurquoise),
                  SizedBox(height: 16),
                  Text('Rota detayları yükleniyor...',
                      style: TextStyle(
                          color: BrandColors.textDark,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          // ── asıl içerik ──────────────────────────────────────
          : GlassBackground(
              child: _buildPanel(
                  ScrollController(), userName, userPhoto, dateStr,
                  description, totalKm, imageUrls, isOwnPost),
            ),

      floatingActionButton: _isLoadingPost || isOwnPost ? null : _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PANEL İÇERİĞİ
  // ─────────────────────────────────────────────────────────────
  Widget _buildPanel(
    ScrollController sc,
    String userName,
    String? userPhoto,
    String dateStr,
    String description,
    double totalKm,
    List<String> imageUrls,
    bool isOwnPost,
  ) {
    final rating = (_data['rating'] as num?)?.toDouble() ?? 0.0;

    return ListView(
      controller: sc,
      padding: const EdgeInsets.only(bottom: 120),
      physics: const ClampingScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),

        // ── Kullanıcı Bilgisi ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  BrandColors.seljukTurquoise.withOpacity(0.12),
              backgroundImage:
                  (userPhoto != null && userPhoto.isNotEmpty)
                      ? CachedNetworkImageProvider(userPhoto)
                      : null,
              child: (userPhoto == null || userPhoto.isEmpty)
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
                  Text(dateStr, style: BrandTypography.bodySmall),
                ],
              ),
            ),
            if (_isOptimized)
              _chip('✅ Optimize', BrandColors.seljukTurquoise),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Kaydedildi bandı ──────────────────────────────────
        if (!isOwnPost && _alreadySaved)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                Icon(Icons.bookmark_rounded,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text('Bu rota Kaydedilenler listenizde.',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700)),
              ]),
            ),
          ),

        // ── Fotoğraflar ────────────────────────────────────────
        if (imageUrls.isNotEmpty) ...[
          SizedBox(
            height: 230,
            child: PageView.builder(
              onPageChanged: (i) =>
                  setState(() => _currentImageIndex = i),
              itemCount: imageUrls.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[i],
                    fit: BoxFit.cover,
                    memCacheHeight: 800, // 🔥 OPTİMİZASYON: RAM ve Decode hızı için (Akıcılığı inanılmaz artırır)
                    fadeInDuration: const Duration(milliseconds: 200),
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
            ),
          ),
          if (imageUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imageUrls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _currentImageIndex == i ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _currentImageIndex == i
                          ? BrandColors.seljukTurquoise
                          : BrandColors.seljukTurquoise.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],

        // ── Açıklama ──────────────────────────────────────────
        if (description.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(description,
                style: BrandTypography.bodySmall
                    .copyWith(color: Colors.grey.shade700)),
          ),
          const SizedBox(height: 14),
        ],

        // ── İstatistikler ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rating > 0)
                    _badge(Icons.star_rounded, '$rating', Colors.amber),
                  _badge(Icons.place_rounded, '${_places.length} Mekan',
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
                    Text('${_data['commentCount'] ?? 0}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Rotadaki Mekanlar ─────────────────────────────────
        if (_places.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.format_list_numbered_rounded,
                  size: 18, color: BrandColors.seljukTurquoise),
              const SizedBox(width: 8),
              Text('Rotadaki Mekanlar',
                  style: BrandTypography.h3
                      .copyWith(color: BrandColors.seljukTurquoise)),
            ]),
          ),
          const SizedBox(height: 10),
          ..._places.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline node
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: BrandColors.seljukTurquoise.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: BrandColors.seljukTurquoise.withOpacity(0.3)),
                            ),
                            child: Center(
                              child: Text('${e.key + 1}',
                                  style: const TextStyle(
                                      color: BrandColors.seljukTurquoise,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if (e.key < _places.length - 1)
                            Container(
                              width: 2,
                              height: 40,
                              color: BrandColors.seljukTurquoise.withOpacity(0.2),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Card content
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: BrandColors.seljukTurquoise.withOpacity(0.15)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Text(e.value.toString(),
                                  style: BrandTypography.bodyMedium),
                            ),
                            // Koordinat yüklendiyse onay işareti
                            if (e.key < _placeCoordinates.length &&
                                _placeCoordinates[e.key] != null)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: BrandColors.seljukTurquoise.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle,
                                    size: 14, color: BrandColors.seljukTurquoise),
                              )
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ] else ...[
          // Mekan yoksa bilgi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.orange, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu post için mekan bilgisi bulunamadı.',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange),
                  ),
                ),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    if (_isRemoving) {
      return FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: Colors.redAccent,
        icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5)),
        label: const Text('Kaldırılıyor...',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      );
    }
    if (_isSaving) {
      return FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: BrandColors.seljukTurquoise,
        icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5)),
        label: const Text('Kaydediliyor...',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      );
    }
    if (_alreadySaved) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.green.shade500,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bookmark_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Kaydedildi',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _removeSavedRoute,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bookmark_remove_rounded,
                    color: Colors.red.shade400, size: 18),
                const SizedBox(width: 6),
                Text('Kaldır',
                    style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ]),
            ),
          ),
        ],
      );
    }
    return FloatingActionButton.extended(
      onPressed: _saveRoute,
      backgroundColor: BrandColors.seljukTurquoise,
      icon: const Icon(Icons.bookmark_add, color: Colors.white),
      label: const Text('Rotayı Kaydet',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // YARDIMCI WIDGET'LAR
  // ─────────────────────────────────────────────────────────────
  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
