import 'package:flutter/material.dart';

/// Botón de like con animación de color.
class LikeButton extends StatelessWidget {
  final bool isLiked;
  final int count;
  final VoidCallback onPressed;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isLiked),
                color: isLiked ? Theme.of(context).colorScheme.error : Theme.of(context).hintColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: isLiked ? Theme.of(context).colorScheme.error : Theme.of(context).hintColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
