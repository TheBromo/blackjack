// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Game.sol";

contract Verify {
    struct Session {
        address house;
        bytes32 finalAnchor;
        bytes32 initialRandom;
        bool anchorVerified;
        uint256 startTime;
        Blackjack game;
    }
    mapping(uint256 => Session) sessions;
    uint256 id;

    uint256 constant VERIFY_DURATION = 120 seconds;

    function verifyGame(uint256 _id, Blackjack _game, bytes32 initialRandom, bytes32 anchor) external {
        id = _id;
        Session storage session = sessions[id];
        session.startTime = block.timestamp;
        session.game = _game;

        session.finalAnchor = anchor;
        session.initialRandom = initialRandom;
    }

    function verifyAnchor(bytes32 salt, uint256 length) external {
        require(sessions[id].startTime + VERIFY_DURATION >= block.timestamp, "verify period is over");
        require(msg.sender == sessions[id].house, "only house allowed");
        bytes32 tempHash = keccak256(abi.encodePacked(sessions[id].initialRandom, salt));
        for (uint256 i = 0; i < length; i++) {
            tempHash = keccak256(abi.encodePacked(tempHash));
        }

        require(tempHash == sessions[id].finalAnchor, "final anchor does not match calulated one");
        sessions[id].anchorVerified = true;
    }

    function resolveGame() external {
        require(sessions[id].startTime + VERIFY_DURATION < block.timestamp, "verify period has not started");
        if (sessions[id].anchorVerified) {
            _resolveGame();
        } else {
            Blackjack blackjack = Blackjack(address(sessions[id].game));
            uint256 playerCount = blackjack.getGamePlayerCount(id);

            for (uint256 i = 0; i < playerCount; i++) {
                (address addr, uint256 bet,,) = blackjack.getPlayerResolveView(id, i);
                (bool success,) = payable(addr).call{value: bet}("");
                require(success, "Refund transfer failed");
            }
        }
    }

    function _resolveGame() internal {
        Blackjack blackjack = Blackjack(address(sessions[id].game));

        uint256 dealerTotal = blackjack.getDealerTotal(id);
        bool dealerBusted = dealerTotal > 21;

        bool dealerBlackjack = dealerTotal == 21 && blackjack.getDealerCardCount(id) == 2;

        uint256 playerCount = blackjack.getGamePlayerCount(id);

        for (uint256 i = 0; i < playerCount; i++) {
            (address addr, uint256 bet, uint256 handTotal, Blackjack.PlayerStatus status) =
                blackjack.getPlayerResolveView(id, i);

            uint256 payout = 0;
            bool won = false;

            if (status == Blackjack.PlayerStatus.BUSTED) {
                won = false;
            } else if (status == Blackjack.PlayerStatus.BLACKJACK) {
                if (dealerBlackjack) {
                    payout = bet;
                } else {
                    payout = bet + (bet * 3) / 2;
                    won = true;
                }
            } else if (dealerBusted) {
                payout = bet * 2;
                won = true;
            } else if (handTotal > dealerTotal) {
                payout = bet * 2;
                won = true;
            } else if (handTotal == dealerTotal) {
                payout = bet;
            }

            if (payout > 0) {
                (bool success,) = payable(addr).call{value: payout}("");
                require(success, "Payout transfer failed");
            }
        }
    }
}

