
import time

def waitForPhase(contract,_phase, name,wait=5,debug=False):
    while True:
        phase = contract.functions.getPhase().call()
        if debug:
            print(phase)
        if phase >= _phase:
            print(f"✅ Now in {name}!{_phase}<=id:{phase}")
            break

        print(f"⏳ Still waiting for {name}...")
        time.sleep(wait)

def verifyExec(verify,ctl,w3, id):
    tx= ctl.functions.verifyGame().transact()
    w3.eth.wait_for_transaction_receipt(tx)

    tx= verify.functions.resolveGame(id).transact()
    w3.eth.wait_for_transaction_receipt(tx)


def waitForRound(game):
    while not game.functions.playerRoundOver().call():
        time.sleep(5)
