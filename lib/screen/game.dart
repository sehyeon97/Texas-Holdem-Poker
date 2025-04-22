import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:street_fighter/bluetooth/server.dart';
import 'package:street_fighter/logic/hand.dart';
import 'package:street_fighter/logic/tiebreaker.dart';
import 'package:street_fighter/models/card.dart';
import 'package:street_fighter/models/commands.dart';
import 'package:street_fighter/logic/dealer.dart';
import 'package:street_fighter/models/rank.dart';
import 'package:street_fighter/ui/player_info.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.devices,
    required this.sendBet,
    required this.readBet,
    required this.readPlayerVis,
    required this.writeWinner,
    required this.readGameState,
    required this.writeGameState,
    required this.writePlayerCards,
  });

  final List<M5Device> devices;
  final Future<void> Function(
    BluetoothCharacteristic characteristic,
    int bet,
  ) sendBet;
  final Future<int?> Function(BluetoothCharacteristic characteristic) readBet;
  final Future<int?> Function(BluetoothCharacteristic characteristic)
      readPlayerVis;
  final Future<void> Function(
    BluetoothCharacteristic characteristic,
    String winner,
  ) writeWinner;
  final Future<int?> Function(BluetoothCharacteristic characteristic)
      readGameState;
  final Future<void> Function(
    BluetoothCharacteristic characteristic,
    int state,
  ) writeGameState;
  final Future<void> Function(
    BluetoothCharacteristic characteristic,
    String cards,
  ) writePlayerCards;

  @override
  State<StatefulWidget> createState() {
    return _GameScreenState();
  }
}

class _GameScreenState extends State<GameScreen> {
  // the Dealer object deals with game logic
  // PlayerInfo class deals with game UI but only those relevant to player(s)
  late final Dealer dealer;

  // player's recent command
  final Map<String, String> playerRecentCommands = {
    "nsdevries": "", // P1
    "sehyeoo": "", // P2
    "DrDan": "", // P3
    "Player4": "", // P4
  };

  // most recent 2 events to display on logs
  final List<String> twoMostRecentEvents = ["", ""];

  // fixed size to two players currently
  // only when both players made move (set to true),
  // the round is complete and incremented by 1
  // this also decides if p2 needs to go again if p1 raised and vice versa
  final List<bool> playerMadeMove = [false, false, false, false];
  int playerTurn = 0;
  int round = 1;
  final int finalRound = 4;

  // after each end of round, instead of showing whose turn it is,
  // it will show "round ends in $secondsLeft"
  bool showNextRoundCountdown = false;
  int secondsLeft = 4;
  Timer? _timer;

  // during round countdowns, touch screen should be disabled
  bool touchDisabled = false;

  // VARIABLES FOR BLE (start)
  int gameState = 1;
  int currentBet = 5;
  // 0: P1, 1: P2, 2: P3, 3: P4
  final List<int> playerVisibilities = [0, 0, 0, 0];
  String winner = "";
  // names of players
  final List<String> namesOfPlayers = [
    "nsdevries", // P1
    "sehyeoo", // P2
    "DrDan", // P3
    "Player4", // P4
  ];
  // the name of player that is currently allowed to make a move
  String nameOfPlayer = "nsdevries";
  int playerNumber = 0;
  // player cards will be local variables
  Timer? gameStateReadTimer;
  // VARIABLES FOR BLE (end)

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

  // Initially we create an instance of Dealer
  // Draw two cards each for each player (this will be displayed on screen)
  // Draw 3 cards for dealer (this will NOT be displayed on screen initially)
  @override
  void initState() {
    super.initState();
    dealer = Dealer();
    dealer.assignAllPlayerCards(namesOfPlayers);
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

      if (nameOfPlayer == namesOfPlayers[0]) {
        nameOfPlayer = namesOfPlayers[1];
      } else if (nameOfPlayer == namesOfPlayers[1]) {
        nameOfPlayer = namesOfPlayers[2];
      } else if (nameOfPlayer == namesOfPlayers[2]) {
        nameOfPlayer = namesOfPlayers[3];
      } else {
        nameOfPlayer = namesOfPlayers[0];
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
      playerMadeMove[2] = false;
      playerMadeMove[3] = false;

      showNextRoundCountdown = true;
      secondsLeft = 3;
    });
    startTimer();
    updateLogs("Round ${round - 1} is ending...");
  }

  void _updateTurns({
    required int playerNumber,
    required bool madeTurn,
    required bool isRaise,
  }) {
    setState(() {
      playerMadeMove[playerNumber] = madeTurn;
      if (isRaise) {
        for (int i = 0; i < playerMadeMove.length; i++) {
          if (i != playerNumber) {
            playerMadeMove[i] = false;
          }
        }
      }
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

  void endMatch(
    List<DeckCard> d,
    List<DeckCard> p1,
    List<DeckCard> p2,
    List<DeckCard> p3,
    List<DeckCard> p4,
  ) {
    List<DeckCard> p1Combo = [];
    p1Combo.addAll(d);
    p1Combo.addAll(p1);

    List<DeckCard> p2Combo = [];
    p2Combo.addAll(d);
    p2Combo.addAll(p2);

    List<DeckCard> p3Combo = [];
    p3Combo.addAll(d);
    p3Combo.addAll(p3);

    List<DeckCard> p4Combo = [];
    p4Combo.addAll(d);
    p4Combo.addAll(p4);

    Hand p1Hand = Hand(cards: p1Combo);
    Hand p2Hand = Hand(cards: p2Combo);
    Hand p3Hand = Hand(cards: p3Combo);
    Hand p4Hand = Hand(cards: p4Combo);

    p1Hand.sortByValue();
    p2Hand.sortByValue();
    p3Hand.sortByValue();
    p4Hand.sortByValue();

    Rank p1Rank = p1Hand.getHandRank();
    Rank p2Rank = p2Hand.getHandRank();
    Rank p3Rank = p3Hand.getHandRank();
    Rank p4Rank = p4Hand.getHandRank();

    int p1RankNumber = _translateHandRankToValue(p1Rank);
    int p2RankNumber = _translateHandRankToValue(p2Rank);
    int p3RankNumber = _translateHandRankToValue(p3Rank);
    int p4RankNumber = _translateHandRankToValue(p4Rank);

    String winnerMessage = "";
    String winner = "";
    int winAmount = 0;

    List<int> winnerRanks = [
      p1RankNumber,
      p2RankNumber,
      p3RankNumber,
      p4RankNumber,
    ];
    // sort in ascending
    winnerRanks.sort((a, b) => a.compareTo(b));
    int winnerRankValue = winnerRanks.first;
    // remove anything to the right of cut off
    int cutOff = winnerRanks.length - 1;
    for (int i = 1; i < winnerRanks.length; i++) {
      if (winnerRanks[i] != winnerRankValue) {
        break;
      } else {
        cutOff--;
      }
    }
    while (cutOff > 0) {
      winnerRanks.removeLast();
      cutOff--;
    }

    // clear winner, no tie
    if (winnerRanks.length == 1) {
      if (_translateHandRankToValue(p1Rank) == winnerRankValue) {
        winner = namesOfPlayers[0];
        winnerMessage = "Player 1 has won";
      } else if (_translateHandRankToValue(p2Rank) == winnerRankValue) {
        winner = namesOfPlayers[1];
        winnerMessage = "Player 2 has won";
      } else if (_translateHandRankToValue(p3Rank) == winnerRankValue) {
        winner = namesOfPlayers[2];
        winnerMessage = "Player 3 has won";
      } else {
        winner = namesOfPlayers[3];
        winnerMessage = "Player 4 has won";
      }
      winAmount = int.parse(dealer.getTableAmount());
      setState(() {
        updateLogs(winnerMessage);
        dealer.addAmountToPlayer(winner, winAmount);
      });
    } else {
      // there's at least 1 tie
      bool p1Tied = false;
      bool p2Tied = false;
      bool p3Tied = false;
      bool p4Tied = false;

      if (p1RankNumber == winnerRankValue) {
        p1Tied = true;
      }
      if (p2RankNumber == winnerRankValue) {
        p2Tied = true;
      }
      if (p3RankNumber == winnerRankValue) {
        p3Tied = true;
      }
      if (p4RankNumber == winnerRankValue) {
        p4Tied = true;
      }

      // tiebreaker only works with 2 players
      // @case 1: all 4 players tied
      if (p1Tied && p2Tied && p3Tied && p4Tied) {
        Tiebreaker tiebreaker12 = Tiebreaker(
          dealerCards: d,
          playerOneCards: p1,
          playerTwoCards: p2,
          tiedRank: p1Rank,
        );
        // 0 = tie, 1 = p1 wins, 2 = p2 wins
        int tiedValue12 = tiebreaker12.tiebreak();
        Tiebreaker tiebreaker34 = Tiebreaker(
          dealerCards: d,
          playerOneCards: p3,
          playerTwoCards: p4,
          tiedRank: p1Rank,
        );
        int tiedValue34 = tiebreaker34.tiebreak();
        // all 4 tied
        if (tiedValue12 == 0 && tiedValue34 == 0) {
          winnerMessage = "All players tied.";
          winAmount = int.parse(dealer.getTableAmount()) / 4 as int;
          setState(() {
            updateLogs(winnerMessage);
            for (int i = 0; i < namesOfPlayers.length; i++) {
              dealer.addAmountToPlayer(namesOfPlayers[i], winAmount);
            }
          });
        } else if (tiedValue12 == 1 && tiedValue34 == 1) {
          // tie break p1 and p3
          Tiebreaker tiebreaker13 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p3,
            tiedRank: p1Rank,
          );
          int tiedValue13 = tiebreaker13.tiebreak();
          if (tiedValue13 == 0) {
            winnerMessage = "Player 1 and 3 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else if (tiedValue13 == 1) {
            winnerMessage = "Player 1 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
            });
          } else {
            winnerMessage = "Player 3 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          }
        } else if (tiedValue12 == 1 && tiedValue34 == 2) {
          // tie break p1 and p4
          Tiebreaker tiebreaker14 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p4,
            tiedRank: p1Rank,
          );
          int tiedValue14 = tiebreaker14.tiebreak();
          if (tiedValue14 == 0) {
            winnerMessage = "Player 1 and 4 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else if (tiedValue14 == 1) {
            winnerMessage = "Player 1 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        } else if (tiedValue12 == 2 && tiedValue34 == 1) {
          Tiebreaker tiebreaker24 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p2,
            playerTwoCards: p4,
            tiedRank: p2Rank,
          );
          int tiedValue24 = tiebreaker24.tiebreak();
          if (tiedValue24 == 0) {
            winnerMessage = "Players 2 and 4 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue24 == 1) {
            winnerMessage = "Player 2 has won.";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won.";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        }
      }
      // @case 2: 3 ties - 4 different possibilities
      else if (p1Tied && p2Tied && p3Tied) {
        Tiebreaker tiebreaker12 = Tiebreaker(
          dealerCards: d,
          playerOneCards: p1,
          playerTwoCards: p2,
          tiedRank: p2Rank,
        );
        int tiedValue12 = tiebreaker12.tiebreak();
        if (tiedValue12 == 0 || tiedValue12 == 1) {
          Tiebreaker tiebreaker13 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p3,
            tiedRank: p1Rank,
          );
          int tiedValue13 = tiebreaker13.tiebreak();
          if (tiedValue13 == 0) {
            winnerMessage = "Players 1, 2, 3 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 3 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else if (tiedValue13 == 1) {
            winnerMessage = "Players 1 and 2 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else {
            winnerMessage = "Player 3 won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          }
        } else {
          // p2 vs p3
          Tiebreaker tiebreaker23 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p2,
            playerTwoCards: p3,
            tiedRank: p2Rank,
          );
          int tiedValue23 = tiebreaker23.tiebreak();
          if (tiedValue23 == 0) {
            winnerMessage = "Player 2 and 3 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else if (tiedValue23 == 1) {
            winnerMessage = "Player 2 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else {
            winnerMessage = "Player 3 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          }
        }
      } else if (p1Tied && p2Tied && p4Tied) {
        Tiebreaker tiebreaker12 = Tiebreaker(
          dealerCards: d,
          playerOneCards: p1,
          playerTwoCards: p2,
          tiedRank: p2Rank,
        );
        int tiedValue12 = tiebreaker12.tiebreak();
        if (tiedValue12 == 0 || tiedValue12 == 1) {
          Tiebreaker tiebreaker14 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p4,
            tiedRank: p1Rank,
          );
          int tiedValue14 = tiebreaker14.tiebreak();
          if (tiedValue14 == 0) {
            winnerMessage = "Players 1, 2, 4 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 3 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue14 == 1) {
            winnerMessage = "Players 1 and 2 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else {
            winnerMessage = "Player 4 won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        } else {
          // p2 vs p4
          Tiebreaker tiebreaker24 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p2,
            playerTwoCards: p4,
            tiedRank: p2Rank,
          );
          int tiedValue24 = tiebreaker24.tiebreak();
          if (tiedValue24 == 0) {
            winnerMessage = "Player 2 and 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue24 == 1) {
            winnerMessage = "Player 2 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        }
      } else if (p2Tied && p3Tied && p4Tied) {
        Tiebreaker tiebreaker23 = Tiebreaker(
          dealerCards: d,
          playerOneCards: p2,
          playerTwoCards: p3,
          tiedRank: p2Rank,
        );
        int tiedValue23 = tiebreaker23.tiebreak();
        if (tiedValue23 == 0 || tiedValue23 == 1) {
          Tiebreaker tiebreaker24 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p2,
            playerTwoCards: p4,
            tiedRank: p2Rank,
          );
          int tiedValue24 = tiebreaker24.tiebreak();
          if (tiedValue24 == 0) {
            winnerMessage = "Players 2, 3, 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 3 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue24 == 1) {
            winnerMessage = "Players 2 and 3 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else {
            winnerMessage = "Player 4 won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        } else {
          // p3 vs p4
          Tiebreaker tiebreaker34 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p3,
            playerTwoCards: p4,
            tiedRank: p3Rank,
          );
          int tiedValue34 = tiebreaker34.tiebreak();
          if (tiedValue34 == 0) {
            winnerMessage = "Player 3 and 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue23 == 1) {
            winnerMessage = "Player 3 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        }
      } else if (p1Tied && p3Tied && p4Tied) {
        Tiebreaker tiebreaker13 = Tiebreaker(
          dealerCards: d,
          playerOneCards: p1,
          playerTwoCards: p3,
          tiedRank: p1Rank,
        );
        int tiedValue13 = tiebreaker13.tiebreak();
        if (tiedValue13 == 0 || tiedValue13 == 1) {
          Tiebreaker tiebreaker14 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p4,
            tiedRank: p1Rank,
          );
          int tiedValue14 = tiebreaker14.tiebreak();
          if (tiedValue14 == 0) {
            winnerMessage = "Players 1, 3, 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 3 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue14 == 1) {
            winnerMessage = "Players 1 and 4 tied.";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else {
            winnerMessage = "Player 4 won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        } else {
          // p3 vs p4
          Tiebreaker tiebreaker34 = Tiebreaker(
            dealerCards: d,
            playerOneCards: p3,
            playerTwoCards: p4,
            tiedRank: p3Rank,
          );
          int tiedValue34 = tiebreaker34.tiebreak();
          if (tiedValue34 == 0) {
            winnerMessage = "Player 3 and 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue34 == 1) {
            winnerMessage = "Player 3 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        }
      } else {
        // only 2 players tied
        // there are 6 possibilities
        if (p1Tied && p2Tied) {
          // p1 vs p2
          Tiebreaker tiebreaker = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p2,
            tiedRank: p1Rank,
          );
          int tiedValue = tiebreaker.tiebreak();
          if (tiedValue == 0) {
            winnerMessage = "Player 1 and 2 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else if (tiedValue == 1) {
            winnerMessage = "Player 1 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
            });
          } else {
            winnerMessage = "Player 2 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          }
        } else if (p1Tied && p3Tied) {
          // p1 vs p3
          Tiebreaker tiebreaker = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p3,
            tiedRank: p1Rank,
          );
          int tiedValue = tiebreaker.tiebreak();
          if (tiedValue == 0) {
            winnerMessage = "Player 1 and 3 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else if (tiedValue == 1) {
            winnerMessage = "Player 1 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
            });
          } else {
            winnerMessage = "Player 3 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          }
        } else if (p1Tied && p4Tied) {
          // p1 vs p4
          Tiebreaker tiebreaker = Tiebreaker(
            dealerCards: d,
            playerOneCards: p1,
            playerTwoCards: p4,
            tiedRank: p1Rank,
          );
          int tiedValue = tiebreaker.tiebreak();
          if (tiedValue == 0) {
            winnerMessage = "Player 1 and 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue == 1) {
            winnerMessage = "Player 1 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[0], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        } else if (p2Tied && p3Tied) {
          // p2 vs p3
          Tiebreaker tiebreaker = Tiebreaker(
            dealerCards: d,
            playerOneCards: p2,
            playerTwoCards: p3,
            tiedRank: p2Rank,
          );
          int tiedValue = tiebreaker.tiebreak();
          if (tiedValue == 0) {
            winnerMessage = "Player 2 and 3 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else if (tiedValue == 1) {
            winnerMessage = "Player 2 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else {
            winnerMessage = "Player 3 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          }
        } else if (p2Tied && p4Tied) {
          // p2 vs p4
          Tiebreaker tiebreaker = Tiebreaker(
            dealerCards: d,
            playerOneCards: p2,
            playerTwoCards: p4,
            tiedRank: p2Rank,
          );
          int tiedValue = tiebreaker.tiebreak();
          if (tiedValue == 0) {
            winnerMessage = "Player 2 and 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue == 1) {
            winnerMessage = "Player 2 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[1], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        } else if (p3Tied && p4Tied) {
          // p3 vs p4
          Tiebreaker tiebreaker = Tiebreaker(
            dealerCards: d,
            playerOneCards: p3,
            playerTwoCards: p4,
            tiedRank: p3Rank,
          );
          int tiedValue = tiebreaker.tiebreak();
          if (tiedValue == 0) {
            winnerMessage = "Player 3 and 4 tied";
            winAmount = int.parse(dealer.getTableAmount()) / 2 as int;
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          } else if (tiedValue == 1) {
            winnerMessage = "Player 3 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[2], winAmount);
            });
          } else {
            winnerMessage = "Player 4 has won";
            winAmount = int.parse(dealer.getTableAmount());
            setState(() {
              updateLogs(winnerMessage);
              dealer.addAmountToPlayer(namesOfPlayers[3], winAmount);
            });
          }
        }
      }
    }

    // TODO: jk not todo, highlighted for DEBUG
    List<DeckCard> p1BestHand = p1Hand.getBestHandBasedOnHandRank(p1Rank);
    List<DeckCard> p2BestHand = p2Hand.getBestHandBasedOnHandRank(p2Rank);
    List<DeckCard> p3BestHand = p3Hand.getBestHandBasedOnHandRank(p3Rank);
    List<DeckCard> p4BestHand = p4Hand.getBestHandBasedOnHandRank(p4Rank);

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

    print("\nprinting player 3's cards");
    for (int i = 0; i < p3BestHand.length; i++) {
      String suit = p3BestHand[i].playingCard.suit.toString();
      String cardValue = p3BestHand[i].playingCard.value.toString();
      print('$i: $cardValue of $suit');
    }

    print("\nprinting player 4's cards");
    for (int i = 0; i < p4BestHand.length; i++) {
      String suit = p4BestHand[i].playingCard.suit.toString();
      String cardValue = p4BestHand[i].playingCard.value.toString();
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
      secondsLeft = 3;
      dealer.reset();
      playerMadeMove[0] = false;
      playerMadeMove[1] = false;
      playerMadeMove[2] = false;
      playerMadeMove[3] = false;
      round = 1;
      nameOfPlayer = namesOfPlayers[0];
      playerRecentCommands[namesOfPlayers[0]] = "";
      playerRecentCommands[namesOfPlayers[1]] = "";
      playerRecentCommands[namesOfPlayers[2]] = "";
      playerRecentCommands[namesOfPlayers[3]] = "";
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

  // This will read the game state from the player until they write 5
  void attemptGameStateRead(Function onChange, BluetoothCharacteristic bc) {
    Timer.periodic(const Duration(seconds: 1), (gameStateTimer) async {
      try {
        int newGameState = await widget.readGameState(bc) ?? gameState;

        print("Current Game State: $newGameState");

        if (newGameState == 5) {
          gameStateTimer.cancel();
          print("Game State is 5!");
          onChange();
        }
      } catch (e) {
        print("Error reading game state: $e");
        gameStateTimer.cancel();
      }
    });
  }

  String convertCardDataToBLECardData(DeckCard card) {
    String cardStr = "C";
    String cardValueStr = "";
    String suitRankStr = "";

    switch (card.playingCard.suit) {
      case Suit.clubs:
        suitRankStr = "C";
        break;
      case Suit.diamonds:
        suitRankStr = "D";
        break;
      case Suit.hearts:
        suitRankStr = "H";
        break;
      case Suit.spades:
        suitRankStr = "S";
        break;
      default: // will never be joker
        break;
    }

    switch (card.playingCard.value) {
      case CardValue.ace:
        cardValueStr = "A";
        break;
      case CardValue.two:
        cardValueStr = "2";
        break;
      case CardValue.three:
        cardValueStr = "3";
        break;
      case CardValue.four:
        cardValueStr = "4";
        break;
      case CardValue.five:
        cardValueStr = "5";
        break;
      case CardValue.six:
        cardValueStr = "6";
        break;
      case CardValue.seven:
        cardValueStr = "7";
        break;
      case CardValue.eight:
        cardValueStr = "8";
        break;
      case CardValue.nine:
        cardValueStr = "9";
        break;
      case CardValue.ten:
        cardValueStr = "T";
        break;
      case CardValue.jack:
        cardValueStr = "J";
        break;
      case CardValue.queen:
        cardValueStr = "Q";
        break;
      case CardValue.king:
        cardValueStr = "K";
        break;
      default: // will never be joker
        break;
    }

    return cardStr + cardValueStr + suitRankStr;
  }

  // current bet, game state, winner
  void _makeMove() {
    for (int i = 0; i < widget.devices.length; i++) {
      widget.sendBet(
        widget.devices[i]
            .characteristics[Guid("710c29f5-bc94-424b-a80f-7ac6d7b1e503")]!,
        dealer.callAmount,
      );
      if (playerNumber == 1) {
        // p1 needs to make a move
        attemptGameStateRead(
          () {
            setState(() {
              gameState = 5;
            });
          },
          widget.devices[0]
              .characteristics[Guid("3c479062-fca6-4e2b-8812-172a47615aff")]!,
        );
      }
    }
    setState(() {
      playerMadeMove[playerNumber] = true;
      playerNumber++;
      if (playerNumber >= 4) {
        playerNumber = 0;
      }
    });
  }

  // 0 - fold, returnVal = currentBet - call, returnVal > currentBet - raise by diff

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
    List<DeckCard> p1Cards = dealer.getPlayerCards(namesOfPlayers[0]);
    List<DeckCard> p2Cards = dealer.getPlayerCards(namesOfPlayers[1]);
    List<DeckCard> p3Cards = dealer.getPlayerCards(namesOfPlayers[2]);
    List<DeckCard> p4Cards = dealer.getPlayerCards(namesOfPlayers[3]);
    List<int> allPlayerAmountOwned = dealer.getAllPlayerAmountOwned();

    if (!playerMadeMove[playerNumber]) {
      _makeMove();
    }

    // both players made move this round
    if (playerMadeMove[0] &&
        playerMadeMove[1] &&
        playerMadeMove[2] &&
        playerMadeMove[3]) {
      // all rounds are complete, match has ended
      if (round == finalRound) {
        if (!showRestartButton) {
          endMatch(dealerCards, p1Cards, p2Cards, p3Cards, p4Cards);
          displayRestartButton(); // sets it to true
        }
        // reset(); // originally just this line
      } else {
        showTimer();
        _nextRound();
      }
    }

    return Scaffold(
      appBar: PreferredSize(
          // change height of app bar
          preferredSize: const Size.fromHeight(20.0),
          child: AppBar(
            title: const Text('Texas Hold \'em'),
            centerTitle: true,
          )),
      // Wrapping a widget with AbsorbPointer allows you to set an absorbing prop
      // The absorbing property enables touch screen if false,
      // and disables touch screen if true
      body: SafeArea(
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
                      top: topCenter * 0.3,
                      left: leftCenter * 0.75,
                      child: SizedBox(
                        width: 200,
                        height: 30,
                        child: Center(
                          child: Text(
                            dealer.getTableAmount(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Player one is positioned top left
                    Positioned(
                      top: -30,
                      left: leftCenter * 0.02,
                      child: PlayerInfo(
                        name: namesOfPlayers[0],
                        card1: p1Cards[0],
                        card2: p1Cards[1],
                        amount: allPlayerAmountOwned[0],
                        recentCommand: playerRecentCommands[namesOfPlayers[0]]!,
                        raiseAmount:
                            playerRecentCommands[namesOfPlayers[0]] == "Raise"
                                ? "50"
                                : "",
                        showDetails: true,
                      ),
                    ),
                    // Player two is positioned top right
                    Positioned(
                      top: -30,
                      left: (leftCenter * 2) * 0.82,
                      child: PlayerInfo(
                        name: namesOfPlayers[1],
                        card1: p2Cards[0],
                        card2: p2Cards[1],
                        amount: allPlayerAmountOwned[1],
                        recentCommand: playerRecentCommands[namesOfPlayers[1]]!,
                        raiseAmount:
                            playerRecentCommands[namesOfPlayers[1]] == "Raise"
                                ? "50"
                                : "",
                        showDetails: true,
                      ),
                    ),
                    // Player 3 is positioned bot left
                    Positioned(
                      top: topCenter,
                      left: leftCenter * 0.02,
                      child: PlayerInfo(
                        name: namesOfPlayers[2],
                        card1: p3Cards[0],
                        card2: p3Cards[1],
                        amount: allPlayerAmountOwned[2],
                        recentCommand: playerRecentCommands[namesOfPlayers[2]]!,
                        raiseAmount:
                            playerRecentCommands[namesOfPlayers[2]] == "Raise"
                                ? "50"
                                : "",
                        showDetails: true,
                      ),
                    ),
                    // Player 4 is positioned bot right
                    Positioned(
                      top: topCenter,
                      left: (leftCenter * 2) * 0.82,
                      child: PlayerInfo(
                        name: namesOfPlayers[3],
                        card1: p4Cards[0],
                        card2: p4Cards[1],
                        amount: allPlayerAmountOwned[3],
                        recentCommand: playerRecentCommands[namesOfPlayers[3]]!,
                        raiseAmount:
                            playerRecentCommands[namesOfPlayers[3]] == "Raise"
                                ? "50"
                                : "",
                        showDetails: true,
                      ),
                    ),
                    // shows what round it is
                    Positioned(
                      top: topCenter * 0.05,
                      left: leftCenter * 0.89,
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
                      top: topCenter * 0.175,
                      left: leftCenter * 0.75,
                      child: SizedBox(
                        width: 200,
                        height: 30,
                        child: Center(
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
                      ),
                    ),
                    // draws dealer cards to screen
                    Positioned(
                      top: topCenter * 0.9,
                      left: leftCenter * 0.57,
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
                      top: topCenter * 1.45,
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
                      top: topCenter * 1.6,
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
                    if (showRestartButton)
                      Positioned(
                        top: topCenter * 0.55,
                        left: leftCenter * 0.88,
                        child: restartButton(onRestart: reset),
                      ),
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
                                    if (nameOfPlayer == namesOfPlayers[0]) {
                                      playerNumber = 0;
                                    } else if (nameOfPlayer ==
                                        namesOfPlayers[1]) {
                                      playerNumber = 1;
                                    } else if (nameOfPlayer ==
                                        namesOfPlayers[2]) {
                                      playerNumber = 2;
                                    } else {
                                      playerNumber = 3;
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
                                      if (nameOfPlayer == namesOfPlayers[0]) {
                                        _updateTurns(
                                          playerNumber: 0,
                                          madeTurn: true,
                                          isRaise: true,
                                        );
                                      } else if (nameOfPlayer ==
                                          namesOfPlayers[1]) {
                                        _updateTurns(
                                          playerNumber: 1,
                                          madeTurn: true,
                                          isRaise: true,
                                        );
                                      } else if (nameOfPlayer ==
                                          namesOfPlayers[2]) {
                                        _updateTurns(
                                          playerNumber: 2,
                                          madeTurn: true,
                                          isRaise: true,
                                        );
                                      } else {
                                        _updateTurns(
                                          playerNumber: 3,
                                          madeTurn: true,
                                          isRaise: true,
                                        );
                                      }
                                    } else {
                                      // Fold, check, call
                                      if (nameOfPlayer == namesOfPlayers[0]) {
                                        _updateTurns(
                                          playerNumber: 0,
                                          madeTurn: true,
                                          isRaise: false,
                                        );
                                      } else if (nameOfPlayer ==
                                          namesOfPlayers[1]) {
                                        _updateTurns(
                                          playerNumber: 1,
                                          madeTurn: true,
                                          isRaise: false,
                                        );
                                      } else if (nameOfPlayer ==
                                          namesOfPlayers[2]) {
                                        _updateTurns(
                                          playerNumber: 2,
                                          madeTurn: true,
                                          isRaise: false,
                                        );
                                      } else {
                                        _updateTurns(
                                          playerNumber: 3,
                                          madeTurn: true,
                                          isRaise: false,
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
      ),
    );
  }
}
