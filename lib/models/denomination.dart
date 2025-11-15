class Denomination {
  const Denomination(this.value);

  final double value;

  factory Denomination.fromJson(String rawValue) {
    final parsed = double.tryParse(rawValue);
    return Denomination(parsed ?? 0);
  }

  String toJson() => value.toString();
}
