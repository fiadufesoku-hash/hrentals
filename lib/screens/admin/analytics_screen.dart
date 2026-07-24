import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/graphql_service.dart';
import '../../themes.dart';

class AnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic>? dashboardStats;
  final List<dynamic> properties;

  const AnalyticsScreen({
    super.key,
    required this.dashboardStats,
    required this.properties,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final stats = widget.dashboardStats;
    final properties = widget.properties;

    if (stats == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Platform Overview'),
          const SizedBox(height: 16),
          _buildSummaryGrid(stats),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildChartCard('Property Types', _buildPieChart(properties))),
              if (MediaQuery.of(context).size.width > 600)
                Expanded(child: _buildChartCard('Availability', _buildBarChart(stats))),
            ],
          ),
          if (MediaQuery.of(context).size.width <= 600) ...[
            const SizedBox(height: 16),
            _buildChartCard('Availability', _buildBarChart(stats)),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle('Top Locations'),
          const SizedBox(height: 16),
          _buildLocationList(properties),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSummaryGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Users', stats['totalUsers'].toString(), Icons.people, Colors.blue),
        _buildStatCard('Properties', stats['totalProperties'].toString(), Icons.business, Colors.purple),
        _buildStatCard('Available', stats['availableProperties'].toString(), Icons.check_circle, Colors.green),
        _buildStatCard('Rented', stats['rentedProperties'].toString(), Icons.key, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(List<dynamic> properties) {
    final Map<String, int> typeCounts = {};
    for (var p in properties) {
      final type = p.type ?? 'Other';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    final List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.cyan];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: typeCounts.entries.indexed.map((entry) {
          final index = entry.$1;
          final val = entry.$2;
          return PieChartSectionData(
            color: colors[index % colors.length],
            value: val.value.toDouble(),
            title: val.key,
            radius: 50,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> stats) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: stats['totalProperties'].toDouble(),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: stats['availableProperties'].toDouble(), color: Colors.green)]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: stats['rentedProperties'].toDouble(), color: Colors.orange)]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('Avail');
                if (value == 1) return const Text('Taken');
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _buildLocationList(List<dynamic> properties) {
    final Map<String, int> locationCounts = {};
    for (var p in properties) {
      final loc = p.location ?? 'Unknown';
      locationCounts[loc] = (locationCounts[loc] ?? 0) + 1;
    }

    final sortedLocs = locationCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedLocs.length > 5 ? 5 : sortedLocs.length,
      itemBuilder: (context, index) {
        final loc = sortedLocs[index];
        return ListTile(
          leading: CircleAvatar(backgroundColor: AppTheme.primaryRed.withOpacity(0.1), child: Text('${index + 1}')),
          title: Text(loc.key),
          trailing: Text('${loc.value} Properties', style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}
