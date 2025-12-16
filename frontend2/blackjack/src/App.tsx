import { Layout } from './components/Layout';
import { SetupPhase } from './components/SetupPhase';
import { GamePhase } from './components/GamePhase';
import { VerifyPhase } from './components/VerifyPhase';
import { useWeb3 } from './hooks/useWeb3';
import { useGameState, Phase } from './hooks/useGameState';

function App() {
  const { web3, account, contracts } = useWeb3();
  const { phase, roundId } = useGameState(contracts);

  const isLoading = !web3 || !account || !contracts.controller;

  return (
    <Layout>
      {isLoading ? (
        <div className="text-center mt-20">
          <p className="text-2xl animate-pulse">Connecting to Table...</p>
          <p className="text-sm mt-4 text-gray-400">Ensure local node is running on :8545</p>
        </div>
      ) : (
        <div className="w-full animate-fade-in">
          <div className="mb-4 text-center opacity-50 text-sm">
            Phase: {Object.keys(Phase).find(key => Phase[key as keyof typeof Phase] === phase)} | Round: {roundId} | User: {account?.slice(0, 6)}...{account?.slice(-4)}
          </div>

          {phase === Phase.SETUP && (
            <SetupPhase contracts={contracts} account={account} web3={web3} />
          )}

          {phase === Phase.GAME && (
            <GamePhase contracts={contracts} account={account} roundId={roundId} />
          )}

          {phase === Phase.VERIFY && (
            <VerifyPhase contracts={contracts} account={account} />
          )}

          {(phase !== Phase.SETUP && phase !== Phase.GAME && phase !== Phase.VERIFY) && (
            <div className="text-center mt-10">
              <p>Unknown Phase or Loading...</p>
            </div>
          )}

        </div>
      )}
    </Layout>
  );
}

export default App;
