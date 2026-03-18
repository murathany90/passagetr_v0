import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

/// Utility for checking whether the current user's interactions
/// (progress, favorites, flashcard results, streaks) should be persisted.
///
/// All student content is PUBLIC — anyone can view readings, words, and grammar.
/// However, user interactions are only persisted for registered (non-anonymous) users.
class InteractionGuard {
  InteractionGuard._();

  /// Returns `true` if the user is authenticated and not anonymous.
  /// Only registered users can persist their interaction data.
  static bool canPersist(AccessContext ctx) =>
      ctx.isAuthenticated && !ctx.isAnonymous;

  /// Shows a bottom sheet encouraging the user to register.
  /// Call this when an anonymous user tries to perform a persistable action.
  static void promptRegistration(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add_alt_1_rounded,
              size: 48,
              color: tokens.accent,
            ),
            const SizedBox(height: 16),
            Text(
              'İlerlemeni kaydetmek için giriş yap',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Anonim olarak içerikleri görüntüleyebilirsin, ancak ilerleme, '
              'favori ve çalışma verilerinin kaydedilmesi için bir hesap gerekli.',
              textAlign: TextAlign.center,
              style: Theme.of(
                sheetContext,
              ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  // Navigate to profile which has auth access sheet
                  Navigator.of(context).pushNamed('/profile');
                },
                child: const Text('Hesap Oluştur / Giriş Yap'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Şimdilik Geç'),
            ),
          ],
        ),
      ),
    );
  }
}
