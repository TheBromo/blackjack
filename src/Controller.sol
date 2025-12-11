// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Setup.sol" as st;
import "./Game.sol" as g;
import "./Verify.sol" as v;

contract BlackjackController {
    address immutable HOUSE;
    enum Phase {
        Setup,
        Game,
        Verification
    }
    Phase currentPhase;
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
        currentPhase = Phase.Setup;
        reset();
    }

    function getPhase() external view returns (Phase) {
        return currentPhase;
    }

    function startGame() public onlyHouse {
        require(currentPhase == Phase.Setup, "must be in setup phase to start game");
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

    function verifyGame() public {
        require(currentPhase == Phase.Game);
        bytes32 initial = setup.getFinalRandom();
        verify.verifyGame(roundId, game, initial);
        currentPhase = Phase.Verification;
    }

    function reset() public onlyHouse {
        roundId++;
        setup.start(roundId);
        currentPhase = Phase.Setup;
    }
}

