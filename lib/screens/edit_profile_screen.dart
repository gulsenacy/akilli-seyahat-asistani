import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/glass_background.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  File? _imageFile;
  String? _currentPhotoUrl; // Firebase Storage URL
  final ImagePicker _picker = ImagePicker();

  final List<String> _availableCategories = [
    '☕ Kafe Kâşifi',
    '🌲 Doğa Tutkunu',
    '🏛️ Tarih Avcısı',
    '🍔 Gurme Gezgin',
    '🎨 Sanat Sever'
  ];
  List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    final displayName =
        user?.displayName ?? (user?.email?.split('@')[0].toUpperCase() ?? '');
    _nameController = TextEditingController(text: displayName);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _selectedCategories =
                List<String>.from(data['categories'] ?? []);
            // URL tabanlı fotoğraf yükleme
            _currentPhotoUrl = data['profilePhotoUrl'] as String?;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  /// Seçilen fotoğrafı Firebase Storage'a yükler, URL döndürür.
  Future<String?> _uploadPhotoToStorage() async {
    if (_imageFile == null || user == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user!.uid}.jpg');

      final uploadTask = await ref.putFile(
        _imageFile!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage upload error: $e');
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        if (user != null) {
          await user!.updateDisplayName(_nameController.text);

          String? photoUrl = _currentPhotoUrl;

          // Yeni fotoğraf seçildiyse Storage'a yükle
          if (_imageFile != null) {
            photoUrl = await _uploadPhotoToStorage();
          } else if (_currentPhotoUrl == null) {
            // Fotoğraf kaldırıldıysa null yap
            photoUrl = null;
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .set({
            'displayName': _nameController.text,
            'categories': _selectedCategories,
            'profilePhotoUrl': photoUrl,
          }, SetOptions(merge: true));

          // ── NoSQL Veri Tutarlılığı: Eski gönderilerdeki isim ve fotoğrafı da güncelle ──
          final postsSnap = await FirebaseFirestore.instance
              .collection('community_posts')
              .where('userId', isEqualTo: user!.uid)
              .get();
          
          if (postsSnap.docs.isNotEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            for (var doc in postsSnap.docs) {
              batch.update(doc.reference, {
                'userName': _nameController.text,
                'userPhoto': photoUrl ?? '',
              });
            }
            await batch.commit();
          }

          if (mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Profil güncellendi! ✅',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: BrandColors.seljukTurquoise,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.only(bottom: 24),
            ),
            const Text('Profil Fotoğrafı',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: BrandColors.textDark)),
            const SizedBox(height: 24),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: BrandColors.seljukTurquoise),
              title: const Text('Yeni Fotoğraf Seç',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            if (_imageFile != null || _currentPhotoUrl != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Mevcut Fotoğrafı Kaldır',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageFile = null;
                    _currentPhotoUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Görüntülenecek fotoğraf: yeni seçilen var mı? → local file, yoksa URL
    ImageProvider? profileImage;
    if (_imageFile != null) {
      profileImage = FileImage(_imageFile!);
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      profileImage = NetworkImage(_currentPhotoUrl!);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Profili Düzenle', style: BrandTypography.h3),
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
          icon: const Icon(Icons.arrow_back_ios_new,
              color: BrandColors.seljukTurquoise, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GlassBackground(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 56),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      // PROFİL FOTOĞRAFI
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: BrandColors.seljukTurquoise
                                      .withOpacity(0.5),
                                  width: 2),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor:
                                      BrandColors.seljukTurquoise.withOpacity(0.1),
                                  backgroundImage: profileImage,
                                  child: profileImage == null
                                      ? const Icon(Icons.person,
                                          size: 50,
                                          color: BrandColors.seljukTurquoise)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: BrandColors.seljukTurquoise,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2)),
                                    child: const Icon(Icons.camera_alt,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(' Kullanıcı Adı',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: BrandColors.textDark,
                                    fontSize: 16)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.9),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: TextFormField(
                                controller: _nameController,
                                style: const TextStyle(
                                    color: BrandColors.textDark,
                                    fontWeight: FontWeight.bold),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                        ? 'Bu alan boş bırakılamaz.'
                                        : null,
                                decoration: InputDecoration(
                                  hintText: 'Örn: Ahmet Yılmaz',
                                  hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.normal,
                                      fontSize: 14),
                                  prefixIcon: const Icon(Icons.person_outline,
                                      color: BrandColors.seljukTurquoise,
                                      size: 22),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(' Seyahat Tarzını Seç',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: BrandColors.textDark,
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _availableCategories.map((category) {
                            bool isSelected =
                                _selectedCategories.contains(category);
                            return FilterChip(
                              label: Text(category,
                                  style: TextStyle(
                                      color: isSelected
                                          ? BrandColors.seljukTurquoise
                                          : Colors.grey.shade700,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600)),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                              },
                              selectedColor:
                                  BrandColors.seljukTurquoise.withOpacity(0.15),
                              checkmarkColor: BrandColors.seljukTurquoise,
                              backgroundColor: Colors.white.withOpacity(0.65),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: isSelected
                                        ? BrandColors.seljukTurquoise
                                        : Colors.white.withOpacity(0.9),
                                    width: 1.5),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 40),
                      GlassButton(
                        label: 'Değişiklikleri Kaydet',
                        isLoading: _isLoading,
                        onPressed: _saveChanges,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}