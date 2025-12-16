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
            <div className="card-sketch w-32 h-48 flex items-center justify-center bg-gray-100">
                <span className="text-4xl text-gray-400">?</span>
            </div>
        );
    }

    if (!suit || !rank) {
        return (
            <div className="card-sketch w-32 h-48 flex items-center justify-center bg-gray-50">
                <span className="text-2xl text-gray-300">-</span>
            </div>
        );
    }

    return (
        <div className="card-sketch w-32 h-48 flex flex-col justify-between items-start min-w-[8rem] p-3">
            <div className={`text-2xl font-bold ${isRed ? 'text-red-700' : 'text-black'}`}>
                {rank}{suit}
            </div>
            <div className="self-center text-6xl opacity-20">
                {suit}
            </div>
            <div className={`text-2xl font-bold self-end rotate-180 ${isRed ? 'text-red-700' : 'text-black'}`}>
                {rank}{suit}
            </div>
        </div>
    );
};
