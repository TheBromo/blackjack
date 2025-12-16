import Web3 from 'web3';

// Ported from example.py: make_commit logic
export const makeCommit = () => {
    // 1. Generate random 32-byte secret s
    // In browser, we use window.crypto
    const randomBytes = new Uint8Array(32);
    window.crypto.getRandomValues(randomBytes);
    const s = Web3.utils.bytesToHex(randomBytes);

    // 2. co = keccak256(s)
    const co = Web3.utils.keccak256(s);

    // 3. cv = keccak256(co)
    const cv = Web3.utils.keccak256(co);

    return { s, co, cv };
};
