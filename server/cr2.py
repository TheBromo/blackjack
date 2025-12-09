from web3 import Web3
import secrets
import time

def waitForStage(constract,phase, name,wait=5,debug=False):
    while True:
        phase = constract.functions.getPhase().call()
        if debug:
            print(phase)
        if phase == 0:  # Phase.Reveal1
            print(f"✅ Now in {name}!")
            break

        print(f"⏳ Still waiting for {name}...")
        time.sleep(wait)


def setupExec(setup,cr2,w3,user,registrar, salt):
    waitForStage(setup,1,"rng")

    random = crr(cr2,w3,user,registrar)

    waitForStage(setup,2,"commit chain")

    chain = generate(random, salt)

    tx_hash = setup.functions.submitChain(chain[-1]).transact({
        "from": user.address
    })
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)


    waitForStage(setup,4,"cut chain")

    cut = setup.functions.getCut().call()

    val = setup.functions.evalHash(chain[len(chain)-1-cut]).call()


    tx = setup.functions.revealCutChain(chain[len(chain)-1-cut]).transact()
    w3.eth.wait_for_transaction_receipt(tx)


def generate(random,salt):
    chain = []

    salt_bytes = salt.to_bytes(32, "big")
    temp = Web3.keccak(random+salt_bytes)
    chain.append(temp)

    for i in range(200):
        temp = Web3.keccak(temp)
        chain.append(temp)

    return chain 


def crr(cr2,w3,user,registrar):
    s, co, cv = make_commit("MyLiveSecret")

    # ---------------------------------------------------------
    assert Web3.keccak(co) == cv, "Local hash mismatch! cv != keccak(co)"

    waitForStage(cr2,0,"commit")

    phase = cr2.functions.getParticipant().call()
    print("Submitting commit...")

    tx= cr2.functions.commit(cv).transact({
        "value": w3.to_wei(0.1, "ether")
    })

    receipt = w3.eth.wait_for_transaction_receipt(tx)
    if receipt["status"] == 0:
        phase = cr2.functions.getPhase().call()
        raise Exception("Commit tx reverted on-chain")

    # ---------------------------------------------------------
    # 4. Wait for Reveal1 Phase (REAL TIME)
    # ---------------------------------------------------------

    waitForStage(cr2,1,"reveal1")

    # ---------------------------------------------------------
    # 5. Reveal1
    # ---------------------------------------------------------

    print("Submitting Reveal1...")
    tx = cr2.functions.reveal1(co).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    # ---------------------------------------------------------
    # 6. Wait for OrderCalculation Phase
    # ---------------------------------------------------------

    waitForStage(cr2,2,"order OrderCalculation")
    # ---------------------------------------------------------
    # 7. Submit Reveal Order (single user)
    # ---------------------------------------------------------

    addresses, dvals = cr2.functions.getParticipantsAndDVals().call()

    sorted_addresses = [
        addr for addr, _ in sorted(
            zip(addresses, dvals),
            key=lambda x: x[1],
            reverse=True
        )
    ]
    sorted_participants = sorted(
        zip(addresses, dvals),
        key=lambda x: x[1],
        reverse=True
    )
    print("\nParticipants sorted by dVal (descending):\n")
    for addr, dval in sorted_participants:
        print(f"{addr}  ->  dVal: {dval}")

        print("Submitting reveal order...")

    tx = cr2.functions.submitRevealOrder(sorted_addresses).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    # ---------------------------------------------------------
    # 8. Wait for Reveal2 Phase
    # ---------------------------------------------------------

    waitForStage(cr2,3,"Reveal2")

    # ---------------------------------------------------------
    # 9. Reveal2
    # ---------------------------------------------------------

    print("Submitting Reveal2...")
    tx = cr2.functions.reveal2(s).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    # ---------------------------------------------------------
    # 10. Wait for Finished Phase
    # ---------------------------------------------------------

    waitForStage(cr2,4,"finish")

    # ---------------------------------------------------------
    # 11. Fetch Final Randomness
    # ---------------------------------------------------------

    final_randomness = cr2.functions.omega_o().call()
    print(final_randomness)
    return final_randomness 



# Create secret, co = H(secret), cv = H(co)
def make_commit(secret_str:str):
    secret_int = secrets.randbits(256)
    print("Random secret integer:", secret_int)
    # 1) random 32-byte secret s
    s = secrets.token_bytes(32)          # 256-bit secret

    # 2) co = keccak256(abi.encodePacked(s))
    co = Web3.keccak(s)

    # 3) cv = keccak256(abi.encodePacked(co))
    cv = Web3.keccak(co)
    assert Web3.keccak(co) == cv, "Local hash mismatch! cv != keccak(co)"

    # return s, co, cv
    # s = Web3.solidity_keccak(
    #     ['uint256'],
    #     [secret_int]
    # )
    #
    # co = Web3.solidity_keccak(
    #     ['bytes32'],
    #     [s]
    # )
    #
    # cv = Web3.solidity_keccak(
    #     ['bytes32'],
    #     [co]
    # )
    return s, co, cv
