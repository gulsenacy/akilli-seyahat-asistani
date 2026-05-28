import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DataManager {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String googleApiKey = "AIzaSyAbclSR-M23Z9MZZBXaTreBZIednbJXGgc";

  // 1. NÜKLEER TEMİZLİK
  static Future<void> cleanAllData(String collectionName) async {
    print("🧹 $collectionName temizleniyor...");
    final snapshots = await _db.collection(collectionName).get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
    print("✨ $collectionName tertemiz!");
  }

  // 2. YENİ NESİL MEGA YÜKLEYİCİ (Sadece gerekli alanlar)
  static Future<void> uploadMegaData(Map<String, Map<String, List<String>>> megaList) async {
    for (String mainCategory in megaList.keys) {
      Map<String, List<String>> subCategories = megaList[mainCategory]!;
      for (String subCategory in subCategories.keys) {
        List<String> places = subCategories[subCategory]!;
        for (String name in places) {
          String cleanName = name.trim();
          if (cleanName.isEmpty) continue;

          final existing = await _db.collection('places').where('name', '==', cleanName).get();
          if (existing.docs.isNotEmpty) {
            print("⏩ $cleanName zaten var.");
            continue;
          }

          try {
            final searchUrl = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent("$cleanName Konya")}&inputtype=textquery&fields=rating,formatted_address&key=$googleApiKey";
            final response = await http.get(Uri.parse(searchUrl));
            final data = json.decode(response.body);

            double rating = 0.0;
            String addressDesc = "$cleanName, Konya'da mutlaka görmeniz gereken yerlerden biridir.";

            if (data['candidates'] != null && data['candidates'].isNotEmpty) {
              rating = (data['candidates'][0]['rating'] ?? 0.0).toDouble();
              if (data['candidates'][0]['formatted_address'] != null) {
                addressDesc = data['candidates'][0]['formatted_address'];
              }
            }

            bool isOutdoor = true;
            if (mainCategory == "Alışveriş" || subCategory == "Müze" || subCategory == "Cami" || subCategory == "Kapalı Alan" || cleanName.toLowerCase().contains("müzesi") || cleanName.toLowerCase().contains("avm")) {
              isOutdoor = false;
            }

            await _db.collection('places').add({
              "name": cleanName,
              "rating": rating,
              "category": mainCategory,       
              "subCategory": subCategory,     
              "description": addressDesc, 
              "isOutdoor": isOutdoor,   
              "createdAt": FieldValue.serverTimestamp(),
            });
            print("✅ $cleanName yüklendi.");
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            print("❌ $cleanName hatası: $e");
          }
        }
      }
    }
    print("🏁 TÜM LİSTE YÜKLENDİ!");
  }

  // 3. BANNER YÜKLEME
  static Future<void> uploadBanners() async {
    List<Map<String, String>> banners = [
      {"title": "Konya Lale Festivali", "subtitle": "Karatay Şehir Parkı'nda Renk Cümbüşü!"},
      {"title": "Sille Antik Kenti", "subtitle": "Tarihe ve Doğaya Yolculuk"},
      {"title": "Tropikal Kelebek Bahçesi", "subtitle": "Büyülü Kelebek Dünyasını Keşfet"},
    ];
    for (var b in banners) {
      final existing = await _db.collection('banners').where('title', '==', b['title']).get();
      if (existing.docs.isEmpty) {
        await _db.collection('banners').add(b);
        print("🚩 Banner: ${b['title']} eklendi.");
      }
    }
  }
}