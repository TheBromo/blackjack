// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Setup.sol" as st;

contract BlackjackController {
    address immutable HOUSE;
    enum Phase {
        Setup,
        Game,
        Verification
    }
    Phase currentPhase;
    uint256 roundId;
    uint256 startTime;
    st.Setup setup;

    modifier onlyHouse() {
        _onlyHouse();
        _;
    }

    function _onlyHouse() internal view {
        require(msg.sender != HOUSE, "only house allowed");
    }

    constructor() {
        HOUSE = msg.sender;
        setup = new st.Setup(HOUSE, address(0)); //TODO: set winning addr to verify
    }

    function start() external onlyHouse {
        startTime = block.timestamp;
    }

    function timedTransition() internal {
        if (block.timestamp > startTime + setup.TOTAL_DURATION()) {
            nextPhase();
        }
    }

    function nextPhase() internal onlyHouse {
        if (currentPhase == Phase.Setup) {
            bytes32 anchor = setup.anchor();
            require(anchor != 0, "anchor not set");
            address[] memory players = setup.participants();
            require(players.length != 0, "no players set");

            //TODO: init game
            currentPhase = Phase.Game;
        } else if (currentPhase == Phase.Game) {
            currentPhase = Phase.Verification;
        } else if (currentPhase == Phase.Verification) {
            //reset
            currentPhase = Phase.Setup;
            roundId++;
        }
    }
}

