import 'package:playing_cards/playing_cards.dart';
import 'package:street_fighter/models/card.dart';

/*
Pre-Flop (The first round of betting):

Each player is dealt two private cards (known as "hole cards") face down.
Players look at their hole cards and the first round of betting begins.

The Flop (Second round):

After the first round of betting, the dealer places
  three community cards face-up in the center of the table.
These are known as the "flop."
Another round of betting occurs.

The Turn (Third round):

After the second round of betting, the dealer places
  one more community card face-up in the center.
This card is called the "turn."
Another round of betting follows.

The River (Fourth round):

After the third round of betting, the dealer places
  one final community card face-up in the center.
This card is called the "river."
The final round of betting takes place.
*/
class Table {
  int amountOnTable = 0;
  List<PlayingCard> cardsOnTable = [];
  int round = 1;
  int dealerCardsSize = 5;

  void addAmount(int amount) {
    amountOnTable += amount;
  }

  void addFirstThreeCards(List<PlayingCard> threeCards) {
    cardsOnTable = threeCards;
  }

  void addCommunityCard(PlayingCard card) {
    cardsOnTable.add(card);
  }

  void reset() {
    cardsOnTable.clear();
    round = 1;
    amountOnTable = 0;
  }

  void incrementRound() {
    round += 1;
  }

  // Will always return either zero or 5 cards
  List<DeckCard> getCards() {
    List<DeckCard> cards = [];

    for (int i = 0; i < cardsOnTable.length; i++) {
      cards.add(DeckCard(playingCard: cardsOnTable[i], showBack: false));
    }

    // Depending on the round, some cards will be facing down
    // This uses dummy cards not part of deck to draw cards facing down
    for (int i = cardsOnTable.length; i < dealerCardsSize; i++) {
      cards.add(
        DeckCard(
          playingCard: PlayingCard(
            Suit.joker,
            CardValue.joker_1,
          ),
          showBack: true,
        ),
      );
    }

    return cards;
  }
}
