# KeyOnChain Docker Lab

Entorno Docker para el PoC de distribución confidencial de claves en Starknet usando ElGamal.

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│  SELLER                                                      │
│  1. Crea listing con key_price y key_amount                  │
│  2. Recibe pago cuando buyer compra                          │
│  3. El monto cifrado (= key) se almacena on-chain            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  KeyMarket Contract (Starknet)                               │
│  - Maneja listings (key_price, key_amount, active)           │
│  - Transfiere pago del buyer al seller                       │
│  - Cifra key_amount con ElGamal bajo pubkey del buyer        │
│  - Almacena CipherBalance { L, R } por pubkey                │
│  - El monto (key) NUNCA se ve on-chain                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  BUYER                                                       │
│  1. Genera keypair (private_key, public_key = g^private_key) │
│  2. Se registra con el contrato                              │
│  3. Compra key: paga price, recibe balance cifrado           │
│  4. Lee get_encrypted_balance() → (L_x, L_y, R_x, R_y)      │
│  5. Descifra off-chain: g^m * R^x == L → m = key             │
│  6. Usa la key para su propósito                             │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# Ejecutar tests
docker compose -f docker/docker-compose.yml up test

# Entorno interactivo
docker compose -f docker/docker-compose.yml run dev

# Devnet local
docker compose -f docker/docker-compose.yml up devnet

# Demo completa
docker compose -f docker/docker-compose.yml up demo

# Seller interface
docker compose -f docker/docker-compose.yml run seller

# Buyer interface
docker compose -f docker/docker-compose.yml run buyer
```

## Services

| Service | Description | Port |
|---------|-------------|------|
| `dev` | Entorno desarrollo interactivo | 5050, 8080 |
| `devnet` | Starknet devnet local | 5050 |
| `test` | Ejecuta todos los tests | - |
| `build` | Solo compila contratos | - |
| `seller` | Interfaz del vendedor | 5050 |
| `buyer` | Interfaz del comprador | 5051 |
| `demo` | Demo completa del flujo | - |
| `deploy-sepolia` | Deploy a Sepolia testnet | - |

## Deploy a Sepolia

```bash
# Set environment variables
export STARKNET_PRIVATE_KEY=0x...
export STARKNET_ACCOUNT_ADDRESS=0x...
export VENDOR_ADDRESS=0x...  # Optional, defaults to account

# Deploy
docker compose -f docker/docker-compose.yml run deploy-sepolia
```

## Flujo Completo

### 1. Seller crea listing
```bash
docker compose -f docker/docker-compose.yml run seller
# Select: 1. Create listing
# Enter key_price and key_amount
```

### 2. Buyer genera keypair
```bash
docker compose -f docker/docker-compose.yml run buyer
# Select: 1. Generate keypair
# Save private_key securely!
```

### 3. Buyer se registra
```bash
# Select: 2. Register as buyer
# Enter pubkey_x and pubkey_y
```

### 4. Buyer compra key
```bash
# Select: 3. Buy key
# Enter listing_id, pubkey, randomness
```

### 5. Buyer descifra
```bash
# Select: 5. Decrypt balance
# Enter private_key and encrypted values
# Decrypted value = secret key!
```

## Files

```
key_onchain/
├── docker/
│   ├── Dockerfile              # Scarb + snforge + starknet-devnet
│   ├── docker-compose.yml      # Service definitions
│   ├── README.md               # This file
│   └── scripts/
│       ├── run-tests.sh        # Run all tests
│       ├── build.sh            # Build contracts
│       ├── deploy.sh           # Deploy to devnet
│       ├── deploy-sepolia.sh   # Deploy to Sepolia
│       ├── demo.sh             # Basic demo
│       ├── demo-complete.sh    # Complete demo
│       ├── seller.sh           # Seller interface
│       └── buyer.sh            # Buyer interface
├── src/
│   └── lib.cairo               # KeyOnChain + KeyMarket contracts
├── tests/
│   └── test_key_onchain.cairo  # Test suite
└── Scarb.toml                  # Project config
```

## Key Contracts

### KeyOnChain (Simple)
- Vendor mints encrypted keys directly
- Good for simple vendor→buyer distribution

### KeyMarket (Marketplace)
- Listings with prices
- Payment transfer to seller
- Buyer registration
- Full marketplace flow

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SCARB_CACHE` | `/root/.cache/scarb` | Scarb cache directory |
| `SNFORGE_CACHE` | `/root/.cache/snforge` | snforge cache directory |
| `RPC_URL` | `http://localhost:5050` | Starknet RPC endpoint |
| `STARKNET_PRIVATE_KEY` | - | Deployer private key |
| `STARKNET_ACCOUNT_ADDRESS` | - | Deployer account |
| `VENDOR_ADDRESS` | - | Vendor address |
| `CONTRACT_ADDRESS` | - | Deployed contract |

## Troubleshooting

### Build fails
```bash
docker compose -f docker/docker-compose.yml down -v
docker compose -f docker/docker-compose.yml up build
```

### Devnet not starting
```bash
lsof -i :5050
# Kill existing process or change port
```

### Tests fail
```bash
docker compose -f docker/docker-compose.yml run dev snforge test -vvv
```
