import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/glass_background.dart';
import '../services/google_places_service.dart';

// 🔥 GOOGLE API ANAHTARIN
const String googleApiKey = "AIzaSyAbclSR-M23Z9MZZBXaTreBZIednbJXGgc";

class PlacesScreen extends StatefulWidget {
  final List<String> selectedCategories;
  const PlacesScreen({super.key, required this.selectedCategories});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<String> selectedPlaces = [];
  String searchQuery = "";
  String currentSort = "Varsayılan";
  double minRating = 0.0;
  String currentPriceFilter = "Tümü";
  bool filterOutdoor = false;

  // 🔥 FAVORİ SİSTEMİ DEĞİŞKENLERİ
  bool filterFavorites = false;
  List<String> userFavorites = [];

/*
  Future<void> _verileriSifirlaVeYukle() async {
    print("🚀 NÜKLEER TEMİZLİK VE YÜKLEME BAŞLADI...");
    
    await DataManager.cleanAllData('places');
    await DataManager.cleanAllData('banners');

    Map<String, Map<String, List<String>>> tamListe = {
      "Doğa": {
        "Park": ["Japon Kyoto Parkı", "Kültürpark ve Dede Bahçesi", "Sille Baraj Parkı", "Türk Yıldızları Parkı", "Karaaslan Hadimi Parkı", "80 Binde Devr-i Alem Parkı"],
        "Doğa Alanı": ["Meram Bağları ve Bahçeleri", "Alaeddin Tepesi", "Tavus Baba Koruluğu", "Konya Kent Ormanı"]
      },
      "Kültür": {
        "Müze": ["Mevlana Müzesi", "Karatay Medresesi", "İnce Minareli Medrese", "Arkeoloji Müzesi", "Konya Panorama Müzesi"],
        "Cami": ["Alaeddin Camii", "Sultan Selim (Selimiye) Camii", "Şems Camii ve Türbesi", "Aziziye Camii", "Kapu Camii"],
        "Tarihi & Antik": ["Çatalhöyük", "Sille", "Zazadin Hanı", "Sırçalı Medrese", "Konya Bedesteni"]
      },
      "Eğlence": {
        "Aktivite": ["Tropikal Kelebek Bahçesi", "Konya Bilim Merkezi"],
        "Açık Hava": ["Kültürpark", "Meram Bağları", "Kent Ormanı", "Karaaslan Parkı"]
      },
      "Alışveriş": {
        "AVM": ["Kulesite AVM", "Kentplaza AVM", "M1 Konya AVM", "Novaland Outlet"],
        "Tarihi Çarşı": ["Tarihi Buğday Pazarı"]
      },
      "Yemek": {
        "Yöresel": ["Cemo Etliekmek", "Celal Bey Etli Ekmek", "Havzan Etliekmek", "Ferah Etliekmek", "Hacı Şükrü", "Ali Baba Fırın Kebap", "Gazyağcı Furun Kebabı", "Tiritçi Mithat", "Lokmahane", "Konya Mutfağı (Akyokuş)", "Konya Mutfağı (Mevlana)"],
        "Kafe / KAFEM": ["KAFEM Şehitlik Çay Bahçesi", "KAFEM Kalehan Ecdat Bahçesi", "KAFEM Alaaddin Çay Bahçesi", "KAFEM Bilim Merkezi", "Osmanlı Kahvehanesi Kalehan", "KAFEM Camlı Köşk", "KAFEM Japon Parkı", "KAFEM Dede Bahçesi", "KAFEM Gençlik Merkezi", "KAFEM Şefikcan", "KAFEM Nişantaşı", "KAFEM Konevi", "KAFEM Tavusbaba", "KAFEM Akyokuş Park", "KAFEM Çamlıbel", "KAFEM Evliya Çelebi"]
      }
    };

    await DataManager.uploadMegaData(tamListe);
    await DataManager.uploadBanners();

    print("🏁 İŞLEM BİTTİ! VERİTABANI ARTIK JİLET GİBİ!");
  }
*/
  late Stream<QuerySnapshot> _placesStream;

  @override
  void initState() {
    super.initState();
    _fetchUserFavorites(); // Açılışta favorileri çek
    
    // Firestore stream'ini initState'te tanımlıyoruz ki her setState'te (favoriye basınca) liste tamamen sıfırlanıp başa sarmasın.
    _placesStream = widget.selectedCategories.isEmpty
        ? FirebaseFirestore.instance.collection('places').snapshots()
        : FirebaseFirestore.instance.collection('places').where('category', whereIn: widget.selectedCategories).snapshots();
  }

  // 🔥 FAVORİLERİ FİREBASE'DEN ÇEKEN FONKSİYON
  Future<void> _fetchUserFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final favs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .get();
      if (mounted) {
        setState(() {
          userFavorites = favs.docs.map((doc) => doc.id).toList();
        });
      }
    }
  }

  // 🔥 FAVORİ EKLE/SİL FONKSİYONU
  Future<void> _toggleFavorite(String placeName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(placeName);

    if (userFavorites.contains(placeName)) {
      await favRef.delete();
      setState(() => userFavorites.remove(placeName));
    } else {
      await favRef.set({'addedAt': FieldValue.serverTimestamp()});
      setState(() => userFavorites.add(placeName));
    }
  }

  // 🔥 PUANLARI GÜVENLİCE SAYIYA ÇEVİREN YARDIMCI FONKSİYON
  double _safeParseRating(dynamic r) {
    if (r == null) return 0.0;
    if (r is num) return r.toDouble();
    return double.tryParse(r.toString()) ?? 0.0;
  }

  // --- DETAYLI FİLTRE BOTTOM SHEET ---
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32))
              ),
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10)
                            ),
                            margin: const EdgeInsets.only(bottom: 20)
                        )
                    ),
                    const Text("Detaylı Filtre", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: BrandColors.textDark)),
                    const SizedBox(height: 20),

                    // ❤️ FAVORİLERİM FİLTRESİ
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("❤️ Sadece Favorilerim", style: TextStyle(fontWeight: FontWeight.w600, color: BrandColors.textDark)),
                        value: filterFavorites,
                        activeColor: Colors.redAccent,
                        onChanged: (val) {
                          setModalState(() => filterFavorites = val);
                          setState(() => filterFavorites = val);
                        }
                    ),
                    const Divider(),

                    const Text("Minimum Puan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [0.0, 3.0, 4.0, 4.5].map((rating) {
                        bool isSel = minRating == rating;
                        return ChoiceChip(
                            label: Text(rating == 0 ? "Farketmez" : "⭐ $rating+"),
                            selected: isSel,
                            selectedColor: BrandColors.seljukTurquoise,
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(
                                color: isSel ? Colors.white : BrandColors.seljukTurquoise,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500
                            ),
                            onSelected: (selected) {
                              setModalState(() => minRating = rating);
                              setState(() => minRating = rating);
                            }
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text("Özellikler", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("🌳 Açık Hava Mekanı", style: TextStyle(fontWeight: FontWeight.w500, color: BrandColors.textDark)),
                        value: filterOutdoor,
                        activeColor: BrandColors.accentSand,
                        activeTrackColor: BrandColors.seljukTurquoise,
                        onChanged: (val) {
                          setModalState(() => filterOutdoor = val);
                          setState(() => filterOutdoor = val);
                        }
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      label: "Sonuçları Göster",
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSaveRouteBottomSheet() {
    TextEditingController routeNameController = TextEditingController();
    TextEditingController descController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Enables keyboard interaction
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isNameEmpty = routeNameController.text.trim().isEmpty;
            
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.only(bottom: 24)
                          )
                      ),
                      const Text("Rotanı Kaydet", style: TextStyle(color: BrandColors.textDark, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      Text("Harika bir gezi planı oluşturdun. Bu rotayı Rotalarım'a kaydet.", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      const SizedBox(height: 24),
                      
                      const Text("Rota Adı *", style: TextStyle(fontWeight: FontWeight.bold, color: BrandColors.seljukTurquoise, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: routeNameController,
                          onChanged: (val) => setModalState(() {}),
                          enabled: true,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: BrandColors.textDark),
                          decoration: InputDecoration(
                              //hintText: "Örn: Hafta Sonu Turu",
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                          )
                      ),
                      const SizedBox(height: 20),

                      const Text("Açıklama / Notlar", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: descController,
                          maxLines: 3,
                          style: const TextStyle(color: BrandColors.textDark),
                          decoration: InputDecoration(
                              //hintText: "Rotaya eklemek istediğiniz notlar...",
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                          )
                      ),
                      const SizedBox(height: 32),
                      
                      const SizedBox(height: 32),
                      
                      GlassButton(
                        label: "Rotayı Kaydet",
                        color: isNameEmpty ? Colors.grey : BrandColors.seljukTurquoise,
                        onPressed: isNameEmpty ? () {} : () async {
                          User? user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('routes')
                                .add({
                              'routeName': routeNameController.text.trim(),
                              'description': descController.text.trim(),
                              'places': selectedPlaces,
                              'createdAt': FieldValue.serverTimestamp()
                            });
                            if (mounted) {
                              Navigator.pop(context); // Bottom sheet'i kapat
                              setState(() => selectedPlaces.clear()); // Seçimleri temizle
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Rota başarıyla Rotalarım sayfasına kaydedildi!", style: TextStyle(fontWeight: FontWeight.bold)),
                                  backgroundColor: BrandColors.seljukTurquoise,
                                  behavior: SnackBarBehavior.floating, // Havada duran zarif bildirim
                                  margin: EdgeInsets.all(20), // Köşelerden biraz içeride
                                  duration: Duration(seconds: 3),
                                )
                              );
                            }
                          }
                        },
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

  void _showPlaceDetails(BuildContext context, Map<String, dynamic> data, String placeName) {
    int currentImageIndex = 0;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return FutureBuilder<Map<String, dynamic>>(
              future: GooglePlacesService.getGooglePlaceData(placeName),
              builder: (context, dataSnap) {
                List<String> urls = dataSnap.hasData ? List<String>.from(dataSnap.data!['photos']) : [];
                final realRating = dataSnap.data?['rating'] ?? data['rating'].toString();

                return DraggableScrollableSheet(
                  initialChildSize: 0.75,
                  builder: (_, controller) {
                    return StatefulBuilder(
                        builder: (BuildContext context, StateSetter setSheetState) {
                          bool isAdded = selectedPlaces.contains(placeName);
                          bool isFav = userFavorites.contains(placeName);

                          return Container(
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(32))
                            ),
                            child: ListView(
                              controller: controller,
                              padding: EdgeInsets.zero,
                              children: [
                                Stack(
                                  children: [
                                    SizedBox(
                                      height: 280,
                                      child: Hero(
                                        tag: "photo_$placeName",
                                        child: urls.isNotEmpty
                                            ? PageView.builder(
                                          itemCount: urls.length,
                                          onPageChanged: (index) => setSheetState(() => currentImageIndex = index),
                                          itemBuilder: (context, index) => GooglePlacesService.buildPlaceImage(
                                              urls[index],
                                              fit: BoxFit.cover,
                                          ),
                                        )
                                            : Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey))),
                                      ),
                                    ),
                                    Positioned(
                                        top: 16,
                                        right: 16,
                                        child: CircleAvatar(
                                            backgroundColor: Colors.black.withOpacity(0.4),
                                            child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                                        )
                                    ),

                                    // 🔥 DETAYDA FAVORİ BUTONU
                                    Positioned(
                                        top: 16,
                                        left: 16,
                                        child: CircleAvatar(
                                            backgroundColor: Colors.white.withOpacity(0.9),
                                            child: IconButton(
                                                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent),
                                                onPressed: () {
                                                  _toggleFavorite(placeName);
                                                  setSheetState(() {});
                                                  setState(() {});
                                                }
                                            )
                                        )
                                    ),

                                    if(urls.length > 1)
                                      Positioned(
                                          bottom: 12,
                                          right: 16,
                                          child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                                              child: Text("${currentImageIndex + 1}/${urls.length}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                                          )
                                      ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(placeName, style: BrandTypography.h2.copyWith(color: BrandColors.seljukTurquoise))),
                                            Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(color: BrandColors.seljukTurquoise.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                                                child: Row(children: [const Icon(Icons.star_rounded, color: BrandColors.accentSand, size: 20), const SizedBox(width: 4), Text(realRating, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BrandColors.textDark))])
                                            ),
                                          ]),
                                      const SizedBox(height: 8),
                                      Text("${data['city'] ?? 'Konya'}", style: TextStyle(fontSize: 15, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 28),
                                      const Text("Adres", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.seljukTurquoise)),
                                      const SizedBox(height: 12),
                                      Text(data['description'] ?? "Mekan detayları yakında eklenecektir.", style: BrandTypography.bodyMedium.copyWith(color: Colors.grey.shade700, height: 1.6)),
                                      const SizedBox(height: 40),
                                      GlassButton(
                                        label: isAdded ? "Rotaya Eklendi" : "Rotama Ekle",
                                        icon: isAdded ? Icons.check_circle : Icons.add_location_alt,
                                        color: isAdded ? BrandColors.textDark : BrandColors.seljukTurquoise,
                                        onPressed: () {
                                          setSheetState(() => isAdded ? selectedPlaces.remove(placeName) : selectedPlaces.add(placeName));
                                          setState(() {});
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        }
                    );
                  },
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Keşfet", style: BrandTypography.h2),
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
        child: Column(
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          style: BrandTypography.bodyMedium,
                          decoration: InputDecoration(
                              hintText: "Ara...",
                              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                              prefixIcon: const Icon(Icons.search_rounded, color: BrandColors.seljukTurquoise, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12)
                          ),
                          onChanged: (value) => setState(() => searchQuery = value.toLowerCase())
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                        icon: const Icon(Icons.sort_rounded, color: BrandColors.seljukTurquoise),
                        onSelected: (value) => setState(() => currentSort = value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: "Varsayılan", child: Text("Varsayılan")),
                          const PopupMenuItem(value: "⭐ Puan", child: Text("⭐ En Yüksek Puan")),
                          const PopupMenuItem(value: "🔤 A-Z", child: Text("🔤 A'dan Z'ye"))
                        ]
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: BrandColors.seljukTurquoise), 
                      onPressed: _showFilterBottomSheet
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _placesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: BrandColors.seljukTurquoise));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("Mekan bulunamadı.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)));

                // 🔥 FİLTRELEME MANTIĞI
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String name = (data['name'] ?? "").toString();
                  double rating = _safeParseRating(data['rating']);

                  if (searchQuery.isNotEmpty && !name.toLowerCase().contains(searchQuery)) return false;
                  if (rating < minRating) return false;
                  
                  // 🔥 AÇIK HAVA (Sadece Doğa ve Park kategorilerini alır)
                  if (filterOutdoor && data['category'] != 'Doğa') return false;
                  
                  if (filterFavorites && !userFavorites.contains(name)) return false;
                  return true;
                }).toList();

                // 🔥 SIRALAMA MANTIĞI
                filteredDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  if (currentSort == '⭐ Puan') {
                    return _safeParseRating(dataB['rating']).compareTo(_safeParseRating(dataA['rating']));
                  }
                  if (currentSort == '🔤 A-Z') {
                    return (dataA['name']?.toString() ?? "").compareTo(dataB['name']?.toString() ?? "");
                  }
                  return 0;
                });

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 130), // Navigasyon bar altında ezilme payı
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var data = filteredDocs[index].data() as Map<String, dynamic>;
                    String name = data['name'] ?? "Mekan";

                    var cachedParam = GooglePlacesService.getCachedData(name);

                    return FutureBuilder<Map<String, dynamic>>(
                        initialData: cachedParam,
                        future: cachedParam != null ? null : GooglePlacesService.getGooglePlaceData(name),
                        builder: (context, dataSnap) {
                          String thumb = dataSnap.hasData && dataSnap.data!['photos'].isNotEmpty ? dataSnap.data!['photos'][0] : "";
                          String realRating = dataSnap.data?['rating'] ?? _safeParseRating(data['rating']).toString();
                          bool isAdded = selectedPlaces.contains(name);
                          bool isFav = userFavorites.contains(name);

                          return FadeSlideUp(
                            delay: Duration(milliseconds: index * 100),
                            duration: const Duration(milliseconds: 600),
                            child: GlassCard(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              padding: EdgeInsets.zero,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () => _showPlaceDetails(context, data, name),
                                child: Row(children: [
                                  SizedBox(
                                      width: 130,
                                      height: 130,
                                      child: Hero(
                                        tag: "photo_$name",
                                        child: ClipRRect(
                                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                                            child: thumb.isNotEmpty
                                                ? GooglePlacesService.buildPlaceImage(thumb, fit: BoxFit.cover)
                                                : Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey))
                                        ),
                                      )
                                  ),
                                  Expanded(
                                      child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: BrandTypography.bodyBold.copyWith(color: BrandColors.seljukTurquoise), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                Text(data['category'] ?? "Konya", style: BrandTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                                const SizedBox(height: 14),
                                                Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(children: [const Icon(Icons.star_rounded, color: BrandColors.accentSand, size: 18), const SizedBox(width: 4), Text(realRating, style: BrandTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: BrandColors.textDark))]),
                                                      Row(children: [
                                                        // 🔥 FAVORİ KALP BUTONU
                                                        GestureDetector(onTap: () => _toggleFavorite(name), child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 24)),
                                                        const SizedBox(width: 12),
                                                        GestureDetector(
                                                            onTap: () {
                                                              setState(() { isAdded ? selectedPlaces.remove(name) : selectedPlaces.add(name); });
                                                            },
                                                            child: CircleAvatar(
                                                                radius: 16,
                                                                backgroundColor: isAdded ? BrandColors.textDark : BrandColors.seljukTurquoise.withOpacity(0.08),
                                                                child: Icon(isAdded ? Icons.check : Icons.add, color: isAdded ? Colors.white : BrandColors.seljukTurquoise, size: 20)
                                                            )
                                                        ),
                                                      ]),
                                                    ]),
                                              ]
                                          )
                                      )
                                  ),
                                ]),
                              ),
                            ),
                          );
                        }
                    );
                  },
                );
              },
            ),
          ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedPlaces.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90.0, left: 32, right: 32),
              child: GlassButton(
                label: "${selectedPlaces.length} Mekan • Rotayı Kaydet",
                icon: Icons.map_outlined,
                onPressed: _showSaveRouteBottomSheet,
              ),
          )
          : null,
    );
  }
}

// BU KODU places_screen.dart DOSYASININ EN ALTINA YAPIŞTIR
class DataManager {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String googleApiKey = "AIzaSyAbclSR-M23Z9MZZBXaTreBZIednbJXGgc";

  static Future<void> cleanAllData(String collectionName) async {
    final snapshots = await _db.collection(collectionName).get();
    for (var doc in snapshots.docs) { await doc.reference.delete(); }
  }

  static Future<void> uploadMegaData(Map<String, Map<String, List<String>>> megaList) async {
    for (String mainCategory in megaList.keys) {
      Map<String, List<String>> subCategories = megaList[mainCategory]!;
      for (String subCategory in subCategories.keys) {
        for (String name in subCategories[subCategory]!) {
          String cleanName = name.trim();
          final existing = await _db.collection('places').where('name', isEqualTo: cleanName).get();
          if (existing.docs.isNotEmpty) continue;
          try {
            final searchUrl = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent("$cleanName Konya")}&inputtype=textquery&fields=rating,formatted_address&key=$googleApiKey";
            final response = await http.get(Uri.parse(searchUrl));
            final data = json.decode(response.body);
            double rating = 0.0;
            String addressDesc = "$cleanName, Konya'da görülmesi gereken bir yerdir.";
            if (data['candidates'] != null && data['candidates'].isNotEmpty) {
              rating = (data['candidates'][0]['rating'] ?? 0.0).toDouble();
              addressDesc = data['candidates'][0]['formatted_address'] ?? addressDesc;
            }
            bool isOutdoor = true;
            if (mainCategory == "Alışveriş" || subCategory == "Müze" || subCategory == "Cami" || cleanName.toLowerCase().contains("müzesi") || cleanName.toLowerCase().contains("avm")) {
              isOutdoor = false;
            }
            await _db.collection('places').add({
              "name": cleanName, "rating": rating, "category": mainCategory, "subCategory": subCategory, "description": addressDesc, "isOutdoor": isOutdoor, "createdAt": FieldValue.serverTimestamp(),
            });
            print("✅ $cleanName eklendi.");
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) { print("❌ Hata: $e"); }
        }
      }
    }
  }

  static Future<void> uploadBanners() async {
    List<Map<String, String>> banners = [
      {"title": "Konya Lale Festivali", "subtitle": "Karatay Şehir Parkı'nda Renk Cümbüşü!"},
      {"title": "Sille Antik Kenti", "subtitle": "Tarihe ve Doğaya Yolculuk"},
      {"title": "Tropikal Kelebek Bahçesi", "subtitle": "Büyülü Kelebek Dünyasını Keşfet"},
    ];
    for (var b in banners) {
      final existing = await _db.collection('banners').where('title', isEqualTo: b['title']).get();
      if (existing.docs.isEmpty) await _db.collection('banners').add(b);
    }
  }
}