import time
from random import randrange

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

def gameExec(game,ctl,w3):
    waitForPhase(game,1,"play_cards")

    while not game.functions.allFinished().call():
        waitForRound(game)
        print("player turn")
        action =randrange(0,2)
        if action == 0:
            print("hit")
            tx = game.functions.hit().transact()
            w3.eth.wait_for_transaction_receipt(tx)
            pass
        else:
            print("stand")
            tx = game.functions.stand().transact()
            w3.eth.wait_for_transaction_receipt(tx)
            pass



def waitForRound(game):
    while game.functions.playerRoundOver().call():
        time.sleep(5)
