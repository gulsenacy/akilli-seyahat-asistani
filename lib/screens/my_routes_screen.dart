import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'route_detail_screen.dart';
import 'community_screen.dart';
import '../widgets/glass_background.dart';

class MyRoutesScreen extends StatelessWidget {
  const MyRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: GlassBackground(
          child: Center(
            child: Text(
              'Rotalarınızı görmek için giriş yapmalısınız.',
              style: TextStyle(
                  fontSize: 16,
                  color: BrandColors.textDark,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Rotalarım', style: BrandTypography.h2),
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
              SizedBox(height: MediaQuery.of(context).padding.top + 56),
              // ── Başlık çizgisi ──
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
              const SizedBox(height: 10),

              // ── Sekme butonu ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10)
                    ],
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: BrandColors.seljukTurquoise,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: BrandColors.textDark,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle:
                        const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: const [
                      Tab(text: '🗺️ Rotalarım'),
                      Tab(text: '💾 Kaydedilenler'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('routes')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: BrandColors.seljukTurquoise));
                    }

                    final allDocs = snapshot.data?.docs ?? [];

                    // Ayrıştır: kayıtlı olan ve kendi oluşturulan
                    final myRoutes = allDocs
                        .where((d) =>
                            (d.data() as Map<String, dynamic>)['savedFrom'] ==
                            null)
                        .toList();
                    final savedRoutes = allDocs
                        .where((d) =>
                            (d.data() as Map<String, dynamic>)['savedFrom'] !=
                            null)
                        .toList();

                    return TabBarView(
                      children: [
                        // ── Tab 1: Benim Rotalarım ──
                        myRoutes.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.map_outlined,
                                title: 'Keşfe Hazır Mısın?',
                                subtitle:
                                    'Henüz rota oluşturmadın. Mekanlar sayfasından harika yerler seçip rotanı oluşturabilirsin.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 120),
                                physics: const BouncingScrollPhysics(),
                                itemCount: myRoutes.length,
                                itemBuilder: (context, index) {
                                  return FadeSlideUp(
                                    delay:
                                        Duration(milliseconds: index * 80),
                                    duration:
                                        const Duration(milliseconds: 600),
                                    child: _RouteCard(
                                      routeDoc: myRoutes[index],
                                      user: user,
                                      index: index,
                                    ),
                                  );
                                },
                              ),

                        // ── Tab 2: Kaydedilen Rotalar ──
                        savedRoutes.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.bookmark_border_rounded,
                                title: 'Kaydedilen Rota Yok',
                                subtitle:
                                    'Topluluk sayfasından beğendiğin rotaları kaydet, burada görünsün.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 120),
                                physics: const BouncingScrollPhysics(),
                                itemCount: savedRoutes.length,
                                itemBuilder: (context, index) {
                                  return FadeSlideUp(
                                    delay:
                                        Duration(milliseconds: index * 80),
                                    duration:
                                        const Duration(milliseconds: 600),
                                    child: _RouteCard(
                                      routeDoc: savedRoutes[index],
                                      user: user,
                                      index: index,
                                      isSaved: true,
                                    ),
                                  );
                                },
                              ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return FadeSlideUp(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: BrandColors.seljukTurquoise.withOpacity(0.05),
                  shape: BoxShape.circle),
              child:
                  Icon(icon, size: 56, color: BrandColors.seljukTurquoise),
            ),
            const SizedBox(height: 20),
            Text(title, style: BrandTypography.h2),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(subtitle,
                  textAlign: TextAlign.center,
                  style: BrandTypography.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ROTA KARTI
// ─────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final QueryDocumentSnapshot routeDoc;
  final User user;
  final int index;
  final bool isSaved;

  const _RouteCard({
    required this.routeDoc,
    required this.user,
    required this.index,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    final routeData = routeDoc.data() as Map<String, dynamic>;
    final routeId = routeDoc.id;
    final routeName = routeData['routeName'] ?? 'İsimsiz Rota';
    final description = routeData['description'] ?? '';
    final places = routeData['places'] ?? [];
    final String? startLocationName = routeData['startLocationName'];
    final double? startLocationLat = routeData['startLocationLat'] != null
        ? (routeData['startLocationLat'] as num).toDouble()
        : null;
    final double? startLocationLng = routeData['startLocationLng'] != null
        ? (routeData['startLocationLng'] as num).toDouble()
        : null;
    final bool isOptimized = routeData['isOptimized'] == true;
    final double totalKm =
        (routeData['totalKm'] as num?)?.toDouble() ?? 0.0;
    final List<double> segmentKms =
        (routeData['segmentKms'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [];
    final Timestamp? t = routeData['createdAt'] as Timestamp?;
    final String dateStr = t != null
        ? DateFormat('dd MMM yyyy').format(t.toDate())
        : 'Yeni';

    // Kaydedilen rotanın kaynağı
    final savedFrom = routeData['savedFrom'] as Map<String, dynamic>?;
    final savedFromName = savedFrom?['userName'] as String?;

    return Dismissible(
      key: Key(routeId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: Colors.red.shade400.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Rotayı Sil', style: BrandTypography.h3),
            content: Text("'$routeName' silinecek. Emin misin?",
                style: BrandTypography.bodySmall),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'İptal',
                      color: Colors.grey.shade400,
                      height: 48,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      label: 'Sil',
                      color: Colors.red.shade400,
                      height: 48,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('routes')
            .doc(routeId)
            .delete();
      },
      child: GlassCard(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(bottom: 14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteDetailScreen(
              routeId: routeId,
              routeName: routeName,
              description: description,
              places: places,
              startLocationName: startLocationName,
              startLocationLat: startLocationLat,
              startLocationLng: startLocationLng,
              isOptimized: isOptimized,
              totalKm: totalKm,
              segmentKms: segmentKms,
            ),
          ),
        ),
        child: Row(
          children: [
            // Sol renkli şerit
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: isSaved
                    ? BrandColors.accentSand
                    : isOptimized
                        ? BrandColors.seljukTurquoise
                        : Colors.grey.shade300,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Satır 1: isim + rozet
                    Row(
                      children: [
                        Expanded(
                          child: Text(routeName,
                              style: BrandTypography.h3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSaved
                                ? BrandColors.accentSand.withOpacity(0.15)
                                : isOptimized
                                    ? BrandColors.seljukTurquoise
                                        .withOpacity(0.1)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSaved
                                  ? BrandColors.accentSand.withOpacity(0.4)
                                  : isOptimized
                                      ? BrandColors.seljukTurquoise
                                          .withOpacity(0.3)
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            isSaved
                                ? '💾 Kaydedildi'
                                : isOptimized
                                    ? '✅ Optimize'
                                    : '⏳ Düzenle',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSaved
                                  ? BrandColors.accentSand
                                  : isOptimized
                                      ? BrandColors.seljukTurquoise
                                      : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Satır 2: tarih + mekan + km
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(dateStr,
                              style: BrandTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600)),
                        ]),
                        Row(children: [
                          if (!isSaved && isOptimized && totalKm > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: BrandColors.accentSand
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '📍 ~${totalKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: BrandColors.textDark),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                                color: BrandColors.seljukTurquoise
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('${places.length} MEKAN',
                                style: BrandTypography.caption),
                          ),
                        ]),
                      ],
                    ),

                    // Satır 3: başlangıç noktası veya kaydedildi bilgisi
                    if (isSaved && savedFromName != null) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.person_rounded,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('$savedFromName paylaştı',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ] else if (!isSaved && startLocationName != null) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.hotel_rounded,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(startLocationName,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),

            // Sağ: paylaş (kendi rota) veya kaldır (kaydedilen) + ok
            if (!isSaved)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityScreen(
                          preselectedRouteId: routeId,
                          preselectedRouteName: routeName,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      margin:
                          const EdgeInsets.only(right: 8, bottom: 6),
                      decoration: BoxDecoration(
                        color:
                            BrandColors.seljukTurquoise.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.share_rounded,
                          size: 15,
                          color: BrandColors.seljukTurquoise),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: Colors.grey),
                  ),
                ],
              )
            else
              // Kaydedilen rota: Kaldır butonu
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          title: Text('Rotayı Kaldır',
                              style: BrandTypography.h3),
                          content: Text(
                              "'$routeName' kaydedilenlerden kaldırılacak.",
                              style: const TextStyle(color: Colors.grey)),
                          actionsAlignment: MainAxisAlignment.center,
                          actionsPadding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          actions: [
                            Row(children: [
                              Expanded(
                                child: GlassButton(
                                  label: 'İptal',
                                  color: Colors.grey.shade400,
                                  height: 48,
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassButton(
                                  label: 'Kaldır',
                                  color: Colors.redAccent,
                                  height: 48,
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('routes')
                            .doc(routeId)
                            .delete();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      margin:
                          const EdgeInsets.only(right: 8, bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red.shade200, width: 1),
                      ),
                      child: Icon(Icons.bookmark_remove_rounded,
                          size: 15, color: Colors.red.shade400),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}