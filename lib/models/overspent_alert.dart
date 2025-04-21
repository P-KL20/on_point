class OverspentAlert {
  final String category;
  final double spent;
  final double limit;
  final double percent;

  OverspentAlert({
    required this.category,
    required this.spent,
    required this.limit,
    required this.percent,
  });

  factory OverspentAlert.fromMap(Map<String, dynamic> map) {
    return OverspentAlert(
      category: map['category'] as String,
      spent: (map['spent'] as num).toDouble(),
      limit: (map['limit'] as num).toDouble(),
      percent: (map['percent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'spent': spent,
      'limit': limit,
      'percent': percent,
    };
  }
}
