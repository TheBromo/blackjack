from web3 import Web3
from cr2 import setupExec
from web3.middleware import SignAndSendRawMiddlewareBuilder
import time
import os
import secrets

# ---------------------------------------------------------
# 1. Blockchain + Contract Setup
# ---------------------------------------------------------

HOUSE_PRIVATE_KEY = os.environ["HOUSE_PK"]

w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
assert w3.is_connected(), "Node is not running!"

house_account = w3.eth.account.from_key(HOUSE_PRIVATE_KEY)
HOUSE_ADDRESS = house_account.address

print("HOUSE address:", HOUSE_ADDRESS)

w3.middleware_onion.inject(
    SignAndSendRawMiddlewareBuilder.build(house_account),
    layer=0
)
w3.eth.default_account = house_account.address
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




PRIVATE_KEY_REGISTRAR = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80#os.environ["REGISTRAR_PK"]
PRIVATE_KEY_USER      = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80#os.environ["USER_PK"]

registrar = w3.eth.account.from_key(PRIVATE_KEY_REGISTRAR)
user      = w3.eth.account.from_key(PRIVATE_KEY_USER)

print("Registrar:", registrar.address)
print("User:", user.address) 
tx_hash = controller.functions.reset().transact()
receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

salt = secrets.randbits(256)

while True:
    phase = controller.functions.getPhase().call()
    print(phase)
    if phase == 0:
        setupExec(setup,cr2,w3,user,registrar,salt)

        tx_hash = controller.functions.startGame().transact()
        w3.eth.wait_for_transaction_receipt(tx_hash)

        phase = controller.functions.getPhase().call()
        print(phase)
    elif phase == 1:
        print("gaming...")
        #game
    elif phase == 2:
        #verify
        pass
    time.sleep(30)



