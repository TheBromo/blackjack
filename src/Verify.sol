// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Game.sol";
import {console} from "forge-std/console.sol";

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

    uint256 constant VERIFY_DURATION = 12 seconds;
    event DebugLog(string message, uint256 val);
    event DebugBytes(string message, bytes32 val);

    function verifyGame(uint256 _id, address _game, bytes32 initialRandom) external {
        id = _id;
        sessionExists[_id] = true;
        Session storage session = sessions[_id];
        session.startTime = block.timestamp;
        session.game = Blackjack(_game);
        session.house = session.game.HOUSE();

        session.finalAnchor = session.game.getAnchor();
        session.initialRandom = initialRandom;
        session.payed = false;
    }

    function verifyAnchor(uint256 _id, bytes32 salt, uint256 length) external {
        console.log("verifying anchor", sessionExists[_id]);

        require(sessionExists[_id], "session does not exist");

        console.log("sessoin exists", sessions[_id].startTime + VERIFY_DURATION >= block.timestamp);

        require(sessions[_id].startTime + VERIFY_DURATION >= block.timestamp, "verify period is over");

        console.log("verify period not over", msg.sender == sessions[_id].house);

        require(msg.sender == sessions[_id].house, "only house allowed");

        console.log("nto hopuse");

        console.log(uint256(sessions[_id].initialRandom), uint256(salt));

        bytes32 tempHash = keccak256(abi.encodePacked(sessions[_id].initialRandom, salt));

        console.log("first hash", uint256(tempHash));

        console.log("length", length);

        for (uint256 i = 0; i < length; i++) {
            tempHash = keccak256(abi.encodePacked(tempHash));
            console.log(uint256(tempHash));
        }

        require(tempHash == sessions[_id].finalAnchor, "final anchor does not match calulated one");

        console.log("hash matches");

        sessions[_id].anchorVerified = true;
    }

    function resolveGame(uint256 _id) external {
        require(sessionExists[_id], "session does not exist");
        require(sessions[_id].startTime + VERIFY_DURATION <= block.timestamp, "verify has not started");
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

