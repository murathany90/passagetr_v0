import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/theme/app_colors.dart';

void main() {
  test('dark palette uses expected slate + blue token values', () {
    expect(AppColors.darkBackground, const Color(0xFF10131A));
    expect(AppColors.darkSurface, const Color(0xFF171C24));
    expect(AppColors.darkSurfaceVariant, const Color(0xFF232B37));
    expect(AppColors.darkOnSurface, const Color(0xFFE8ECF4));
    expect(AppColors.darkOnSurfaceVariant, const Color(0xFFB6C0CF));
    expect(AppColors.darkPrimary, const Color(0xFF8EA8FF));
    expect(AppColors.darkPrimaryContainer, const Color(0xFF2A3E73));
    expect(AppColors.darkSecondary, const Color(0xFFA9B9E4));
    expect(AppColors.darkSecondaryContainer, const Color(0xFF2D3A5A));
    expect(AppColors.darkOutline, const Color(0xFF7F8A9E));
    expect(AppColors.darkInversePrimary, const Color(0xFF4E6ECF));
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
