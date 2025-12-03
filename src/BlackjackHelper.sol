// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Blackjack.sol";
import "./EfficientHashLib.sol";

library Helper {
    using Helper for Blackjack.Game;

    function _resolveGame(Blackjack.Game storage game) internal {
        game.stage = Blackjack.Stages.FINISHED;

        uint8 dealerTotal = 1; //game.dealerHand.total;
        bool dealerBusted = dealerTotal > 21;
        bool dealerBlackjack = dealerTotal == 21 && game.dealerHand.cards.length == 2;

        for (uint256 i = 0; i < game.players.length; i++) {
            Blackjack.PlayerState storage player = game.players[i];

            uint256 payout = 0;
            bool won = false;

            if (player.status == Blackjack.PlayerStatus.BUSTED) {
                won = false;
            } else if (player.status == Blackjack.PlayerStatus.BLACKJACK) {
                if (dealerBlackjack) {
                    payout = player.bet;
                } else {
                    payout = player.bet + (player.bet * 3) / 2;
                    won = true;
                }
            } else if (dealerBusted) {
                payout = player.bet * 2;
                won = true;
            } else if (player.hand.total > dealerTotal) {
                payout = player.bet * 2;
                won = true;
            } else if (player.hand.total == dealerTotal) {
                payout = player.bet;
            }

            // ------------- Payout if needed -------------
            if (payout > 0) {
                (bool success,) = payable(player.addr).call{value: payout}("");
                require(success, "Payout transfer failed");
            }
        }
    }

    function _dealCardToPlayer(Blackjack.Game storage game, uint256 seed, Blackjack.PlayerState storage player)
        internal
    {
        Blackjack.Card memory card = _drawCard(game, seed);
        player.hand.cards.push(card);
        _updateHandTotal(player.hand, card);
    }

    function _dealCardToDealer(Blackjack.Game storage game, uint256 seed) internal {
        Blackjack.Card memory card = _drawCard(game, seed);
        game.dealerHand.cards.push(card);
        _updateHandTotal(game.dealerHand, card);
    }

    function _drawCard(Blackjack.Game storage game, uint256 seed) internal returns (Blackjack.Card memory) {
        uint256 rand = uint256(EfficientHashLib.hash(seed, ++game.cardCount));

        uint8 value = uint8((rand % 13) + 1); // 1-13
        uint8 suit = uint8((rand / 13) % 4); // 0-3

        return Blackjack.Card({value: value, suit: suit});
    }

    function _updateHandTotal(Blackjack.Hand storage hand, Blackjack.Card memory card) internal {
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
