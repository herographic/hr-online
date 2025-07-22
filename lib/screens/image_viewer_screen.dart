// lib/screens/image_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveImage() async {
    // ... (Existing save logic remains the same)
  }

  // --- [START] NEW SHARE FUNCTION ---
  Future<void> _shareImage() async {
    try {
      final imageUrl = widget.imageUrls[_currentIndex];
      // For sharing, we can just share the URL directly.
      // Or download and share the file if needed, but URL is simpler.
      await Share.share('ดูรูปภาพนี้: $imageUrl');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถแชร์รูปภาพได้: $e')),
        );
      }
    }
  }
  // --- [END] NEW SHARE FUNCTION ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: GoogleFonts.anuphan(),
        ),
        actions: [
          // --- [START] ADDED SHARE BUTTON ---
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareImage,
            tooltip: 'แชร์รูปภาพ',
          ),
          // --- [END] ADDED SHARE BUTTON ---
          IconButton(
            icon: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,)) : const Icon(Icons.save_alt_outlined),
            onPressed: _saveImage,
            tooltip: 'บันทึกรูปภาพ',
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.imageUrls.length,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(widget.imageUrls[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrls[index]),
          );
        },
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
