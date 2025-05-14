import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class KpiBarChart extends StatelessWidget {
  final int finishedTasks;
  final int activeProjects;
  final int workingDays;

  KpiBarChart({
    required this.finishedTasks,
    required this.activeProjects,
    required this.workingDays,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(toY: finishedTasks.toDouble(), color: Colors.green),
            ],
            showingTooltipIndicators: [0],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(toY: activeProjects.toDouble(), color: Colors.orange),
            ],
            showingTooltipIndicators: [0],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(toY: workingDays.toDouble(), color: Colors.blue),
            ],
            showingTooltipIndicators: [0],
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, _) {
              switch (value.toInt()) {
                case 0:
                  return Text('Tâches');
                case 1:
                  return Text('Projets');
                case 2:
                  return Text('Jours');
                default:
                  return Text('');
              }
            }),
          ),
        ),
      ),
    );
  }
}
