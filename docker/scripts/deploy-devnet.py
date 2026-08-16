#!/usr/bin/env python3
"""
Deploy KeyMarket contract to Starknet devnet
"""
import json
import asyncio
from starknet_py.net.account.account import Account
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models import StarknetChainId
from starknet_py.contract import Contract

# Devnet configuration
RPC_URL = "http://localhost:5050"
CONTRACT_CLASS_PATH = "target/dev/key_onchain_KeyMarket.contract_class.json"

# Devnet pre-deployed account (seed=12345)
DEVNET_ACCOUNT_ADDRESS = "0x127058687166639230431872114492350844249053916038363788110312559"
DEVNET_PRIVATE_KEY = "0xc386c467ce21212c26363661515196db118687b11267ddf8e2133482b24f8f"


async def main():
    print("🚀 Deploying KeyMarket to devnet...")

    # Connect to devnet
    client = FullNodeClient(node_url=RPC_URL)

    # Create account
    key_pair = KeyPair.from_private_key(int(DEVNET_PRIVATE_KEY, 16))
    account = Account(
        client=client,
        address=DEVNET_ACCOUNT_ADDRESS,
        key_pair=key_pair,
        chain=StarknetChainId.TESTNET
    )

    print(f"📦 Account: {account.address}")

    # Read contract class
    with open(CONTRACT_CLASS_PATH, "r") as f:
        contract_class = json.load(f)

    # Declare contract
    print("📝 Declaring contract...")
    declare_result = await account.declare(
        contract=contract_class,
        max_fee=int(1e16)
    )
    print(f"✅ Declared: {declare_result.class_hash}")

    # Deploy contract
    print("📦 Deploying contract...")
    deploy_result = await account.deploy_contract(
        class_hash=declare_result.class_hash,
        constructor_calldata=[account.address],
        max_fee=int(1e16)
    )

    contract_address = deploy_result.deploy.contract_address
    print(f"✅ Deployed at: {contract_address}")

    # Save deployment info
    deployment_info = {
        "contract_address": contract_address,
        "class_hash": declare_result.class_hash,
        "deployer": account.address,
        "rpc_url": RPC_URL
    }

    with open("deployment.json", "w") as f:
        json.dump(deployment_info, f, indent=2)

    print(f"\n📋 Deployment info saved to deployment.json")
    print(f"\nTo use in frontend:")
    print(f"  localStorage.setItem('keymarket_address', '{contract_address}')")

    return contract_address


if __name__ == "__main__":
    asyncio.run(main())
