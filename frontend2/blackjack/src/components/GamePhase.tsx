import React, { useState, useEffect } from 'react';
import { Card } from './Card';

interface Props {
    contracts: any;
    account: string | null;
    roundId: number;
}

interface CardData {
    value: number; // 1-13 (A, 2-10, J, Q, K)
    suit: number; // 0-3
}

interface PlayedCard extends CardData {
    player: string;
}

const SUITS = ['♠', '♥', '♦', '♣'];
const VALUES = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];

export const GamePhase: React.FC<Props> = ({ contracts, account, roundId }) => {
    const [loading, setLoading] = useState(false);
    const [status, setStatus] = useState("Your Turn");
    const [playerCards, setPlayerCards] = useState<PlayedCard[]>([]);
    const [dealerCards, setDealerCards] = useState<PlayedCard[]>([]);

    // Fetch hands from contract view functions
    useEffect(() => {
        if (!contracts.game || !account) return;

        let isActive = true;

        const fetchHands = async () => {
            try {
                // Call contract view functions to get hands
                const dealerHand = await contracts.game.methods.getDealreHand().call();
                const playerHand = await contracts.game.methods.getPlayerCards().call({ from: account });

                console.log("Dealer hand:", dealerHand);
                console.log("Player hand:", playerHand);

                // Parse dealer cards
                const newDealerCards: PlayedCard[] = [];
                if (dealerHand && dealerHand.cards) {
                    for (let i = 0; i < dealerHand.cards.length; i++) {
                        const card = dealerHand.cards[i];
                        newDealerCards.push({
                            value: Number(card.value),
                            suit: Number(card.suit),
                            player: 'dealer'
                        });
                    }
                }

                // Parse player cards
                const newPlayerCards: PlayedCard[] = [];
                if (playerHand && playerHand.cards) {
                    for (let i = 0; i < playerHand.cards.length; i++) {
                        const card = playerHand.cards[i];
                        newPlayerCards.push({
                            value: Number(card.value),
                            suit: Number(card.suit),
                            player: account
                        });
                    }
                }

                console.log("Setting dealer cards:", newDealerCards);
                console.log("Setting player cards:", newPlayerCards);

                setDealerCards(newDealerCards);
                setPlayerCards(newPlayerCards);

            } catch (error) {
                console.error("Error fetching hands:", error);
            }
        };

        // Initial fetch
        fetchHands();

        // Poll for updates every 2 seconds
        const interval = setInterval(() => {
            if (isActive) {
                fetchHands();
            }
        }, 2000);

        // Cleanup
        return () => {
            isActive = false;
            clearInterval(interval);
        };
    }, [contracts.game, account, roundId]);

    const handleHit = async () => {
        if (!contracts.game || !account) return;
        setLoading(true);
        setStatus("Hitting...");
        try {
            await contracts.game.methods.hit().send({
                from: account,
                gas: 500000
            });
            setStatus("Hit successful!");
        } catch (e: any) {
            console.error(e);
            setStatus("Error: " + e.message);
        } finally {
            setLoading(false);
        }
    };

    const handleStand = async () => {
        if (!contracts.game || !account) return;
        setLoading(true);
        setStatus("Standing...");
        try {
            await contracts.game.methods.stand().send({
                from: account,
                gas: 500000
            });
            setStatus("Stood. Waiting for round end...");
        } catch (e: any) {
            console.error(e);
            setStatus("Error: " + e.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="text-center max-w-2xl mx-auto">
            <p className="mb-8 text-xl">{status}</p>

            {/* Dealer's Hand */}
            <div className="mb-12">
                <h3 className="text-3xl font-bold mb-4">Dealer</h3>
                <div className="flex justify-center gap-3 mb-2">
                    {dealerCards.length === 0 ? (
                        <Card hidden />
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
                <p className="text-xl font-bold">Score: ?</p>
            </div>

            {/* Player's Hand */}
            <div className="mb-8">
                <h3 className="text-3xl font-bold mb-4">Your Hand</h3>
                <div className="flex justify-center gap-3 mb-2">
                    {playerCards.length === 0 ? (
                        <div className="text-gray-400">No cards yet</div>
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
                {playerCards.length > 0 && (
                    <div>
                        <p className="text-xl font-bold mb-1">Score: {playerCards.reduce((sum, c) => sum + Math.min(c.value, 10), 0)}</p>
                        <p className="text-blue-600 text-lg">Bet: 1 ETH</p>
                    </div>
                )}
            </div>

            {/* Actions */}
            <div className="flex gap-4 justify-center">
                <button
                    onClick={handleHit}
                    disabled={loading}
                    className="bg-blue-500 hover:bg-blue-600 text-white font-bold py-3 px-8 rounded-xl border-4 border-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                    Hit
                </button>
                <button
                    onClick={handleStand}
                    disabled={loading}
                    className="bg-blue-500 hover:bg-blue-600 text-white font-bold py-3 px-8 rounded-xl border-4 border-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                    Stand
                </button>
            </div>
        </div>
    );
};
