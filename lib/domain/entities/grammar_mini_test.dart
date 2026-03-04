class GrammarMiniTest {
  const GrammarMiniTest({
    required this.id,
    required this.sayfaId,
    required this.sira,
    required this.soru,
    required this.secenekler,
    required this.dogruCevap,
    required this.aciklama,
  });

  final int id;
  final int sayfaId;
  final int sira;
  final String soru;
  final Map<String, String> secenekler;
  final String dogruCevap;
  final String aciklama;
}

