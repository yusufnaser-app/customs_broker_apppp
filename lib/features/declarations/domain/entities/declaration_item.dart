class DeclarationItem {
  final String id;
  final String declarationId;
  final String hsCode;
  final String itemName;
  final String? description;
  final double quantity;
  final double? weight;
  final String unit;
  final double value;
  final String? originCountry;
  final String createdAt;

  const DeclarationItem({
    required this.id,
    required this.declarationId,
    required this.hsCode,
    required this.itemName,
    this.description,
    required this.quantity,
    this.weight,
    required this.unit,
    required this.value,
    this.originCountry,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'declaration_id': declarationId,
      'hs_code': hsCode,
      'item_name': itemName,
      'description': description,
      'quantity': quantity,
      'weight': weight,
      'unit': unit,
      'value': value,
      'origin_country': originCountry,
      'created_at': createdAt,
    };
  }

  factory DeclarationItem.fromMap(Map<String, dynamic> map) {
    return DeclarationItem(
      id: map['id'] ?? '',
      declarationId: map['declaration_id'] ?? '',
      hsCode: map['hs_code'] ?? '',
      itemName: map['item_name'] ?? '',
      description: map['description'],
      quantity: (map['quantity'] ?? 0).toDouble(),
      weight: map['weight']?.toDouble(),
      unit: map['unit'] ?? '',
      value: (map['value'] ?? 0).toDouble(),
      originCountry: map['origin_country'],
      createdAt: map['created_at'] ?? '',
    );
  }
}
