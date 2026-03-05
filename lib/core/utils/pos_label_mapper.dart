import '../constants/app_constants.dart';

class PosLabelMapper {
  const PosLabelMapper._();

  static const Map<String, String> _labels = <String, String>{
    'prep.': 'Edat (prep.)',
    'phr. v.': 'Deyimsel Fiil (phr. v.)',
    'v.': 'Fiil (v.)',
    'n.': 'İsim (n.)',
    'adj.': 'Sıfat (adj.)',
    'adv.': 'Zarf (adv.)',
    'NP': 'Özel İsim (NP)',
    'conj.': 'Bağlaç (conj.)',
    'det.': 'Belirteç (det.)',
    'modal': 'Kip Fiili (modal)',
  };

  static String labelFor(String code) {
    final String normalized = normalizeCode(code);
    return _labels[normalized] ?? code;
  }

  static String normalizeCode(String code) {
    return code.trim();
  }

  static List<String> sortByCanonicalOrder(Iterable<String> rawValues) {
    final Set<String> unique =
        rawValues.map(normalizeCode).where((String e) => e.isNotEmpty).toSet();

    final List<String> ordered = <String>[];
    for (final String code in AppConstants.posValues) {
      if (unique.remove(code)) {
        ordered.add(code);
      }
    }

    final List<String> unknown = unique.toList(growable: false)
      ..sort(
          (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    ordered.addAll(unknown);
    return ordered;
  }
}
