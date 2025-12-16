// Helper function to wait for a specific setup phase
export const waitForSetupPhase = async (
    setupContract: any,
    targetPhase: number,
    phaseName: string,
    maxWaitMs: number = 120000
): Promise<void> => {
    const startTime = Date.now();

    while (Date.now() - startTime < maxWaitMs) {
        const currentPhase = await setupContract.methods.getPhase().call();
        const phase = Number(currentPhase);

        if (phase >= targetPhase) {
            console.log(`✅ Now in ${phaseName} phase (${targetPhase})`);
            return;
        }

        console.log(`⏳ Waiting for ${phaseName} phase... (current: ${phase}, target: ${targetPhase})`);
        await new Promise(resolve => setTimeout(resolve, 1000));
    }

    throw new Error(`Timeout waiting for ${phaseName} phase`);
};

// Helper function to wait for a specific CR2 phase
export const waitForCR2Phase = async (
    cr2Contract: any,
    targetPhase: number,
    phaseName: string,
    maxWaitMs: number = 120000
): Promise<void> => {
    const startTime = Date.now();

    while (Date.now() - startTime < maxWaitMs) {
        const currentPhase = await cr2Contract.methods.getPhase().call();
        const phase = Number(currentPhase);

        if (phase >= targetPhase) {
            console.log(`✅ Now in ${phaseName} phase (${targetPhase})`);
            return;
        }

        console.log(`⏳ Waiting for ${phaseName} phase... (current: ${phase}, target: ${targetPhase})`);
        await new Promise(resolve => setTimeout(resolve, 1000));
    }

    throw new Error(`Timeout waiting for ${phaseName} phase`);
};
