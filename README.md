<h1 align="center">
  <br>
  🗺️ Konnext — Konya'yı Keşfet
  <br>
</h1>

<h4 align="center">
  Konya'nın tarihi ve kültürel mekânlarını akıllıca keşfetmeni sağlayan Flutter tabanlı seyahat asistanı uygulaması.
</h4>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Google%20Maps-API-4285F4?style=for-the-badge&logo=google-maps&logoColor=white" />
</p>

<p align="center">
  <a href="#-özellikler">Özellikler</a> •
  <a href="#-ekran-görüntüleri">Ekranlar</a> •
  <a href="#-mimari">Mimari</a> •
  <a href="#-kurulum">Kurulum</a> •
  <a href="#-kullanılan-teknolojiler">Teknolojiler</a>
</p>

---

## 📌 Proje Hakkında

**Konnext**, Konya şehrini ziyaret eden veya keşfetmek isteyen kullanıcılar için geliştirilmiş akıllı bir seyahat asistanı mobil uygulamasıdır. Uygulama; tarihi camiler, müzeler, doğal güzellikler ve yerel lezzetler gibi yüzlerce mekânı harita üzerinde sunarken, kullanıcıların birden fazla noktayı en verimli sırayla ziyaret edebilmesi için **rota optimizasyon algoritmaları** kullanmaktadır.

Proje, Selçuk Üniversitesi Bilgisayar Mühendisliği bölümü kapsamında geliştirilen bir mobil uygulama projesidir.

---

## ✨ Özellikler

| Özellik | Açıklama |
|---|---|
| 🗺️ **Harita Entegrasyonu** | Google Maps üzerinde gerçek zamanlı mekân görüntüleme |
| 🔍 **Mekân Arama** | Google Places API ile akıllı arama ve filtreleme |
| 🤖 **Rota Optimizasyonu** | Nearest Neighbor + 2-Opt algoritması ile en kısa tur hesaplama |
| ❤️ **Favoriler** | Beğenilen mekânları kaydetme ve listeleme |
| 🛣️ **Rotalarım** | Oluşturulan rotaları kaydetme ve yönetme |
| 👥 **Topluluk** | Kullanıcıların deneyim paylaşabileceği sosyal akış |
| 💬 **Yorumlar** | Gönderiler üzerinde gerçek zamanlı yorum sistemi |
| 📸 **Fotoğraf Yükleme** | Firebase Storage'a fotoğraf yükleme |
| 🔐 **Kimlik Doğrulama** | Firebase Authentication ile güvenli giriş/kayıt |
| 👤 **Profil Yönetimi** | Profil fotoğrafı ve kişisel bilgileri düzenleme |

---

## 🧠 Rota Optimizasyon Algoritması

Uygulamanın en kritik bileşenlerinden biri olan rota optimizasyonu, iki aşamalı bir yaklaşımla çözülmüştür:

### 1️⃣ Nearest Neighbor (En Yakın Komşu) Algoritması
Başlangıç noktasından hareketle her adımda ziyaret edilmemiş en yakın mekânı seçerek hızlı bir başlangıç çözümü üretir.

### 2️⃣ 2-Opt İyileştirmesi
Nearest Neighbor'dan elde edilen rotayı iteratif olarak iyileştirir. İki kenarı yer değiştirerek rotayı kısaltan değişimleri uygular ve yerel optimuma ulaşır.

```
Örnek: 5 mekân için
Ham sıra:    A → D → B → E → C  (toplam: 42 km)
Optimize:    A → B → C → D → E  (toplam: 31 km)
İyileşme: %26
```

---

## 🏛️ Mimari

```
lib/
├── main.dart                    # Uygulama giriş noktası
├── firebase_options.dart        # Firebase yapılandırması
├── data_manager.dart            # Yerel veri yönetimi
│
├── screens/                     # Uygulama ekranları
│   ├── home_screen.dart         # Ana sayfa (banner, kategoriler)
│   ├── places_screen.dart       # Mekân listesi & harita görünümü
│   ├── route_detail_screen.dart # Rota detayı & optimizasyon
│   ├── my_routes_screen.dart    # Kayıtlı rotalar
│   ├── favorites_screen.dart    # Favori mekânlar
│   ├── community_screen.dart    # Topluluk akışı
│   ├── post_detail_screen.dart  # Gönderi detayı & yorumlar
│   ├── profile_screen.dart      # Kullanıcı profili
│   ├── edit_profile_screen.dart # Profil düzenleme
│   ├── login_screen.dart        # Giriş / Kayıt
│   └── main_nav_screen.dart     # Alt navigasyon çubuğu
│
├── services/                    # İş mantığı servisleri
│   ├── google_places_service.dart   # Google Places API
│   ├── route_optimizer_service.dart # Nearest Neighbor + 2-Opt
│   └── database_service.dart        # Firestore CRUD işlemleri
│
├── widgets/                     # Yeniden kullanılabilir bileşenler
└── utils/                       # Yardımcı fonksiyonlar
```

---

## 🛠️ Kullanılan Teknolojiler

### Frontend
- **Flutter 3.x** — Cross-platform mobil uygulama geliştirme
- **Dart 3.x** — Tip güvenli, modern programlama dili
- **Google Fonts** — Gelişmiş tipografi
- **Cached Network Image** — Performanslı görsel önbellekleme

### Backend & Servisler
- **Firebase Authentication** — Email/şifre ile kullanıcı yönetimi
- **Cloud Firestore** — NoSQL gerçek zamanlı veritabanı
- **Firebase Storage** — Kullanıcı fotoğrafları için bulut depolama
- **Google Maps Flutter** — Etkileşimli harita görüntüleme
- **Google Places API** — Mekân arama ve detay bilgileri

### Algoritmalar
- **Nearest Neighbor Heuristic** — O(n²) karmaşıklıkta TSP yaklaşımı
- **2-Opt Local Search** — Rota kalitesini artıran iteratif iyileştirme
- **Haversine Formülü** — Küresel yüzey üzerinde mesafe hesaplama

---

## 🚀 Kurulum

### Gereksinimler
- Flutter SDK `^3.x`
- Dart SDK `^3.x`
- Android Studio veya VS Code
- Google Maps API Key
- Firebase projesi

### Adımlar

```bash
# 1. Repoyu klonla
git clone https://github.com/gulsenacy/akilli-seyahat-asistani.git
cd akilli-seyahat-asistani

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Firebase yapılandırmasını ekle
# google-services.json → android/app/
# GoogleService-Info.plist → ios/Runner/

# 4. API anahtarlarını ayarla
# android/app/src/main/AndroidManifest.xml içine Google Maps API Key ekle

# 5. Uygulamayı çalıştır
flutter run
```

> **Not:** `firebase_options.dart` ve API anahtarları güvenlik nedeniyle `.gitignore`'a eklenmiştir. Kendi Firebase projenizi ve Google Maps API anahtarınızı oluşturmanız gerekmektedir.

---

## 📁 Veritabanı Yapısı (Firestore)

```
Firestore/
├── users/
│   └── {userId}/
│       ├── displayName, email, photoURL
│       ├── favorites: [placeId, ...]
│       └── savedRoutes: [routeId, ...]
│
├── posts/
│   └── {postId}/
│       ├── userId, content, imageUrl
│       ├── likes: [userId, ...]
│       └── createdAt
│
└── comments/
    └── {postId}/
        └── {commentId}/
            ├── userId, text, createdAt
```

---

## 👩‍💻 Geliştirici

**Gülsena Cy**
- GitHub: [@gulsenacy](https://github.com/gulsenacy)

---

## 📄 Lisans

Bu proje akademik amaçlı geliştirilmiştir. Ticari kullanım için izin gereklidir.

---

<p align="center">
  <i>Konya'yı keşfetmeye hazır mısın? 🕌</i>
</p>
