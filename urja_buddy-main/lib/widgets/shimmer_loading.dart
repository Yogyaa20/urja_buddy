import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/urja_theme.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: UrjaTheme.glassBorder.withValues(alpha: 0.1),
      highlightColor: UrjaTheme.glassBorder.withValues(alpha: 0.3),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Shimmer
          const ShimmerLoading(width: double.infinity, height: 100),
          const SizedBox(height: 32),
          
          // Cards Shimmer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: const [
                    ShimmerLoading(width: double.infinity, height: 250),
                    SizedBox(height: 32),
                    ShimmerLoading(width: double.infinity, height: 300),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 2,
                child: Column(
                  children: const [
                    ShimmerLoading(width: double.infinity, height: 150),
                    SizedBox(height: 32),
                    ShimmerLoading(width: double.infinity, height: 200),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
