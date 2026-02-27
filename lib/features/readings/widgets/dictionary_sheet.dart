import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/word_selection_utils.dart';

class DictionarySheet extends StatefulWidget {
  const DictionarySheet({
    required this.initialSentence,
    this.initialWord,
    super.key,
  });

  final String initialSentence;
  final String? initialWord;

  @override
  State<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<DictionarySheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWord ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Sozluk Ac',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              widget.initialSentence,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Kelime',
                hintText: 'lookup word',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  _openDictionary(buildCambridgeDictionaryUrl(_word)),
              child: const Text('Cambridge'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _openDictionary(buildDictionaryDotComUrl(_word)),
              child: const Text('Dictionary.com'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _copyWord,
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }

  String get _word => _controller.text.trim();

  Future<void> _openDictionary(Uri uri) async {
    if (_word.isEmpty) {
      _showMessage('Lutfen bir kelime girin.');
      return;
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      _showMessage('Sozluk acilamadi.');
    }
  }

  Future<void> _copyWord() async {
    if (_word.isEmpty) {
      _showMessage('Kopyalanacak kelime yok.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _word));
    if (mounted) {
      _showMessage('Kopyalandi.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
