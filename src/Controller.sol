// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Setup.sol" as st;
import "./Game.sol" as g;

contract BlackjackController {
    address immutable HOUSE;
    enum Phase {
        Setup,
        Game,
        Verification
    }
    Phase currentPhase;
    uint256 roundId;
    st.Setup public setup;
    g.Blackjack public game;

    modifier onlyHouse() {
        _onlyHouse();
        _;
    }

    function _onlyHouse() internal view {
        require(msg.sender == HOUSE, "only house allowed");
    }

    constructor() {
        HOUSE = msg.sender;
        setup = new st.Setup(HOUSE, address(0), address(this)); //TODO: set winning addr to verify
        game = new g.Blackjack(address(this));
        currentPhase = Phase.Setup;
        reset();
    }

    function getPhase() external view returns (Phase) {
        return currentPhase;
    }

    function startGame() public onlyHouse {
        address[] memory players = setup.participants();
        if (players.length == 0) {
            reset();
            return;
        }
        bytes32 anchor = setup.anchor();
        require(anchor != 0, "anchor not set");
        game.createGame(players, anchor);
        currentPhase = Phase.Game;
    }

    function reset() public onlyHouse {
        roundId++;
        setup.start(roundId);
        currentPhase = Phase.Setup;
    }
}

