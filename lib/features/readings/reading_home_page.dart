import 'package:flutter/material.dart';

import '../../domain/entities/pack.dart';
import '../packs/pack_list_page.dart';
import 'reading_list_page.dart';

class ReadingHomePage extends StatelessWidget {
  const ReadingHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PackListPage(
      embedded: true,
      emptyHint:
          'Okuma paketleri icin docs/supabase_readings_import.md adimlarini takip edin.',
      onPackTap: (BuildContext context, Pack pack) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReadingListPage(pack: pack),
          ),
        );
      },
    );
  }
}
