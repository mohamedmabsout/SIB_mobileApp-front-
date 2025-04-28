// lib/components/dashboard_card.dart
import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value; // Added value parameter
  final IconData icon;
  final Color startColor; // Gradient start color
  final Color endColor;   // Gradient end color
  final VoidCallback? onTap;

  const DashboardCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.startColor,
    required this.endColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5, // Slightly more elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias, // Clip gradient and InkWell
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [ // Subtle shadow inside the card
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space elements
              crossAxisAlignment: CrossAxisAlignment.start,     // Align text left
              children: [
                // Icon top right
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(icon, size: 34, color: Colors.white.withOpacity(0.9)),
                ),
                // Value and Title bottom left
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox( // Scale down large numbers
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 28, // Prominent value
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.2,
                      ),
                      maxLines: 2, // Allow title to wrap
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}