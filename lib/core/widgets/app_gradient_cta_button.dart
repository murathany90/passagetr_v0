import 'package:flutter/material.dart';

class AppGradientCtaButton extends StatelessWidget {
  const AppGradientCtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool canTap = enabled && onTap != null;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: canTap ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.45) ??
                  colorScheme.primary,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canTap ? onTap : null,
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
