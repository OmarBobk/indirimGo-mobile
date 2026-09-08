import 'dart:async';

import 'package:flutter/material.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';

/// Square, contain-fit artwork frame with bounded decode size.
class CatalogMediaFrame extends StatelessWidget {
  const CatalogMediaFrame({
    super.key,
    required this.imageUrl,
    this.size = 72,
    this.semanticLabel,
    this.borderRadius,
  });

  final Uri? imageUrl;
  final double size;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  static ImageProvider<Object>? providerFor({
    required Uri? imageUrl,
    required double logicalSize,
    required double devicePixelRatio,
  }) {
    if (imageUrl == null) {
      return null;
    }
    final decode = _decodeExtent(logicalSize, devicePixelRatio);
    if (decode == null) {
      return NetworkImage(imageUrl.toString());
    }
    return ResizeImage(
      NetworkImage(imageUrl.toString()),
      width: decode,
      height: decode,
      policy: ResizeImagePolicy.fit,
    );
  }

  static int? _decodeExtent(double logical, double devicePixelRatio) {
    final pixels = (logical * devicePixelRatio).round();
    return pixels > 0 ? pixels : null;
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.input);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final placeholder = _MediaPlaceholder(size: size);

    Widget child;
    if (imageUrl == null) {
      child = placeholder;
    } else {
      child = Image(
        image:
            providerFor(
              imageUrl: imageUrl,
              logicalSize: size,
              devicePixelRatio: dpr,
            ) ??
            NetworkImage(imageUrl.toString()),
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return _MediaPlaceholder(size: size, loading: true);
        },
      );
    }

    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: semanticLabel == null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(width: size, height: size, child: child),
        ),
      ),
    );
  }
}

/// Aspect-ratio locked detail artwork that contains instead of covering.
class CatalogDetailArtwork extends StatelessWidget {
  const CatalogDetailArtwork({
    super.key,
    required this.imageUrl,
    this.semanticLabel,
  });

  final Uri? imageUrl;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return CatalogMediaFrame(
            imageUrl: imageUrl,
            size: side,
            semanticLabel: semanticLabel ?? l10n.packageImageLabel,
            borderRadius: BorderRadius.circular(AppRadii.card),
          );
        },
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.size, this.loading = false});

  final double size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.06),
      child: Center(
        child: loading
            ? SizedBox.square(
                dimension: (size * 0.28).clamp(16, 28),
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.inventory_2_outlined,
                color: scheme.onSurface.withValues(alpha: 0.35),
                size: size * 0.35,
              ),
      ),
    );
  }
}

/// Prefetches a small visible set with the same resized provider used to paint.
void prefetchVisibleCatalogImages(
  BuildContext context, {
  required Iterable<Uri?> urls,
  double logicalSize = 72,
  int limit = 8,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final seen = <String>{};
  var count = 0;
  for (final url in urls) {
    if (url == null || !seen.add(url.toString())) {
      continue;
    }
    final provider = CatalogMediaFrame.providerFor(
      imageUrl: url,
      logicalSize: logicalSize,
      devicePixelRatio: dpr,
    );
    if (provider != null) {
      unawaited(precacheImage(provider, context));
    }
    count += 1;
    if (count >= limit) {
      return;
    }
  }
}
