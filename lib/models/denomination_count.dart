class DenominationCount {
  const DenominationCount({required this.denomination, required this.quantity})
    : assert(quantity >= 0, 'La cantidad no puede ser negativa');

  final double denomination;
  final int quantity;

  double get totalValue => denomination * quantity;

  factory DenominationCount.fromJson(Map<String, dynamic> json) {
    return DenominationCount(
      denomination: (json['denomination'] as num).toDouble(),
      quantity: json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'denomination': denomination,
    'quantity': quantity,
  };

  DenominationCount copyWith({int? quantity}) {
    return DenominationCount(
      denomination: denomination,
      quantity: quantity ?? this.quantity,
    );
  }
}
