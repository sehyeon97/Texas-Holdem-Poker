import 'package:playing_cards/playing_cards.dart';
import 'package:street_fighter/models/card.dart';
import 'package:street_fighter/models/rank.dart';

// The difference between tiebreaker and hand is that
// tiebreaker compares kickers while hand only returns best hand
class Tiebreaker {
  // This object is only called when p1's best hand rank = p2's best hand rank
  // The best hand rank was determined by combining dealer + player's cards
  Tiebreaker({
    required this.dealerCards,
    required this.playerOneCards,
    required this.playerTwoCards,
    required this.tiedRank,
  });

  final List<DeckCard> dealerCards;
  final List<DeckCard> playerOneCards;
  final List<DeckCard> playerTwoCards;
  final Rank tiedRank;

  // returns 0 if tie
  // returns 1 if p1 wins
  // returns 2 if p2 wins
  int tiebreak() {
    // there can only be one scenario of a tied royal flush:
    // by using the dealer's hand only
    if (tiedRank == Rank.royalFlush) {
      return 0;
    }

    /*
      @case 1: both players truly tie with straight-flush
               when they strictly use the dealer's hand
      @case 2: High card decides the winner
    */
    if (tiedRank == Rank.straightFlush) {
      return _evaluateStraightFlushTie();
    }

    /*
      @case 1: higher quads = win
      @case 2: same quads (can only happen if dealer owns the quad)
               then compare the high cards of P1 & P2's best hand
    */
    if (tiedRank == Rank.fourOfAKind) {
      return _evaluateFourOfAKindTie();
    }

    /*
      @case 1: Dealer's cards form the full house by itself
               This is a true tie as poker takes best 5 cards only
      @case 2: Higher 3 of a kind value wins
      @case 3: if case 2 was the same, then higher 2 of a kind wins
    */
    if (tiedRank == Rank.fullHouse) {
      return _evaluateFullHouseTie();
    }

    /*
      @case 1: Dealer's cards form the flush - results in a true tie
      @case 2: compare values of p1Hand and p2Hand in descending order
               whoever has the highest at hand[i] wins
    */
    if (tiedRank == Rank.flush) {
      return _evaluateFlushTie();
    }

    /*
      @case 1: Dealer's cards form the straight - results in a true tie
      @case 2: Combined 5-hand results in same card values but different suits
               This also results in a true tie
      @case 3: If dealer's cards alone do not form the straight,
               Compare the high card of the formed straight
      @attention: Ace can be low 1 or high 14
    */
    if (tiedRank == Rank.straight) {
      return _evaluateStraightTie();
    }

    /*
      @details: triple + 2 kicker cards
      @case 1: Same card values in triple and kicker, but different suits
               results in a true tie
      @case 2: The player with the higher 3 of a kind card value wins
      @case 3: The player with the higher first or second kicker wins
               P1 top kicker vs P2 top kicker 
               If they are equal then:
               P1 low kicker vs P2 low kicker
    */
    if (tiedRank == Rank.threeOfAKind) {
      return _evaluateThreeOfAKind();
    }

    /*
      @details: two pairs + 1 high kicker
      @case 1: Same two pairs card value and same kicker value. This is a tie
      @case 2: one of the pairs card value is greater or kicker value is greater
    */
    if (tiedRank == Rank.twoPair) {
      return _evaluateTwoPair();
    }

    /*
      @details: heavy kicker reliant hand. one pair + 3 kickers
      @case 1: results in a tie
               when both players have same pair and kicker values
      @case 2: higher pair or 1+ higher kicker
    */
    if (tiedRank == Rank.onePair) {
      return _evaluateOnePair();
    }

    if (tiedRank == Rank.highCard) {
      return _evaluateHighCard();
    }

    return -1;
  }

  // returns 0 if tie, 1 if p1 wins, 2 if p2 wins
  int _evaluateStraightFlushTie() {
    // @case 1
    int count = 1;
    DeckCard prev = dealerCards[0];
    for (int i = 1; i < dealerCards.length; i++) {
      DeckCard curr = dealerCards[i];
      if (prev.playingCard.suit == curr.playingCard.suit &&
          _getCardValueNum(prev.playingCard.value) + 1 ==
              _getCardValueNum(curr.playingCard.value)) {
        count++;
      }
    }
    if (count == dealerCards.length) {
      return 0;
    }

    // @case 2 and 3: all the same suit but different card values
    // @example - P1: 2, 6 && P2: 6, 7 && dealer: 3, 4, 5, J, Q
    // P2 wins because 7 is higher than 6 (high cards are compared)
    // step 1: get the straight flush hand for p1 and p2 (size 5 not 7)
    // step 2: compare the high card by doing array[size - 1] comparison

    // p1 straight flush hand
    List<DeckCard> p1StraightFlush = _findStraightFlushHand(playerOneCards);
    // p2 straight flush hand
    List<DeckCard> p2StraightFlush = _findStraightFlushHand(playerTwoCards);

    // both of them are sorted in descending order and are size 5
    for (int i = 0; i < p1StraightFlush.length; i++) {
      int p1CardValue = _getCardValueNum(p1StraightFlush[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2StraightFlush[i].playingCard.value);
      if (p1CardValue == p2CardValue) {
        continue;
      } else if (p1CardValue > p2CardValue) {
        return 1;
      } else {
        return 2;
      }
    }
    return 0;
  }

  // helper for _evaluateStraightFlushTie()
  List<DeckCard> _findStraightFlushHand(List<DeckCard> playerCards) {
    List<DeckCard> playerStraightFlushHand = [];
    // copy over dealer's cards
    for (int i = 0; i < dealerCards.length; i++) {
      playerStraightFlushHand.add(dealerCards[i]);
    }
    // copy over player 1's cards
    playerStraightFlushHand.add(playerCards[0]);
    playerStraightFlushHand.add(playerCards[1]);
    // sort in ascending order
    playerStraightFlushHand.sort((a, b) => _getCardValueNum(a.playingCard.value)
        .compareTo(_getCardValueNum(b.playingCard.value)));
    // remove 2 unnecessary cards
    Map<Suit, List<DeckCard>> sortedBySuit = {};
    // this removes anything not related to forming a flush
    for (DeckCard card in playerStraightFlushHand) {
      Suit suit = card.playingCard.suit;
      if (!sortedBySuit.containsKey(suit)) {
        sortedBySuit[suit] = [card];
      } else {
        // place the card at the start
        // this way the list is in descending order
        // this helps later to get the highest straight possible
        sortedBySuit[suit] = [card, ...sortedBySuit[suit]!];
      }
    }
    List<DeckCard> sortedRemovedNonFlush =
        sortedBySuit.values.firstWhere((value) => value.length >= 5);
    // this removes non-straight
    List<DeckCard> temp = [];
    int tempIndex = 0;
    temp.add(sortedRemovedNonFlush[sortedRemovedNonFlush.length - 1]);
    for (int i = sortedRemovedNonFlush.length - 2; i >= 0; i--) {
      // found the straight combo
      if (temp.length == 5) {
        break;
      }
      // if previous - 1 is not equal to current, reset temp
      if (_getCardValueNum(temp[tempIndex].playingCard.value) - 1 !=
          _getCardValueNum(sortedRemovedNonFlush[i].playingCard.value)) {
        temp.clear();
        tempIndex = 0;
      }
      temp.add(sortedRemovedNonFlush[i]);
      tempIndex++;
    }
    return temp;
  }

  int _evaluateFourOfAKindTie() {
    // they are both size 5 and structured the same way
    // quads followed by kicker
    List<DeckCard> p1Hand = _findFourOfAKindAndKicker(playerOneCards);
    List<DeckCard> p2Hand = _findFourOfAKindAndKicker(playerTwoCards);

    for (int i = 0; i < p1Hand.length; i++) {
      int p1CardValue = _getCardValueNum(p1Hand[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2Hand[i].playingCard.value);
      if (p1CardValue == p2CardValue) {
        continue;
      } else if (p1CardValue > p2CardValue) {
        return 1;
      } else {
        return 2;
      }
    }

    // if this point is reached, the value of the quads and kicker are the same
    // so this is a tie
    return 0;
  }

  // helper for _evaluateFourOfAKindTie()
  // Returns the quad combo and the highest card (kicker)
  // high card is not part of quad
  List<DeckCard> _findFourOfAKindAndKicker(List<DeckCard> playerCards) {
    Map<int, List<DeckCard>> sortedByCardValue = {};
    for (int i = 0; i < dealerCards.length; i++) {
      int cardValue = _getCardValueNum(dealerCards[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [dealerCards[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          dealerCards[i]
        ];
      }
    }
    for (int i = 0; i < playerCards.length; i++) {
      int cardValue = _getCardValueNum(playerCards[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [playerCards[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          playerCards[i]
        ];
      }
    }

    List<DeckCard> quads =
        sortedByCardValue.values.firstWhere((value) => value.length == 4);
    List<List<DeckCard>> potentialHighCards =
        sortedByCardValue.values.where((value) => value.length < 4).toList();
    // apparently has to be initialized to pass null check. "!" doesn't work
    DeckCard kicker = DeckCard(
      playingCard: PlayingCard(
        Suit.joker,
        CardValue.joker_1,
      ),
      showBack: true,
    );
    int highVal = 0;
    for (List<DeckCard> list in potentialHighCards) {
      int cardValue = _getCardValueNum(list[0].playingCard.value);
      if (cardValue > highVal) {
        kicker = list[0];
        highVal = cardValue;
      }
    }

    quads.add(kicker);
    return quads;
  }

  int _evaluateFullHouseTie() {
    List<DeckCard> p1Hand = _findFullHouseHand(playerOneCards);
    List<DeckCard> p2Hand = _findFullHouseHand(playerTwoCards);

    // both hands are size 5 and contain their best 3 of a kind and 2 of a kind
    int p1TripleCardValue = _getCardValueNum(p1Hand.first.playingCard.value);
    int p2TripleCardValue = _getCardValueNum(p2Hand.first.playingCard.value);

    if (p1TripleCardValue > p2TripleCardValue) {
      return 1;
    } else if (p1TripleCardValue < p2TripleCardValue) {
      return 2;
    } else {
      int p1PairCardValue = _getCardValueNum(p1Hand.last.playingCard.value);
      int p2PairCardValue = _getCardValueNum(p2Hand.last.playingCard.value);
      if (p1PairCardValue > p2PairCardValue) {
        return 1;
      } else if (p1PairCardValue < p2PairCardValue) {
        return 2;
      } else {
        return 0;
      }
    }
  }

// helper for _evaluateFullHouseTie()
// Step 1: Combbine the dealer's with player's hand
// Step 2: Take the highest 3 of a kind and add to result
// Step 3: Take the highest 2 of a kind and add to result
// return result
  List<DeckCard> _findFullHouseHand(List<DeckCard> playerCards) {
    Map<int, List<DeckCard>> sortedByCardValue = {};
    // Step 1
    for (int i = 0; i < dealerCards.length; i++) {
      int cardValue = _getCardValueNum(dealerCards[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [dealerCards[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          dealerCards[i]
        ];
      }
    }
    for (int i = 0; i < playerCards.length; i++) {
      int cardValue = _getCardValueNum(playerCards[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [playerCards[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          playerCards[i]
        ];
      }
    }

    List<DeckCard> result = [];
    // Step 2
    List<List<DeckCard>> allThrees =
        sortedByCardValue.values.where((value) => value.length == 3).toList();
    int highThreeIndex = 0;
    int highVal = 0;
    for (int i = 0; i < allThrees.length; i++) {
      if (_getCardValueNum(allThrees[i][0].playingCard.value) > highVal) {
        highThreeIndex = i;
        highVal = _getCardValueNum(allThrees[i][0].playingCard.value);
      }
    }
    for (int i = 0; i < allThrees[highThreeIndex].length; i++) {
      result.add(allThrees[highThreeIndex][i]);
    }

    // Step 3
    List<List<DeckCard>> allTwos =
        sortedByCardValue.values.where((value) => value.length == 2).toList();
    int highTwoIndex = 0;
    int highTwoVal = 0;
    for (int i = 0; i < allTwos.length; i++) {
      int cardValue = _getCardValueNum(allTwos[i][0].playingCard.value);
      if (cardValue > highTwoVal) {
        highTwoIndex = i;
        highTwoVal = cardValue;
      }
    }
    for (int i = 0; i < allTwos[highTwoIndex].length; i++) {
      result.add(allTwos[highTwoIndex][i]);
    }

    return result;
  }

  int _evaluateFlushTie() {
    // both are their best flush hands, size 5, and are in descending order
    List<DeckCard> p1Hand = _findFlushHand(playerOneCards);
    List<DeckCard> p2Hand = _findFlushHand(playerTwoCards);

    for (int i = 0; i < p1Hand.length; i++) {
      int p1CardValue = _getCardValueNum(p1Hand[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2Hand[i].playingCard.value);
      if (p1CardValue == p2CardValue) {
        continue;
      } else if (p1CardValue > p2CardValue) {
        return 1;
      } else {
        return 2;
      }
    }
    return 0;
  }

  // helper for _evaluateFlushTie()
  // Step 1: Combine Dealer's and Player's hand
  // Step 2: Order by Suit
  // Step 3: Extract the flush hand
  // Step 3: Sort by descending order
  // Step 4: Remove the last 2 cards
  List<DeckCard> _findFlushHand(List<DeckCard> playerHand) {
    // Step 1 & 2
    Map<Suit, List<DeckCard>> sortedBySuit = {};
    for (int i = 0; i < dealerCards.length; i++) {
      Suit suit = dealerCards[i].playingCard.suit;
      if (!sortedBySuit.containsKey(suit)) {
        sortedBySuit[suit] = [dealerCards[i]];
      } else {
        sortedBySuit[suit] = [...sortedBySuit[suit]!, dealerCards[i]];
      }
    }
    for (int i = 0; i < playerHand.length; i++) {
      Suit suit = playerHand[i].playingCard.suit;
      if (!sortedBySuit.containsKey(suit)) {
        sortedBySuit[suit] = [playerHand[i]];
      } else {
        sortedBySuit[suit] = [...sortedBySuit[suit]!, playerHand[i]];
      }
    }

    // Step 3
    List<DeckCard> flushHand =
        sortedBySuit.values.firstWhere((value) => value.length >= 5);

    // Step 4
    flushHand.sort((a, b) => _getCardValueNum(b.playingCard.value)
        .compareTo(_getCardValueNum(a.playingCard.value)));

    // Step 5
    if (flushHand.length == 5) {
      return flushHand;
    }

    if (flushHand.length == 6) {
      flushHand.removeLast();
      return flushHand;
    }

    flushHand.removeLast();
    return flushHand;
  }

  int _evaluateStraightTie() {
    // both hands are size 5 and composed of their best straight combo
    List<DeckCard> p1Hand = _findStraightHand(playerOneCards);
    List<DeckCard> p2Hand = _findStraightHand(playerTwoCards);

    for (int i = 0; i < p1Hand.length; i++) {
      int p1CardValue = _getCardValueNum(p1Hand[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2Hand[i].playingCard.value);

      if (p1CardValue > p2CardValue) {
        return 1;
      } else if (p1CardValue < p2CardValue) {
        return 2;
      } else {
        continue;
      }
    }
    return 0;
  }

  // helper for _evaluateStraightTie()
  // Step 1: combine Dealer's and Player's Hand
  // Step 2: sort in descending order
  // Step 3: Find the best straight card combo
  List<DeckCard> _findStraightHand(List<DeckCard> playerHand) {
    // Step 1
    List<DeckCard> straightHand = [];
    for (int i = 0; i < dealerCards.length; i++) {
      straightHand.add(dealerCards[i]);
    }
    straightHand.add(playerHand[0]);
    straightHand.add(playerHand[1]);

    // Step 2
    straightHand.sort((a, b) => _getCardValueNum(b.playingCard.value)
        .compareTo(_getCardValueNum(a.playingCard.value)));
    // Ace can be high 14 or low 1
    if (straightHand[0].playingCard.value == CardValue.ace) {
      straightHand.add(straightHand[0]);
    }

    // Step 3
    List<DeckCard> bestStraightHand = [];
    int prev = _getCardValueNum(straightHand[0].playingCard.value);
    bestStraightHand.add(straightHand[0]);
    for (int i = 1; i < straightHand.length; i++) {
      if (bestStraightHand.length == 5) {
        break;
      }
      int curr = _getCardValueNum(straightHand[i].playingCard.value);
      if (prev - 1 == curr) {
        bestStraightHand.add(straightHand[i]);
      } else {
        bestStraightHand.clear();
      }
      prev = curr;
    }

    return bestStraightHand;
  }

  int _evaluateThreeOfAKind() {
    // both hands are size 5 and have their best triple and 2 kickers
    List<DeckCard> p1Hand = _findThreeOfAKindHand(playerOneCards);
    List<DeckCard> p2Hand = _findThreeOfAKindHand(playerTwoCards);

    // only really need to compare 0th, 4th, and 5th index
    // b/c it's [tripleCard, tripleCard, tripleCard, topKicker, 2ndTopKicker]
    for (int i = 0; i < p1Hand.length; i++) {
      int p1CardValue = _getCardValueNum(p1Hand[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2Hand[i].playingCard.value);
      if (p1CardValue > p2CardValue) {
        return 1;
      } else if (p1CardValue < p2CardValue) {
        return 2;
      } else {
        continue;
      }
    }

    return 0;
  }

  // helper for _evaluateThreeOfAKind()
  // Step 1: Combine Dealer's and Player's hand by card value
  // Step 2: Find the best triple (triple with the highest rank)
  // Step 3: Find the top 2 card values to set as the 2 kickers
  // @details: result will be
  //           [tripleCard, tripleCard, tripleCard, topKicker, 2ndTopKicker]
  List<DeckCard> _findThreeOfAKindHand(List<DeckCard> playerHand) {
    List<DeckCard> result = [];
    Map<int, List<DeckCard>> sortedByCardValue = {};

    // Step 1
    for (int i = 0; i < dealerCards.length; i++) {
      int cardValue = _getCardValueNum(dealerCards[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [dealerCards[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          dealerCards[i]
        ];
      }
    }
    for (int i = 0; i < playerHand.length; i++) {
      int cardValue = _getCardValueNum(playerHand[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [playerHand[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          playerHand[i]
        ];
      }
    }

    // Step 2 (we know there can be at most 2 triples)
    List<List<DeckCard>> triples =
        sortedByCardValue.values.where((value) => value.length == 3).toList();
    if (triples.length > 1) {
      if (_getCardValueNum(triples[0][0].playingCard.value) >
          _getCardValueNum(triples[1][0].playingCard.value)) {
        result.add(triples[0][0]);
        result.add(triples[0][1]);
        result.add(triples[0][2]);
      } else {
        result.add(triples[1][0]);
        result.add(triples[1][1]);
        result.add(triples[1][2]);
      }
    } else {
      result.add(triples[0][0]);
      result.add(triples[0][1]);
      result.add(triples[0][2]);
    }

    // Step 3
    int tripleCardValue = _getCardValueNum(result[0].playingCard.value);
    List<DeckCard> combined = [];
    for (int i = 0; i < dealerCards.length; i++) {
      combined.add(dealerCards[i]);
    }
    for (int i = 0; i < playerHand.length; i++) {
      combined.add(playerHand[i]);
    }
    // sort by descending order
    combined.sort((a, b) => _getCardValueNum(b.playingCard.value)
        .compareTo(_getCardValueNum(a.playingCard.value)));
    for (int i = 0; i < combined.length; i++) {
      if (result.length == 5) {
        break;
      }
      int cardValue = _getCardValueNum(combined[i].playingCard.value);
      if (cardValue != tripleCardValue) {
        result.add(combined[i]);
      }
    }

    return result;
  }

  int _evaluateTwoPair() {
    // both hands are size 5 and have their best two pair and one kicker
    List<DeckCard> p1Hand = _findBestTwoPair(playerOneCards);
    List<DeckCard> p2Hand = _findBestTwoPair(playerTwoCards);

    for (int i = 0; i < p1Hand.length; i++) {
      int p1CardValue = _getCardValueNum(p1Hand[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2Hand[i].playingCard.value);

      if (p1CardValue > p2CardValue) {
        return 1;
      } else if (p2CardValue < p2CardValue) {
        return 2;
      } else {
        continue;
      }
    }

    return 0;
  }

  // Step 1: Combine Dealer's and Player's hands by card value
  // Step 2: Add the highest pair card values in result
  //         (there can be 3 pairs, so find the two highest pairs)
  // Step 3: Find the highest kicker value not part of the result array
  List<DeckCard> _findBestTwoPair(List<DeckCard> playerHand) {
    List<DeckCard> result = [];
    Map<int, List<DeckCard>> sortedByCardValue = {};

    // Step 1
    for (int i = 0; i < dealerCards.length; i++) {
      int cardValue = _getCardValueNum(dealerCards[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [dealerCards[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          dealerCards[i]
        ];
      }
    }
    for (int i = 0; i < playerHand.length; i++) {
      int cardValue = _getCardValueNum(playerHand[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [playerHand[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          playerHand[i]
        ];
      }
    }

    // Step 2: There can be at most 3 pairs, but we can only form 2
    List<List<DeckCard>> pairs =
        sortedByCardValue.values.where((value) => value.length == 2).toList();
    // have 3 pairs
    if (pairs.length == 3) {
      result.add(pairs[2][0]);
      result.add(pairs[2][1]);
    }
    result.add(pairs[0][0]);
    result.add(pairs[0][1]);
    result.add(pairs[1][0]);
    result.add(pairs[1][1]);

    if (pairs.length == 3) {
      // sort in descending
      result.sort((a, b) => _getCardValueNum(b.playingCard.value)
          .compareTo(_getCardValueNum(a.playingCard.value)));
      // remove the lowest pair
      result.removeLast();
      result.removeLast();
    }

    // Step 3
    int firstTwoPairValue = _getCardValueNum(result[0].playingCard.value);
    int secondTwoPairValue = _getCardValueNum(result[3].playingCard.value);
    List<DeckCard> combined = [];
    for (int i = 0; i < dealerCards.length; i++) {
      combined.add(dealerCards[i]);
    }
    for (int i = 0; i < playerHand.length; i++) {
      combined.add(playerHand[i]);
    }
    // sort by descending order
    combined.sort((a, b) => _getCardValueNum(b.playingCard.value)
        .compareTo(_getCardValueNum(a.playingCard.value)));
    // here result.length = 4
    for (int i = 0; i < combined.length; i++) {
      if (result.length == 5) {
        break;
      }
      int cardValue = _getCardValueNum(combined[i].playingCard.value);
      if (cardValue != firstTwoPairValue && cardValue != secondTwoPairValue) {
        result.add(combined[i]);
      }
    }

    return result;
  }

  int _evaluateOnePair() {
    // both hands are size 5 and contain best pair + 3 best kickers
    List<DeckCard> p1Hand = _findBestOnePair(playerOneCards);
    List<DeckCard> p2Hand = _findBestOnePair(playerTwoCards);

    for (int i = 0; i < p1Hand.length; i++) {
      int p1CardValue = _getCardValueNum(p1Hand[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2Hand[i].playingCard.value);

      if (p1CardValue > p2CardValue) {
        return 1;
      } else if (p1CardValue < p2CardValue) {
        return 2;
      } else {
        continue;
      }
    }

    return 0;
  }

  // Finds the best pair and 3 best kickers not part of pair
  // We know that there is only one pair and the other 3 have to be kickers
  // Step 1: combine Dealer's and Player's cards by card value to find pair
  // Step 2: add the pair to result
  // Step 3: combine Dealer's and Player's cards and sort in descending order
  // Step 4: start from index 0
  //         if they're not the pair's card value add to result
  // Step 5: Return result when best hand is found (size 5)
  List<DeckCard> _findBestOnePair(List<DeckCard> playerHand) {
    List<DeckCard> result = [];
    Map<int, List<DeckCard>> sortedByCardValue = {};

    // Step 1
    for (int i = 0; i < dealerCards.length; i++) {
      int cardValue = _getCardValueNum(dealerCards[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [dealerCards[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          dealerCards[i]
        ];
      }
    }
    for (int i = 0; i < playerHand.length; i++) {
      int cardValue = _getCardValueNum(playerHand[i].playingCard.value);
      if (!sortedByCardValue.containsKey(cardValue)) {
        sortedByCardValue[cardValue] = [playerHand[i]];
      } else {
        // place the card at the end; order doesn't matter
        sortedByCardValue[cardValue] = [
          ...sortedByCardValue[cardValue]!,
          playerHand[i]
        ];
      }
    }

    // Step 2
    List<DeckCard> pair =
        sortedByCardValue.values.firstWhere((value) => value.length == 2);
    result.add(pair[0]);
    result.add(pair[1]);

    // Step 3
    int firstPairValue = _getCardValueNum(result[0].playingCard.value);
    int secondPairValue = _getCardValueNum(result[1].playingCard.value);
    List<DeckCard> combined = [];
    for (int i = 0; i < dealerCards.length; i++) {
      combined.add(dealerCards[i]);
    }
    for (int i = 0; i < playerHand.length; i++) {
      combined.add(playerHand[i]);
    }
    // sort by descending order
    combined.sort((a, b) => _getCardValueNum(b.playingCard.value)
        .compareTo(_getCardValueNum(a.playingCard.value)));
    for (int i = 0; i < combined.length; i++) {
      if (result.length == 5) {
        break;
      }
      int cardValue = _getCardValueNum(combined[i].playingCard.value);
      if (cardValue != firstPairValue && cardValue != secondPairValue) {
        result.add(combined[i]);
      }
    }

    return result;
  }

  int _evaluateHighCard() {
    // both hands are size 5 and are sorted in descending order
    List<DeckCard> p1Hand = _findBestFiveHighCards(playerOneCards);
    List<DeckCard> p2Hand = _findBestFiveHighCards(playerTwoCards);

    for (int i = 0; i < p1Hand.length; i++) {
      int p1CardValue = _getCardValueNum(p1Hand[i].playingCard.value);
      int p2CardValue = _getCardValueNum(p2Hand[i].playingCard.value);

      if (p1CardValue > p2CardValue) {
        return 1;
      } else if (p1CardValue < p2CardValue) {
        return 2;
      } else {
        continue;
      }
    }

    return 0;
  }

  // returns 5 best cards formed from combining Dealer's and Player's hand
  // Step 1: combine Dealer's and Player's hand into one list
  // Step 2: sort in descending card value order
  // Step 3: return the first 5 cards in the sorted combined list
  List<DeckCard> _findBestFiveHighCards(List<DeckCard> playerHand) {
    // Step 1
    List<DeckCard> combined = [];
    for (DeckCard card in dealerCards) {
      combined.add(card);
    }
    for (DeckCard card in playerHand) {
      combined.add(card);
    }

    // Step 2: sort by descending order
    combined.sort((a, b) => _getCardValueNum(b.playingCard.value)
        .compareTo(_getCardValueNum(a.playingCard.value)));

    // Step 3
    return combined.take(5).toList();
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
