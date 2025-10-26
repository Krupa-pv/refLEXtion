import 'package:flutter/material.dart';

class AnimatedStar extends StatelessWidget {
  final bool visible;
  final double size;
  final Duration duration;

  const AnimatedStar({
    Key? key,
    required this.visible,
    this.size = 50,
    this.duration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: duration,
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.0,
        duration: duration,
        child: Icon(
          Icons.star,
          color: Colors.amber,
          size: size,
        ),
      ),
    );
  }
}
