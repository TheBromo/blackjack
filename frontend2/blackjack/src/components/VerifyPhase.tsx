import React, { useState, useEffect } from 'react';
import { Card } from './Card';

interface Props {
    contracts: any;
    account: string | null;
}

interface CardData {
    value: number;
    suit: number;
}

const SUITS = ['♠', '♥', '♦', '♣'];
const VALUES = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];

export const VerifyPhase: React.FC<Props> = ({ contracts, account }) => {
    const [loading, setLoading] = useState(false);
    const [status, setStatus] = useState("Game Over. Waiting for verification...");
    const [autoVerifying, setAutoVerifying] = useState(false);
    const [playerCards, setPlayerCards] = useState<CardData[]>([]);
    const [dealerCards, setDealerCards] = useState<CardData[]>([]);
    const [playerTotal, setPlayerTotal] = useState(0);
    const [dealerTotal, setDealerTotal] = useState(0);

    // Fetch final hands
    useEffect(() => {
        if (!contracts.game || !account) return;

        const fetchFinalHands = async () => {
            try {
                const dealerHand = await contracts.game.methods.getDealreHand().call();
                const playerHand = await contracts.game.methods.getPlayerCards().call({ from: account });

                console.log("Final dealer hand:", dealerHand);
                console.log("Final player hand:", playerHand);

                // Parse dealer cards
                const newDealerCards: CardData[] = [];
                if (dealerHand && dealerHand.cards) {
                    for (let i = 0; i < dealerHand.cards.length; i++) {
                        const card = dealerHand.cards[i];
                        newDealerCards.push({
                            value: Number(card.value),
                            suit: Number(card.suit)
                        });
                    }
                    setDealerTotal(Number(dealerHand.total));
                }

                // Parse player cards
                const newPlayerCards: CardData[] = [];
                if (playerHand && playerHand.cards) {
                    for (let i = 0; i < playerHand.cards.length; i++) {
                        const card = playerHand.cards[i];
                        newPlayerCards.push({
                            value: Number(card.value),
                            suit: Number(card.suit)
                        });
                    }
                    setPlayerTotal(Number(playerHand.total));
                }

                setDealerCards(newDealerCards);
                setPlayerCards(newPlayerCards);

            } catch (error) {
                console.error("Error fetching final hands:", error);
            }
        };

        fetchFinalHands();
    }, [contracts.game, account]);

    // Auto-verify when entering verify phase
    useEffect(() => {
        if (!contracts.controller || !account || autoVerifying) return;

        const autoVerify = async () => {
            setAutoVerifying(true);
            setLoading(true);
            setStatus("Waiting for verify phase...");

            try {
                // Wait for the controller to be in VERIFY phase (phase 2)
                let currentPhase = 0;
                while (currentPhase < 2) {
                    const phase = await contracts.controller.methods.getPhase().call();
                    currentPhase = Number(phase);

                    if (currentPhase >= 2) {
                        console.log("✅ Now in VERIFY phase");
                        break;
                    }

                    console.log(`⏳ Waiting for VERIFY phase... (current: ${currentPhase}, target: 2)`);
                    await new Promise(resolve => setTimeout(resolve, 1000));
                }

                // Now verify the game
                setStatus("Verifying Game...");
                await contracts.controller.methods.verifyGame().send({
                    from: account,
                    gas: 1000000
                });
                setStatus("Game Verified! ✅");

            } catch (e: any) {
                console.error("Verification error:", e);
                const errorMsg = e.message || e.toString();
                setStatus("Error: " + errorMsg);
            } finally {
                setLoading(false);
            }
        };

        autoVerify();
    }, [contracts.controller, account, autoVerifying]);

    const handleManualVerify = async () => {
        if (!contracts.controller || !account) return;
        setLoading(true);
        setStatus("Verifying Game...");

        try {
            await contracts.controller.methods.verifyGame().send({
                from: account,
                gas: 1000000
            });
            setStatus("Game Verified! ✅");
        } catch (e: any) {
            console.error(e);
            setStatus("Error: " + e.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="text-center">
            <h2 className="text-4xl mb-6">Verify Phase</h2>
            <p className="mb-6 text-xl">{status}</p>

            {/* Final Hands Display */}
            <div className="mb-8">
                {/* Dealer's Final Hand */}
                <div className="mb-8">
                    <h3 className="text-2xl mb-4">Dealer - Total: {dealerTotal}</h3>
                    <div className="flex justify-center gap-2">
                        {dealerCards.length === 0 ? (
                            <div className="text-gray-400">No cards</div>
                        ) : (
                            dealerCards.map((card, idx) => (
                                <Card
                                    key={idx}
                                    suit={SUITS[card.suit]}
                                    rank={VALUES[card.value - 1]}
                                />
                            ))
                        )}
                    </div>
                </div>

                {/* Player's Final Hand */}
                <div className="mb-8">
                    <h3 className="text-2xl mb-4">You - Total: {playerTotal}</h3>
                    <div className="flex justify-center gap-2">
                        {playerCards.length === 0 ? (
                            <div className="text-gray-400">No cards</div>
                        ) : (
                            playerCards.map((card, idx) => (
                                <Card
                                    key={idx}
                                    suit={SUITS[card.suit]}
                                    rank={VALUES[card.value - 1]}
                                />
                            ))
                        )}
                    </div>
                </div>
            </div>

            {!autoVerifying && (
                <button onClick={handleManualVerify} disabled={loading}>
                    Manual Verify Game
                </button>
            )}
        </div>
    );
};
