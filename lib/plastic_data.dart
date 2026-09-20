import 'dart:convert';

class PlasticRecord {
  final String id;
  final String itemName;
  final String category;
  final String material;
  final String size;
  final double weightG;
  final int quantity;
  final String status;
  final DateTime date;
  final String weightSource;
  final bool saveForLater;

  const PlasticRecord({
    required this.id,
    required this.itemName,
    required this.category,
    required this.material,
    required this.size,
    required this.weightG,
    required this.quantity,
    required this.status,
    required this.date,
    this.weightSource = 'exact',
    this.saveForLater = false,
  });

  double get totalWeight => weightG * quantity;

  Map<String, dynamic> toMap() => {
        'id': id,
        'itemName': itemName,
        'category': category,
        'material': material,
        'size': size,
        'weightG': weightG,
        'quantity': quantity,
        'status': status,
        'date': date.toIso8601String(),
        'weightSource': weightSource,
        'saveForLater': saveForLater,
      };

  factory PlasticRecord.fromMap(Map<String, dynamic> map) {
    return PlasticRecord(
      id: map['id'] as String,
      itemName: map['itemName'] as String,
      category: map['category'] as String,
      material: map['material'] as String,
      size: map['size'] as String,
      weightG: (map['weightG'] as num).toDouble(),
      quantity: map['quantity'] as int,
      status: map['status'] as String,
      date: DateTime.parse(map['date'] as String),
      weightSource: map['weightSource'] as String? ?? 'exact',
      saveForLater: map['saveForLater'] as bool? ?? false,
    );
  }
}

List<PlasticRecord> _records = <PlasticRecord>[
  PlasticRecord(
    id: 'r1',
    itemName: 'Water bottle',
    category: 'Bottle',
    material: 'PET',
    size: '500 ml',
    weightG: 18,
    quantity: 2,
    status: 'Recycled',
    date: DateTime.now().subtract(const Duration(days: 1)),
    weightSource: 'exact',
  ),
  PlasticRecord(
    id: 'r2',
    itemName: 'Shopping bag',
    category: 'Bag',
    material: 'LDPE',
    size: 'Medium',
    weightG: 22,
    quantity: 1,
    status: 'Disposed',
    date: DateTime.now().subtract(const Duration(days: 2)),
    weightSource: 'estimated',
  ),
  PlasticRecord(
    id: 'r3',
    itemName: 'Takeaway container',
    category: 'Container',
    material: 'PP',
    size: '1 L',
    weightG: 30,
    quantity: 3,
    status: 'Unknown',
    date: DateTime.now().subtract(const Duration(days: 3)),
    weightSource: 'similar',
  ),
  PlasticRecord(
    id: 'r4',
    itemName: 'Food wrapper',
    category: 'Packaging',
    material: 'Other',
    size: 'Small',
    weightG: 12,
    quantity: 4,
    status: 'Recycled',
    date: DateTime.now().subtract(const Duration(days: 4)),
    weightSource: 'exact',
  ),
  PlasticRecord(
    id: 'r5',
    itemName: 'Milk bottle',
    category: 'Bottle',
    material: 'HDPE',
    size: '750 ml',
    weightG: 25,
    quantity: 1,
    status: 'Disposed',
    date: DateTime.now().subtract(const Duration(days: 5)),
    weightSource: 'exact',
  ),
  PlasticRecord(
    id: 'r6',
    itemName: 'Snack pack',
    category: 'Packaging',
    material: 'PET',
    size: '250 ml',
    weightG: 16,
    quantity: 2,
    status: 'Recycled',
    date: DateTime.now().subtract(const Duration(days: 6)),
    weightSource: 'estimated',
  ),
];

String _weekdayLabel(DateTime date) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[date.weekday - 1];
}

bool _isThisWeek(DateTime date) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  final end = start.add(const Duration(days: 7));
  return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end);
}

double _sumByStatus(String status) {
  return _records
      .where((record) => record.status == status && _isThisWeek(record.date))
      .fold<double>(0, (total, record) => total + record.totalWeight);
}

Map<String, dynamic> getWeekSummary() {
  final thisWeekRecords = _records.where((record) => _isThisWeek(record.date)).toList();
  final totalPlastic = thisWeekRecords.fold<double>(0, (sum, record) => sum + record.totalWeight);
  final recycledTotal = _sumByStatus('Recycled');
  final disposedTotal = _sumByStatus('Disposed');
  final unknownTotal = _sumByStatus('Unknown');
  final recycledPercent = totalPlastic > 0 ? (recycledTotal / totalPlastic) * 100 : 0.0;
  final weeklyGoal = 200.0;
  final usedPercent = totalPlastic > 0 ? (totalPlastic / weeklyGoal) * 100 : 0.0;
  final remaining = (weeklyGoal - totalPlastic).clamp(0.0, weeklyGoal);

  String summaryText;
  if (totalPlastic <= 0) {
    summaryText = 'No plastic recorded yet this week. Start tracking below!';
  } else if (recycledPercent >= 45) {
    summaryText = 'You\'ve recycled ${recycledPercent.round()}% of your plastic this week. ♻️';
  } else if (usedPercent >= 80) {
    summaryText = 'You\'ve already used ${usedPercent.round()}% of your weekly goal.';
  } else {
    summaryText = 'You\'re on track with your weekly goal.';
  }

  return {
    'totalPlastic': totalPlastic,
    'recycled': recycledTotal,
    'disposed': disposedTotal,
    'unknown': unknownTotal,
    'recycledPercent': recycledPercent,
    'weeklyGoal': weeklyGoal,
    'remaining': remaining,
    'usedPercent': usedPercent,
    'summaryText': summaryText,
  };
}

List<Map<String, dynamic>> getDailyTotals() {
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));

  final output = <Map<String, dynamic>>[];
  for (int i = 0; i < 7; i++) {
    final date = weekStart.add(Duration(days: i));
    double recycled = 0;
    double notRecycled = 0;

    for (final record in _records) {
      final sameDay = record.date.year == date.year &&
          record.date.month == date.month &&
          record.date.day == date.day;
      if (!sameDay) continue;
      if (record.status == 'Recycled') {
        recycled += record.totalWeight;
      } else {
        notRecycled += record.totalWeight;
      }
    }

    output.add({
      'day': _weekdayLabel(date),
      'recycled': recycled,
      'notRecycled': notRecycled,
    });
  }
  return output;
}

List<PlasticRecord> getRecentRecords() {
  final copy = List<PlasticRecord>.from(_records);
  copy.sort((a, b) => b.date.compareTo(a.date));
  return copy;
}

PlasticRecord addRecord(Map<String, dynamic> data) {
  final record = PlasticRecord(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    itemName: data['itemName'] as String? ?? 'New item',
    category: data['category'] as String? ?? 'General',
    material: data['material'] as String? ?? 'PET',
    size: data['size'] as String? ?? 'Medium',
    weightG: (data['weightG'] as num?)?.toDouble() ?? 0.0,
    quantity: data['quantity'] as int? ?? 1,
    status: data['status'] as String? ?? 'Unknown',
    date: data['date'] as DateTime? ?? DateTime.now(),
    weightSource: data['weightSource'] as String? ?? 'exact',
    saveForLater: data['saveForLater'] as bool? ?? false,
  );

  _records.insert(0, record);
  return record;
}

PlasticRecord? updateRecord(String id, Map<String, dynamic> changes) {
  for (int index = 0; index < _records.length; index++) {
    if (_records[index].id == id) {
      final updated = PlasticRecord(
        id: _records[index].id,
        itemName: changes['itemName'] as String? ?? _records[index].itemName,
        category: changes['category'] as String? ?? _records[index].category,
        material: changes['material'] as String? ?? _records[index].material,
        size: changes['size'] as String? ?? _records[index].size,
        weightG: (changes['weightG'] as num?)?.toDouble() ?? _records[index].weightG,
        quantity: changes['quantity'] as int? ?? _records[index].quantity,
        status: changes['status'] as String? ?? _records[index].status,
        date: changes['date'] as DateTime? ?? _records[index].date,
        weightSource: changes['weightSource'] as String? ?? _records[index].weightSource,
        saveForLater: changes['saveForLater'] as bool? ?? _records[index].saveForLater,
      );
      _records[index] = updated;
      return updated;
    }
  }
  return null;
}

void deleteRecord(String id) {
  _records.removeWhere((record) => record.id == id);
}

Map<String, dynamic> getStatsForPeriod(String period, int offset) {
  final now = DateTime.now();
  DateTime startDate;
  DateTime endDate = now;

  switch (period) {
    case 'Biweekly':
      startDate = now.subtract(Duration(days: 14 + offset * 14));
      endDate = startDate.add(const Duration(days: 14));
      break;
    case 'Monthly':
      startDate = DateTime(now.year, now.month + offset, 1);
      endDate = DateTime(startDate.year, startDate.month + 1, 0);
      break;
    case 'Yearly':
      startDate = DateTime(now.year + offset, 1, 1);
      endDate = DateTime(startDate.year + 1, 1, 0);
      break;
    case 'Weekly':
    default:
      startDate = now.subtract(Duration(days: 7 + offset * 7));
      endDate = startDate.add(const Duration(days: 7));
      break;
  }

  final periodRecords = _records.where((record) {
    return !record.date.isBefore(startDate) && record.date.isBefore(endDate.add(const Duration(days: 1)));
  }).toList();

  final totalPlastic = periodRecords.fold<double>(0, (sum, record) => sum + record.totalWeight);
  final recycled = periodRecords
      .where((record) => record.status == 'Recycled')
      .fold<double>(0, (sum, record) => sum + record.totalWeight);
  final disposed = periodRecords
      .where((record) => record.status == 'Disposed')
      .fold<double>(0, (sum, record) => sum + record.totalWeight);
  final estimatedCount = periodRecords.where((record) => record.weightSource == 'estimated').length;

  final usagePoints = <Map<String, dynamic>>[];
  for (int i = 0; i < 6; i++) {
    final pointDate = startDate.add(Duration(days: i * 2));
    final totalForDay = periodRecords
        .where((record) => record.date.year == pointDate.year &&
            record.date.month == pointDate.month &&
            record.date.day == pointDate.day)
        .fold<double>(0, (sum, item) => sum + item.totalWeight);
    usagePoints.add({'label': '${i + 1}', 'value': totalForDay});
  }

  final categoryData = <Map<String, dynamic>>[
    {'label': 'Bottle', 'value': 62},
    {'label': 'Bag', 'value': 40},
    {'label': 'Container', 'value': 76},
    {'label': 'Packaging', 'value': 53},
  ];

  return {
    'totalPlastic': totalPlastic,
    'recycled': recycled,
    'disposed': disposed,
    'rate': totalPlastic > 0 ? (recycled / totalPlastic) * 100 : 0.0,
    'average': totalPlastic > 0 ? totalPlastic / 4 : 0.0,
    'periodLabel': '${_monthName(startDate.month)} ${startDate.year}',
    'includesEstimates': estimatedCount,
    'usagePoints': usagePoints,
    'categoryData': categoryData,
  };
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return names[month - 1];
}

List<String> getItemSizes(String type, String material) {
  final base = {
    'Bottle': ['250 ml', '500 ml', '750 ml', '1 L', '2 L'],
    'Bag': ['Small', 'Medium', 'Large'],
    'Container': ['250 ml', '500 ml', '1 L', '2 L'],
    'Packaging': ['Small', 'Medium', 'Large'],
  };
  return base[type] ?? ['Small', 'Medium', 'Large'];
}

double estimateWeight(String type, String material, String size) {
  final base = {
    'Bottle': {'PET': 18.0, 'HDPE': 22.0, 'LDPE': 20.0, 'PP': 17.0, 'Other': 24.0},
    'Bag': {'PET': 14.0, 'HDPE': 12.0, 'LDPE': 20.0, 'PP': 15.0, 'Other': 18.0},
    'Container': {'PET': 24.0, 'HDPE': 27.0, 'LDPE': 30.0, 'PP': 28.0, 'Other': 32.0},
    'Packaging': {'PET': 8.0, 'HDPE': 10.0, 'LDPE': 12.0, 'PP': 9.0, 'Other': 13.0},
  };

  final sizeMultiplier = {
    '250 ml': 0.7,
    '500 ml': 1.0,
    '750 ml': 1.4,
    '1 L': 1.7,
    '2 L': 2.4,
    'Small': 0.8,
    'Medium': 1.0,
    'Large': 1.5,
  };

  final materialWeight = base[type]?[material] ?? 15.0;
  return materialWeight * (sizeMultiplier[size] ?? 1.0);
}

String exportBackup() {
  final payload = jsonEncode(_records.map((record) => record.toMap()).toList());
  return payload;
}

bool importBackup() {
  final backupText = exportBackup();
  final decoded = jsonDecode(backupText) as List<dynamic>;
  _records = decoded
      .map((item) => PlasticRecord.fromMap(item as Map<String, dynamic>))
      .toList();
  return true;
}
