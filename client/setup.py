import time
import secrets
from web3 import Web3
from random import randrange

def setupExec(setup,cr2,w3,addr,ctl):
    waitForStage(setup,0,"BETTING")

    tx_hash = setup.functions.bet().transact({
        "value": w3.to_wei(1, "ether")
    })
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    if tx_receipt.status==0:
        print("failed sending muuney :(")
        return

    waitForStage(setup,1,"rng")

    random = crr(cr2,w3,addr)
    print(random)

    waitForStage(setup,3,"cut",debug=True)
    cut = randrange(10)

    tx_hash = setup.functions.submitCut(cut).transact()
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)



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
    return s, co, cv

def crr(cr2,w3,addr):
    s, co, cv = make_commit("MyLiveSecret") #TODO: set some actual value

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

    waitForStage(cr2,1,"reveal1")

    print("Submitting Reveal1...")
    tx = cr2.functions.reveal1(co).transact()
    w3.eth.wait_for_transaction_receipt(tx)


    waitForStage(cr2,3,"Reveal2")

    addresses, dvals = cr2.functions.getParticipantsAndDVals().call()

    participants = list(zip(addresses, dvals))
    valid_participants = [p for p in participants if p[1] > 0]

    sorted_participants = sorted(valid_participants, key=lambda x: x[1], reverse=True)
    sorted_addresses_payload = [p[0] for p in sorted_participants]
    print(f"Sorted {len(sorted_addresses_payload)} addresses for submission.")

    start_time = time.time()
    timeout= cr2.functions.TURN_TIMEOUT().call()
    while True:
        current = cr2.functions.getCurrentRevealer().call()
        print(current)
        if addr.address == current:  
            print("your turn!")
            break
        elapsed = time.time() - start_time
        if timeout > 30:
            print("waiting too long")
            try:
                current = cr2.functions.skipStalledUser().transact()
            except:
                print("skip failed")

        print(f"⏳ Still waiting for currenttltly waiting for{addr}...")
        time.sleep(5)

    print("Submitting Reveal2...")
    tx = cr2.functions.reveal2(s).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    waitForStage(cr2,4,"finish")

    final_randomness = cr2.functions.omega_o().call()
    print(final_randomness)
    return final_randomness 


def waitForStage(contract,_phase, name,wait=5,debug=False):
    while True:
        phase = contract.functions.getPhase().call()
        if debug:
            print(phase)
        if phase >= _phase:
            print(f"✅ Now in {name}!{_phase}<=id:{phase}")
            break

        print(f"⏳ Still waiting for {name}...")
        time.sleep(wait)

