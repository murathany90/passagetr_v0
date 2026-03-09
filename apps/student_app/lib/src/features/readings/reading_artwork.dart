import 'package:flutter/material.dart';

import 'reading_seed_data.dart';

class ReadingArtwork extends StatelessWidget {
  const ReadingArtwork({
    super.key,
    required this.seed,
    required this.height,
    required this.borderRadius,
  });

  final ReadingSeedData seed;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: seed.imageAsset == null
            ? _ArtworkFallback(seed: seed)
            : Image.asset(
                seed.imageAsset!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _ArtworkFallback(seed: seed);
                },
              ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.seed});

  final ReadingSeedData seed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: seed.artworkColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: 18,
            top: 18,
            child: Icon(
              seed.artworkIcon,
              size: 48,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 20,
            child: Icon(
              seed.artworkIcon,
              size: 72,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}
