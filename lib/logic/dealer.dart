// The Dealer is how the server manages Table, Cards (or Deck), and Players
import 'package:playing_cards/playing_cards.dart';
import 'package:street_fighter/models/card.dart';
import 'package:street_fighter/models/commands.dart';
import 'package:street_fighter/models/deck.dart';
import 'package:street_fighter/models/player.dart';
import 'package:street_fighter/models/table.dart';

class Dealer {
  List<Player> players = [];
  Table table = Table();
  Deck deck = Deck();
  final int size = 5;
  int callAmount = 5; // starting call amount
  // none of the players have folded initially
  final List<bool> hasFolded = [false, false];

  // Round 1
  // Players are assigned and given 2 cards each
  void assignAllPlayerCards(List<String> playerNames) {
    deck.shuffle();

    for (int i = 0; i < playerNames.length; i++) {
      players.add(Player(
        name: playerNames[i],
        amountOwned: 1000,
        card1: DeckCard(
          playingCard: deck.drawCard(),
          showBack: false,
        ),
        card2: DeckCard(
          playingCard: deck.drawCard(),
          showBack: false,
        ),
      ));
    }
  }

  // Round 2
  // 3 Community Cards are drawn facing up
  void drawThreeCommunityCards() {
    deck.shuffle();

    List<PlayingCard> threeCards = [];
    for (int i = 0; i < 3; i++) {
      PlayingCard playingCard = deck.drawCard();
      threeCards.add(playingCard);
    }
    table.addFirstThreeCards(threeCards);
  }

  List<DeckCard> getPlayerCards(String playerName) {
    for (Player player in players) {
      if (player.name == playerName) {
        return [
          player.card1,
          player.card2,
        ];
      }
    }

    // player name not found, so return empty list
    return [];
  }

  // returns amounted owned by player
  // empty string as return value indicates no change to any displayed amount
  // raisedAmount must be provided only if command is "Raise"
  String updateAmounts({
    required int playerNumber,
    required Commands command,
    int? raisedAmount,
  }) {
    if (hasFolded[playerNumber]) {
      return "";
    }

    Player player = players[playerNumber];
    switch (command) {
      case Commands.fold:
        hasFolded[playerNumber] = true;
        return "";
      case Commands.check:
        return "";
      case Commands.call:
        int playerCallAmount = player.removeAmount(callAmount);
        String updatedAmounts = playerCallAmount.toString();
        table.addAmount(playerCallAmount);
        return updatedAmounts;
      case Commands.raise:
        int playerRaiseAmount = player.removeAmount(raisedAmount!);
        String updatedAmounts = playerRaiseAmount.toString();
        table.addAmount(playerRaiseAmount);
        return updatedAmounts;
    }
  }

  void addAmountToPlayer(String playerName, int amount) {
    for (Player player in players) {
      if (player.name == playerName) {
        player.addAmount(amount);
        break;
      }
    }
  }

  String getTableAmount() {
    return table.amountOnTable.toString();
  }

  List<int> getAllPlayerAmountOwned() {
    List<int> amounts = [];
    for (int i = 0; i < players.length; i++) {
      amounts.add(players[i].amountOwned);
    }
    return amounts;
  }

  void updateCallAmount(int amount) {
    callAmount = amount;
  }

  void reset() {
    // reset table: clear amount gathered, round to 1, clear dealer cards
    table.reset();

    // reset 52 card deck
    deck.reset();

    // start bid amount reset
    callAmount = 5;

    // replace each player's cards
    for (Player player in players) {
      deck.shuffle(); // for fairness
      player.card1 = DeckCard(
        playingCard: deck.drawCard(),
        showBack: false,
      );
      deck.shuffle();
      player.card2 = DeckCard(
        playingCard: deck.drawCard(),
        showBack: false,
      );
    }

    deck.shuffle();

    // draw 3 cards for dealer
    drawThreeCommunityCards();
  }
}
