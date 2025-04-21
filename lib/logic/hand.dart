import 'dart:math' as math;

import 'package:playing_cards/playing_cards.dart';
import 'package:street_fighter/models/card.dart';
import 'package:street_fighter/models/rank.dart';

// Determines the rank based on cards <-> also evaluates the best possible hand
// should be called and used at the end of each match
// to determine the winner
// this does not break ties but it should implement compareTo other Hand's cards
class Hand {
  Hand({required this.cards});

  final List<DeckCard> cards;

  // J - 11
  // Q - 12
  // K - 13
  // A - 14 (highest card, but A,2,3,4,5 can be a low-straight)
  void sortByValue() {
    cards.sort((a, b) => _getCardValueNum(a.playingCard.value)
        .compareTo(_getCardValueNum(b.playingCard.value)));
  }

  // must be called after sortByValue()
  // Then, this will be sorted in ascending order with
  // so that: 2 ~ A along 0 ~ size index
  Rank getHandRank() {
    List<int> cardValues =
        cards.map((card) => _getCardValueNum(card.playingCard.value)).toList();

    // determine if the hand is a straight
    bool isStraight = _containsStraight(cardValues);

    // determine if the hand is a flush
    bool isFlush = _containsFlush(cards);

    // determine if it's a royal (straight) flush
    // pre-req: it's a flush
    if (isFlush && _isRoyalStraightFlush(cardValues)) {
      return Rank.royalFlush;
    }

    // determine if hand is a straight flush
    if (isStraight && isFlush) {
      return Rank.straightFlush;
    }

    if (isStraight) {
      return Rank.straight;
    }

    if (isFlush) {
      return Rank.flush;
    }

    // determine if the hand is a 2, 3, or 4 of a kind
    int x = _getXOfAKind(cardValues);
    if (x == 4) {
      return Rank.fourOfAKind;
    } else if (x == 3) {
      return Rank.threeOfAKind;
    } else if (x == 2) {
      return Rank.onePair;
    } else if (x == 1) {
      return Rank.twoPair;
    } else if (x == 0) {
      return Rank.fullHouse;
    }

    // None of the above applies, so automatically, it's a high card
    return Rank.highCard;
  }

  // must be called after calling getHandRank() at least once
  // @param rank - must be the rank of this hand evaluated by this getHandRank()
  List<DeckCard> getBestHandBasedOnHandRank(Rank rank) {
    List<DeckCard> bestHand = [];
    switch (rank) {
      case Rank.royalFlush:
        bestHand = _getCardsRoyalFlush(cards);
        break;
      case Rank.straightFlush:
        bestHand = _getCardsStraightFlush(cards);
        break;
      case Rank.fourOfAKind:
        bestHand = _getCardsFourOfAKind(cards);
        break;
      case Rank.fullHouse:
        bestHand = [..._getCardBestTriple(cards), ..._getCardBestPair(cards)];
        break;
      case Rank.flush:
        bestHand = _getCardsFlush(cards);
        break;
      case Rank.straight:
        bestHand = _getCardsStraight(cards);
        break;
      case Rank.threeOfAKind:
        bestHand = _getCardBestTriple(cards);
        break;
      case Rank.twoPair:
        bestHand = _getCardBestTwoPair(cards);
        break;
      case Rank.onePair:
        bestHand = _getCardBestPair(cards);
        break;
      case Rank.highCard:
        bestHand = _getCardHighestCard(cards);
        break;
    }
    return bestHand;
  }
}

int _getCardValueNum(CardValue value) {
  if (value case CardValue.two) {
    return 2;
  } else if (value case CardValue.three) {
    return 3;
  } else if (value case CardValue.four) {
    return 4;
  } else if (value case CardValue.five) {
    return 5;
  } else if (value case CardValue.six) {
    return 6;
  } else if (value case CardValue.seven) {
    return 7;
  } else if (value case CardValue.eight) {
    return 8;
  } else if (value case CardValue.nine) {
    return 9;
  } else if (value case CardValue.ten) {
    return 10;
  } else if (value case CardValue.jack) {
    return 11;
  } else if (value case CardValue.queen) {
    return 12;
  } else if (value case CardValue.king) {
    return 13;
  } else if (value case CardValue.ace) {
    return 14;
  } else {
    return -1; // doesn't exist
  }
}

// defintion of straight: 5 cards ordered, but not all the same suit
// Returns true if given hand contains a straight
bool _containsStraight(List<int> cardValues) {
  int consecutiveCount = 1;

  // if card contains ace (14), add 1 to start of array for low-straight check
  if (cardValues[cardValues.length - 1] == 14) {
    cardValues.insert(0, 1);
  }

  // Loop through the sorted card values to check for consecutive numbers
  for (int i = 1; i < cardValues.length; i++) {
    if (cardValues[i] == cardValues[i - 1] + 1) {
      consecutiveCount++;
      if (consecutiveCount >= 5) {
        return true;
      }
    } else {
      consecutiveCount = 1;
    }
  }

  return false;
}

// definition of flush: 5 cards of the same suit, but not ordered
// Returns true if given hand contains a flush
bool _containsFlush(List<DeckCard> cards) {
  // index 0: spades
  // 1: clover
  // 2: heart
  // 3: diamond
  final List<int> suitCount = [0, 0, 0, 0];
  for (DeckCard card in cards) {
    if (card.playingCard.suit == Suit.spades) {
      suitCount[0]++;
    } else if (card.playingCard.suit == Suit.clubs) {
      suitCount[1]++;
    } else if (card.playingCard.suit == Suit.hearts) {
      suitCount[2]++;
    } else if (card.playingCard.suit == Suit.diamonds) {
      suitCount[3]++;
    }
  }

  return suitCount[0] == 5 ||
      suitCount[1] == 5 ||
      suitCount[2] == 5 ||
      suitCount[3] == 5;
}

// def of x of a kind: same x number of card values but not necessarily suit
// Returns 4 if 4 of a kind, 3 if 3 of a kind, 2 if 2 of a kind (pair)
// Returns 1 if there exists 2 pairs
// Returns 0 if full house (3 of a kind + 2 of a kind)
// Returns -1 if none of the above apply
int _getXOfAKind(List<int> cardValues) {
  // key: cardValue (2 - 14)
  // value: occurrence of cardValue (all zero initially)
  Map<int, int> valueCounts = {};

  for (int cardValue in cardValues) {
    if (!valueCounts.containsKey(cardValue)) {
      valueCounts[cardValue] = 0;
    }
    valueCounts[cardValue] = valueCounts[cardValue]! + 1;
  }

  bool isFourOfAKind = valueCounts.values.any((count) => count == 4);
  bool isThreeOfAKind = valueCounts.values.any((count) => count == 3);
  bool isPair = valueCounts.values.any((count) => count == 2);

  if (isFourOfAKind) {
    return 4;
  }

  // full house condition: 3 of a kind + 2 of a kind
  if (isThreeOfAKind && isPair) {
    return 0;
  }

  if (isThreeOfAKind) {
    return 3;
  }

  // Check for 2 pairs
  if (isPair) {
    List<int> pairs = valueCounts.values.where((value) => value == 2).toList();
    if (pairs.length == 2) {
      return 1; // 2 pairs
    }
    return 2;
  }

  // there was no 2, 3, 4 of a kind and also no 2 pairs
  return -1;
}

// A Royal Flush is a flush that contains 10, J, Q, K, A
bool _isRoyalStraightFlush(List<int> cardValues) {
  return cardValues.contains(10) &&
      cardValues.contains(11) &&
      cardValues.contains(12) &&
      cardValues.contains(13) &&
      cardValues.contains(14);
}

// get 5 cards for royal flush
List<DeckCard> _getCardsRoyalFlush(List<DeckCard> cards) {
  List<DeckCard> temp = [];
  bool tenFound = false;
  bool jackFound = false;
  bool queenFound = false;
  bool kingFound = false;
  bool aceFound = false;

  for (DeckCard card in cards) {
    // found our card combo for royal flush
    if (temp.length == 5) {
      break;
    }

    int cardValue = _getCardValueNum(card.playingCard.value);
    if (!temp.contains(card)) {
      if (!tenFound && cardValue == 10) {
        temp.add(card);
        tenFound = true;
      }

      if (!jackFound && cardValue == 11) {
        temp.add(card);
        jackFound = true;
      }

      if (!queenFound && cardValue == 12) {
        temp.add(card);
        queenFound = true;
      }

      if (!kingFound && cardValue == 13) {
        temp.add(card);
        kingFound = true;
      }

      if (!aceFound && cardValue == 14) {
        temp.add(card);
        aceFound = true;
      }
    }
  }

  return temp;
}

// get 5 cards for straight flush (not royal)
List<DeckCard> _getCardsStraightFlush(List<DeckCard> cards) {
  List<DeckCard> temp = [];

  // first, order by suit to get flush combination
  // worst case all 7 cards are of the same suit
  // key: suit | value: list of cards of this suit
  Map<Suit, List<DeckCard>> flushEvaluator = {};
  for (DeckCard card in cards) {
    Suit suit = card.playingCard.suit;
    if (!flushEvaluator.containsKey(suit)) {
      flushEvaluator[suit] = [card];
    } else {
      flushEvaluator[suit] = [...flushEvaluator[suit]!, card];
    }
  }

  // there can only be one suit with 5 or more cards of the same suit
  List<DeckCard> flushHand =
      flushEvaluator.values.firstWhere((value) => value.length >= 5);

  // get the straight combo from flushHand (in case 5+ cards cause a flush)
  // remember that the @param cards are already sorted
  // therefore, flushHand should already be sorted to form a straight
  if (flushHand.length == 5) {
    return flushHand;
  }
  temp.add(flushHand[0]);
  for (int i = 1; i < flushHand.length; i++) {
    // found 5 cards that form a straight
    if (temp.length == 5) {
      break;
    }
    // if previous + 1 is not equal to current, reset temp
    if (_getCardValueNum(temp[i - 1].playingCard.value) + 1 !=
        _getCardValueNum(flushHand[i].playingCard.value)) {
      temp.clear();
    }
    temp.add(flushHand[i]);
  }

  return temp;
}

// get 4 cards for 4-of-a-kind
List<DeckCard> _getCardsFourOfAKind(List<DeckCard> cards) {
  // sort by card value
  Map<CardValue, List<DeckCard>> fourHand = {};
  for (DeckCard card in cards) {
    CardValue cardValue = card.playingCard.value;
    if (!fourHand.containsKey(cardValue)) {
      fourHand[cardValue] = [card];
    } else {
      fourHand[cardValue] = [card, ...fourHand[cardValue]!];
    }
  }

  // there can only be one possibility of a four of a kind
  // therefore return the combo where map[key] length is 4
  return fourHand.values.firstWhere((value) => value.length == 4);
}

// get 5 cards that form a flush
List<DeckCard> _getCardsFlush(List<DeckCard> cards) {
  Map<Suit, List<DeckCard>> flushHand = {};
  for (DeckCard card in cards) {
    Suit suit = card.playingCard.suit;
    if (!flushHand.containsKey(suit)) {
      flushHand[suit] = [card];
    } else {
      flushHand[suit] = [card, ...flushHand[suit]!];
    }
  }
  return flushHand.values.firstWhere((value) => value.length == 5);
}

// get 5 cards that form a straight (includes low straight and royal straight)
List<DeckCard> _getCardsStraight(List<DeckCard> cards) {
  List<DeckCard> temp = [];
  temp.add(cards[0]);

  for (int i = 1; i < cards.length; i++) {
    int prev = _getCardValueNum(temp[i - 1].playingCard.value);
    int curr = _getCardValueNum(cards[i].playingCard.value);

    if (prev + 1 != curr) {
      temp.clear();
    }
    temp.add(cards[i]);
  }

  return temp;
}

// returns the best 3-of-a-kind
// similar logic as 4-of-a-kind but needs to sort in descending order
List<DeckCard> _getCardBestTriple(List<DeckCard> cards) {
  final Map<CardValue, List<DeckCard>> tripleHands = {};
  for (DeckCard card in cards) {
    CardValue cardValue = card.playingCard.value;
    if (!tripleHands.containsKey(cardValue)) {
      tripleHands[cardValue] = [card];
    } else {
      tripleHands[cardValue] = [card, ...tripleHands[cardValue]!];
    }
  }

  // there could be 1 or 2 triples, therefore cannot use direct "firstWhere"
  Iterable<List<DeckCard>> triplesItr =
      tripleHands.values.where((value) => value.length == 3);
  List<List<DeckCard>> triples = triplesItr.toList();

  // for 1 triple
  if (triples.length == 1) {
    return triples[0];
  }

  // for 2 triples
  int firstRank = _getCardValueNum(triples[0][0].playingCard.value);
  int secondRank = _getCardValueNum(triples[1][0].playingCard.value);

  if (firstRank > secondRank) {
    return triples[0];
  }
  return triples[1];
}

// returns the best 2-pair
List<DeckCard> _getCardBestTwoPair(List<DeckCard> cards) {
  final Map<CardValue, List<DeckCard>> twoPairHand = {};
  for (DeckCard card in cards) {
    CardValue cardValue = card.playingCard.value;
    if (!twoPairHand.containsKey(cardValue)) {
      twoPairHand[cardValue] = [card];
    } else {
      twoPairHand[cardValue] = [card, ...twoPairHand[cardValue]!];
    }
  }

  List<List<DeckCard>> twoPairs =
      twoPairHand.values.where((value) => value.length == 2).toList();

  // case 1: only one two pair found
  if (twoPairs.length == 2) {
    return [...twoPairs[0], ...twoPairs[1]];
  }

  // case 2: 3 pairs found
  int firstRank = _getCardValueNum(twoPairs[0][0].playingCard.value);
  int secondRank = _getCardValueNum(twoPairs[1][0].playingCard.value);
  int thirdRank = _getCardValueNum(twoPairs[2][0].playingCard.value);

  int firstSecondCombo = firstRank + secondRank;
  int firstThirdCombo = firstRank + thirdRank;
  int secondThirdCombo = secondRank + thirdRank;

  int max =
      math.max(firstSecondCombo, math.max(firstThirdCombo, secondThirdCombo));

  if (max == firstSecondCombo) {
    return [...twoPairs[0], ...twoPairs[1]];
  } else if (max == firstThirdCombo) {
    return [...twoPairs[0], ...twoPairs[2]];
  } else {
    return [...twoPairs[1], ...twoPairs[2]];
  }
}

// returns the best pair
// this assumes that there is only one pair in cards
// because if there was more than one, it becomes a bestTwoPair
List<DeckCard> _getCardBestPair(List<DeckCard> cards) {
  final Map<CardValue, List<DeckCard>> pairHand = {};
  for (DeckCard card in cards) {
    CardValue cardValue = card.playingCard.value;
    if (!pairHand.containsKey(cardValue)) {
      pairHand[cardValue] = [card];
    } else {
      pairHand[cardValue] = [card, ...pairHand[cardValue]!];
    }
  }

  return pairHand.values.firstWhere((value) => value.length == 2);
}

// returns the highest card in @param: cards
// the resulting list will always be of size 1
List<DeckCard> _getCardHighestCard(List<DeckCard> cards) {
  int high = 0;
  DeckCard highCard = cards[0];
  for (DeckCard card in cards) {
    // highest possible
    if (high == 14) {
      break;
    }
    int cardValue = _getCardValueNum(card.playingCard.value);
    if (cardValue > high) {
      high = cardValue;
      highCard = card;
    }
  }
  return [highCard];
}
