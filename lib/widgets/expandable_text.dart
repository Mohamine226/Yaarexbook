import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Texte limité à [maxLines] lignes. Quand il est plus long, « Voir plus » est
/// placé à droite de la dernière ligne visible ; une fois déplié, « Voir moins »
/// s'affiche à droite sous le texte.
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  /// Hauteur maximale du texte déplié (au-delà, il défile). Null = illimitée.
  final double? maxExpandedHeight;

  const ExpandableText(
      this.text, {
        super.key,
        this.maxLines = 2,
        this.style,
        this.maxExpandedHeight,
      });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = () => setState(() => _expanded = !_expanded);

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = base.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    );
    final dir = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        bool fits(InlineSpan span) {
          final p = TextPainter(text: span, maxLines: widget.maxLines, textDirection: dir)
            ..layout(maxWidth: width);
          return !p.didExceedMaxLines;
        }

        // Le texte tient dans la limite : rien à ajouter.
        if (fits(TextSpan(text: widget.text, style: base))) {
          return Text(widget.text, style: base);
        }

        if (_expanded) {
          Widget body = Text(widget.text, style: base);
          if (widget.maxExpandedHeight != null) {
            body = ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxExpandedHeight!),
              child: SingleChildScrollView(child: body),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              body,
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Voir moins', style: linkStyle),
                  ),
                ),
              ),
            ],
          );
        }

        // Replié : on cherche le plus long début de texte qui laisse la place à « … Voir plus ».
        InlineSpan candidate(String prefix) => TextSpan(
          style: base,
          children: [
            TextSpan(text: '${prefix.trimRight()}… '),
            TextSpan(text: 'Voir plus', style: linkStyle),
          ],
        );

        var lo = 0;
        var hi = widget.text.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) ~/ 2;
          if (fits(candidate(widget.text.substring(0, mid)))) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        final prefix = widget.text.substring(0, lo).trimRight();

        return Text.rich(
          TextSpan(
            style: base,
            children: [
              TextSpan(text: '$prefix… '),
              TextSpan(text: 'Voir plus', style: linkStyle, recognizer: _tap),
            ],
          ),
          maxLines: widget.maxLines,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}