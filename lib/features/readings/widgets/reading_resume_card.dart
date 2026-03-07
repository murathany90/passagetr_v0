import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_cta_button.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_surface_card.dart';

class ReadingResumeCard extends StatelessWidget {
  const ReadingResumeCard.loading({
    this.desktop = false,
    super.key,
  })  : message = null,
        title = null,
        progressText = null,
        onTap = null,
        isLoading = true;

  const ReadingResumeCard.message({
    required this.message,
    this.desktop = false,
    super.key,
  })  : title = null,
        progressText = null,
        onTap = null,
        isLoading = false;

  const ReadingResumeCard.content({
    required this.title,
    required this.progressText,
    required this.onTap,
    this.desktop = false,
    super.key,
  })  : message = null,
        isLoading = false;

  final String? message;
  final String? title;
  final String? progressText;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: const ValueKey<String>('reading-home-resume-card'),
      variant: AppSurfaceVariant.grouped,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: desktop ? 168 : 72),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          height: 32,
          width: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (message != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          desktop ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(title: 'Okumaya Devam Et'),
        const SizedBox(height: 6),
        Text(
          title!,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          progressText!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: desktop ? 220 : double.infinity,
            child: AppGradientCtaButton(
              onTap: onTap,
              icon: Icons.play_arrow_rounded,
              label: 'Devam Et',
            ),
          ),
        ),
      ],
    );
  }
}
