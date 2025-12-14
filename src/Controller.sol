// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Setup.sol" as st;
import "./Game.sol" as g;
import "./Verify.sol" as v;
// import {console} from "forge-std/console.sol";

contract BlackjackController {
    address immutable HOUSE;
    enum Phase {
        Setup,
        Game,
        Verification
    }
    Phase phase;
    uint256 public roundId;
    st.Setup public setup;
    g.Blackjack public game;
    v.Verify public verify;

    modifier onlyHouse() {
        _onlyHouse();
        _;
    }

    function _onlyHouse() internal view {
        require(msg.sender == HOUSE, "only house allowed");
    }

    constructor() {
        HOUSE = msg.sender;
        verify = new v.Verify();
        setup = new st.Setup(HOUSE, address(verify), address(this)); //TODO: set winning addr to verify
        game = new g.Blackjack(HOUSE, address(this));
        phase = Phase.Setup;
        reset();
    }

    function startGame() public onlyHouse {
        require(phase == Phase.Setup, "must be in setup phase to start game");
        address[] memory players = setup.participants();
        if (players.length == 0) {
            reset();
            return;
        }
        for (uint256 index = 0; index < players.length; index++) {
            // console.log("adding player", players[index]);
        }
        phase = Phase.Game;
        bytes32 anchor = setup.anchor();
        require(anchor != 0, "anchor not set+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
        game.createGame(players, anchor);
        phase = Phase.Game;
        require(anchor != 0, "anchor not set");
    }

    function verifyGame() public {
        // console.log("------------------------------------------------------------------------------ verifying game");
        // require(phase == Phase.Game, "current phase not game");
        bytes32 initial = setup.getFinalRandom();
        // console.log("initial random", uint256(initial));
        verify.verifyGame(roundId, address(game), initial);
        phase = Phase.Verification;
    }

    function reset() public onlyHouse {
        // console.log("------------------------------------------------------------------------------ rest ");
        roundId++;
        setup.start(roundId);
        phase = Phase.Setup;
    }

    function getPhase() public view returns (Phase) {
        return phase;
    }
}

