import 'package:flutter/material.dart';

import '../../../domain/entities/dictionary_entry.dart';
import '../../../domain/entities/dictionary_lookup_result.dart';

class DictionaryFallbackSheet extends StatelessWidget {
  const DictionaryFallbackSheet({
    required this.query,
    required this.lookup,
    super.key,
  });

  final String query;
  final DictionaryLookupResult lookup;

  @override
  Widget build(BuildContext context) {
    final String sourceLabel = dictionaryLookupSourceLabel(lookup);
    final List<String> lines = dictionaryPreviewLines(lookup.entries, limit: 5);
    final String fallback = (lookup.fallbackTranslatedText ?? '').trim();
    final String error = (lookup.error ?? '').trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    query,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (sourceLabel.isNotEmpty)
                  Chip(
                    label: Text(sourceLabel),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (lines.isNotEmpty)
              ...lines.map(
                (String line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line),
                ),
              )
            else if (fallback.isNotEmpty)
              Text(
                fallback,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              )
            else if (error.isNotEmpty)
              Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              const Text('Bu kelime icin sonuc bulunamadi.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String dictionaryLookupSourceLabel(DictionaryLookupResult lookup) {
  if (lookup.hasLocalEntries) {
    return 'Local sozluk';
  }
  if (lookup.fromServerCache == true) {
    return 'Sunucu cache';
  }
  if (lookup.fromDeepL == true) {
    return 'DeepL sozluk';
  }
  if (lookup.hasFallback) {
    return 'Fallback';
  }
  if (lookup.hasError) {
    return 'Hata';
  }
  return 'Sonuc yok';
}

List<String> dictionaryPreviewLines(
  List<DictionaryEntry> entries, {
  int limit = 5,
}) {
  if (entries.isEmpty || limit <= 0) {
    return const <String>[];
  }
  return entries.take(limit).map((DictionaryEntry entry) {
    final String pos = (entry.pos ?? '').trim();
    if (pos.isEmpty) {
      return entry.trMeaning;
    }
    return '$pos | ${entry.trMeaning}';
  }).toList(growable: false);
}
