import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:street_fighter/models/card.dart';

class PlayerInfo extends StatelessWidget {
  const PlayerInfo({
    super.key,
    required this.name,
    required this.card1,
    required this.card2,
    required this.amount,
    required this.recentCommand,
    required this.raiseAmount,
    required this.showDetails,
  });

  final String name;
  final DeckCard card1;
  final DeckCard card2;
  final int amount;
  final String recentCommand;
  final String raiseAmount;

  // if true, show this player's details on table
  // it will always show their name and amount owned
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // show player's result message only if show details is true
          // TODO: change to result message and remove recent command message
          // if (showDetails) SpeechBubble(text: '$recentCommand $raiseAmount'),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          // player's amount owned
          SizedBox(
            width: 100,
            height: 30,
            child: TextField(
              decoration: InputDecoration(
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  filled: true,
                  fillColor: Colors.redAccent,
                  label: Center(
                    child: Text(
                      '\$${amount.toString()}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  )),
              readOnly: true,
              // Ensure no more than 13 characters
              inputFormatters: [
                LengthLimitingTextInputFormatter(13),
              ],
            ),
          ),
          // players cards are only shown if they swipe up their M5
          if (showDetails)
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  card1.getCard(),
                  card2.getCard(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SpeechBubble extends StatelessWidget {
  final String text;

  const SpeechBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BubblePainter(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(left: 2.5),
        constraints: const BoxConstraints(minWidth: 60, maxWidth: 200),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const borderRadius = 20.0;
    const borderColor = Colors.blue;
    const tailHeight = 10.0;
    const tailWidth = 16.0;

    final bubbleRect =
        Rect.fromLTWH(0, 0, size.width, size.height - tailHeight);

    final rRect = RRect.fromRectAndRadius(
        bubbleRect, const Radius.circular(borderRadius));
    final path = Path()..addRRect(rRect);

    // Tail path
    final tailPath = Path()
      ..moveTo(size.width / 2 - tailWidth / 2, size.height - tailHeight)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 + tailWidth / 2, size.height - tailHeight)
      ..close();

    // Combine bubble + tail
    path.addPath(tailPath, Offset.zero);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
