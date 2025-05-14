import 'package:flutter/material.dart';

class ReusableDetailCard extends StatelessWidget {
  final List<DetailItem> items;
  final String title;

  const ReusableDetailCard({Key? key, required this.title, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.grey[100],
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items.map((item) {
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(item.icon, color: item.iconColor),
                      title: Text(item.label),
                      subtitle: item.widget ?? Text(item.value ?? ""),
                    ),
                    if (item != items.last) const Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class DetailItem {
  final String label;
  final String? value;
  final Widget? widget;
  final IconData icon;
  final Color iconColor;

  DetailItem({
    required this.label,
    this.value,
    this.widget,
    required this.icon,
    this.iconColor = Colors.black,
  });
}
