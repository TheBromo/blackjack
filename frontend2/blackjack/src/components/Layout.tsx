import React from 'react';

interface LayoutProps {
    children: React.ReactNode;
}

export const Layout: React.FC<LayoutProps> = ({ children }) => {
    return (
        <div className="min-h-screen flex flex-col items-center justify-center p-8">
            <header className="mb-12 text-center">
                <h1 className="text-6xl font-bold mb-2 transform -rotate-2">Blackjack</h1>
                <div className="w-32 h-1 bg-current mx-auto rounded-full transform rotate-1"></div>
                <p className="mt-2 text-xl opacity-80 rotate-1">Hand-Drawn & Decentralized</p>
            </header>

            <main className="w-full max-w-4xl flex-1 flex flex-col items-center justify-center">
                {children}
            </main>

            <footer className="mt-12 text-center opacity-60 text-sm">
                <p>Built with Web3 & ❤️</p>
            </footer>
        </div>
    );
};
