import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

class DeckCard {
  DeckCard({
    required this.playingCard,
    required this.showBack,
  });

  final PlayingCard playingCard;
  final bool showBack;

  // used for drawing this card to the screen
  Widget getCard() {
    return PlayingCardView(
      card: playingCard,
      showBack: showBack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
    );
    //   if (facingUp) {
    //     return PlayingCardView(
    //       card: playingCard,
    //       showBack: false,
    //       shape: RoundedRectangleBorder(
    //         borderRadius: BorderRadius.circular(0),
    //       ),
    //     );
    //   }

    //   return PlayingCardView(
    //     card: PlayingCard(
    //       Suit.joker,
    //       CardValue.joker_1,
    //     ),
    //     showBack: true,
    //     shape: RoundedRectangleBorder(
    //       borderRadius: BorderRadius.circular(0),
    //     ),
    //   );
    // }
  }
}
