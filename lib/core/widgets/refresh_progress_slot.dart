import 'package:flutter/material.dart';

/// Reserved 4px slot so refresh indicators do not shift list content.
class RefreshProgressSlot extends StatelessWidget {
  const RefreshProgressSlot({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: active
          ? const LinearProgressIndicator(key: Key('refresh-progress'))
          : null,
    );
  }
}
