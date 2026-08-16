# KeyOnChain

Confidential key distribution on Starknet. The transfer amount IS the secret key.

## Live Demo

```
https://distribution-breathing-checkout-rebecca.trycloudflare.com
```

**⚠️ Cloudflare tunnel is temporary. Install [Ready wallet](https://readywallet.app) browser extension for full STRK20 support.**

## How It Works

```
┌──────────────┐      ElGamal       ┌──────────────┐
│    SELLER    │ ──────────────────► │   CONTRACT   │
│  creates     │  encrypt key_amount│  stores      │
│  listing     │  under buyer pubkey│  CipherBalance│
└──────────────┘                    └──────┬───────┘
                                           │
┌──────────────┐    pay price        ┌─────┴───────┐
│    BUYER     │ ──────────────────► │  PAYMENT    │
│  receives    │ ◄────────────────── │  to seller  │
│  encrypted   │  encrypted balance  └─────────────┘
│  balance     │
└──────┬───────┘
       │ decrypt off-chain
       ▼
   secret key
```

**ElGamal on Stark Curve:**
- `R = g^r`
- `L = g^key_amount · buyer_pubkey^r`
- Encrypted balance `(L, R)` stored on-chain
- Only buyer's private key can decrypt

## Quick Start

### Frontend (with Cloudflare Tunnel)

```bash
# Start frontend server
cd frontend
python3 -m http.server 3000

# In another terminal, start tunnel
cloudflared tunnel --url http://localhost:3000
```

### Docker Lab

```bash
# Run tests
docker compose up test

# Full lab (devnet + frontend + tunnel)
docker compose up full-lab

# Seller interface
docker compose run seller

# Buyer interface  
docker compose run buyer
```

### Deploy to Devnet

```bash
# Start devnet
starknet-devnet --host 0.0.0.0 --port 5050 --seed 12345

# Deploy contract
docker compose run deploy-devnet
```

### Deploy to Sepolia

```bash
export STARKNET_PRIVATE_KEY=0x...
export STARKNET_ACCOUNT_ADDRESS=0x...
docker compose run deploy-sepolia
```

## Frontend Features

- **Wallet Connection**: Argent, Braavos, Xverse
- **Contract Deployment**: Deploy KeyMarket from browser
- **Create Listings**: Vendors can create key listings
- **Buy Keys**: Purchase keys with ElGamal encryption
- **Decrypt**: View your secret keys off-chain

## Use Cases

- **NFT gated access** — key unlocks content, amount hides on-chain
- **Software licenses** — purchase → receive encrypted license key
- **Confidential credentials** — certifiers issue keys without revealing them
- **Private API access** — payment amount = API key
- **Cross-chain bridges** — encrypted secrets for atomic swaps

## Architecture

| Component | Purpose |
|-----------|---------|
| `KeyOnChain` | Simple vendor→buyer key distribution |
| `KeyMarket` | Marketplace with listings, payments, encrypted balances |
| ElGamal | Homomorphic encryption hiding amounts on-chain |
| Frontend | Web UI with wallet connection and contract interaction |
| Docker Lab | Local devnet + seller/buyer interfaces |

## Project Structure

```
key_onchain/
├── src/
│   ├── lib.cairo              # KeyOnChain + KeyMarket contracts
│   └── key_market.cairo       # Marketplace logic
├── tests/
│   └── test_key_onchain.cairo # 4 passing tests
├── frontend/
│   ├── index.html             # Complete web UI
│   └── keymarket_class.json   # Contract class for deployment
├── docker/
│   ├── Dockerfile             # Scarb + snforge + devnet
│   ├── docker-compose.yml     # All services
│   └── scripts/               # Deploy and utility scripts
├── Scarb.toml
└── README.md
```

## Contracts

### KeyOnChain (Simple)
- `set_key_amount(amount)` — Vendor sets the secret key
- `get_encrypted_balance(pubkey_x, pubkey_y)` — Get encrypted balance
- `withdraw()` — Vendor withdraws payments

### KeyMarket (Marketplace)
 - `create_listing(price, amount, description)` — Create a listing
 - `deactivate_listing(id)` — Deactivate a listing
 - `register_buyer(pubkey_x, pubkey_y, viewing_key)` — Register buyer's public key with STRK20 viewing key
 - `mark_shielded(buyer_pubkey_x)` — Mark buyer as having shielded STRK20 balance
 - `buy_key(listing_id, pubkey_x, pubkey_y, randomness)` — Purchase a key (requires shielded balance)
 - `get_listing(id)` — Get listing details
 - `get_encrypted_balance(pubkey_x, pubkey_y)` — Get encrypted balance
 - `get_strk20_pool()` — Get STRK20 pool address
 - `get_viewing_key(buyer_pubkey_x)` — Get buyer's viewing key
 - `withdraw()` — Vendor withdraws payments

## Audit Fixes (STRK20 Skills Review)

All 4 critical audit findings from the STRK20 skills review have been fixed:

1. **STRK20 Pool Address** — Added Sepolia pool address `0x0254a6b2997ef52e9f830ce1f543f6b29768295e8d17e2267d672c552cfe0d91` in constructor
2. **Viewing Key Registration** — `register_buyer` now requires a `viewing_key` parameter for STRK20 note discovery
3. **Shielded Balance Requirement** — `buy_key` now asserts `buyer_shielded` flag; buyers must call `mark_shielded` after shielding STRK20 in the pool
4. **FPI Screening** — Added FPI screening contract address in constructor; `buy_key` verifies deposit screening

## Links

- [Starknet](https://starknet.io)
- [Tongo](https://github.com/fatlabsxyz/tongo) — ElGamal inspiration
- [STRK20](https://strk20.starknet.io) — privacy for ERC-20
