import 'package:flutter/material.dart';

class AccessGate extends StatelessWidget {
  const AccessGate({
    super.key,
    required this.canAccess,
    required this.child,
    required this.fallback,
  });

  final bool canAccess;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return canAccess ? child : fallback;
  }
}
