import 'package:flutter_test/flutter_test.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

void main() {
  group('FoundationDictionaryRepository', () {
    test('passes normalized query into local lookup override', () async {
      String? receivedPath;
      String? receivedQuery;

      final repository = FoundationDictionaryRepository.preview(
        localPathProvider: () async => r'C:\tmp\dictionary_local.sqlite',
        localLookupOverride:
            ({
              required String databasePath,
              required String normalizedQuery,
            }) async {
              receivedPath = databasePath;
              receivedQuery = normalizedQuery;
              return const DictionaryEntry(
                enWord: 'author',
                trMeaning: 'yazar',
                pos: 'noun',
              );
            },
      );

      final entry = await repository.lookupWord('Author');

      expect(receivedPath, r'C:\tmp\dictionary_local.sqlite');
      expect(receivedQuery, 'author');
      expect(entry, isNotNull);
      expect(entry?.enWord, 'author');
      expect(entry?.trMeaning, 'yazar');
      expect(entry?.pos, 'noun');
    });

    test('normalizes punctuation before local lookup', () async {
      String? receivedQuery;

      final repository = FoundationDictionaryRepository.preview(
        localPathProvider: () async => r'C:\tmp\dictionary_local.sqlite',
        localLookupOverride:
            ({
              required String databasePath,
              required String normalizedQuery,
            }) async {
              receivedQuery = normalizedQuery;
              return const DictionaryEntry(
                enWord: 'ocean',
                trMeaning: 'okyanus',
                pos: 'noun',
              );
            },
      );

      final entry = await repository.lookupWord('ocean,');

      expect(receivedQuery, 'ocean');
      expect(entry?.enWord, 'ocean');
      expect(entry?.trMeaning, 'okyanus');
    });

    test('falls back to remote lookup when local is unavailable', () async {
      final repository = FoundationDictionaryRepository.preview(
        localPathProvider: () async => null,
        remoteLookupOverride: (normalizedQuery) async {
          if (normalizedQuery != 'mystery') {
            return null;
          }

          return const DictionaryEntry(
            enWord: 'mystery',
            trMeaning: 'gizem',
            pos: 'noun',
          );
        },
      );

      final entry = await repository.lookupWord('Mystery');

      expect(entry, isNotNull);
      expect(entry?.trMeaning, 'gizem');
    });

    test('falls back to remote lookup when local lookup throws', () async {
      final repository = FoundationDictionaryRepository.preview(
        localPathProvider: () async => r'C:\tmp\dictionary_local.sqlite',
        localLookupOverride:
            ({
              required String databasePath,
              required String normalizedQuery,
            }) async {
              throw StateError('local lookup unavailable');
            },
        remoteLookupOverride: (normalizedQuery) async {
          if (normalizedQuery != 'backup') {
            return null;
          }

          return const DictionaryEntry(
            enWord: 'backup',
            trMeaning: 'yedek',
            pos: 'noun',
          );
        },
      );

      final entry = await repository.lookupWord('Backup');

      expect(entry, isNotNull);
      expect(entry?.trMeaning, 'yedek');
    });

    test('returns null when no local or remote entry exists', () async {
      final repository = FoundationDictionaryRepository.preview(
        localPathProvider: () async => null,
        remoteLookupOverride: (_) async => null,
      );

      final entry = await repository.lookupWord('nonexistent');

      expect(entry, isNull);
    });
  });
}
