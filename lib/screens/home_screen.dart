import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'places_screen.dart';
import '../widgets/glass_background.dart';
import '../services/google_places_service.dart';

// 🔥 GOOGLE ANAHTARIN
const String googleApiKey = "AIzaSyAbclSR-M23Z9MZZBXaTreBZIednbJXGgc";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> selectedCategories = [];
  String currentTemp = "--°C";
  IconData weatherIcon = Icons.hourglass_empty;
  Color weatherColor = Colors.orange;

  int _currentBannerIndex = 0;
  int _totalBanners = 0;
  final PageController _pageController = PageController();
  Timer? _carouselTimer;

  late Stream<QuerySnapshot> _bannersStream;
  late Stream<QuerySnapshot> _trendingPlacesStream;
  
  String? _displayName;

  final List<Map<String, dynamic>> categoryData = [
    {"name": "Kültür", "icon": Icons.account_balance},
    {"name": "Yemek", "icon": Icons.restaurant},
    {"name": "Doğa", "icon": Icons.park},
    {"name": "Alışveriş", "icon": Icons.local_mall},
    {"name": "Eğlence", "icon": Icons.attractions},
  ];

  @override
  void initState() {
    super.initState();
    _bannersStream = FirebaseFirestore.instance.collection('banners').snapshots();
    _trendingPlacesStream = FirebaseFirestore.instance.collection('places').orderBy('rating', descending: true).limit(8).snapshots();
    
    _fetchUser();
    _fetchWeather();
    _startAutoPlay();
  }

  void _fetchUser() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String name = user.displayName ?? "Gezgin";
      // İsmin sadece ilk kısmını al (Örn: "Ahmet Yılmaz" -> "Ahmet")
      _displayName = name.split(" ")[0];
      setState(() {});
    }
  }

  void _startAutoPlay() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_totalBanners > 1 && _pageController.hasClients) {
        int nextPage = (_currentBannerIndex + 1) % _totalBanners;
        _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() { _carouselTimer?.cancel(); _pageController.dispose(); super.dispose(); }

  Future<void> _fetchWeather() async {
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=37.8746&longitude=32.4931&current_weather=true');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['current_weather']['temperature'].round();
        final weatherCode = data['current_weather']['weathercode'];

        IconData icon = Icons.wb_sunny;
        Color color = Colors.orange;

        if (weatherCode == 0) { 
          icon = Icons.wb_sunny; 
          color = Colors.orange; 
        } else if (weatherCode >= 1 && weatherCode <= 3) { 
          icon = Icons.cloud_queue; 
          color = Colors.blueGrey; 
        } else if (weatherCode == 45 || weatherCode == 48) {
          icon = Icons.wb_cloudy_outlined;
          color = Colors.grey;
        } else if (weatherCode >= 51 && weatherCode <= 55) {
          icon = Icons.grain; // Çisenti için daha hafif ikon
          color = Colors.blue;
        } else if (weatherCode >= 61 && weatherCode <= 67) { 
          icon = Icons.umbrella; 
          color = Colors.blue; 
        } else if (weatherCode >= 71 && weatherCode <= 77) { 
          icon = Icons.ac_unit; 
          color = Colors.lightBlueAccent; 
        } else if (weatherCode >= 80) {
          icon = Icons.thunderstorm;
          color = Colors.indigo;
        }

        if (mounted) {
          setState(() { currentTemp = "$temp°C"; weatherIcon = icon; weatherColor = color; });
        }
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent, 
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: selectedCategories.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90.0), // Navigasyon üstü
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PlacesScreen(selectedCategories: selectedCategories))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: BrandColors.seljukTurquoise.withOpacity(0.35), 
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                        boxShadow: [BoxShadow(color: BrandColors.seljukTurquoise.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 15))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.explore_outlined, color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text("${selectedCategories.length} Alan • Keşfet", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      
      // 🔥 YENİ PREMİUM GLASSMORPHİSM EFEKTİ & YATAY KAYDIRMA DÜNYASI
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 1. HEADER (KİŞİYE ÖZEL SELAMLAMA + KONUM & HAVA DURUMU)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Motive Edici Başlık
                      /*const Text(
                        "Bugün Nereyi Keşfediyoruz? 🗺️", 
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: BrandColors.textDark, letterSpacing: -0.5)
                      ),
                      const SizedBox(height: 8),*/

                      // Lokasyon ve Hava Durumu — Gradient versiyonu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              // 5. Lokasyon ikonu — gradient dolgu
                              Container(
                                padding: const EdgeInsets.all(1.8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [BrandColors.seljukTurquoise, Color(0xFFE9C46A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEAF6F7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on, color: BrandColors.seljukTurquoise, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text("Konya,Türkiye", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: BrandColors.textDark)),
                            ],
                          ),
                          // 5. Hava durumu badge — hafif gradient cam
                          Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [BrandColors.seljukTurquoise.withOpacity(0.4), BrandColors.accentSand.withOpacity(0.35)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.80),
                                borderRadius: BorderRadius.circular(15.5),
                              ),
                              child: Row(children: [
                                Icon(weatherIcon, color: weatherColor, size: 18),
                                const SizedBox(width: 6),
                                Text(currentTemp, style: const TextStyle(fontWeight: FontWeight.bold, color: BrandColors.textDark, fontSize: 14))
                              ]),
                            ),
                          ),
                        ],
                      ),
                      // 4. Header altı ince altın çizgi
                      const SizedBox(height: 14),
                      Container(
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
                    ],
                  ),
                ),
                
                const SizedBox(height: 6),

                // 🔥 2. AFİŞLER (BANNERS) - ARTIK ÜSTTE
                StreamBuilder<QuerySnapshot>(
                  stream: _bannersStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: BrandColors.seljukTurquoise)));
                    final banners = snapshot.data!.docs;
                    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _totalBanners = banners.length; });

                    return Column(children: [
                      SizedBox(
                        height: 195, // Sinematik ve daha dar bir banner boyu (ekranı kurtarmak için sıkıştırıldı)
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (i) => setState(() => _currentBannerIndex = i),
                          itemCount: banners.length,
                          itemBuilder: (context, index) {
                            var data = banners[index].data() as Map<String, dynamic>;
                            String title = data["title"] ?? "";
                            String imageUrl = data["imageUrl"] ?? "";
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8))],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Stack(fit: StackFit.expand, children: [
                                  if (imageUrl.isNotEmpty)
                                    Image.asset(imageUrl, fit: BoxFit.cover)
                                  else
                                    Container(color: Colors.white.withOpacity(0.65)),

                                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)], stops: const [0.4, 1.0]))),

                                  Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(data["subtitle"] ?? "", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                                    ]),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 6. Banner dots — gradient pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(banners.length, (i) {
                          final isActive = _currentBannerIndex == i;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: isActive ? 28 : 8,
                            decoration: BoxDecoration(
                              gradient: isActive
                                ? const LinearGradient(
                                    colors: [BrandColors.seljukTurquoise, BrandColors.accentSand],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : null,
                              color: isActive ? null : BrandColors.accentSand.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }),
                      ),
                    ]);
                  },
                ),
                
                const SizedBox(height: 8),

                // 🔥 3. KATEGORİLER
                const SizedBox(height: 4),
                SizedBox(
                  height: 85,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: categoryData.map((cat) {
                          final isSelected = selectedCategories.contains(cat["name"]);
                          return GestureDetector(
                            onTap: () => setState(() => isSelected ? selectedCategories.remove(cat["name"]) : selectedCategories.add(cat["name"])),
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(children: [
                                // 1. Gradient border trick — seçili iken turkuaz→sand border
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 52, width: 52,
                                  padding: const EdgeInsets.all(1.8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isSelected
                                        ? [BrandColors.seljukTurquoise, BrandColors.accentSand]
                                        : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.9)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                          ? BrandColors.seljukTurquoise.withOpacity(0.25)
                                          : Colors.black.withOpacity(0.04),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? BrandColors.seljukTurquoise : Colors.white.withOpacity(0.80),
                                      borderRadius: BorderRadius.circular(16.5),
                                    ),
                                    child: Center(
                                      child: Icon(cat["icon"], size: 24, color: isSelected ? Colors.white : BrandColors.seljukTurquoise),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(cat["name"], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? BrandColors.seljukTurquoise : Colors.grey.shade700)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 🔥 4. TREND MEKANLAR
                Container(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  color: Colors.transparent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Trend Mekanlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.textDark, letterSpacing: -0.3)),
                            Icon(Icons.arrow_forward_ios, size: 16, color: BrandColors.seljukTurquoise.withOpacity(0.5))
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      StreamBuilder<QuerySnapshot>(
                        stream: _trendingPlacesStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: BrandColors.seljukTurquoise));
                          final trendPlaces = snapshot.data!.docs;

                          return SizedBox(
                            height: 230, // 🔥 1. DÜZELTME: 210'u 230 yaptık ki gölgeye yer açılsın
                            child: ListView.builder(
                              clipBehavior: Clip.none, // 🔥 2. DÜZELTME: Sınırları aşan gölgeleri KESME dedik
                              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
                              scrollDirection: Axis.horizontal, 
                              physics: const BouncingScrollPhysics(),
                              itemCount: trendPlaces.length,
                              itemBuilder: (context, index) {
                                var data = trendPlaces[index].data() as Map<String, dynamic>;
                                String name = data["name"] ?? "Mekan";

                                return FutureBuilder<String>(
                                  future: GooglePlacesService.getSinglePlacePhoto(name),
                                  builder: (context, photoSnap) {
                                    return Container(
                                      width: 160, 
                                      margin: const EdgeInsets.only(right: 16), 
                                      child: GlassCard( 
                                        color: Colors.white, // 🔥 Kartın içi net beyaz yapıldı (fotoğraftaki gibi temiz dursun diye)
                                        padding: EdgeInsets.zero,
                                        margin: EdgeInsets.zero,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                                child: photoSnap.hasData && photoSnap.data != ""
                                                    ? GooglePlacesService.buildPlaceImage(photoSnap.data!, fit: BoxFit.cover)
                                                    : Container(color: Colors.white.withOpacity(0.3), child: const Center(child: Icon(Icons.image, color: Colors.grey))),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BrandColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  const SizedBox(height: 6),
                                                  // 2. Rating cam rozeti
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          BrandColors.seljukTurquoise.withOpacity(0.12),
                                                          BrandColors.accentSand.withOpacity(0.12),
                                                        ],
                                                        begin: Alignment.centerLeft,
                                                        end: Alignment.centerRight,
                                                      ),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: BrandColors.seljukTurquoise.withOpacity(0.25),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.star_rounded, color: BrandColors.accentSand, size: 13),
                                                        const SizedBox(width: 3),
                                                        Text("${data["rating"]}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: BrandColors.textDark)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 90), // Navbar güvenlik mesafesi (navbar 62 + 20 padding = 82px)
              ],
            ),
          ),
        ),
      ),
    );
  }
}