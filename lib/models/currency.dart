class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.countryCodes,
  });

  final String code;
  final String name;
  final String symbol;
  final List<String> countryCodes;
}
