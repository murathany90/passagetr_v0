import 'package:flutter/material.dart';

import '../../../../domain/entities/dictionary_lookup_result.dart';

class DictionaryResultList extends StatelessWidget {
  const DictionaryResultList({
    required this.result,
    super.key,
  });

  final DictionaryLookupResult result;

  @override
  Widget build(BuildContext context) {
    if (result.hasLocalEntries) {
      return ListView.separated(
        itemCount: result.entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final entry = result.entries[index];
          final String subtitle = (entry.pos ?? '').trim().isEmpty
              ? entry.trMeaning
              : '${entry.pos} | ${entry.trMeaning}';
          return ListTile(
            title: Text(entry.enWord),
            subtitle: Text(subtitle),
            dense: true,
          );
        },
      );
    }

    if (result.hasFallback) {
      final String sourceLabel = result.fromServerCache
          ? 'Sunucu cache sonucu'
          : (result.fromDeepL ? 'DeepL fallback sonucu' : 'Fallback sonucu');
      return ListView(
        children: <Widget>[
          ListTile(
            title: Text(sourceLabel),
            subtitle: Text(result.fallbackTranslatedText!.trim()),
          ),
        ],
      );
    }

    if (result.hasError) {
      return ListView(
        children: <Widget>[
          ListTile(
            title: const Text('Sonuc bulunamadi'),
            subtitle: Text(result.error!),
          ),
        ],
      );
    }

    return ListView(
      children: const <Widget>[
        ListTile(
          title: Text('Sonuc yok'),
          subtitle: Text('Arama kelimesi girin.'),
        ),
      ],
    );
  }
}
