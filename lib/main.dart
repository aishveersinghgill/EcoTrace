import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'plastic_data.dart';

void main() {
  runApp(const EcoTraceApp());
}

// The app root. It controls the theme and the shared data list.
class EcoTraceApp extends StatefulWidget {
  const EcoTraceApp({super.key});

  @override
  State<EcoTraceApp> createState() => _EcoTraceAppState();
}

class _EcoTraceAppState extends State<EcoTraceApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String _unit = 'g';
  List<PlasticRecord> _records = getRecentRecords();

  void _refreshRecords() {
    setState(() {
      _records = getRecentRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plastic Usage Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
      ),
      home: HomePage(
        records: _records,
        unit: _unit,
        themeMode: _themeMode,
        onThemeChanged: (ThemeMode mode) {
          setState(() {
            _themeMode = mode;
          });
        },
        onUnitChanged: (String unit) {
          setState(() {
            _unit = unit;
          });
        },
        onRefresh: _refreshRecords,
      ),
    );
  }
}

// The main shell with the 3-tab bottom navigation.
class HomePage extends StatefulWidget {
  final List<PlasticRecord> records;
  final String unit;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onRefresh;

  const HomePage({
    super.key,
    required this.records,
    required this.unit,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onUnitChanged,
    required this.onRefresh,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // This helper chooses which screen is shown for each bottom tab.
  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return ThisWeekScreen(
          onOpenSettings: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SettingsScreen(
                  currentTheme: widget.themeMode,
                  currentUnit: widget.unit,
                  onThemeChanged: widget.onThemeChanged,
                  onUnitChanged: widget.onUnitChanged,
                ),
              ),
            );
          },
          onOpenItem: (PlasticRecord record) async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (context) => ItemDetailsScreen(record: record),
              ),
            );
            if (result == true && mounted) {
              widget.onRefresh();
            }
          },
        );
      case 1:
        return AddScreen(
          onAdded: () {
            widget.onRefresh();
            setState(() {
              _selectedIndex = 0;
            });
          },
        );
      case 2:
        return StatsScreen();
      default:
        return ThisWeekScreen(
          onOpenSettings: () {},
          onOpenItem: (_) async {},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today_rounded), label: 'This Week'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
        ],
      ),
    );
  }
}

// Screen 1: This Week summary and recent activity.
class ThisWeekScreen extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final Future<void> Function(PlasticRecord record) onOpenItem;

  const ThisWeekScreen({
    super.key,
    required this.onOpenSettings,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    final summary = getWeekSummary();
    final dailyTotals = getDailyTotals();
    final recentRecords = getRecentRecords();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('This Week'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary sentence at the top. It changes based on the current data.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                summary['summaryText'] as String,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main stat cards for the total plastic and recycled percentage.
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Recycled %',
                    value: '${(summary['recycledPercent'] as double).round()}%',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Total plastic',
                    value: '${summary['totalPlastic'].round()} g',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekly goal card with progress and remaining amount.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekly goal', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${summary['totalPlastic'].round()} / ${summary['weeklyGoal'].round()} g',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: ((summary['totalPlastic'] as double) / (summary['weeklyGoal'] as double)).clamp(0.0, 1.0),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary['remaining'].round()} g remaining',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Totals for recycled, disposed and unknown statuses.
            Row(
              children: [
                Expanded(child: _StatusCard(label: 'Recycled', value: '${summary['recycled'].round()} g', color: Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _StatusCard(label: 'Disposed', value: '${summary['disposed'].round()} g', color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _StatusCard(label: 'Unknown', value: '${summary['unknown'].round()} g', color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 20),

            // Line chart of daily plastic use. It compares recycled and not recycled totals.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily plastic trend',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 26,
                                getTitlesWidget: (value, meta) {
                                  final label = dailyTotals[value.toInt()]['day'] as String? ?? '';
                                  return Text(label, style: const TextStyle(fontSize: 10));
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                              spots: dailyTotals
                                  .asMap()
                                  .entries
                                  .map((entry) => FlSpot(entry.key.toDouble(), (entry.value['recycled'] as num).toDouble()))
                                  .toList(),
                            ),
                            LineChartBarData(
                              isCurved: true,
                              color: Colors.orange,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                              spots: dailyTotals
                                  .asMap()
                                  .entries
                                  .map((entry) => FlSpot(entry.key.toDouble(), (entry.value['notRecycled'] as num).toDouble()))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        _LegendDot(color: Colors.green, label: 'Recycled'),
                        SizedBox(width: 18),
                        _LegendDot(color: Colors.orange, label: 'Not recycled'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Recent item list. Each item opens the detail screen.
            Text(
              'Recent items',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...recentRecords.take(6).map((record) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(record.itemName),
                  subtitle: Text('${record.material} • ${record.size} • ${record.status}'),
                  trailing: Text('${record.totalWeight.round()} g'),
                  onTap: () async => onOpenItem(record),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// A reusable metric tile used on the home screen.
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Small colored status box on the home screen.
class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
      ),
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// A small legend item for the chart.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

// Screen 2: Add entries. Two paths: common item and custom item.
class AddScreen extends StatefulWidget {
  final VoidCallback onAdded;

  const AddScreen({super.key, required this.onAdded});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final List<String> _types = ['Bottle', 'Bag', 'Container', 'Packaging'];
  final List<String> _materials = ['PET', 'HDPE', 'LDPE', 'PP', 'Other'];
  final List<String> _statuses = ['Recycled', 'Disposed', 'Unknown'];

  String _selectedType = 'Bottle';
  String _selectedMaterial = 'PET';
  String _selectedSize = '500 ml';
  int _quantity = 1;
  String _status = 'Unknown';

  final TextEditingController _customNameController = TextEditingController();
  String _customMaterial = 'PET';
  int _customQuantity = 1;
  String _customStatus = 'Unknown';
  final TextEditingController _customWeightController = TextEditingController(text: '0');
  bool _saveForLater = false;
  String _weightSource = 'exact';

  @override
  void dispose() {
    _customNameController.dispose();
    _customWeightController.dispose();
    super.dispose();
  }

  double _estimatedCommonWeight() {
    final estimate = estimateWeight(_selectedType, _selectedMaterial, _selectedSize);
    return estimate * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final sizes = getItemSizes(_selectedType, _selectedMaterial);
    if (!sizes.contains(_selectedSize)) {
      _selectedSize = sizes.first;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add material'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Common item'),
              Tab(text: 'Custom item'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Common item path.
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item type', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = type == _selectedType;
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _selectedType = type;
                          _selectedSize = getItemSizes(type, _selectedMaterial).first;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMaterial,
                    decoration: const InputDecoration(labelText: 'Material'),
                    items: _materials.map((material) {
                      return DropdownMenuItem(value: material, child: Text(material));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMaterial = value;
                        _selectedSize = getItemSizes(_selectedType, value).first;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('Size', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sizes.map((size) {
                      final selected = size == _selectedSize;
                      return ChoiceChip(
                        label: Text(size),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedSize = size),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Quantity'),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() => _quantity = (_quantity - 1).clamp(1, 99)),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$_quantity'),
                      IconButton(
                        onPressed: () => setState(() => _quantity = (_quantity + 1).clamp(1, 99)),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Estimated plastic: ${_estimatedCommonWeight().round()} g',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statuses.map((status) {
                      return DropdownMenuItem(value: status, child: Text(status));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        addRecord({
                          'itemName': '$_selectedType (${_selectedMaterial})',
                          'category': _selectedType,
                          'material': _selectedMaterial,
                          'size': _selectedSize,
                          'weightG': estimateWeight(_selectedType, _selectedMaterial, _selectedSize),
                          'quantity': _quantity,
                          'status': _status,
                          'date': DateTime.now(),
                          'weightSource': 'estimated',
                        });
                        widget.onAdded();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Record added to tracker.')),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add to Tracker'),
                    ),
                  ),
                ],
              ),
            ),

            // Custom item path.
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _customNameController,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _customMaterial,
                    decoration: const InputDecoration(labelText: 'Material'),
                    items: _materials.map((material) {
                      return DropdownMenuItem(value: material, child: Text(material));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _customMaterial = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight in grams'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Quantity'),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() => _customQuantity = (_customQuantity - 1).clamp(1, 99)),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$_customQuantity'),
                      IconButton(
                        onPressed: () => setState(() => _customQuantity = (_customQuantity + 1).clamp(1, 99)),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _saveForLater,
                    onChanged: (value) => setState(() => _saveForLater = value ?? false),
                    title: const Text('Save this item for later'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _customStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statuses.map((status) {
                      return DropdownMenuItem(value: status, child: Text(status));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _customStatus = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Don\'t know the weight?', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _weightSource,
                    decoration: const InputDecoration(labelText: 'Weight source'),
                    items: const [
                      DropdownMenuItem(value: 'exact', child: Text('Exact weight')),
                      DropdownMenuItem(value: 'similar', child: Text('Pick a similar existing item')),
                      DropdownMenuItem(value: 'estimated', child: Text('Use a default estimate')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _weightSource = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _weightSource == 'estimated'
                        ? 'Using a default estimate based on material and size.'
                        : _weightSource == 'similar'
                            ? 'A similar item is being used as a guide.'
                            : 'Exact measurement entered by the user.',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final weightValue = double.tryParse(_customWeightController.text) ?? 0.0;
                        addRecord({
                          'itemName': _customNameController.text.trim().isNotEmpty ? _customNameController.text.trim() : 'Custom item',
                          'category': 'Custom',
                          'material': _customMaterial,
                          'size': 'Custom',
                          'weightG': weightValue > 0 ? weightValue : estimateWeight('Bottle', _customMaterial, '500 ml'),
                          'quantity': _customQuantity,
                          'status': _customStatus,
                          'date': DateTime.now(),
                          'weightSource': _weightSource,
                          'saveForLater': _saveForLater,
                        });
                        widget.onAdded();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Custom item saved.')),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save custom item'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Screen 3: Stats dashboard with time period filter and charts.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _period = 'Weekly';
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final stats = getStatsForPeriod(_period, _offset);
    final usagePoints = stats['usagePoints'] as List<Map<String, dynamic>>;

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period selector and arrow month switcher.
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => _offset = _offset - 1);
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _period,
                    items: const [
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'Biweekly', child: Text('Biweekly')),
                      DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _period = value);
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _offset = _offset + 1);
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                stats['periodLabel'] as String,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),

            // Overview cards for totals and average.
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MetricCard(label: 'Total plastic', value: '${(stats['totalPlastic'] as double).round()} g', color: Colors.green),
                _MetricCard(label: 'Recycled', value: '${(stats['recycled'] as double).round()} g', color: Colors.teal),
                _MetricCard(label: 'Recycling rate', value: '${(stats['rate'] as double).round()}%', color: Colors.lightGreen),
                _MetricCard(label: 'Avg / week', value: '${(stats['average'] as double).round()} g', color: Colors.blue),
              ],
            ),
            const SizedBox(height: 20),

            // Usage over time chart.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                          spots: usagePoints
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(entry.key.toDouble(), (entry.value['value'] as num).toDouble()))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Recycled vs disposed bars.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: (stats['recycled'] as double), color: Colors.green, width: 22)]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: (stats['disposed'] as double), color: Colors.orange, width: 22)]),
                      ],
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Plastic by category chart.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(value: 62, color: Colors.green, title: 'Bottle', radius: 54),
                        PieChartSectionData(value: 40, color: Colors.teal, title: 'Bag', radius: 54),
                        PieChartSectionData(value: 76, color: Colors.lightGreen, title: 'Container', radius: 54),
                        PieChartSectionData(value: 53, color: Colors.orange, title: 'Packaging', radius: 54),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if ((stats['includesEstimates'] as int) > 0)
              Text(
                '(includes ${stats['includesEstimates']} estimates)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}

// Screen 4: Item details and inline editing.
class ItemDetailsScreen extends StatefulWidget {
  final PlasticRecord record;

  const ItemDetailsScreen({super.key, required this.record});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  late String _status = widget.record.status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.record.itemName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _DetailRow(label: 'Size', value: widget.record.size),
            _DetailRow(label: 'Material', value: widget.record.material),
            _DetailRow(label: 'Weight', value: '${widget.record.weightG.toStringAsFixed(1)} g'),
            _DetailRow(label: 'Quantity', value: widget.record.quantity.toString()),
            _DetailRow(label: 'Total', value: '${widget.record.totalWeight.round()} g'),
            _DetailRow(label: 'Status', value: widget.record.status),
            _DetailRow(label: 'Date', value: widget.record.date.toLocal().toString().split(' ')[0]),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Update status'),
              items: const [
                DropdownMenuItem(value: 'Recycled', child: Text('Recycled')),
                DropdownMenuItem(value: 'Disposed', child: Text('Disposed')),
                DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _status = value;
                });
                updateRecord(widget.record.id, {'status': value});
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      updateRecord(widget.record.id, {'status': _status});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Status updated.')),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      deleteRecord(widget.record.id);
                      Navigator.of(context).pop(true);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Screen 5: Settings. This is UI-only with confirm dialogs for backup actions.
class SettingsScreen extends StatelessWidget {
  final ThemeMode currentTheme;
  final String currentUnit;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onUnitChanged;

  const SettingsScreen({
    super.key,
    required this.currentTheme,
    required this.currentUnit,
    required this.onThemeChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: currentTheme,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onThemeChanged(value);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Units'),
            trailing: DropdownButton<String>(
              value: currentUnit,
              items: const [
                DropdownMenuItem(value: 'g', child: Text('g')),
                DropdownMenuItem(value: 'kg', child: Text('kg')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onUnitChanged(value);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              final backup = exportBackup();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Backup created (${backup.length} bytes).')),
              );
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Export Backup'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Restore backup?'),
                    content: const Text('This may replace your existing data.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          importBackup();
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup restored.')),
                          );
                        },
                        child: const Text('Restore'),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Import Backup'),
          ),
          const SizedBox(height: 20),
          const AboutListTile(
            applicationName: 'Plastic Usage Tracker',
            applicationVersion: '1.0.0',
            applicationLegalese: 'College project demo. Offline and local only.',
          ),
        ],
      ),
    );
  }
}
