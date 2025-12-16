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


from web3 import Web3
# from cr2 import setupExec
from web3.middleware import SignAndSendRawMiddlewareBuilder
import os
from setup import setupExec 
from game import gameExec 
import time



def main():
    CLIENT_PRIVATE_KEY = os.environ["CLIENT_PK"]

    w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
    assert w3.is_connected(), "Node is not running!"

    client_account = w3.eth.account.from_key(CLIENT_PRIVATE_KEY)
    CLIENT_ADDRESS = client_account.address

    print("Client address:", CLIENT_ADDRESS)

    w3.middleware_onion.inject(
        SignAndSendRawMiddlewareBuilder.build(client_account),
        layer=0
    )
    w3.eth.default_account = client_account.address
    # Load contract ABI + address
    import json

    with open("./../out/Controller.sol/BlackjackController.json") as f:
        artifact = json.load(f)
    abi = artifact["abi"]

    controllerAddr= Web3.to_checksum_address("0x5FbDB2315678afecb367f032d93F642f64180aa3")
    controller  = w3.eth.contract(address=controllerAddr, abi=abi)


    setup_address = controller.functions.setup().call()
    with open("./../out/Setup.sol/Setup.json") as f:
        artifact = json.load(f)
    abi = artifact["abi"]

    setupAddr= Web3.to_checksum_address(setup_address)
    setup = w3.eth.contract(address=setupAddr, abi=abi)

    with open("./../out/CRR2.sol/CommitReveal2.json") as f:
        artifact = json.load(f)
    abi = artifact["abi"]

    cr2_address = setup.functions.cr().call()
    cr2Addr= Web3.to_checksum_address(cr2_address)
    cr2 = w3.eth.contract(address=cr2Addr, abi=abi)

    game_address = controller.functions.game().call()
    with open("./../out/Game.sol/Blackjack.json") as f:
        artifact = json.load(f)
    abi = artifact["abi"]

    gameAddr= Web3.to_checksum_address(game_address)
    game = w3.eth.contract(address=gameAddr, abi=abi)


    joined = False
    while True:
        id = controller.functions.roundId().call()
        phase = controller.functions.getPhase().call()
        print("controller phase",phase)
        if phase == 0 :
            try:
                setupExec(setup,cr2,w3,client_account,controller)
                joined = True
                waitForPhase(controller,1,"waiting for game phase")
            except  Exception as e:
                print("error :(", e)
                joined = False

        elif phase == 1 and joined:
            try:
                print("gaming...")
                gameExec(game,cr2,w3)
            except  Exception as e:
                print("error :(", e)
            waitForPhase(controller,2,"waiting  verify phase")
            
        elif phase == 2 and joined:
            print("verifying....")
            # try:
            #     # verifyExec(setup,cr2,w3,id)
            # except  Exception as e:
            #     print("error :(", e)
            joined = False

        time.sleep(1)





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


if __name__ == "__main__":
    main()


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
        time.sleep(1)

    print("Submitting Reveal2...")
    tx = cr2.functions.reveal2(s).transact()
    w3.eth.wait_for_transaction_receipt(tx)

    waitForStage(cr2,4,"finish")

    final_randomness = cr2.functions.omega_o().call()
    print(final_randomness)
    return final_randomness 


def waitForStage(contract,_phase, name,wait=1,debug=False):
    while True:
        phase = contract.functions.getPhase().call()
        if debug:
            print(phase)
        if phase >= _phase:
            print(f"✅ Now in {name}!{_phase}<=id:{phase}")
            break

        print(f"⏳ Still waiting for {name}...")
        time.sleep(wait)

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
