import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glass_background.dart';
import '../services/route_optimizer_service.dart';

// 🔥 GOOGLE API ANAHTARIN
const String googleApiKey = "AIzaSyAbclSR-M23Z9MZZBXaTreBZIednbJXGgc";

class RouteDetailScreen extends StatefulWidget {
  final String routeId;
  final String routeName;
  final String? description;
  final List<dynamic> places;
  final String? startLocationName;
  final double? startLocationLat;
  final double? startLocationLng;
  final bool isOptimized;
  final double totalKm;
  final List<double> segmentKms;

  const RouteDetailScreen({
    super.key,
    required this.routeId,
    required this.routeName,
    this.description,
    required this.places,
    this.startLocationName,
    this.startLocationLat,
    this.startLocationLng,
    this.isOptimized = false,
    this.totalKm = 0.0,
    this.segmentKms = const [],
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen>
    with SingleTickerProviderStateMixin {
  final LatLng konyaCenter = const LatLng(37.8746, 32.4931);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  LatLngBounds? _bounds;

  String? _startLocationName;
  LatLng? _startLocationLatLng;
  bool _isSearchingStart = false;

  String currentRouteName = "";
  String currentDescription = "";
  List<dynamic> currentPlaces = [];

  // Koordinat cache — API'den bir kez çekip saklarız
  List<LatLng?> _placeCoordinates = [];

  // Optimizasyon state
  bool _isOptimizing = false;
  bool _isOptimized = false;
  double _totalRouteKm = 0;
  List<double> _segmentKms = []; // Her durağa mesafe (km)

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    currentRouteName = widget.routeName;
    currentDescription = widget.description ?? "";
    currentPlaces = List.from(widget.places);
    _isOptimized = widget.isOptimized;
    _totalRouteKm = widget.totalKm;
    _segmentKms = List.from(widget.segmentKms);

    if (widget.startLocationName != null &&
        widget.startLocationLat != null &&
        widget.startLocationLng != null) {
      _startLocationName = widget.startLocationName;
      _startLocationLatLng =
          LatLng(widget.startLocationLat!, widget.startLocationLng!);
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.85, end: 1.0).animate(_pulseController);

    _loadAllCoordinates();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // KOORDİNAT YÜKLEME + MARKER + POLYLİNE
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadAllCoordinates() async {
    Set<Marker> tempMarkers = {};
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    // Yeni koordinat listesi oluştur (places sırası ile eşleşecek)
    List<LatLng?> newCoords = List.filled(currentPlaces.length, null);

    void updateBounds(double lat, double lng) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    if (_startLocationLatLng != null) {
      tempMarkers.add(
        Marker(
          markerId: const MarkerId('start_point'),
          position: _startLocationLatLng!,
          infoWindow: InfoWindow(title: "📍 Başlangıç: $_startLocationName"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow),
          zIndex: 2,
        ),
      );
      updateBounds(
          _startLocationLatLng!.latitude, _startLocationLatLng!.longitude);
    }

    for (int i = 0; i < currentPlaces.length; i++) {
      String placeName = currentPlaces[i].toString();
      try {
        final url =
            "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent("$placeName Konya")}&inputtype=textquery&fields=geometry&key=$googleApiKey";
        final response = await http.get(Uri.parse(url));
        final data = json.decode(response.body);

        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final location = data['candidates'][0]['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final coord = LatLng(lat, lng);
          newCoords[i] = coord;

          final icon = await _createNumberedMarker(
            i + 1,
            Colors.grey.shade600,
          );
          tempMarkers.add(
            Marker(
              markerId: MarkerId(placeName),
              position: coord,
              infoWindow: InfoWindow(title: "${i + 1}. $placeName"),
              icon: icon,
              zIndex: 1,
            ),
          );
          updateBounds(lat, lng);
        }
      } catch (e) {
        debugPrint("Koordinat hatası ($placeName): $e");
      }
    }

    if (mounted) {
      setState(() {
        _markers = tempMarkers;
        _placeCoordinates = newCoords;
      });

      // Mevcut optimizasyon varsa polyline'ı yenile
      if (_isOptimized) _drawPolyline();

      if (tempMarkers.isNotEmpty && minLat != 90.0) {
        _bounds = LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng));
        if (_mapController != null) {
          _mapController!
              .animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 60.0));
        }
      }

      // ✅ Koordinatları Firebase'e kaydet (PostDetailScreen için)
      _saveCoordinatesToFirebase(newCoords);
    }
  }

  /// Koordinatları Firebase'e kaydeder — PostDetailScreen'in API'ye
  /// ihtiyaç duymadan marker gösterebilmesi için.
  Future<void> _saveCoordinatesToFirebase(List<LatLng?> coords) async {
    if (coords.every((c) => c == null)) return; // Hiç koordinat yoksa atla
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final coordList = coords
          .map((c) => c != null ? {'lat': c.latitude, 'lng': c.longitude} : null)
          .toList();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('routes')
          .doc(widget.routeId)
          .update({'placeCoordinates': coordList});
    } catch (e) {
      debugPrint('Koordinat kaydetme hatası: $e'); // kritik değil, sessiz hata
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🗺️ POLYLİNE ÇİZİMİ
  // ─────────────────────────────────────────────────────────────
  void _drawPolyline() {
    final List<LatLng> validCoords = _placeCoordinates
        .where((c) => c != null)
        .map((c) => c!)
        .toList();

    if (validCoords.isEmpty) return;

    final List<LatLng> fullPath = _startLocationLatLng != null
        ? [_startLocationLatLng!, ...validCoords]
        : validCoords;

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('optimized_route'),
          points: fullPath,
          color: BrandColors.seljukTurquoise,
          width: 4,
          patterns: [], // düz çizgi
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      };
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 🧠 ROTA OPTİMİZASYONU
  // ─────────────────────────────────────────────────────────────
  Future<void> _optimizeRoute() async {
    if (_isOptimizing) return;

    // Koordinatları kontrol et
    final validCoords =
        _placeCoordinates.where((c) => c != null).map((c) => c!).toList();
    if (validCoords.length < 2) {
      _showSnack(
          "⚠️ Optimizasyon için en az 2 mekanın koordinatı gereklidir.",
          Colors.orange);
      return;
    }
    if (validCoords.length < _placeCoordinates.length) {
      _showSnack(
          "⚠️ Bazı mekanların koordinatı bulunamadı. Lütfen bekleyin.",
          Colors.orange);
      return;
    }

    setState(() => _isOptimizing = true);

    // Küçük bir gecikme ile UI'ın busy state'i göstermesini sağla
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // Algoritma çalıştır
      final List<LatLng> pointList = _placeCoordinates
          .where((c) => c != null)
          .map((c) => c!)
          .toList();

      final result = RouteOptimizerService.optimizeRoute(
        startPoint: _startLocationLatLng,
        points: pointList,
      );

      if (result.orderedIndices.isEmpty) {
        setState(() => _isOptimizing = false);
        return;
      }

      // Yeni sırayı uygula
      final List<dynamic> newPlaces =
          result.orderedIndices.map((i) => currentPlaces[i]).toList();
      final List<LatLng?> newCoords =
          result.orderedIndices.map((i) => _placeCoordinates[i]).toList();

      // Segment mesafelerini hesapla
      final List<double> segs = RouteOptimizerService.segmentDistances(
        _startLocationLatLng,
        newCoords.where((c) => c != null).map((c) => c!).toList(),
      );

      // Firebase güncelle
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('routes')
            .doc(widget.routeId)
            .update({
              'places': newPlaces,
              'isOptimized': true,
              'totalKm': result.totalKm,
              'segmentKms': segs,
            });
      }

      // Marker'ları güncelle (sıra numaraları değişti)
      Set<Marker> updatedMarkers = {};
      if (_startLocationLatLng != null) {
        updatedMarkers.add(
          Marker(
            markerId: const MarkerId('start_point'),
            position: _startLocationLatLng!,
            infoWindow:
                InfoWindow(title: "📍 Başlangıç: $_startLocationName"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow),
            zIndex: 2,
          ),
        );
      }
      for (int i = 0; i < newPlaces.length; i++) {
        if (newCoords[i] != null) {
          final icon = await _createNumberedMarker(
            i + 1,
            BrandColors.seljukTurquoise,
          );
          updatedMarkers.add(
            Marker(
              markerId: MarkerId(newPlaces[i].toString()),
              position: newCoords[i]!,
              infoWindow: InfoWindow(title: "${i + 1}. ${newPlaces[i]}"),
              icon: icon,
              zIndex: 1,
            ),
          );
        }
      }

      setState(() {
        currentPlaces = newPlaces;
        _placeCoordinates = newCoords;
        _isOptimizing = false;
        _isOptimized = true;
        _totalRouteKm = result.totalKm;
        _segmentKms = segs;
        _markers = updatedMarkers;
      });

      _drawPolyline();

      _showSnack(
        "✅ Rota optimize edildi! Toplam ~${result.totalKm.toStringAsFixed(1)} km",
        BrandColors.seljukTurquoise,
      );
    } catch (e) {
      debugPrint("Optimizasyon hatası: $e");
      setState(() => _isOptimizing = false);
      _showSnack("❌ Optimizasyon sırasında hata oluştu.", Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // 🔢 NUMARALI MARKER OLUŞTURUCU
  // ─────────────────────────────────────────────────────────────


  // ─────────────────────────────────────────────────────────────
  // 🔢 NUMARALI MARKER OLUŞTURUCU
  // ─────────────────────────────────────────────────────────────
  Future<BitmapDescriptor> _createNumberedMarker(
      int number, Color bgColor) async {
    const double width = 80.0;
    const double height = 100.0;
    const double radius = 30.0;
    const double cx = width / 2;
    const double cy = radius + 10;
        
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // Gölge
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      
    // Damla (Teardrop) Şekli
    final Path markerPath = Path()
      ..moveTo(cx, height - 10) // İğnenin alt ucu
      ..quadraticBezierTo(cx - radius, cy + radius, cx - radius, cy)
      ..arcToPoint(Offset(cx + radius, cy), radius: const Radius.circular(radius), clockwise: true)
      ..quadraticBezierTo(cx + radius, cy + radius, cx, height - 10)
      ..close();

    canvas.drawPath(markerPath.shift(const Offset(0.0, 5.0)), shadowPaint);
    canvas.drawPath(markerPath, Paint()..color = bgColor);

    // İç beyaz daire
    canvas.drawCircle(Offset(cx, cy), radius - 6, Paint()..color = Colors.white);

    // Rakam (Rengi arka plan rengiyle aynı yapalım uyumlu olsun)
    final double fontSize = number >= 10 ? 24.0 : 28.0;
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w900,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: bgColor,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w900,
      ))
      ..addText('$number');

    final ui.Paragraph para = pb.build()
      ..layout(const ui.ParagraphConstraints(width: width));

    canvas.drawParagraph(
      para,
      Offset(0, cy - para.height / 2),
    );

    final ui.Image img = await recorder
        .endRecording()
        .toImage(width.toInt(), height.toInt());
    final ByteData? byteData =
        await img.toByteData(format: ui.ImageByteFormat.png);

    // BitmapDescriptor.bytes kullanıyoruz (fromBytes deprecated)
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: 40,
      height: 50,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ROTAYI DÜZENLEME (İSİM & AÇIKLAMA)
  // ─────────────────────────────────────────────────────────────
  Future<void> _showEditRouteDialog() async {
    TextEditingController nameController =
        TextEditingController(text: currentRouteName);
    TextEditingController descController =
        TextEditingController(text: currentDescription);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isNameEmpty = nameController.text.trim().isEmpty;

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 24.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.only(bottom: 24),
                        ),
                      ),
                      Text("Rotayı Düzenle", style: BrandTypography.h2),
                      const SizedBox(height: 8),
                      Text(
                          "Rota ismini ve açıklamalarını buradan güncelleyebilirsin.",
                          style: BrandTypography.bodySmall),
                      const SizedBox(height: 24),
                      Text("Rota Adı *",
                          style: BrandTypography.bodyBold.copyWith(
                              color: BrandColors.seljukTurquoise,
                              fontSize: 15)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        onChanged: (val) => setModalState(() {}),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: BrandColors.textDark),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text("Açıklama / Notlar",
                          style: BrandTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        style: const TextStyle(color: BrandColors.textDark),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              label: "İptal",
                              color: Colors.grey.shade400,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GlassButton(
                              label: "Kaydet",
                              color: isNameEmpty
                                  ? Colors.grey
                                  : BrandColors.seljukTurquoise,
                              onPressed: isNameEmpty
                                  ? () {}
                                  : () async {
                                      final newName = nameController.text.trim();
                                      final newDesc = descController.text.trim();
                                      User? user =
                                          FirebaseAuth.instance.currentUser;

                                      if (user != null) {
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .collection('routes')
                                            .doc(widget.routeId)
                                            .update({
                                          'routeName': newName,
                                          'description': newDesc,
                                        });

                                        setState(() {
                                          currentRouteName = newName;
                                          currentDescription = newDesc;
                                        });
                                      }

                                      if (mounted) {
                                        Navigator.pop(context);
                                        _showSnack(
                                            "Rota başarıyla güncellendi! ✅",
                                            BrandColors.seljukTurquoise);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ROTADAN MEKAN ÇIKARMA
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmRemovePlace(int index) async {
    final placeToRemove = currentPlaces[index];
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Mekanı Çıkar", style: BrandTypography.h3),
        content: Text("'$placeToRemove' rotadan çıkarılacak. Emin misiniz?",
            style: BrandTypography.bodySmall),
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
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassButton(
                  label: "Çıkar",
                  color: Colors.redAccent,
                  height: 48,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      _removePlaceFromRoute(index);
    }
  }

  Future<void> _removePlaceFromRoute(int index) async {
    final placeToRemove = currentPlaces[index];
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentPlaces.removeAt(index);
        if (_placeCoordinates.length > index) {
          _placeCoordinates.removeAt(index);
        }
        if (_segmentKms.length > index) _segmentKms.removeAt(index);
        _isOptimized = false;
        _polylines = {};
      });
      _loadAllCoordinates();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('routes')
          .doc(widget.routeId)
          .update({
            'places': currentPlaces,
            'isOptimized': false,
            'totalKm': FieldValue.delete(),
            'segmentKms': FieldValue.delete(),
          });
      if (mounted) {
        _showSnack("🗑️ $placeToRemove rotadan çıkarıldı.", Colors.redAccent);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BAŞLANGIÇ NOKTASI
  // ─────────────────────────────────────────────────────────────
  void _showStartLocationDialog() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
                color: Colors.white.withOpacity(0.9), width: 1.5)),
        title: Text("Başlangıç Noktası Seç", style: BrandTypography.h3),
        content: TextField(
          controller: controller,
          style: const TextStyle(
              color: BrandColors.textDark, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintStyle: TextStyle(
                color: Colors.grey.shade500, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: Colors.white.withOpacity(0.7),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            prefixIcon: const Icon(Icons.hotel, color: BrandColors.seljukTurquoise),
          ),
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
                  label: "Ayarla",
                  height: 48,
                  onPressed: () async {
                    String query = controller.text.trim();
                    if (query.isNotEmpty) {
                      Navigator.pop(context);
                      _findAndSetStartLocation(query);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _findAndSetStartLocation(String query) async {
    setState(() => _isSearchingStart = true);
    try {
      final url =
          "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent("$query Konya")}&inputtype=textquery&fields=geometry,name&key=$googleApiKey";
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final loc = data['candidates'][0]['geometry']['location'];
        String foundName = data['candidates'][0]['name'] ?? query;

        setState(() {
          _startLocationName = foundName;
          _startLocationLatLng = LatLng(loc['lat'], loc['lng']);
          _isSearchingStart = false;
          // Başlangıç değişince optimizasyonu sıfırla
          _isOptimized = false;
          _polylines = {};
        });

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('routes')
              .doc(widget.routeId)
              .update({
            'startLocationName': foundName,
            'startLocationLat': loc['lat'],
            'startLocationLng': loc['lng'],
            'isOptimized': false,
            'totalKm': FieldValue.delete(),
            'segmentKms': FieldValue.delete(),
          });
        }

        _loadAllCoordinates();
      } else {
        setState(() => _isSearchingStart = false);
        _showSnack("Konum bulunamadı, lütfen daha açık yazın.", Colors.orange);
      }
    } catch (e) {
      setState(() => _isSearchingStart = false);
      debugPrint("Başlangıç bulma hatası: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(currentRouteName, style: BrandTypography.h3),
        centerTitle: true,
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: BrandColors.seljukTurquoise, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ─── 🗺️ HARİTA — Tam Ekran ───────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: konyaCenter, zoom: 12.0),
              zoomControlsEnabled: false,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              // Harita, sheet'in minChildSize'ına göre padding alır;
              // sheet yukarı çekildikçe harita bu alanı kazanır.
              padding: EdgeInsets.only(bottom: screenHeight * 0.42),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_bounds != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _mapController
                        ?.animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 60.0));
                  });
                }
              },
            ),
          ),

          // ─── 📝 DRAGGABLE GLASSMORPHISM PANEL ────────────────
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.50,
            minChildSize: 0.40,
            maxChildSize: 0.90,
            snap: true,
            snapSizes: const [0.40, 0.60, 0.90],
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32)),
                      border: Border(
                          top: BorderSide(
                              color: Colors.white.withOpacity(0.9),
                              width: 1.5)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, -4)),
                      ],
                    ),
                    // CustomScrollView: sheet drag'i ile liste scroll'u
                    // tek bir ScrollController üzerinde çalışır.
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // ── Sabit İçerik (başlık, açıklama, araçlar) ──
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Handle bar
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      top: 14, bottom: 16),
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade400
                                          .withOpacity(0.5),
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              ),

                              // ── Başlık Satırı ──
                              FadeSlideUp(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentRouteName,
                                              style: BrandTypography.h1
                                                  .copyWith(height: 1.1),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            if (_isOptimized) ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 10,
                                                    vertical: 4),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      BrandColors
                                                          .seljukTurquoise
                                                          .withOpacity(0.85),
                                                      BrandColors.accentSand
                                                          .withOpacity(0.85),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                        Icons.auto_awesome,
                                                        color: Colors.white,
                                                        size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "Optimize Edildi • ${_totalRouteKm.toStringAsFixed(1)} km",
                                                      style: BrandTypography
                                                          .caption
                                                          .copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        children: [
                                          GestureDetector(
                                            onTap: _showEditRouteDialog,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: BrandColors
                                                      .accentSand
                                                      .withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: BrandColors
                                                          .accentSand
                                                          .withOpacity(0.3),
                                                      width: 1)),
                                              child: const Icon(
                                                  Icons.edit_rounded,
                                                  size: 20,
                                                  color:
                                                      BrandColors.accentSand),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                                color: BrandColors
                                                    .seljukTurquoise
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: BrandColors
                                                        .seljukTurquoise
                                                        .withOpacity(0.3),
                                                    width: 1)),
                                            child: Text(
                                              "${currentPlaces.length} Mekan",
                                              style: BrandTypography.caption
                                                  .copyWith(
                                                      color: BrandColors
                                                          .seljukTurquoise,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Açıklama
                              if (currentDescription.isNotEmpty)
                                FadeSlideUp(
                                  delay: const Duration(milliseconds: 100),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 10, 24, 0),
                                    child: Text(currentDescription,
                                        style: BrandTypography.bodySmall),
                                  ),
                                ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                child: Divider(
                                    height: 22,
                                    color: Colors.grey.withOpacity(0.3)),
                              ),

                              // ── Başlangıç Noktası Kutusu ──
                              FadeSlideUp(
                                delay: const Duration(milliseconds: 150),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0),
                                  child: InkWell(
                                    onTap: _isSearchingStart
                                        ? null
                                        : _showStartLocationDialog,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _startLocationName == null
                                            ? Colors.white.withOpacity(0.5)
                                            : BrandColors.seljukTurquoise
                                                .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: _startLocationName == null
                                                ? Colors.white
                                                    .withOpacity(0.9)
                                                : BrandColors.seljukTurquoise
                                                    .withOpacity(0.4),
                                            width: 1.5),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                                color: _startLocationName ==
                                                        null
                                                    ? BrandColors.accentSand
                                                        .withOpacity(0.2)
                                                    : BrandColors
                                                        .seljukTurquoise
                                                        .withOpacity(0.2),
                                                shape: BoxShape.circle),
                                            child: Icon(
                                                Icons.my_location,
                                                color: _startLocationName ==
                                                        null
                                                    ? Colors.orange.shade700
                                                    : BrandColors
                                                        .seljukTurquoise,
                                                size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _startLocationName != null
                                                      ? "Başlangıç: $_startLocationName"
                                                      : "Başlangıç Noktası Ekle",
                                                  style:
                                                      BrandTypography.bodyBold,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _startLocationName != null
                                                      ? "Dönüş noktanız belirlendi."
                                                      : "Optimizasyon için ekleyin.",
                                                  style: BrandTypography
                                                      .bodySmall
                                                      .copyWith(fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_isSearchingStart)
                                            const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: BrandColors
                                                            .seljukTurquoise))
                                          else
                                            Icon(
                                              _startLocationName == null
                                                  ? Icons
                                                      .add_circle_outline_rounded
                                                  : Icons.edit_rounded,
                                              color:
                                                  _startLocationName == null
                                                      ? BrandColors.accentSand
                                                      : BrandColors
                                                          .seljukTurquoise,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // ── 🧠 OPTİMİZASYON BUTONU ──
                              FadeSlideUp(
                                delay: const Duration(milliseconds: 200),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0),
                                  child: _isOptimizing
                                      ? ScaleTransition(
                                          scale: _pulseAnimation,
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  BrandColors.seljukTurquoise
                                                      .withOpacity(0.7),
                                                  BrandColors.accentSand
                                                      .withOpacity(0.7),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2),
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  "Rota Hesaplanıyor...",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 14,
                                                      letterSpacing: 0.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: _optimizeRoute,
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: _isOptimized
                                                    ? [
                                                        Colors.green.shade400,
                                                        Colors.teal.shade400,
                                                      ]
                                                    : [
                                                        BrandColors
                                                            .seljukTurquoise,
                                                        BrandColors.accentSand
                                                            .withOpacity(0.85),
                                                      ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: BrandColors
                                                      .seljukTurquoise
                                                      .withOpacity(0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _isOptimized
                                                      ? Icons
                                                          .check_circle_rounded
                                                      : Icons.route_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _isOptimized
                                                      ? "Yeniden Optimize Et"
                                                      : "Rotayı Optimize Et",
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 14,
                                                      letterSpacing: 0.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ── Mekanlar Bölüm Başlığı ──
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 16,
                                      decoration: BoxDecoration(
                                          color: BrandColors.seljukTurquoise,
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Duraklar",
                                      style: BrandTypography.h3.copyWith(
                                          fontSize: 15,
                                          color: BrandColors.textDark),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),
                            ],
                          ),
                        ),

                        // ── 📍 MEKAN LİSTESİ (SliverList) ──────────
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final double segKm = (_isOptimized &&
                                        _segmentKms.length > index)
                                    ? _segmentKms[index]
                                    : -1;

                                return FadeSlideUp(
                                  delay: Duration(
                                      milliseconds: 100 + (index * 40)),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.6),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                            color: _isOptimized
                                                ? BrandColors.seljukTurquoise
                                                    .withOpacity(0.25)
                                                : Colors.white
                                                    .withOpacity(0.8),
                                            width: 1),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: _isOptimized
                                                  ? BrandColors.seljukTurquoise
                                                  : Colors.grey.shade300,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                "${index + 1}",
                                                style: TextStyle(
                                                  color: _isOptimized
                                                      ? Colors.white
                                                      : Colors.grey.shade700,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  currentPlaces[index]
                                                      .toString(),
                                                  style:
                                                      BrandTypography.bodyBold,
                                                ),
                                                if (segKm >= 0) ...[
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .arrow_upward_rounded,
                                                          size: 12,
                                                          color: Colors
                                                              .grey.shade500),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        segKm < 1
                                                            ? "${(segKm * 1000).toStringAsFixed(0)} m önceki noktadan"
                                                            : "${segKm.toStringAsFixed(1)} km önceki noktadan",
                                                        style: BrandTypography
                                                            .bodySmall
                                                            .copyWith(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.cancel_outlined,
                                                color: Colors.redAccent,
                                                size: 22),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                            onPressed: () =>
                                                _confirmRemovePlace(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: currentPlaces.length,
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(
                            child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}