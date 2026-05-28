import 'package:flutter/material.dart';
import 'dart:ui';

import 'home_screen.dart';
import 'places_screen.dart';
import 'my_routes_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart'; 

import '../widgets/glass_background.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const PlacesScreen(selectedCategories: []),
    const MyRoutesScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  // 🔥 ÖZEL GLASS NAVİGASYON İKON OLUŞTURUCU
  Widget _buildNavItem(IconData outlineIcon, IconData filledIcon, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // İkon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                size: isSelected ? 26 : 22, // İkonları barın inceliğine göre ufalttık
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Seçili olduğunda altta beliren sihirli nokta
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isSelected ? 1.0 : 0.0,
              child: Container(
                height: 5,
                width: 5,
                decoration: BoxDecoration(
                  color: BrandColors.accentSand,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: BrandColors.accentSand.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)
                  ]
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: _screens[_currentIndex],

      // 🔥 PREMİUM CANLI TURKUAZ YÜZEN NAVİGASYON BAR
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20), // Alt mesafe biraz düşürüldü
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30), // Yüksekliğe tam uyumlu kavis
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 62, // 75'ten 62'ye indirildi (Çok daha ince ve kibar)
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                // 💎 GRADIENT NAV BAR — turkuazdan altına zarif geçiş
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    BrandColors.seljukTurquoise.withOpacity(0.55),
                    BrandColors.seljukTurquoise.withOpacity(0.35),
                    BrandColors.accentSand.withOpacity(0.35),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: BrandColors.seljukTurquoise.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 15)),
                  BoxShadow(color: BrandColors.accentSand.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(Icons.home_outlined, Icons.home, 0),
                  _buildNavItem(Icons.explore_outlined, Icons.explore, 1),
                  _buildNavItem(Icons.map_outlined, Icons.map, 2),
                  _buildNavItem(Icons.people_outline, Icons.people, 3),
                  _buildNavItem(Icons.person_outline, Icons.person, 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}