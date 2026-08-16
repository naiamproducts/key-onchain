# KeyOnChain

Confidential key distribution on Starknet. The transfer amount IS the secret key.

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

```bash
# Run tests
docker compose up test

# Seller interface
docker compose run seller

# Buyer interface  
docker compose run buyer

# Deploy to Sepolia
export STARKNET_PRIVATE_KEY=0x...
export STARKNET_ACCOUNT_ADDRESS=0x...
docker compose run deploy-sepolia
```

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
| Docker Lab | Local devnet + seller/buyer interfaces |

## Links

- [Starknet](https://starknet.io)
- [Tongo](https://github.com/fatlabsxyz/tongo) — ElGamal inspiration
- [STRK20](https://strk20.starknet.io) — privacy for ERC-20
