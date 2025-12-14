from random import randrange
import  time

def waitForPhase(contract,_phase, name,wait=1,debug=False):
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

    while not game.functions.allFinished().call():
        waitForRound(game)
        print("player turn")
        hasPlayed = game.functions.hasPlayed().call()
        action =randrange(0,2)
        if action == 0 and not hasPlayed:
            print("hit")
            try:
                tx = game.functions.hit().transact()
                w3.eth.wait_for_transaction_receipt(tx)
            except:
                pass
        elif not hasPlayed:
            print("stand")
            try:
                tx = game.functions.stand().transact()
                w3.eth.wait_for_transaction_receipt(tx)
            except:
                pass
            return 
        time.sleep(1)



def waitForRound(game):
    while game.functions.playerRoundOver().call():
        time.sleep(1)
