// the win condition ranks ordered from highest to lowest
enum Rank {
  royalFlush, // combines straight, flush, and (10, J, Q, K, A)
  straightFlush, // combines straight and flush
  fourOfAKind,
  // fullHouse is 3 of a kind + 2 of a kind
  // the suit of 3 of a kind is stronger
  // that means Q Q Q 3 3 > J J J A A
  fullHouse,
  flush, // same suit, but not in a particular order
  straight, // ordered, but not all the same suit
  threeOfAKind, // same card values but not necessarily suit
  twoPair, // 2 of a kind, same card values but not necessarily suit
  onePair,
  highCard,
}
