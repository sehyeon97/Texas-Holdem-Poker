import 'package:street_fighter/models/card.dart';

class Player {
  Player({
    required this.name,
    required this.amountOwned,
    required this.card1,
    required this.card2,
  });

  final String name;
  int amountOwned;
  DeckCard card1;
  DeckCard card2;

  void addAmount(int amount) {
    amountOwned += amount;
  }

  // Returns the amount removed from Player
  int removeAmount(int amount) {
    int attemptedAmount = amountOwned - amount;
    if (attemptedAmount < 0) {
      amount = amountOwned;
      amountOwned = 0;
    } else {
      amountOwned = attemptedAmount;
    }
    return amount;
  }
}
