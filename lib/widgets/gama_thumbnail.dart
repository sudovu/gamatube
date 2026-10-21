import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GamaThumbnail extends StatefulWidget {
  final String videoId;
  final String? thumbnailUrl;
  final String? highThumbnailUrl;
  final String? standardThumbnailUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final int? cacheWidth;

  const GamaThumbnail({
    super.key,
    required this.videoId,
    this.thumbnailUrl,
    this.highThumbnailUrl,
    this.standardThumbnailUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.cacheWidth,
  });

  @override
  State<GamaThumbnail> createState() => _GamaThumbnailState();
}

class _GamaThumbnailState extends State<GamaThumbnail> {
  int _currentCandidateIndex = 0;
  late List<String> _candidates;

  @override
  void initState() {
    super.initState();
    _buildCandidates();
  }

  @override
  void didUpdateWidget(covariant GamaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl ||
        oldWidget.highThumbnailUrl != widget.highThumbnailUrl) {
      _currentCandidateIndex = 0;
      _buildCandidates();
    }
  }

  void _buildCandidates() {
    final list = <String>[];

    void addUrl(String? url) {
      if (url != null && url.trim().isNotEmpty && !list.contains(url.trim())) {
        list.add(url.trim());
      }
    }

    // 1. Provided thumbnail URLs
    addUrl(widget.highThumbnailUrl);
    addUrl(widget.thumbnailUrl);
    addUrl(widget.standardThumbnailUrl);

    // 2. High Quality & Standard YouTube CDN fallbacks
    if (widget.videoId.isNotEmpty) {
      addUrl('https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg');
      addUrl('https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg');
      addUrl('https://i.ytimg.com/vi/${widget.videoId}/mqdefault.jpg');
      addUrl('https://img.youtube.com/vi/${widget.videoId}/mqdefault.jpg');
      addUrl('https://i.ytimg.com/vi/${widget.videoId}/sddefault.jpg');
      addUrl('https://img.youtube.com/vi/${widget.videoId}/default.jpg');
    }

    _candidates = list;
  }

  void _handleImageError() {
    if (_currentCandidateIndex < _candidates.length - 1) {
      if (mounted) {
        setState(() {
          _currentCandidateIndex++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E2E2);

    Widget content;

    if (_candidates.isEmpty || _currentCandidateIndex >= _candidates.length) {
      content = _buildFallbackPlaceholder(isDark);
    } else {
      final activeUrl = _candidates[_currentCandidateIndex];

      content = Image.network(
        activeUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        // CRITICAL: NEVER pass cacheWidth on Flutter Web as it throws UnimplementedError
        // and breaks image decoding across CanvasKit / HTML.
        cacheWidth: kIsWeb ? null : widget.cacheWidth,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return Container(
            width: widget.width,
            height: widget.height,
            color: placeholderColor,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleImageError());
          return Container(
            width: widget.width,
            height: widget.height,
            color: placeholderColor,
            child: const Center(
              child: Icon(Icons.play_circle_outline_rounded, color: Colors.white38, size: 38),
            ),
          );
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildFallbackPlaceholder(bool isDark) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : const Color(0xFFEEEEEE),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF262626), const Color(0xFF121212)]
              : [const Color(0xFFF0F0F0), const Color(0xFFDCDCDC)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          size: 42,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }
}
