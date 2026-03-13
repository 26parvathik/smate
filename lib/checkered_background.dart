import 'package:flutter/material.dart';

class CheckeredBackground extends StatelessWidget {
  final Widget child;

  const CheckeredBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const darkTile = Color(0xFF0B1220);
    const lightTile = Color(0xFF0F172A);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {

                const int columns = 12;
                final double tileSize = constraints.maxWidth / columns;
                final int rows =
                    (constraints.maxHeight / tileSize).ceil();

                return Column(
                  children: List.generate(rows, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(columns, (col) {
                          final bool isDark = (row + col) % 2 == 0;

                          return Expanded(
                            child: Container(
                              color: isDark ? darkTile : lightTile,
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}