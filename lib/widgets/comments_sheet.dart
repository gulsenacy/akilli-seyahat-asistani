import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../widgets/glass_background.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  static void show(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: postId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Yorum yapmak için giriş yapmalısınız.'),
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final userName = userData['displayName'] ??
          user.displayName ??
          user.email?.split('@')[0] ??
          'Gezgin';
      final userPhotoUrl = userData['profilePhotoUrl'] as String? ?? '';

      final postRef = FirebaseFirestore.instance
          .collection('community_posts')
          .doc(widget.postId);

      // Batch kullanarak hem yorumu ekle hem de sayacı güncelle
      final batch = FirebaseFirestore.instance.batch();
      
      final newCommentRef = postRef.collection('comments').doc();
      batch.set(newCommentRef, {
        'userId': user.uid,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(postRef, {
        'commentCount': FieldValue.increment(1),
      });

      await batch.commit();

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Yorum eklenemedi: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Yorumu Sil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bu yorumu silmek istediğinize emin misiniz?'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final postRef = FirebaseFirestore.instance.collection('community_posts').doc(widget.postId);
      final batch = FirebaseFirestore.instance.batch();
      
      batch.delete(postRef.collection('comments').doc(commentId));
      batch.update(postRef, {'commentCount': FieldValue.increment(-1)});
      
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    
    return Container(
      height: sh * 0.75, // Ekranın %75'ini kaplar
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ── Üst Tutamak ve Başlık ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Text('Yorumlar', style: BrandTypography.h3),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

          // ── Yorum Listesi ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community_posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00838F)),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, 
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Henüz yorum yapılmamış.',
                            style: TextStyle(color: Colors.grey.shade500)),
                        Text('İlk yorumu siz yapın!',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  );
                }

                final comments = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data = comments[index].data() as Map<String, dynamic>;
                    final commentId = comments[index].id;
                    final userId = data['userId'] as String?;
                    final isOwnComment = FirebaseAuth.instance.currentUser?.uid == userId;

                    final userName = data['userName'] ?? 'Kullanıcı';
                    final userPhotoUrl = data['userPhotoUrl'] as String?;
                    final text = data['text'] ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;
                    final dateStr = createdAt != null ? _timeAgo(createdAt.toDate()) : 'şimdi';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: BrandColors.seljukTurquoise.withOpacity(0.1),
                            backgroundImage: (userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                                ? CachedNetworkImageProvider(userPhotoUrl)
                                : null,
                            child: (userPhotoUrl == null || userPhotoUrl.isEmpty)
                                ? const Icon(Icons.person, size: 18, color: Color(0xFF00838F))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(userName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text(dateStr,
                                        style: TextStyle(
                                            color: Colors.grey.shade500, fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: const TextStyle(fontSize: 14, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          if (isOwnComment)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () => _deleteComment(commentId),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Yorum Yazma Alanı ──
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                      decoration: const InputDecoration(
                        hintText: 'Bir yorum ekle...',
                        hintStyle: TextStyle(fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSubmitting ? null : _submitComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00838F),
                      shape: BoxShape.circle,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
