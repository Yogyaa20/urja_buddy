import 'package:flutter/material.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Community',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildCommunityGoalCard(context),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 3,
                      child: _buildSocietyLeaderboardCard(context),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildCommunityGoalCard(context),
                    const SizedBox(height: 32),
                    _buildSocietyLeaderboardCard(context),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityGoalCard(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Community Goal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Monthly savings competition',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          
          // Progress Bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '412 / 500 kWh',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Goal: 500 kWh',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: 412 / 500,
                  backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  color: Theme.of(context).primaryColor,
                  minHeight: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // KPI Grid
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(context, '82%', 'Complete', Icons.pie_chart),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(context, '42', 'Households', Icons.home),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(context, '88', 'kWh to go', Icons.bolt),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Deadline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFF0F2F5) : UrjaTheme.glassBorder.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, color: isLight ? Colors.black54 : UrjaTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Goal deadline: Dec 31, 2024',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isLight ? Colors.black87 : UrjaTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String value, String label, IconData icon) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF0F2F5) : UrjaTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLight ? Colors.black87 : null,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: isLight ? Colors.black54 : null,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSocietyLeaderboardCard(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Green Valley Society Leaderboard', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            separatorBuilder: (context, index) => Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), height: 24),
            itemBuilder: (context, index) {
              final rank = index + 1;
              final isMe = rank == 4; // Your Household - You
              
              // Mock Data
              final names = [
                'The Sharma Family',
                'Green House',
                'Blue Sky',
                'Your Household - You',
                'Mehta Residence',
                'Unit B-402',
                'The Kapoors',
                'Singh Villa'
              ];
              
              final units = [
                'Unit A-101',
                'Unit C-304',
                'Unit B-202',
                'Unit A-105',
                'Unit D-501',
                'Unit B-402',
                'Unit C-102',
                'Unit A-204'
              ];

              final saved = [52.4, 48.1, 46.5, 45.2, 42.0, 38.5, 35.2, 32.1];
              final percents = [24, 21, 19, 18, 16, 14, 12, 10];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: isMe ? BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                ) : null,
                child: Row(
                  children: [
                    // Rank Icon
                    SizedBox(
                      width: 40,
                      child: _buildRankIcon(context, rank),
                    ),
                    const SizedBox(width: 12),
                    
                    // Name & Unit
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            names[index],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMe 
                                  ? Theme.of(context).primaryColor 
                                  : (isLight ? Colors.black87 : UrjaTheme.textPrimary),
                            ),
                          ),
                          Text(
                            units[index],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isLight ? Colors.black54 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Stats
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${saved[index]} kWh',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${percents[index]}% saved',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: isLight ? Colors.black54 : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRankIcon(BuildContext context, int rank) {
    if (rank == 1) {
      return const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28); // Gold
    } else if (rank == 2) {
      return const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 24); // Silver
    } else if (rank == 3) {
      return const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 24); // Bronze
    } else {
      final isLight = Theme.of(context).brightness == Brightness.light;
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$rank',
          style: TextStyle(
            color: isLight ? Colors.black54 : UrjaTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
  }
}
