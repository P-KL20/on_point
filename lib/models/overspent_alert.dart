// This file defines the OverspentAlert class, which represents an alert for overspending in a specific category.
// It includes properties for the category name, amount spent, limit, and percentage of the limit that has been spent.
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
