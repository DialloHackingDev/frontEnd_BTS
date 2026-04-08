import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Utilitaires pour l'optimisation des images
/// Gère le lazy loading, caching et compression
class ImageUtils {
  /// Builder pour les images réseau avec lazy loading
  static Widget buildOptimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    Duration fadeDuration = const Duration(milliseconds: 300),
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: fadeDuration,
        fadeOutDuration: fadeDuration,
        placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
        errorWidget: (context, url, error) => errorWidget ?? _defaultErrorWidget(),
        // Cache configuration
        memCacheWidth: width?.toInt(),
        memCacheHeight: height?.toInt(),
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 1200,
      ),
    );
  }

  /// Placeholder par défaut pendant le chargement
  static Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  /// Widget d'erreur par défaut
  static Widget _defaultErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey,
      ),
    );
  }

  /// Précharge une image dans le cache
  static Future<void> precacheImage(BuildContext context, String imageUrl) async {
    final provider = CachedNetworkImageProvider(imageUrl);
    await precacheImageProvider(provider, context);
  }

  /// Précharge plusieurs images (pour les listes)
  static Future<void> precacheImages(BuildContext context, List<String> imageUrls) async {
    for (final url in imageUrls) {
      await precacheImage(context, url);
    }
  }

  /// Efface le cache d'une image spécifique
  static Future<void> clearImageCache(String imageUrl) async {
    await CachedNetworkImage.evictFromCache(imageUrl);
  }

  /// Efface tout le cache d'images
  static Future<void> clearAllImageCache() async {
    await CachedNetworkImage.clearCache();
  }

  /// Obtient les stats du cache d'images
  static Future<Map<String, dynamic>> getCacheStats() async {
    // Note: cached_network_image ne fournit pas de stats directement
    // Cette méthode peut être étendue avec flutter_cache_manager si nécessaire
    return {
      'type': 'cached_network_image',
      'note': 'Le cache est géré automatiquement par la librairie',
    };
  }
}

/// Extension pour faciliter l'utilisation dans les widgets
extension ImageExtension on String {
  /// Retourne un widget CachedNetworkImage optimisé
  Widget toOptimizedImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return ImageUtils.buildOptimizedImage(
      imageUrl: this,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }
}

/// Widget pour les avatars optimisés
class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color backgroundColor;
  final Color foregroundColor;

  const OptimizedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.fallbackText,
    this.backgroundColor = Colors.grey,
    this.foregroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: ImageUtils.buildOptimizedImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: _buildFallback(),
          errorWidget: _buildFallback(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        fallbackText?.substring(0, 1).toUpperCase() ?? '?',
        style: TextStyle(
          color: foregroundColor,
          fontSize: radius,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Widget pour les thumbnails optimisés
class OptimizedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 80,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = ImageUtils.buildOptimizedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );

    if (onTap != null) {
      image = GestureDetector(
        onTap: onTap,
        child: image,
      );
    }

    return image;
  }
}
