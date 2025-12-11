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
        bool payed;
        Blackjack game;
    }
    mapping(uint256 => Session) sessions;
    mapping(uint256 => bool) sessionExists;
    uint256 id;

    uint256 constant VERIFY_DURATION = 120 seconds;

    function verifyGame(uint256 _id, Blackjack _game, bytes32 initialRandom) external {
        id = _id;
        sessionExists[id] = true;
        Session storage session = sessions[id];
        session.startTime = block.timestamp;
        session.game = _game;

        session.finalAnchor = _game.getAnchor();
        session.initialRandom = initialRandom;
        session.payed = false;
    }

    function verifyAnchor(uint256 _id, bytes32 salt, uint256 length) external {
        require(sessionExists[id], "session does not exist");
        require(sessions[_id].startTime + VERIFY_DURATION >= block.timestamp, "verify period is over");
        require(msg.sender == sessions[_id].house, "only house allowed");
        bytes32 tempHash = keccak256(abi.encodePacked(sessions[_id].initialRandom, salt));
        for (uint256 i = 0; i < length; i++) {
            tempHash = keccak256(abi.encodePacked(tempHash));
        }

        require(tempHash == sessions[id].finalAnchor, "final anchor does not match calulated one");
        sessions[_id].anchorVerified = true;
    }

    function resolveGame(uint256 _id) external {
        require(sessionExists[id], "session does not exist");
        require(sessions[_id].startTime + VERIFY_DURATION >= block.timestamp, "verify period is over");
        require(sessions[_id].startTime + VERIFY_DURATION < block.timestamp, "verify period has not started");
        require(!sessions[_id].payed, "game can already be payed out");
        if (sessions[_id].anchorVerified) {
            _resolveGame(_id);
        } else {
            Blackjack blackjack = Blackjack(address(sessions[_id].game));
            uint256 playerCount = blackjack.getGamePlayerCount(_id);

            for (uint256 i = 0; i < playerCount; i++) {
                (address addr, uint256 bet,,) = blackjack.getPlayerResolveView(_id, i);
                (bool success,) = payable(addr).call{value: bet}("");
                require(success, "Refund transfer failed");
            }
        }
        sessions[_id].payed = true;
    }

    function _resolveGame(uint256 _id) internal {
        Blackjack blackjack = Blackjack(address(sessions[_id].game));

        uint256 dealerTotal = blackjack.getDealerTotal(_id);
        bool dealerBusted = dealerTotal > 21;

        bool dealerBlackjack = dealerTotal == 21 && blackjack.getDealerCardCount(_id) == 2;

        uint256 playerCount = blackjack.getGamePlayerCount(id);

        for (uint256 i = 0; i < playerCount; i++) {
            (address addr, uint256 bet, uint256 handTotal, Blackjack.PlayerStatus status) =
                blackjack.getPlayerResolveView(_id, i);

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

    function getPhase(uint256 _id) external view returns (uint256) {
        if (sessions[_id].startTime + VERIFY_DURATION >= block.timestamp) {
            return 0;
        } else {
            return 1;
        }
    }
    receive() external payable {}
}

