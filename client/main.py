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
