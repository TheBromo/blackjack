import { useState, useEffect } from 'react';


export const Phase = {
    SETUP: 0,
    GAME: 1,
    VERIFY: 2,
    LOADING: -1
} as const;

export type PhaseType = typeof Phase[keyof typeof Phase];

export const useGameState = (contracts: any) => {
    const [phase, setPhase] = useState<PhaseType>(Phase.LOADING);
    const [roundId, setRoundId] = useState<number>(0);

    useEffect(() => {
        if (!contracts.controller) return;

        const pollPhase = async () => {
            try {
                const currentPhase = await contracts.controller.methods.getPhase().call();
                // Check if we need to convert BigInt to number (web3 4.x returns BigInt often)
                const p = Number(currentPhase) as PhaseType;
                setPhase(p);

                const rid = await contracts.controller.methods.roundId().call();
                setRoundId(Number(rid));
            } catch (error) {
                console.error("Error polling phase:", error);
            }
        };

        const interval = setInterval(pollPhase, 2000);
        pollPhase(); // initial call

        return () => clearInterval(interval);
    }, [contracts.controller]);

    return { phase, roundId };
};
