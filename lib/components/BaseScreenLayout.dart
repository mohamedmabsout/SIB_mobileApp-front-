import 'package:flutter/material.dart';

class BaseScreenLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const BaseScreenLayout({
    Key? key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
