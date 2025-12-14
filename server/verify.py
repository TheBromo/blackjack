import time

def waitForPhase(contract,_phase,id, name,wait=1,debug=False):
    while True:
        phase = contract.functions.getPhase(id).call()
        if debug:
            print(phase)
        if phase >= _phase:
            print(f"✅ Now in {name}!{_phase}<=id:{phase}")
            break

        print(f"⏳ Still waiting for {name}...")
        time.sleep(wait)

def verifyExec(verify,w3, chain,salt, id):
    print("submitting anchor")
    print(salt)
    try:
        print(id,salt.to_bytes(32, byteorder='big'),len(chain))
        tx= verify.functions.verifyAnchor(id,salt.to_bytes(32, byteorder='big'),len(chain)).transact({
            "gas": 1_000_000, })
        receipt = w3.eth.wait_for_transaction_receipt(tx)
        print(f"Transaction status: {receipt['status']} (1=Success, 0=Fail)")

    except:
        print("failed verifying")

    waitForPhase(verify,1,id, "waiting for resolving")
    print("resolveing game anchor")
    tx= verify.functions.resolveGame(id).transact()
    receipt = w3.eth.wait_for_transaction_receipt(tx)
    print(f"Transaction status: {receipt['status']} (1=Success, 0=Fail)")

