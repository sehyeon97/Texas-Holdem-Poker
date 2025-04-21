import 'dart:core';

import 'package:playing_cards/playing_cards.dart';

class Deck {
  List<PlayingCard> deck = standardFiftyTwoCardDeck();

  void reset() {
    deck = standardFiftyTwoCardDeck();
  }

  void shuffle() {
    deck.shuffle();
  }

  PlayingCard drawCard() {
    return deck.removeLast();
  }
}
