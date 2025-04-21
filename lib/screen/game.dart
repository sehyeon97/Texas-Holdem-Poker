import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:street_fighter/logic/hand.dart';
import 'package:street_fighter/logic/tiebreaker.dart';
import 'package:street_fighter/models/card.dart';
import 'package:street_fighter/models/commands.dart';
import 'package:street_fighter/logic/dealer.dart';
import 'package:street_fighter/models/rank.dart';
import 'package:street_fighter/ui/player_info.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _GameScreenState();
  }
}

class _GameScreenState extends State<GameScreen> {
  // the Dealer object deals with game logic
  // PlayerInfo class deals with game UI but only those relevant to player(s)
  late final Dealer dealer;

  // the name of player that is currently allowed to make a move
  String nameOfPlayer = "Sehyeon";

  // player's recent command
  final Map<String, String> playerRecentCommands = {
    "Sehyeon": "",
    "Nathan": "",
  };

  // most recent 2 events to display on logs
  final List<String> twoMostRecentEvents = ["", ""];

  // fixed size to two players currently
  // only when both players made move (set to true),
  // the round is complete and incremented by 1
  // this also decides if p2 needs to go again if p1 raised and vice versa
  final List<bool> playerMadeMove = [false, false];
  int round = 1;
  final int finalRound = 4;

  // after each end of round, instead of showing whose turn it is,
  // it will show "round ends in $secondsLeft"
  bool showNextRoundCountdown = false;
  int secondsLeft = 5;
  Timer? _timer;

  // during round countdowns, touch screen should be disabled
  bool touchDisabled = false;

  // TODO: THIS IS A DUMMY WAY TO RESTART
  // in the future, each M5 (each player) will need to send data notifying
  // the server they are ready for next match
  // once all players are ready, next match should begin
  bool showRestartButton = false;
  ElevatedButton restartButton({required void Function() onRestart}) =>
      ElevatedButton(
        onPressed: () {
          onRestart();
        },
        child: const Text("Restart"),
      );

  void displayRestartButton() {
    setState(() {
      showRestartButton = true;
    });
  }

  void hideRestartButton() {
    setState(() {
      showRestartButton = false;
    });
  }
  // TODO: END OF DUMMY WAY TO RESTART

  // Initially we create an instance of Dealer
  // Draw two cards each for each player (this will be displayed on screen)
  // Draw 3 cards for dealer (this will NOT be displayed on screen initially)
  @override
  void initState() {
    super.initState();
    dealer = Dealer();
    dealer.assignAllPlayerCards(["Sehyeon", "Nathan"]);
    dealer.drawThreeCommunityCards();
  }

  // updates the UI to show the name of player that is making the NEXT move
  // updates CURRENT player's chat bubble to their recent move name
  // unless they folded already for this round
  void _updateTable(String command) {
    setState(() {
      // if player has not folded, change the command that appears @chat bubble
      if (playerRecentCommands[nameOfPlayer] != "Fold") {
        playerRecentCommands[nameOfPlayer] = command;
      }

      if (nameOfPlayer == "Sehyeon") {
        nameOfPlayer = "Nathan";
      } else {
        nameOfPlayer = "Sehyeon";
      }
    });
  }

  // increment round by 1 and dealer draws a card
  // players need to make moves again so reset madeMove to false
  // start a countdown until next round
  void _nextRound() {
    setState(() {
      round += 1;
      if (round > 2) {
        dealer.table.incrementRound();
        dealer.table.addCommunityCard(dealer.deck.drawCard());
      }
      playerMadeMove[0] = false;
      playerMadeMove[1] = false;

      showNextRoundCountdown = true;
      secondsLeft = 3;
    });
    startTimer();
    updateLogs("Round ${round - 1} is ending...");
  }

  void _updateTurns({
    required bool playerOneMadeTurn,
    required bool playerTwoMadeTurn,
  }) {
    setState(() {
      playerMadeMove[0] = playerOneMadeTurn;
      playerMadeMove[1] = playerTwoMadeTurn;
    });
  }

  // UI is updated for 3 seconds and each second shows the user
  // 'round ends in: x' where x = second(s)
  // after the countdown reaches 0, its properties are reset and
  // all player's recent commands are reset to blank
  void startTimer() {
    disableTouch();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (secondsLeft <= 0) {
        timer.cancel();
        // reset for next end of round
        setState(() {
          showNextRoundCountdown = false;
          secondsLeft = 3;

          playerRecentCommands["Sehyeon"] = "";
          playerRecentCommands["Nathan"] = "";

          dealer.updateCallAmount(5);
          updateLogs("Round $round has begun.");
          enableTouch();
        });
      } else {
        setState(() {
          secondsLeft--;
        });
      }
    });
  }

  void showTimer() {
    setState(() {
      showNextRoundCountdown = true;
    });
  }

  void updateLogs(String mostRecentEvent) {
    setState(() {
      twoMostRecentEvents[0] = twoMostRecentEvents[1];
      twoMostRecentEvents[1] = mostRecentEvent;
    });
  }

  void endMatch(List<DeckCard> d, List<DeckCard> p1, List<DeckCard> p2) {
    List<DeckCard> p1Combo = [];
    p1Combo.addAll(d);
    p1Combo.addAll(p1);

    List<DeckCard> p2Combo = [];
    p2Combo.addAll(d);
    p2Combo.addAll(p2);

    Hand p1Hand = Hand(cards: p1Combo);
    Hand p2Hand = Hand(cards: p2Combo);

    p1Hand.sortByValue();
    p2Hand.sortByValue();

    Rank p1Rank = p1Hand.getHandRank();
    Rank p2Rank = p2Hand.getHandRank();

    String winnerMessage = "";
    String winner = "";
    int winAmount = 0;

    // TODO: implement tie breaker
    if (p1Rank == p2Rank) {
      Tiebreaker tiebreaker = Tiebreaker(
        dealerCards: d,
        playerOneCards: p1,
        playerTwoCards: p2,
        tiedRank: p1Rank,
      );
      // 0 = tie, 1 = p1 wins, 2 = p2 wins
      int tiedValue = tiebreaker.tiebreak();
      bool isTie = false;
      if (tiedValue == 1) {
        winner = "Sehyeon";
        winnerMessage = "There was a tie, but Sehyeon comes out the winner";
        winAmount = int.parse(dealer.getTableAmount());
      } else if (tiedValue == 2) {
        winner = "Nathan";
        winnerMessage = "There was a tie, but Nathan comes out the winner";
        winAmount = int.parse(dealer.getTableAmount());
      } else {
        winnerMessage = "Sehyeon and Nathan ties. Split table amount";
        winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
        isTie = true;
      }

      if (isTie) {
        setState(() {
          updateLogs(winnerMessage);
          dealer.addAmountToPlayer("Sehyeon", winAmount);
          dealer.addAmountToPlayer("Nathan", winAmount);
        });
      } else {
        setState(() {
          updateLogs(winnerMessage);
          dealer.addAmountToPlayer(winner, winAmount);
        });
      }
    } else {
      int p1RankNumber = _translateHandRankToValue(p1Rank);
      int p2RankNumber = _translateHandRankToValue(p2Rank);

      // lowest number wins
      int min = math.min(p1RankNumber, p2RankNumber);
      if (min == p1RankNumber) {
        winnerMessage = "Sehyeon wins with ${p1Rank.toString()}";
        winner = "Sehyeon";
      } else {
        winnerMessage = "Nathan wins with ${p2Rank.toString()}";
        winner = "Nathan";
      }
      winAmount = int.parse(dealer.getTableAmount());
      setState(() {
        updateLogs(winnerMessage);
        dealer.addAmountToPlayer(winner, winAmount);
      });
    }

    // this should only be processed when there's a tie
    // but for testing purposes, there is no if statement to check tie
    List<DeckCard> p1BestHand = p1Hand.getBestHandBasedOnHandRank(p1Rank);
    List<DeckCard> p2BestHand = p2Hand.getBestHandBasedOnHandRank(p2Rank);

    // TODO: jk not todo, highlighted for DEBUG
    print("\nprinting player 1's cards");
    for (int i = 0; i < p1BestHand.length; i++) {
      String suit = p1BestHand[i].playingCard.suit.toString();
      String cardValue = p1BestHand[i].playingCard.value.toString();
      print('$i: $cardValue of $suit');
    }

    print("\nprinting player 2's cards");
    for (int i = 0; i < p2BestHand.length; i++) {
      String suit = p2BestHand[i].playingCard.suit.toString();
      String cardValue = p2BestHand[i].playingCard.value.toString();
      print('$i: $cardValue of $suit');
    }
    print("\n");
  }

  // translates hand ranks to a value for comparison
  int _translateHandRankToValue(Rank rank) {
    int translatedRankValue;
    switch (rank) {
      case Rank.royalFlush:
        translatedRankValue = 1;
        break;
      case Rank.straightFlush:
        translatedRankValue = 2;
        break;
      case Rank.fourOfAKind:
        translatedRankValue = 3;
        break;
      case Rank.fullHouse:
        translatedRankValue = 4;
        break;
      case Rank.flush:
        translatedRankValue = 5;
        break;
      case Rank.straight:
        translatedRankValue = 6;
        break;
      case Rank.threeOfAKind:
        translatedRankValue = 7;
        break;
      case Rank.twoPair:
        translatedRankValue = 8;
        break;
      case Rank.onePair:
        translatedRankValue = 9;
        break;
      case Rank.highCard:
        translatedRankValue = 10;
        break;
    }
    return translatedRankValue;
  }

  void reset() {
    hideRestartButton();
    setState(() {
      showNextRoundCountdown = false;
      secondsLeft = 5;
      dealer.reset();
      playerMadeMove[0] = false;
      playerMadeMove[1] = false;
      round = 1;
      nameOfPlayer = "Sehyeon";
      playerRecentCommands["Sehyeon"] = "";
      playerRecentCommands["Nathan"] = "";
      startTimer();
    });
  }

  void enableTouch() {
    setState(() {
      touchDisabled = false;
    });
  }

  void disableTouch() {
    setState(() {
      touchDisabled = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topCenter = MediaQuery.of(context).size.height * 0.45;
    final double leftCenter = MediaQuery.of(context).size.width * 0.5;

    List<DeckCard> dealerCards = dealer.table.getCards();
    List<DeckCard> myCards = dealer.getPlayerCards("Sehyeon");
    List<DeckCard> yourCards = dealer.getPlayerCards("Nathan");
    List<int> allPlayerAmountOwned = dealer.getAllPlayerAmountOwned();

    // both players made move this round
    if (playerMadeMove[0] && playerMadeMove[1]) {
      // all rounds are complete, match has ended
      if (round == finalRound) {
        // TODO: DUMMY WAY TO RESTART CALL
        if (!showRestartButton) {
          endMatch(dealerCards, myCards, yourCards);
          displayRestartButton(); // sets it to true
        }
        // reset(); // originally just this line
      } else {
        showTimer();
        _nextRound();
      }
    }

    // Wrapping a widget with AbsorbPointer allows you to set an absorbing prop
    // The absorbing property enables touch screen if false,
    // and disables touch screen if true
    return SafeArea(
      // Draw Table
      child: AbsorbPointer(
        absorbing: touchDisabled,
        child: Container(
          color: Colors.green, // table color
          // the things we need to draw on the table
          child: SingleChildScrollView(
            child: SizedBox(
              // defines the height of how far the screen can scroll down by
              height: 500,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Positioned>[
                  // Table total bet amount for current round positioned top mid
                  Positioned(
                    top: topCenter * 0.5,
                    left: leftCenter * 0.94,
                    child: Text(
                      dealer.getTableAmount(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Player one is positioned top left
                  Positioned(
                    top: 0,
                    left: leftCenter * 0.02,
                    child: PlayerInfo(
                      name: "Sehyeon",
                      card1: myCards[0],
                      card2: myCards[1],
                      amount: allPlayerAmountOwned[0],
                      recentCommand: playerRecentCommands["Sehyeon"]!,
                      raiseAmount: playerRecentCommands["Sehyeon"] == "Raise"
                          ? "50"
                          : "",
                      showDetails: false,
                    ),
                  ),
                  // Player two is positioned top right
                  Positioned(
                    top: 0,
                    left: (leftCenter * 2) * 0.82,
                    child: PlayerInfo(
                      name: "Nathan",
                      card1: yourCards[0],
                      card2: yourCards[1],
                      amount: allPlayerAmountOwned[1],
                      recentCommand: playerRecentCommands["Nathan"]!,
                      raiseAmount:
                          playerRecentCommands["Nathan"] == "Raise" ? "50" : "",
                      showDetails: true,
                    ),
                  ),
                  // shows what round it is
                  Positioned(
                    top: topCenter * 0.2,
                    left: leftCenter * 0.91,
                    child: Text(
                      'Round $round',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  // shows which player's turn it is, center of table (not screen)
                  Positioned(
                    top: topCenter * 0.35,
                    left: leftCenter * 0.84,
                    child: Text(
                      showNextRoundCountdown
                          ? 'Ending round in: ${secondsLeft.toString()}'
                          : '$nameOfPlayer\'s turn',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  // draws dealer cards to screen
                  Positioned(
                    top: topCenter * 0.7,
                    left: leftCenter * 0.56,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // dealer cards should not be shown in round 1
                          if (round > 1) dealerCards[0].getCard(),
                          if (round > 1) dealerCards[1].getCard(),
                          if (round > 1) dealerCards[2].getCard(),
                          if (round > 1) dealerCards[3].getCard(),
                          if (round > 1) dealerCards[4].getCard(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: topCenter * 1.3,
                    left: leftCenter * 0.93,
                    child: const Text(
                      "Logs",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  // shows logs of top 2 most recent moves made by players
                  // (2 lines total)
                  Positioned(
                    top: topCenter * 1.5,
                    left: leftCenter * 0.485,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 60,
                      color: const Color.fromARGB(255, 11, 151, 51),
                      child: Column(
                        children: [
                          Text(
                            twoMostRecentEvents[0],
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            twoMostRecentEvents[1],
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // TODO: DUMMY WAY OF RESTART WIDGET BEGIN LINE
                  if (showRestartButton)
                    Positioned(
                      top: topCenter * 1.5,
                      left: leftCenter * 0.1,
                      child: restartButton(onRestart: reset),
                    ),
                  // TODO: DUMMY WAY OF RESTART WIDGET END LINE
                  // TODO: Anything below this point is
                  // TODO: purely for testing without any M5s or bluetooth
                  if (!showRestartButton)
                    Positioned(
                      top: topCenter * 2,
                      left: leftCenter * 0.79,
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: GridView.builder(
                          shrinkWrap: true,
                          itemCount: 4,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                2, // The number of columns in the grid
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            // Create a GridTile for each item at the given index
                            final List<String> commands = [
                              "Fold",
                              "Check",
                              "Call",
                              "Raise",
                            ];
                            return GridTile(
                              // button selection for fold, check, call, raise
                              child: TextButton(
                                onPressed: () {
                                  late Commands command;
                                  switch (commands[index]) {
                                    case "Fold":
                                      command = Commands.fold;
                                      break;
                                    case "Check":
                                      command = Commands.check;
                                      break;
                                    case "Call":
                                      command = Commands.call;
                                      break;
                                    case "Raise":
                                      command = Commands.raise;
                                      dealer.updateCallAmount(50);
                                      break;
                                  }

                                  // update player amount owned based on
                                  // their button selection above
                                  int playerNumber = 0;
                                  if (nameOfPlayer == "Sehyeon") {
                                    playerNumber = 0;
                                  } else {
                                    playerNumber = 1;
                                  }
                                  if (command == Commands.raise) {
                                    dealer.updateAmounts(
                                      playerNumber: playerNumber,
                                      command: command,
                                      raisedAmount: 50,
                                    );
                                  } else {
                                    dealer.updateAmounts(
                                      playerNumber: playerNumber,
                                      command: command,
                                    );
                                  }

                                  // Raise, current player made move,
                                  // other player needs to make move again
                                  if (command == Commands.raise) {
                                    if (nameOfPlayer == "Sehyeon") {
                                      _updateTurns(
                                        playerOneMadeTurn: true,
                                        playerTwoMadeTurn: false,
                                      );
                                    } else {
                                      _updateTurns(
                                        playerOneMadeTurn: false,
                                        playerTwoMadeTurn: true,
                                      );
                                    }
                                  } else {
                                    // Fold, check, call
                                    if (nameOfPlayer == "Sehyeon") {
                                      _updateTurns(
                                        playerOneMadeTurn: true,
                                        playerTwoMadeTurn: playerMadeMove[1],
                                      );
                                    } else {
                                      _updateTurns(
                                        playerOneMadeTurn: playerMadeMove[0],
                                        playerTwoMadeTurn: true,
                                      );
                                    }
                                  }
                                  updateLogs(
                                      "$nameOfPlayer ${commands[index]}s");
                                  _updateTable(commands[index]);
                                },
                                child: Text(commands[index]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
