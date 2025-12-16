import React from 'react';

interface CardProps {
    suit?: string;
    rank?: string;
    hidden?: boolean;
}

export const Card: React.FC<CardProps> = ({ suit, rank, hidden }) => {
    const isRed = suit === '♥' || suit === '♦';

    if (hidden) {
        return (
            <div className="w-24 h-32 flex items-center justify-center bg-white border-4 border-gray-800 rounded-xl">
                <div className="text-4xl">🂠</div>
            </div>
        );
    }

    if (!suit || !rank) {
        return (
            <div className="w-24 h-32 flex items-center justify-center bg-white border-4 border-gray-800 rounded-xl">
                <span className="text-2xl text-gray-300">-</span>
            </div>
        );
    }

    return (
        <div className="w-24 h-32 flex items-center justify-center bg-white border-4 border-gray-800 rounded-xl">
            <div className={`text-3xl font-bold ${isRed ? 'text-red-600' : 'text-black'}`}>
                {rank}{suit}
            </div>
        </div>
    );
};
