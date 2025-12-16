import React, { useState } from 'react';
import { makeCommit } from '../utils/crypto';
import { waitForSetupPhase, waitForCR2Phase } from '../utils/waitForPhase';

interface Props {
    contracts: any;
    account: string | null;
    web3: any;
}

export const SetupPhase: React.FC<Props> = ({ contracts, account, web3 }) => {
    const [status, setStatus] = useState("Idle");
    const [loading, setLoading] = useState(false);

    const handleJoin = async () => {
        if (!contracts.setup || !contracts.cr2 || !account || !web3) return;
        setLoading(true);

        try {
            // Wait for BETTING phase (0)
            setStatus("Waiting for betting phase...");
            await waitForSetupPhase(contracts.setup, 0, "BETTING");

            // 1. Bet
            setStatus("Betting (1 ETH)...");
            const betTx = await contracts.setup.methods.bet().send({
                from: account,
                value: web3.utils.toWei('1', 'ether'),
                gas: 500000
            });
            console.log("Bet tx:", betTx);

            // Wait for RNG phase (1)
            setStatus("Waiting for RNG phase...");
            await waitForSetupPhase(contracts.setup, 1, "RNG");

            // 2. Generate Secret
            const { s, co, cv } = makeCommit();
            localStorage.setItem(`blackjack_secret_${account}`, s);
            console.log("Generated commitment - cv:", cv);

            // Wait for CR2 commit phase (0)
            setStatus("Waiting for commit phase...");
            await waitForCR2Phase(contracts.cr2, 0, "COMMIT");

            // 3. Commit
            setStatus("Committing Randomness (0.1 ETH)...");
            const commitTx = await contracts.cr2.methods.commit(cv).send({
                from: account,
                value: web3.utils.toWei('0.1', 'ether'),
                gas: 500000
            });
            console.log("Commit tx:", commitTx);

            // Wait for CR2 reveal1 phase (1)
            setStatus("Waiting for reveal1 phase...");
            await waitForCR2Phase(contracts.cr2, 1, "REVEAL1");

            // 4. Reveal 1
            setStatus("Revealing Hash (Reveal 1)...");
            const reveal1Tx = await contracts.cr2.methods.reveal1(co).send({
                from: account,
                gas: 500000
            });
            console.log("Reveal1 tx:", reveal1Tx);

            // Wait for CUT phase (3)
            setStatus("Waiting for cut phase...");
            await waitForSetupPhase(contracts.setup, 3, "CUT");

            // 5. Submit Cut
            setStatus("Submitting Cut...");
            const cut = Math.floor(Math.random() * 10);
            console.log("Submitting cut:", cut);
            const cutTx = await contracts.setup.methods.submitCut(cut).send({
                from: account,
                gas: 500000
            });
            console.log("Cut tx:", cutTx);

            setStatus("Setup complete! Waiting for game phase...");

        } catch (e: any) {
            console.error("Full error:", e);
            const errorMsg = e.message || e.toString();
            setStatus("Error: " + errorMsg);
        } finally {
            setLoading(false);
        }
    };

    const handleReveal2 = async () => {
        if (!contracts.cr2 || !account) return;
        setLoading(true);
        try {
            setStatus("Submitting Reveal 2...");
            const s = localStorage.getItem(`blackjack_secret_${account}`);
            if (!s) throw new Error("No secret found!");

            await contracts.cr2.methods.reveal2(s).send({ from: account });
            setStatus("Reveal 2 Done! Waiting for Cut...");

        } catch (e: any) {
            console.error(e);
            setStatus("Error: " + e.message);
        } finally {
            setLoading(false);
        }
    };

    const handleCut = async () => {
        if (!contracts.setup || !account) return;
        setLoading(true);
        try {
            setStatus("Submitting Cut...");
            const cut = Math.floor(Math.random() * 10);
            await contracts.setup.methods.submitCut(cut).send({ from: account });
            setStatus("Cut submitted!");
        } catch (e: any) {
            console.error(e);
            setStatus("Error: " + e.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="text-center w-full max-w-md">
            <h2 className="text-4xl mb-6">Setup Phase</h2>
            <div className="card-sketch p-8 flex flex-col gap-4">
                <p className="text-xl">{status}</p>

                {!loading && (
                    <>
                        <button onClick={handleJoin} disabled={loading}>
                            Join Table (Bet & Commit)
                        </button>

                        <div className="border-t border-gray-300 my-2 pt-2">
                            <p className="text-sm opacity-50 mb-2">Advanced / Debug Steps</p>
                            <div className="flex gap-2 justify-center">
                                <button onClick={handleReveal2} className="text-sm px-2 py-1">
                                    Manual Reveal 2
                                </button>
                                <button onClick={handleCut} className="text-sm px-2 py-1">
                                    Manual Cut
                                </button>
                            </div>
                        </div>
                    </>
                )}
            </div>
        </div>
    );
};
