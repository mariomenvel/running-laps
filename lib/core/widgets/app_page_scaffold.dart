import 'package:flutter/material.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.header,
    required this.body,
    this.footer,
  });

  final Widget header;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: body,
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}
