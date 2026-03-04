import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/dictionary_lookup_result.dart';
import '../application/dictionary_lookup_controller.dart';
import 'widgets/dictionary_result_list.dart';

class DictionarySearchPage extends ConsumerStatefulWidget {
  const DictionarySearchPage({super.key});

  @override
  ConsumerState<DictionarySearchPage> createState() =>
      _DictionarySearchPageState();
}

class _DictionarySearchPageState extends ConsumerState<DictionarySearchPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DictionaryLookupResult> result = ref.watch(
      dictionaryLookupControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _lookup,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'kelime veya phrase ara',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _lookup(_controller.text),
                  child: const Text('Ara'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: result.when(
                data: (DictionaryLookupResult data) =>
                    DictionaryResultList(result: data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) => ListView(
                  children: <Widget>[
                    ListTile(
                      title: const Text('Hata'),
                      subtitle: Text(error.toString()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _lookup(String query) {
    ref.read(dictionaryLookupControllerProvider.notifier).lookup(query);
  }
}
