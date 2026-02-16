import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import 'dart:math' as dart_math;
import '../theme/urja_theme.dart';

// 1. Reusable Glass Card Component
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child, this.padding, this.onTap});

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Determine gradient colors based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Gradient Logic: 
    // Dark Mode: Transparent -> Black/Dark
    // Light Mode: White/Grey -> White (Subtle inner shadow)
    
    // final gradientColors = isDark 
    //   ? [Colors.white.withValues(alpha: 0.05), Colors.transparent]
    //   : [Colors.black.withValues(alpha: 0.03), Colors.transparent];

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: isDark ? 0.2 : 0.8), width: 1),
        // Inner Gradient Effect via Gradient Box Decoration
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [Colors.white.withValues(alpha: 0.05), Colors.transparent]
              : [const Color(0xFFF1F5F9), const Color(0xFFFFFFFF)], // Greyish-White -> White
          stops: const [0.0, 0.4],
        ),
        boxShadow: _isHovered
            ? [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ]
            : [
              // Subtle shadow for light mode depth
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(24),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    } else {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: content,
      );
    }
  }
}

// 2. Updated Metric Card
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subValue;
  final bool isPositive;
  final IconData icon;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subValue,
    required this.isPositive,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: SizedBox(
        height: 140, // Fixed height for consistency
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
              ],
            ),
            // Centered Value
            Expanded(
              child: Center(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. Consumption Trend Chart (Line Chart with Gradient)
class ConsumptionTrendChart extends StatefulWidget {
  final List<double> weeklyData;
  final List<double>? monthlyData; 
  final List<double>? yearlyData;
  final double? todayTotalOverride; // New parameter to force today's total

  const ConsumptionTrendChart({
    super.key, 
    required this.weeklyData, 
    this.monthlyData,
    this.yearlyData,
    this.todayTotalOverride,
  });

  @override
  State<ConsumptionTrendChart> createState() => _ConsumptionTrendChartState();
}

class _ConsumptionTrendChartState extends State<ConsumptionTrendChart> {
  String _selectedPeriod = 'Weekly';

  @override
  Widget build(BuildContext context) {
    // Determine which data to show
    final isMonthly = _selectedPeriod == 'Monthly';
    final isYearly = _selectedPeriod == 'Yearly';
    
    // Create a mutable copy of the data
    List<double> currentData = isYearly 
        ? List.from(widget.yearlyData ?? [])
        : isMonthly 
            ? List.from(widget.monthlyData ?? []) 
            : List.from(widget.weeklyData);

    // FIX: Update today's usage in Monthly/Yearly views if needed
    if (!isMonthly && !isYearly && widget.todayTotalOverride != null && currentData.isNotEmpty) {
       // Find today's index (0=Mon ... 6=Sun)
       final todayIndex = DateTime.now().weekday - 1;
       if (todayIndex >= 0 && todayIndex < currentData.length) {
         currentData[todayIndex] = widget.todayTotalOverride!;
       }
    } else if (isMonthly && widget.todayTotalOverride != null && currentData.isNotEmpty) {
       final currentMonthIndex = DateTime.now().month - 1;
       if (currentMonthIndex >= 0 && currentMonthIndex < currentData.length) {
          // If the aggregated monthly total is LESS than today's usage (which is impossible unless data is missing),
          // update it to at least match today's usage.
          if (currentData[currentMonthIndex] < widget.todayTotalOverride!) {
             currentData[currentMonthIndex] = widget.todayTotalOverride!; 
          }
       }
    } else if (isYearly && widget.todayTotalOverride != null && currentData.isNotEmpty) {
       // Current year is the last index (4)
       if (currentData.last < widget.todayTotalOverride!) {
          currentData[currentData.length - 1] = widget.todayTotalOverride!;
       }
    }
    
    // Safety check: ensure we have data or default to zeros
    final displayData = currentData.isEmpty 
        ? List.filled(isYearly ? 5 : (isMonthly ? 12 : 7), 0.0) 
        : currentData;

    final maxX = (isYearly ? 4 : (isMonthly ? 11 : 6)).toDouble();

    // Dynamic Y max based on data peak + padding
    final maxValue = displayData.reduce((curr, next) => curr > next ? curr : next);
    // Ensure min Y is at least 20 or 1.5x of today's usage to prevent flat lines
    final minMaxY = (widget.todayTotalOverride ?? 0) * 1.5;
    final calculatedMaxY = maxValue * 1.2;
    final maxY = (calculatedMaxY > minMaxY ? calculatedMaxY : minMaxY).clamp(20.0, 50000.0);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Consumption Trend', style: Theme.of(context).textTheme.titleLarge),
              Row(
                children: ['Weekly', 'Monthly', 'Yearly'].map((period) {
                  final isSelected = _selectedPeriod == period;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = period),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        period,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: displayData.every((e) => e == 0)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.query_stats, size: 48, color: UrjaTheme.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedPeriod.toLowerCase()} consumption data',
                          style: const TextStyle(color: UrjaTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              String label = 'Daily';
                              if (isMonthly) label = 'Total Monthly';
                              if (isYearly) label = 'Total Yearly';
                              
                              return LineTooltipItem(
                                '$label: ${touchedSpot.y.toStringAsFixed(1)} kWh',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              const style = TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold);
                              if (isYearly) {
                                final currentYear = DateTime.now().year;
                                final years = List.generate(5, (index) => (currentYear - 4) + index);
                                if (value.toInt() >= 0 && value.toInt() < years.length) {
                                   return Padding(padding: const EdgeInsets.only(top: 8), child: Text(years[value.toInt()].toString(), style: style));
                                }
                              } else if (isMonthly) {
                                 const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                 if (value.toInt() >= 0 && value.toInt() < months.length) {
                                   return Padding(padding: const EdgeInsets.only(top: 8), child: Text(months[value.toInt()], style: style));
                                 }
                              } else {
                                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                if (value.toInt() >= 0 && value.toInt() < days.length) {
                                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(days[value.toInt()], style: style));
                                }
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: maxY / 5, 
                            reservedSize: 40, 
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const Text(''); 
                              return Text(
                                value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toInt().toString(),
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: displayData
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: const Color(0xFF39FF14), // Neon Green
                          barWidth: 4,
                          isStrokeCapRound: true,
                          shadow: const Shadow(color: Color(0xFF39FF14), blurRadius: 10),
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) {
                              return spot.x == displayData.length - 1;
                            },
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: const Color(0xFF39FF14),
                                strokeWidth: 3,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF39FF14).withValues(alpha: 0.3),
                                const Color(0xFF39FF14).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// 4. Consumption Breakdown (Donut Chart)
class ConsumptionBreakdownChart extends StatefulWidget {
  final List<dynamic>? appliances;

  const ConsumptionBreakdownChart({super.key, this.appliances});

  @override
  State<ConsumptionBreakdownChart> createState() => _ConsumptionBreakdownChartState();
}

class _ConsumptionBreakdownChartState extends State<ConsumptionBreakdownChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.appliances == null || widget.appliances!.isEmpty) {
      return _buildEmptyState(context);
    }

    // 1. Process Data
    double totalUsage = 0;
    final List<Map<String, dynamic>> dataPoints = [];
    
    // Extended Color Palette
    final List<Color> colors = [
      const Color(0xFF10B981), // Green (Fan)
      const Color(0xFFA855F7), // Purple (AC)
      const Color(0xFFF59E0B), // Orange (Dryer)
      const Color(0xFF0EA5E9), // Sky Blue
      const Color(0xFFEC4899), // Pink
      const Color(0xFFEF4444), // Red
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Violet
    ];

    for (int i = 0; i < widget.appliances!.length; i++) {
      var app = widget.appliances![i];
      double monthlyKwh = (app.wattage * app.hoursPerDay * 30) / 1000;
      totalUsage += monthlyKwh;
      
      dataPoints.add({
        'value': monthlyKwh,
        'name': app.name,
        'color': colors[i % colors.length],
        'index': i,
      });
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Breakdown in kW', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Chart Dimensions
                const double centerRadius = 40;
                const double sectionRadius = 40;
                const double chartRadius = centerRadius + sectionRadius; // 80
                final Offset center = Offset(constraints.maxWidth / 2, 120);

                // 2. Calculate Angles & Positions for Labels & Popups
                double currentAngle = -90; // Start from top
                List<_ChartLabel> labels = [];
                _ChartLabel? activePopupLabel;

                for (int i = 0; i < dataPoints.length; i++) {
                  final data = dataPoints[i];
                  final value = data['value'] as double;
                  final percentage = totalUsage > 0 ? (value / totalUsage) : 0;
                  final sweepAngle = percentage * 360;
                  final midAngle = currentAngle + (sweepAngle / 2);
                  
                  // Create label object
                  final label = _ChartLabel(
                    angle: midAngle,
                    text: '${(percentage * 100).round()}%',
                    subText: data['name'],
                    color: data['color'],
                    value: value,
                  );

                  // Only show static label if percentage > 1% AND not currently selected (optional, or keep both)
                  if (percentage > 0.01) {
                     labels.add(label);
                  }
                  
                  // Identify active popup
                  if (i == _touchedIndex) {
                    activePopupLabel = label;
                  }

                  currentAngle += sweepAngle;
                }

                // 3. Resolve Overlaps for static labels
                _resolveLabelOverlaps(labels, center, chartRadius, constraints.maxWidth);

                // Calculate Popup Position (Reuse logic but with closer radius)
                Offset? popupOffset;
                if (activePopupLabel != null) {
                   final rad = activePopupLabel.angle * (dart_math.pi / 180);
                   // Place popup slightly outside the chart
                   final dist = chartRadius + 10; 
                   popupOffset = Offset(center.dx + dist * dart_math.cos(rad), center.dy + dist * dart_math.sin(rad));
                }

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none, // Allow popup to overflow slightly if needed
                  children: [
                    // A. The Pie Chart
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 2,
                        centerSpaceRadius: centerRadius,
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                               if (event is FlTapUpEvent && _touchedIndex != -1) {
                                 // Clicked outside -> Close
                                 setState(() => _touchedIndex = -1);
                               }
                              return;
                            }
                            
                            if (event is FlTapUpEvent) {
                              final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              setState(() {
                                if (_touchedIndex == touchedIndex) {
                                  _touchedIndex = -1; // Toggle off
                                } else {
                                  _touchedIndex = touchedIndex;
                                }
                              });
                            }
                          },
                        ),
                        sections: dataPoints.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final data = entry.value;
                          final value = data['value'] as double;
                          final isTouched = idx == _touchedIndex;
                          
                          return PieChartSectionData(
                            color: data['color'],
                            value: value,
                            title: '',
                            radius: isTouched ? sectionRadius + 8 : sectionRadius, // Explode effect
                            showTitle: false,
                            borderSide: isTouched 
                                ? BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 2) 
                                : BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // B. Center Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalUsage.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text('kW Total', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),

                    // C. Connector Lines & Labels (Hide connected label if popup is active for that section? No, keep them)
                    CustomPaint(
                      size: Size(constraints.maxWidth, 240),
                      painter: _ConnectorPainter(
                        labels: labels,
                        center: center,
                        radius: chartRadius,
                        lineColor: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    
                    // D. Render Text Labels
                    ...labels.map((label) {
                       return Positioned(
                         left: label.finalOffset.dx - (label.isLeft ? 100 : 0),
                         top: label.finalOffset.dy - 20,
                         width: 100,
                         child: Column(
                           crossAxisAlignment: label.isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                           children: [
                             Text(
                               label.text,
                               style: TextStyle(
                                 color: Theme.of(context).colorScheme.onSurface, 
                                 fontWeight: FontWeight.bold, 
                                 fontSize: 12
                               ),
                             ),
                             Text(
                               label.subText,
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                               style: TextStyle(
                                 color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), 
                                 fontSize: 10
                               ),
                               textAlign: label.isLeft ? TextAlign.right : TextAlign.left,
                             ),
                           ],
                         ),
                       );
                    }),

                    // E. Interactive Pop-up
                    if (_touchedIndex != -1 && popupOffset != null && activePopupLabel != null)
                      Positioned(
                        left: popupOffset.dx - 60, // Center horizontally (width 120)
                        top: popupOffset.dy - 60, // Place above the point
                        child: _buildPopup(context, activePopupLabel.subText, activePopupLabel.text, activePopupLabel.color),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopup(BuildContext context, String name, String percentage, Color color) {
     return Container(
       constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
       decoration: BoxDecoration(
         color: const Color(0xFF1A1A1A).withValues(alpha: 0.8), // #1a1a1a with 80% opacity
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: color, width: 1), // Dynamic border color
       ),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           Text(
             name,
             style: const TextStyle(
               color: Colors.white,
               fontWeight: FontWeight.bold,
               fontSize: 12,
             ),
             textAlign: TextAlign.center,
             maxLines: 1,
             overflow: TextOverflow.ellipsis,
           ),
           Text(
             percentage,
             style: const TextStyle(
               color: Colors.white,
               fontSize: 12,
             ),
             textAlign: TextAlign.center,
           ),
         ],
       ),
     );
   }

  Widget _buildEmptyState(BuildContext context) {
       return GlassCard(
         child: SizedBox(
           height: 300,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Breakdown in kW', style: Theme.of(context).textTheme.titleLarge),
               Expanded(
                 child: Center(
                   child: Stack(
                     alignment: Alignment.center,
                     children: [
                       SizedBox(
                         height: 200,
                         child: PieChart(
                           PieChartData(
                             sectionsSpace: 0,
                             centerSpaceRadius: 40,
                             sections: [
                               PieChartSectionData(
                                 color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                                 value: 100,
                                 title: '',
                                 radius: 50,
                               ),
                             ],
                           ),
                         ),
                       ),
                       Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Icon(Icons.devices_other, size: 24, color: Theme.of(context).disabledColor),
                           const SizedBox(height: 4),
                           Text(
                             'No Appliances\nAdded',
                             textAlign: TextAlign.center,
                             style: Theme.of(context).textTheme.bodySmall,
                           ),
                         ],
                       ),
                     ],
                   ),
                 ),
               ),
             ],
           ),
         ),
       );
   }

   void _resolveLabelOverlaps(List<_ChartLabel> labels, Offset center, double radius, double maxWidth) {
      // Split into Left and Right
      final leftLabels = labels.where((l) => l.isLeft).toList();
      final rightLabels = labels.where((l) => !l.isLeft).toList();
      
      rightLabels.sort((a, b) => a.angle.compareTo(b.angle));
      leftLabels.sort((a, b) => a.angle.compareTo(b.angle)); 
      
      _layoutSide(rightLabels, center, radius, true);
      _layoutSide(leftLabels, center, radius, false);
   }

   void _layoutSide(List<_ChartLabel> sideLabels, Offset center, double radius, bool isRight) {
      if (sideLabels.isEmpty) return;

      // 1. Calculate ideal positions
      for (var label in sideLabels) {
         final rad = label.angle * (dart_math.pi / 180);
         // Base position at distance
         double dist = radius + 30; // Connector length
         // double dx = center.dx + dist * (isRight ? 1 : -1) * (isRight ? 1 : 1).abs(); 
         double py = center.dy + dist * dart_math.sin(rad);
         
         // Force X alignment for neat columns
         double alignX = center.dx + (radius + 40) * (isRight ? 1 : -1);
         
         label.finalOffset = Offset(alignX, py);
         label.anchorOffset = Offset(center.dx + radius * dart_math.cos(rad), center.dy + radius * dart_math.sin(rad));
      }
      
      // 2. Adjust Y to avoid overlap
      sideLabels.sort((a, b) => a.finalOffset.dy.compareTo(b.finalOffset.dy));
      
      const minSpacing = 30.0;
      
      for (int i = 0; i < sideLabels.length - 1; i++) {
         final current = sideLabels[i];
         final next = sideLabels[i + 1];
         
         if (next.finalOffset.dy < current.finalOffset.dy + minSpacing) {
            // Push next down
            double newY = current.finalOffset.dy + minSpacing;
            next.finalOffset = Offset(next.finalOffset.dx, newY);
         }
      }
   }
}

class _ChartLabel {
  final double angle;
  final String text;
  final String subText;
  final Color color;
  final double value;
  
  Offset finalOffset = Offset.zero; // Where text sits
  Offset anchorOffset = Offset.zero; // Where line starts on chart
  
  _ChartLabel({required this.angle, required this.text, required this.subText, required this.color, required this.value});
  
  bool get isLeft {
     // Normalize angle to -180..180 or 0..360
     // We started at -90. 
     // Right: -90..90. Left: 90..270.
     double norm = angle;
     while (norm < -90) {
       norm += 360;
     }
     while (norm >= 270) {
       norm -= 360;
     }
     
     return norm > 90 && norm < 270;
  }
}

class _ConnectorPainter extends CustomPainter {
  final List<_ChartLabel> labels;
  final Offset center;
  final double radius;
  final Color lineColor;

  _ConnectorPainter({required this.labels, required this.center, required this.radius, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var label in labels) {
       // Draw Polyline: Anchor (Chart Edge) -> Elbow -> Text
       // 1. Anchor
       final p1 = label.anchorOffset;
       
       // 3. Text Position (Vertical adjusted)
       // final p3 = Offset(label.finalOffset.dx + (label.isLeft ? 10 : -10), label.finalOffset.dy + 10); // +10 to center text vertically?
       // Actually finalOffset is top-left of text box. Center Y is +10 (approx font height/2).
       
       // 2. Elbow point
       // We want a line that goes out radially then horizontally?
       // Or just straight to the text block?
       // User asked for "Connector Lines (Arrows) ... thin line (polyline)".
       // Polyline usually means 2 segments.
       
       // Let's do: Anchor -> Point aligned with text Y -> Text
       // Point 2 X: halfway? Or just use the adjusted Y with some radial component?
       
       // Simple version:
       // Line from Anchor to (AnchorX + offset, LabelY) -> Label
       
       // double elbowX = label.isLeft ? center.dx - radius - 15 : center.dx + radius + 15;
       // Actually, let's just draw a straight line with a small horizontal tail.
       
       final path = Path();
       path.moveTo(p1.dx, p1.dy);
       
       // Control point or elbow
       // Let's go to the Y level of the text, but keep X somewhat close to chart, then go horizontal.
       // final elbow = Offset(label.isLeft ? p1.dx - 10 : p1.dx + 10, p1.dy);
       // This is just a small radial extension.
       
       // Let's try:
       // P1 (Chart) -> P2 (Radial Out) -> P3 (Horizontal to Text)
       
       // Radial vector
       double rad = label.angle * (3.14159 / 180);
       // Offset p2 = Offset(center.dx + (radius + 10) * dart_math.cos(rad), center.dy + (radius + 10) * dart_math.sin(rad));
       
       // Then to text Y
       // Offset p3 = Offset(p2.dx, label.finalOffset.dy + 10); // Go vertical? No looks bad.
       
       // Standard "Dog-leg":
       // 1. Radial line to OuterRadius + padding
       // 2. Horizontal line to Text
       
       // Let's define p2 at the text's Y level, but constrained X?
       // Hard to do smooth elbow without overlapping lines.
       
       // Fallback: Direct line from Anchor to Text-Side
       // Offset textAnchor = Offset(label.finalOffset.dx + (label.isLeft ? 100 : 0), label.finalOffset.dy + 15);
       // Wait, if label is Left, text starts at finalOffset.dx - 100.
       // So right side of text is finalOffset.dx.
       // If label is Right, text starts at finalOffset.dx.
       // So left side of text is finalOffset.dx.
       
       Offset target = label.isLeft 
          ? Offset(label.finalOffset.dx, label.finalOffset.dy + 10)
          : Offset(label.finalOffset.dx, label.finalOffset.dy + 10);
          
       // Draw
       // path.lineTo(target.dx, target.dy);
       
       // Polyline:
       // 1. Outward 10px
       Offset pOut = Offset(center.dx + (radius + 15) * dart_math.cos(rad), center.dy + (radius + 15) * dart_math.sin(rad));
       path.lineTo(pOut.dx, pOut.dy);
       // 2. To Target
       path.lineTo(target.dx, target.dy);
       
       canvas.drawPath(path, paint);
       
       // Dot at anchor
       canvas.drawCircle(p1, 2, Paint()..color = label.color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 5. Smart Hub Card (Slider)
class SmartHubCard extends StatefulWidget {
  final double currentLimit;
  final double currentUsage;
  final Function(double) onLimitChanged;

  const SmartHubCard({
    super.key,
    required this.currentLimit,
    required this.currentUsage,
    required this.onLimitChanged,
  });

  @override
  State<SmartHubCard> createState() => _SmartHubCardState();
}

class _SmartHubCardState extends State<SmartHubCard> {
  late double _localLimit;

  @override
  void initState() {
    super.initState();
    _localLimit = widget.currentLimit;
  }

  @override
  void didUpdateWidget(covariant SmartHubCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLimit != widget.currentLimit) {
      _localLimit = widget.currentLimit;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Condition 1: If Slider Limit > Current Usage -> Cyan (Safe)
    // Condition 2: If Slider Limit <= Current Usage -> Red (Exceeded)
    final bool isSafe = _localLimit > widget.currentUsage;
    
    // Use standard error color for danger, and Cyan for safe state
    final Color safeColor = Colors.cyan;
    final Color dangerColor = Theme.of(context).colorScheme.error;
    final Color targetColor = isSafe ? safeColor : dangerColor;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KW Limit', style: Theme.of(context).textTheme.titleLarge),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: targetColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: targetColor.withValues(alpha: 0.2)),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    color: targetColor, 
                    fontWeight: FontWeight.bold,
                    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                  ),
                  child: Text('${_localLimit.toInt()} kW'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<Color?>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            tween: ColorTween(begin: safeColor, end: targetColor),
            builder: (context, color, child) {
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  thumbColor: Colors.white,
                  trackHeight: 6,
                  overlayColor: color?.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _localLimit,
                  min: 0,
                  max: 500,
                  onChanged: (val) {
                    setState(() => _localLimit = val);
                  },
                  onChangeEnd: (val) {
                    widget.onLimitChanged(val);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: !isSafe
              ? Row(
                  key: const ValueKey('alert'),
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: dangerColor),
                    const SizedBox(width: 4),
                    Text(
                      'Limit Exceeded! Current: ${widget.currentUsage.toStringAsFixed(1)} kW',
                      style: TextStyle(color: dangerColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : SizedBox(
                  key: const ValueKey('normal'),
                  width: double.infinity,
                  child: Text(
                    'Set your daily consumption limit to receive alerts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// 6. AI Insights Card
class AiInsightsCard extends StatelessWidget {
  final List<dynamic>? appliances; // Accept appliances list

  const AiInsightsCard({super.key, this.appliances});

  @override
  Widget build(BuildContext context) {
    // Conditional Content
    final hasAppliances = appliances != null && appliances!.isNotEmpty;
    
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAppliances ? 'AI Insight' : 'Get Started',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFA855F7),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAppliances 
                      ? 'Reduce HVAC usage by 10% during peak hours to save ₹450/month.'
                      : 'Add your first appliance to get personalized energy-saving tips!',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 7. Leaderboard Card (Right Panel)
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final leaders = [
      {'name': 'Sharma Villa', 'score': '98%', 'rank': 1, 'avatar': 'S'},
      {'name': 'Green House', 'score': '95%', 'rank': 2, 'avatar': 'G'},
      {'name': 'Your Home', 'score': '92%', 'rank': 3, 'avatar': 'Y'},
      {'name': 'Blue Sky', 'score': '88%', 'rank': 4, 'avatar': 'B'},
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neighborhood Leaderboard', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          ...leaders.map((leader) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      child: Text(
                        leader['avatar'] as String,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leader['name'] as String,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: leader['name'] == 'Your Home' ? Theme.of(context).primaryColor : null,
                                ),
                          ),
                          Text(
                            'Rank #${leader['rank']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        leader['score'] as String,
                        style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
