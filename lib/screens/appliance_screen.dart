import 'package:flutter/material.dart';
import '../widgets/appliance_manager_card.dart';

class ApplianceScreen extends StatelessWidget {
  const ApplianceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ApplianceManagerCard(),
        ],
      ),
    );
  }
}