import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../application/analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(analyticsSnapshotProvider);

    return Column(
      children: [
        const GlowBanner(icon: Icons.bar_chart_outlined, title: 'التحليلات', subtitle: 'أداء المكتب بلمحة واحدة'),
        Expanded(
          child: RefreshIndicator(
      onRefresh: () async => ref.invalidate(analyticsSnapshotProvider),
      child: snapshotAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'تعذّر تحميل التحليلات', onRetry: () => ref.invalidate(analyticsSnapshotProvider)),
        data: (snap) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: KpiCard(
                label: 'متوسط تقييم العملاء',
                value: snap.averageRating > 0 ? snap.averageRating.toStringAsFixed(1) : '—',
                icon: Icons.star_outline,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(index: 1, child: _ChartCard(title: 'حالات الاستشارات', child: _StatusDonut(data: snap.consultationsByStatus))),
            const SizedBox(height: 20),
            FadeSlideIn(index: 2, child: _ChartCard(title: 'حالات المواعيد', child: _StatusDonut(data: snap.appointmentsByStatus))),
            const SizedBox(height: 20),
            FadeSlideIn(index: 3, child: _ChartCard(title: 'حالات تذاكر الدعم', child: _StatusDonut(data: snap.ticketsByStatus))),
            const SizedBox(height: 20),
            FadeSlideIn(index: 4, child: _ChartCard(title: 'زيارات الموقع (آخر 14 يوماً)', child: _VisitsBarChart(data: snap.visitsByDay))),
            const SizedBox(height: 20),
            FadeSlideIn(index: 5, child: _ChartCard(title: 'ساعات الذروة', child: _PeakHoursChart(data: snap.visitsByHour))),
          ],
        ),
      ),
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 14),
          SizedBox(height: 180, child: child),
        ],
      ),
    );
  }
}

const _statusColors = [AppColors.primary, AppColors.gold, AppColors.success, AppColors.danger, Colors.grey];

class _StatusDonut extends StatelessWidget {
  final Map<String, int> data;
  const _StatusDonut({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.values.every((v) => v == 0)) {
      return const EmptyState(message: 'لا توجد بيانات كافية');
    }
    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (a, b) => a + b.value);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _statusColors[i % _statusColors.length],
                    title: total == 0 ? '' : '${(entries[i].value / total * 100).round()}%',
                    radius: 42,
                    titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: _statusColors[i % _statusColors.length]),
                    const SizedBox(width: 6),
                    Text('${entries[i].key} (${entries[i].value})', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VisitsBarChart extends StatelessWidget {
  final Map<DateTime, int> data;
  const _VisitsBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const EmptyState(message: 'لا توجد زيارات مسجلة');
    final days = data.keys.toList()..sort();
    final maxVal = data.values.fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxVal <= 0 ? 1 : maxVal * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${days[i].day}/${days[i].month}', style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: data[days[i]]!.toDouble(), color: AppColors.primary, width: 10, borderRadius: BorderRadius.circular(3)),
            ]),
        ],
      ),
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  final Map<int, int> data;
  const _PeakHoursChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const EmptyState(message: 'لا توجد بيانات كافية');
    final maxVal = data.values.fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxVal <= 0 ? 1 : maxVal * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 4,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 9)),
            ),
          ),
        ),
        barGroups: [
          for (var h = 0; h < 24; h++)
            BarChartGroupData(x: h, barRods: [
              BarChartRodData(toY: (data[h] ?? 0).toDouble(), color: AppColors.gold, width: 6, borderRadius: BorderRadius.circular(2)),
            ]),
        ],
      ),
    );
  }
}
