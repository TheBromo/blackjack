// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Game.sol";
import "./EfficientHashLib.sol";
// import {console} from "forge-std/console.sol";

library Helper {
    // using Helper for Blackjack.Game;
    event CardPlayed(bytes32 seed, Blackjack.Card card);
    event DealerResult(uint256 score, Blackjack.Hand hand);
    event PlayerResult(uint256 score, Blackjack.Hand hand);

    function _dealCardToPlayer(Blackjack.Game storage game, bytes32 seed, Blackjack.PlayerState storage player)
        internal
    {
        // console.log("deal card player");
        Blackjack.Card memory card = _drawCard(game, seed);
        player.hand.cards.push(card);
        _updateHandTotal(player.hand, card);
        emit CardPlayed(seed, card);
    }

    function _dealCardToDealer(Blackjack.Game storage game, bytes32 seed) internal {
        // console.log("deal card dealer");
        Blackjack.Card memory card = _drawCard(game, seed);
        game.dealerHand.cards.push(card);
        _updateHandTotal(game.dealerHand, card);
        emit CardPlayed(seed, card);
    }

    function _drawCard(Blackjack.Game storage game, bytes32 seed) internal returns (Blackjack.Card memory) {
        // console.log("draw card");
        uint256 rand = uint256(keccak256(abi.encodePacked(seed, ++game.cardCount)));

        uint8 value = uint8((rand % 13) + 1); // 1-13
        uint8 suit = uint8((rand / 13) % 4); // 0-3

        return Blackjack.Card({value: value, suit: suit});
    }

    function _updateHandTotal(Blackjack.Hand storage hand, Blackjack.Card memory card) internal {
        // console.log("update hand total");
        uint8 cardValue;

        if (card.value == 1) {
            // Ace
            cardValue = 11;
            hand.hasUsableAce = true;
        } else if (card.value > 10) {
            // Face cards (J, Q, K)
            cardValue = 10;
        } else {
            cardValue = card.value;
        }

        hand.total += cardValue;

        // Adjust for ace if busted
        if (hand.total > 21 && hand.hasUsableAce) {
            hand.total -= 10;
            hand.hasUsableAce = false;
        }
    }
}
