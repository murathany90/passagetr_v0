import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/theme/app_colors.dart';

void main() {
  test('dark palette uses expected slate + blue token values', () {
    expect(AppColors.darkBackground, const Color(0xFF14181F));
    expect(AppColors.darkSurface, const Color(0xFF1B212B));
    expect(AppColors.darkSurfaceVariant, const Color(0xFF262E3A));
    expect(AppColors.darkOnSurface, const Color(0xFFE4E8EF));
    expect(AppColors.darkOnSurfaceVariant, const Color(0xFFAFB8C7));
    expect(AppColors.darkPrimary, const Color(0xFF9AB6F3));
    expect(AppColors.darkPrimaryContainer, const Color(0xFF314575));
    expect(AppColors.darkSecondary, const Color(0xFFAECAC1));
    expect(AppColors.darkSecondaryContainer, const Color(0xFF2B4942));
    expect(AppColors.darkOutline, const Color(0xFF788397));
    expect(AppColors.darkInversePrimary, const Color(0xFF4C6BC0));
  });

  test('dark palette keeps readable contrast for key pairs', () {
    expect(_contrastRatio(AppColors.darkSurface, AppColors.darkOnSurface), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(AppColors.darkPrimary, AppColors.darkOnPrimary), greaterThanOrEqualTo(4.5));
    expect(
      _contrastRatio(AppColors.darkPrimaryContainer, AppColors.darkOnPrimaryContainer),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('AppTheme.dark is wired to dark palette tokens', () {
    final String source = File('lib/core/theme/app_theme.dart').readAsStringSync();

    expect(source.contains('primary: AppColors.darkPrimary'), isTrue);
    expect(source.contains('primaryContainer: AppColors.darkPrimaryContainer'), isTrue);
    expect(source.contains('secondary: AppColors.darkSecondary'), isTrue);
    expect(source.contains('secondaryContainer: AppColors.darkSecondaryContainer'), isTrue);
    expect(source.contains('outline: AppColors.darkOutline'), isTrue);
    expect(source.contains('surfaceTint: AppColors.darkPrimary'), isTrue);
    expect(source.contains('indicatorColor: colorScheme.primaryContainer'), isTrue);
    expect(source.contains('scaffoldBackground: AppColors.darkBackground'), isTrue);
  });
}

double _contrastRatio(Color a, Color b) {
  final double l1 = a.computeLuminance();
  final double l2 = b.computeLuminance();
  final double lighter = l1 > l2 ? l1 : l2;
  final double darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}
