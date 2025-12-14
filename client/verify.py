import time

def waitForPhase(contract,_phase, id,name,wait=5,debug=False):
    while True:
        phase = contract.functions.getPhase(id).call()
        if debug:
            print(phase)
        if phase >= _phase:
            print(f"✅ Now in {name}!{_phase}<=id:{phase}")
            break

        print(f"⏳ Still waiting for {name}...")
        # time.sleep(wait)

def verifyExec(verify,ctl,w3, id):
    print("calling verify game")
    tx= ctl.functions.verifyGame().transact({
    "gas": 1_000_000, # Force a high gas limit
    })
    receipt = w3.eth.wait_for_transaction_receipt(tx)
    print(f"Transaction status: {receipt['status']} (1=Success, 0=Fail)")

    print("calling resolve game")
    tx= verify.functions.resolveGame(id).transact()
    w3.eth.wait_for_transaction_receipt(tx)


def waitForRound(game):
    while not game.functions.playerRoundOver().call():
        pass
        time.sleep(1)
