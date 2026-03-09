import 'package:flutter/material.dart';

class DeferredPageLoader extends StatefulWidget {
  const DeferredPageLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<DeferredPageLoader> createState() => _DeferredPageLoaderState();
}

class _DeferredPageLoaderState extends State<DeferredPageLoader> {
  late Future<void> _libraryLoader;

  @override
  void initState() {
    super.initState();
    _libraryLoader = widget.loadLibrary();
  }

  @override
  void didUpdateWidget(covariant DeferredPageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadLibrary != widget.loadLibrary) {
      _libraryLoader = widget.loadLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _libraryLoader,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error!) ??
              Center(child: Text('Sayfa yüklenemedi: ${snapshot.error}'));
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }

        return widget.builder(context);
      },
    );
  }
}
