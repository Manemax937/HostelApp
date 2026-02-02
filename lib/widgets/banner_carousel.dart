import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hostelapp/services/banner_service.dart';

class BannerCarousel extends StatefulWidget {
  final List<BannerImage> banners;
  final double height;
  final Duration autoSlideDuration;
  final bool showIndicators;

  const BannerCarousel({
    super.key,
    required this.banners,
    this.height = 180,
    this.autoSlideDuration = const Duration(seconds: 4),
    this.showIndicators = true,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If banners were empty (or single) and now we have multiple, start auto-slide.
    if ((oldWidget.banners.length <= 1) && (widget.banners.length > 1)) {
      _startAutoSlide();
    }

    // If we had multiple banners before but now have <=1, cancel timer.
    if ((oldWidget.banners.length > 1) && (widget.banners.length <= 1)) {
      _autoSlideTimer?.cancel();
      _autoSlideTimer = null;
    }

    // If the current page index is out of range for new banners, reset it.
    if (_currentPage >= widget.banners.length) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    // Ensure we don't create multiple timers
    _autoSlideTimer?.cancel();

    if (widget.banners.length <= 1) return;

    _autoSlideTimer = Timer.periodic(widget.autoSlideDuration, (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Page View
            PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return _buildBannerItem(banner);
              },
            ),

            // Gradient overlay for text visibility
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
            ),

            // Title and description
            if (widget.banners[_currentPage].title != null ||
                widget.banners[_currentPage].description != null)
              Positioned(
                bottom: widget.showIndicators ? 35 : 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.banners[_currentPage].title != null)
                      Text(
                        widget.banners[_currentPage].title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.banners[_currentPage].description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.banners[_currentPage].description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

            // Page Indicators
            if (widget.showIndicators && widget.banners.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.banners.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerItem(BannerImage banner) {
    return CachedNetworkImage(
      imageUrl: banner.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey[400],
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Image not available',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome to Comfort PG',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your home away from home',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
