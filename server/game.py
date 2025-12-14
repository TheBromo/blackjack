import time
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

def gameExec(game,ctl,w3, chain,salt,random):

    phase = ctl.functions.getPhase.call()
    print("phase ctl: ", phase)

    waitForPhase(game,0,"deal_cards")
    print("len ",len(chain))
    anchor = chain.pop()
    anchor = chain.pop()
    print(anchor)
    tx = game.functions.deal(anchor).transact()
    w3.eth.wait_for_transaction_receipt(tx)
    print("dealt cards")

    while  game.functions.getPhase().call() < 3:
        phase = ctl.functions.getPhase.call()
        print("phase ctl: ", phase)
        print("wait")
        waitForRound(game)
        print("dealing actions")
        anchor = chain.pop()
        tx = game.functions.dealActions(anchor).transact()
        w3.eth.wait_for_transaction_receipt(tx)
    
    tx = ctl.functions.verifyGame().transact()
    w3.eth.wait_for_transaction_receipt(tx)




def waitForRound(game):
    while not game.functions.playerRoundOver().call():
        print("wait to deal")
        time.sleep(1)
