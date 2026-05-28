import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glass_background.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Favorilerim", style: BrandTypography.h3),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: BrandColors.seljukTurquoise, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GlassBackground(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 56), // AppBar spacing
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('favorites')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: BrandColors.seljukTurquoise));
                  if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Henüz favori mekanın yok. ❤️", style: TextStyle(color: BrandColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      String placeName = snapshot.data!.docs[index].id;
                      return GlassCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: BrandColors.seljukTurquoise.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
                          ),
                          title: Text(placeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BrandColors.textDark)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: () => FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('favorites')
                                .doc(placeName)
                                .delete(),
                          ),
                        ),
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
}