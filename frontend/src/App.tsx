/* eslint-disable @typescript-eslint/no-misused-promises */
import { Authenticated, Unauthenticated, useQuery, useMutation } from "convex/react";
import { api } from "../convex/_generated/api";
import { SignInForm } from "./SignInForm";
import { SignOutButton } from "./SignOutButton";
import { Toaster } from "sonner";
import { useState, useEffect } from "react";

export default function App() {
  return (
    <div className="min-h-screen bg-paper">
      <header className="sketch-border-bottom bg-white p-4 flex justify-between items-center">
        <h1 className="text-3xl font-bold sketch-text">♠ Blackjack Sketch ♥</h1>
        <SignOutButton />
      </header>
      <main className="p-6">
        <Content />
      </main>
      <Toaster />
    </div>
  );
}

function Content() {
  const loggedInUser = useQuery(api.auth.loggedInUser);
  const currentGame = useQuery(api.blackjack.getCurrentGame);
  const setupTables = useMutation(api.setup.setupTables);

  useEffect(() => {
    if (loggedInUser) {
      void setupTables();
    }
  }, [loggedInUser, setupTables]);

  if (loggedInUser === undefined) {
    return (
      <div className="flex justify-center items-center min-h-96">
        <div className="sketch-spinner"></div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      <Authenticated>
        {currentGame ? <GameView game={currentGame} /> : <TableSelection />}
      </Authenticated>
      <Unauthenticated>
        <div className="text-center py-12">
          <h2 className="text-4xl font-bold sketch-text mb-6">Welcome to Blackjack!</h2>
          <p className="text-xl text-gray-600 mb-8">Sign in to start playing</p>
          <div className="max-w-md mx-auto">
            <SignInForm />
          </div>
        </div>
      </Unauthenticated>
    </div>
  );
}

function TableSelection() {
  const tables = useQuery(api.blackjack.getTables);
  const joinTable = useMutation(api.blackjack.joinTable);

  if (!tables) {
    return (
      <div className="flex justify-center items-center min-h-96">
        <div className="sketch-spinner"></div>
      </div>
    );
  }

  return (
    <div className="text-center">
      <h2 className="text-3xl font-bold sketch-text mb-8">Choose Your Table</h2>
      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 max-w-4xl mx-auto">
        {tables.map((table) => (
          <div key={table._id} className="sketch-card p-6">
            <h3 className="text-xl font-bold sketch-text mb-4">{table.name}</h3>
            <div className="space-y-2 text-gray-700 mb-6">
              <p>Min Bet: <span className="font-bold">${table.minBet}</span></p>
              <p>Max Bet: <span className="font-bold">${table.maxBet}</span></p>
              <p>Players: <span className="font-bold">{table.playerCount}/{table.maxPlayers}</span></p>
            </div>
            <button
              onClick={() => joinTable({ tableId: table._id })}
              disabled={table.playerCount >= table.maxPlayers}
              className="sketch-button w-full"
            >
              {table.playerCount >= table.maxPlayers ? "Table Full" : "Join Table"}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

function GameView({ game }: { game: any }) {
  const placeBet = useMutation(api.blackjack.placeBet);
  const hit = useMutation(api.blackjack.hit);
  const stand = useMutation(api.blackjack.stand);
  const doubleDown = useMutation(api.blackjack.doubleDown);
  const newGame = useMutation(api.blackjack.newGame);
  const leaveTable = useMutation(api.blackjack.leaveTable);
  const [betAmount, setBetAmount] = useState(game.table?.minBet || 10);

  const handleBet = async () => {
    await placeBet({ bet: betAmount });
  };

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex justify-between items-center mb-8">
        <div>
          <h2 className="text-2xl font-bold sketch-text">{game.table?.name}</h2>
          <p className="text-gray-600">Chips: <span className="font-bold text-green-600">${game.chips}</span></p>
        </div>
        <button onClick={() => leaveTable()} className="sketch-button-secondary">
          Leave Table
        </button>
      </div>

      {/* Game Area */}
      <div className="space-y-8">
        {/* Dealer Section */}
        <div className="text-center">
          <h3 className="text-xl font-bold sketch-text mb-4">Dealer</h3>
          <div className="flex justify-center gap-2 mb-2">
            {game.dealerCards.map((card: any, index: number) => (
              <div key={index} className="sketch-card-small">
                {game.dealerHidden && index === 1 ? (
                  <div className="text-2xl">🂠</div>
                ) : (
                  <div className="text-lg font-bold">
                    {card.rank}{card.suit}
                  </div>
                )}
              </div>
            ))}
          </div>
          <p className="font-bold">
            Score: {game.dealerHidden ? "?" : game.dealerScore}
          </p>
        </div>

        {/* Player Section */}
        <div className="text-center">
          <h3 className="text-xl font-bold sketch-text mb-4">Your Hand</h3>
          <div className="flex justify-center gap-2 mb-2">
            {game.playerCards.map((card: any, index: number) => (
              <div key={index} className="sketch-card-small">
                <div className="text-lg font-bold">
                  {card.rank}{card.suit}
                </div>
              </div>
            ))}
          </div>
          <p className="font-bold">Score: {game.playerScore}</p>
          {game.bet > 0 && <p className="text-blue-600">Bet: ${game.bet}</p>}
        </div>

        {/* Game Controls */}
        <div className="text-center">
          {game.gameState === "betting" && (
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold sketch-text mb-2">
                  Bet Amount: ${betAmount}
                </label>
                <input
                  type="range"
                  min={game.table?.minBet || 10}
                  max={Math.min(game.table?.maxBet || 1000, game.chips)}
                  value={betAmount}
                  onChange={(e) => setBetAmount(Number(e.target.value))}
                  className="w-64"
                />
              </div>
              <button onClick={handleBet} className="sketch-button">
                Place Bet
              </button>
            </div>
          )}

          {game.gameState === "playing" && (
            <div className="flex justify-center gap-4">
              <button onClick={() => hit()} className="sketch-button">
                Hit
              </button>
              <button onClick={() => stand()} className="sketch-button">
                Stand
              </button>
              {game.canDoubleDown && game.chips >= game.bet && (
                <button onClick={() => doubleDown()} className="sketch-button">
                  Double Down
                </button>
              )}
            </div>
          )}

          {game.gameState === "finished" && (
            <div className="space-y-4">
              <div className="text-2xl font-bold sketch-text">
                {game.result === "win" && "🎉 You Win!"}
                {game.result === "lose" && "😔 You Lose"}
                {game.result === "push" && "🤝 Push"}
                {game.result === "blackjack" && "🎊 Blackjack!"}
              </div>
              <button onClick={() => newGame()} className="sketch-button">
                New Game
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
