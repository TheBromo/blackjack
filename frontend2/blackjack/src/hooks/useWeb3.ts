import { useState, useEffect } from 'react';
import Web3 from 'web3';
import { Contract } from 'web3-eth-contract';

import ControllerArtifact from '../abis/Controller.sol/BlackjackController.json';
import SetupArtifact from '../abis/Setup.sol/Setup.json';
import CRR2Artifact from '../abis/CRR2.sol/CommitReveal2.json';
import GameArtifact from '../abis/Game.sol/Blackjack.json';

const CONTROLLER_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const LOCAL_PROVIDER_URL = "http://127.0.0.1:8545";

export const useWeb3 = () => {
    const [web3, setWeb3] = useState<Web3 | null>(null);
    const [account, setAccount] = useState<string | null>(null);
    const [contracts, setContracts] = useState<{
        controller: Contract<any> | null;
        setup: Contract<any> | null;
        cr2: Contract<any> | null;
        game: Contract<any> | null;
    }>({ controller: null, setup: null, cr2: null, game: null });

    useEffect(() => {
        const init = async () => {
            // Using local provider as primary requirement implies local node interaction
            const w3 = new Web3(new Web3.providers.HttpProvider(LOCAL_PROVIDER_URL));
            setWeb3(w3);

            // Get accounts
            try {
                // For local anvil/hardhat node, we can access accounts directly
                // In a real Metamask set up we'd use window.ethereum
                const accounts = await w3.eth.getAccounts();
                if (accounts.length > 0) {
                    // Use the last account to act as player (assuming 0 is deployer/house)
                    // or just use 0 if it's a test script style
                    // example.py uses CLIENT_PK which implies a specific account. 
                    // We'll use the first one available or let user choose later.
                    // For now, let's pick index 1 to be different from Deployer if possible, else 0.
                    const playerIdx = accounts.length > 1 ? 1 : 0;
                    setAccount(accounts[playerIdx]);
                }
            } catch (e) {
                console.error("Could not fetch accounts", e);
            }

            // Init Controller
            try {
                const controller = new w3.eth.Contract(ControllerArtifact.abi as any, CONTROLLER_ADDRESS);

                // Fetch dependent addresses
                const setupAddress = String(await controller.methods.setup().call());
                const gameAddress = String(await controller.methods.game().call());

                const setup = new w3.eth.Contract(SetupArtifact.abi as any, setupAddress);
                const game = new w3.eth.Contract(GameArtifact.abi as any, gameAddress);

                // Fetch CR2 from Setup
                const cr2Address = String(await setup.methods.cr().call());
                const cr2 = new w3.eth.Contract(CRR2Artifact.abi as any, cr2Address);

                setContracts({ controller, setup, cr2, game });
                console.log("Contracts loaded:", { controller, setup, cr2, game });

            } catch (error) {
                console.error("Failed to load contracts:", error);
            }
        };

        init();
    }, []);

    return { web3, account, contracts };
};
