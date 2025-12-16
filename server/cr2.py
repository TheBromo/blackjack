from web3 import Web3
import secrets
import time

def waitForStage(constract,_phase, name,wait=1,debug=False):
    while True:
        phase = constract.functions.getPhase().call()
        if debug:
            print(phase)
        if phase >= _phase:
            print(f"✅ Now in {name}!{_phase}<=id:{phase}")
            break

        print(f"⏳ Still waiting for {name}...")
        time.sleep(wait)


def setupExec(setup,cr2,ctl,w3,user,registrar, salt):
    waitForStage(setup,0,"betting")
    waitForStage(setup,1,"rng")

    count = setup.functions.playerCount().call()
    if count == 0:
        print("no players joined :(")
        return

    random = crr(cr2,w3,user,registrar)

    waitForStage(setup,2,"chain")

    chain = generate(random, salt)
    print("chain length", len(chain))

    print("submitting",chain[len(chain)-1])
    tx_hash = setup.functions.submitChain(chain[len(chain)-1]).transact() #TODO: this fails
    w3.eth.wait_for_transaction_receipt(tx_hash)

    # waitForStage(setup,3,"cut ")


    waitForStage(setup,4,"cut chain")

    cut = setup.functions.getCut().call()
    print("chain length -cut",len(chain[-cut]))

    val = setup.functions.evalHash(chain[len(chain)-1-cut]).call()

    blkchain= setup.functions.anchor().call()
    print("chain",chain[len(chain)-1])
    print("blkchain",blkchain)

    for el in chain:
        print(el)
    chain = chain[:len(chain)-cut]
    print("new chain",chain[len(chain)-1])

    tx = setup.functions.revealCutChain(chain[len(chain)-1]).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    return chain, salt,random 



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
    w3.eth.wait_for_transaction_receipt(tx)
 
    # ---------------------------------------------------------
    # 4. Wait for Reveal1 Phase (REAL TIME)
    # ---------------------------------------------------------

    waitForStage(cr2,1,"reveal1" )

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

    tx_hash = cr2.functions.calculateIntermediateValues().transact()
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print("Values calculated on-chain.")

    addresses, dvals = cr2.functions.getParticipantsAndDVals().call()

    participants = list(zip(addresses, dvals))
    valid_participants = [p for p in participants if p[1] > 0]

    sorted_participants = sorted(valid_participants, key=lambda x: x[1], reverse=True)
    sorted_addresses_payload = [p[0] for p in sorted_participants]
    print(f"Sorted {len(sorted_addresses_payload)} addresses for submission.")
    tx = cr2.functions.submitRevealOrder(sorted_addresses_payload).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    # ---------------------------------------------------------
    # 8. Wait for Reveal2 Phase
    # ---------------------------------------------------------

    waitForStage(cr2,3,"Reveal2")

    # ---------------------------------------------------------
    # 9. Reveal2
    # ---------------------------------------------------------

    start_time = time.time()
    timeout= cr2.functions.TURN_TIMEOUT().call()
    while True:
        current = cr2.functions.getCurrentRevealer().call()
        print(current)
        if user.address== current:  
            print("your turn!")
            break
        elapsed = time.time() - start_time
        if timeout < elapsed:
            print("waiting too long")
            try:
                current = cr2.functions.skipStalledUser().transact()
            except:
                print("skip failed")

        print(f"⏳ Still waiting for {current}...")
        time.sleep(1)

    print("Submitting Reveal2...")
    tx = cr2.functions.reveal2(s).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    # ---------------------------------------------------------
    # 10. Wait for Finished Phase
    # ---------------------------------------------------------

    # waitForStage(cr2,4,"finish")

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
