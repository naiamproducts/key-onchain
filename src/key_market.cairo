/// # KeyMarket
///
/// A confidential key distribution marketplace on Starknet.
///
/// ## Architecture
/// - Vendor mints KeyTokens (ERC20-like) with specific amounts
/// - Each KeyToken has an encrypted balance (ElGamal) tied to buyer's public key
/// - The encrypted amount IS the secret key
/// - Buyer decrypts off-chain to recover the key
///
/// ## Flow
/// 1. Vendor creates a listing (key_price, key_amount)
/// 2. Buyer registers with public key
/// 3. Buyer calls buy(listing_id, buyer_pubkey)
///   - Buyer pays key_price in STRK/ERC20
///   - Contract transfers payment to vendor
///   - Contract encrypts key_amount under buyer's pubkey
///   - Contract stores encrypted balance
/// 4. Buyer reads encrypted balance and decrypts off-chain
/// 5. Decrypted value = the secret key

/// Interface for the KeyMarket contract.
#[starknet::interface]
pub trait IKeyMarket<TContractState> {
    // ===== Vendor Operations =====

    /// Create a new key listing. Only vendor can call this.
    fn create_listing(
        ref self: TContractState,
        key_price: u256,
        key_amount: felt252,
        description: felt252,
    );

    /// Deactivate a listing. Only vendor can call this.
    fn deactivate_listing(ref self: TContractState, listing_id: u64);

    // ===== Buyer Operations =====

    /// Register a buyer with their public key.
    fn register_buyer(
        ref self: TContractState,
        pubkey_x: felt252,
        pubkey_y: felt252,
    );

    /// Buy a key from a listing.
    /// - Transfers key_price from buyer to vendor
    /// - Encrypts key_amount under buyer's pubkey
    /// - Stores encrypted balance
    fn buy_key(
        ref self: TContractState,
        listing_id: u64,
        buyer_pubkey_x: felt252,
        buyer_pubkey_y: felt252,
        randomness: felt252,
    );

    // ===== View Operations =====

    /// Get encrypted balance for a buyer.
    fn get_encrypted_balance(
        self: @TContractState,
        buyer_pubkey_x: felt252,
        buyer_pubkey_y: felt252,
    ) -> (felt252, felt252, felt252, felt252);

    /// Get listing details.
    fn get_listing(
        self: @TContractState,
        listing_id: u64,
    ) -> (u256, felt252, bool, u64);

    /// Get vendor address.
    fn get_vendor(self: @TContractState) -> starknet::ContractAddress;

    /// Get total listings.
    fn get_total_listings(self: @TContractState) -> u64;

    /// Get total keys sold.
    fn get_total_keys_sold(self: @ContractState) -> u64;
}

/// # KeyMarket Contract
///
/// Marketplace for confidential key distribution using ElGamal encryption.
#[starknet::contract]
mod KeyMarket {
    use core::ec::{EcPoint, EcPointTrait, EcStateTrait, NonZeroEcPoint};
    use core::ec::stark_curve::{GEN_X, GEN_Y};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::token::IERC20Dispatcher;
    use starknet::token::IERC20DispatcherTrait;

    /// Represents a point on the Stark curve.
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct StarkPoint {
        x: felt252,
        y: felt252,
    }

    /// ElGamal ciphertext: (L, R) where L = g^m * y^r, R = g^r
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct CipherBalance {
        L: StarkPoint,
        R: StarkPoint,
    }

    /// Listing structure.
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct Listing {
        key_price: u256,
        key_amount: felt252,
        active: bool,
        keys_sold: u64,
    }

    #[storage]
    struct Storage {
        /// The vendor who creates listings.
        vendor: ContractAddress,
        /// Payment token (STRK or ERC20).
        payment_token: ContractAddress,
        /// Listings indexed by ID.
        listings: Map<u64, Listing>,
        /// Total listings created.
        total_listings: u64,
        /// Encrypted balances indexed by buyer pubkey x-coordinate.
        balances: Map<felt252, CipherBalance>,
        /// Track which buyer pubkeys are registered.
        buyer_registered: Map<felt252, bool>,
        /// Y-coordinate of buyer pubkeys.
        buyer_pubkey_y: Map<felt252, felt252>,
        /// Total keys sold.
        total_keys_sold: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ListingCreated: ListingCreated,
        ListingDeactivated: ListingDeactivated,
        BuyerRegistered: BuyerRegistered,
        KeyPurchased: KeyPurchased,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCreated {
        listing_id: u64,
        key_price: u256,
        key_amount: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingDeactivated {
        listing_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct BuyerRegistered {
        buyer_pubkey_x: felt252,
        buyer_pubkey_y: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct KeyPurchased {
        listing_id: u64,
        buyer_pubkey_x: felt252,
        buyer_pubkey_y: felt252,
        nonce: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        vendor: ContractAddress,
        payment_token: ContractAddress,
    ) {
        self.vendor.write(vendor);
        self.payment_token.write(payment_token);
        self.total_listings.write(0);
        self.total_keys_sold.write(0);
    }

    #[abi(embed_v0)]
    impl KeyMarketImpl of super::IKeyMarket<ContractState> {
        /// Create a new key listing.
        fn create_listing(
            ref self: ContractState,
            key_price: u256,
            key_amount: felt252,
            description: felt252,
        ) {
            let caller = get_caller_address();
            assert(caller == self.vendor.read(), 'Only vendor can create listings');
            assert(key_price > 0, 'Price must be > 0');
            assert(key_amount != 0, 'Key amount cannot be zero');

            let listing_id = self.total_listings.read();
            let listing = Listing {
                key_price,
                key_amount,
                active: true,
                keys_sold: 0,
            };

            self.listings.entry(listing_id).write(listing);
            self.total_listings.write(listing_id + 1);

            self.emit(ListingCreated { listing_id, key_price, key_amount });
        }

        /// Deactivate a listing.
        fn deactivate_listing(ref self: ContractState, listing_id: u64) {
            let caller = get_caller_address();
            assert(caller == self.vendor.read(), 'Only vendor can deactivate');

            let mut listing = self.listings.entry(listing_id).read();
            listing.active = false;
            self.listings.entry(listing_id).write(listing);

            self.emit(ListingDeactivated { listing_id });
        }

        /// Register a buyer with their public key.
        fn register_buyer(
            ref self: ContractState,
            pubkey_x: felt252,
            pubkey_y: felt252,
        ) {
            assert(!self.buyer_registered.entry(pubkey_x).read(), 'Buyer already registered');

            self.buyer_registered.entry(pubkey_x).write(true);
            self.buyer_pubkey_y.entry(pubkey_x).write(pubkey_y);

            self.emit(BuyerRegistered { buyer_pubkey_x: pubkey_x, buyer_pubkey_y: pubkey_y });
        }

        /// Buy a key from a listing.
        ///
        /// Flow:
        /// 1. Transfer key_price from buyer to vendor
        /// 2. Encrypt key_amount under buyer's pubkey
        /// 3. Store encrypted balance
        fn buy_key(
            ref self: ContractState,
            listing_id: u64,
            buyer_pubkey_x: felt252,
            buyer_pubkey_y: felt252,
            randomness: felt252,
        ) {
            let caller = get_caller_address();
            assert(self.buyer_registered.entry(buyer_pubkey_x).read(), 'Buyer not registered');
            assert(
                self.buyer_pubkey_y.entry(buyer_pubkey_x).read() == buyer_pubkey_y,
                'Invalid pubkey y',
            );

            let mut listing = self.listings.entry(listing_id).read();
            assert(listing.active, 'Listing not active');
            assert(randomness != 0, 'Randomness cannot be zero');

            // Transfer payment from buyer to vendor
            let token = IERC20Dispatcher { contract_address: self.payment_token.read() };
            let vendor = self.vendor.read();

            token.transfer_from(caller, vendor, listing.key_price);

            // ElGamal encryption: encrypt key_amount under buyer's pubkey
            let g_ec: EcPoint = EcPointTrait::new(GEN_X, GEN_Y).expect('Invalid generator');
            let g_nz: NonZeroEcPoint = g_ec.try_into().expect('Generator is zero');

            let buyer_pubkey: NonZeroEcPoint = EcPointTrait::new_nz(
                buyer_pubkey_x,
                buyer_pubkey_y,
            )
                .expect('Invalid buyer public key');

            // R = g^r
            let R_ec: EcPoint = g_ec.mul(randomness);
            let R_nz: NonZeroEcPoint = R_ec.try_into().expect('R is zero point');

            // L = g^m * y^r
            let mut state = EcStateTrait::init();
            state.add_mul(listing.key_amount, g_nz);
            state.add_mul(randomness, buyer_pubkey);
            let L_nz: NonZeroEcPoint = state.finalize_nz().expect('L is zero point');

            // Convert to StarkPoint
            let (lx, ly) = L_nz.coordinates();
            let (rx, ry) = R_nz.coordinates();
            let L = StarkPoint { x: lx, y: ly };
            let R = StarkPoint { x: rx, y: ry };

            // Store encrypted balance
            let cipher = CipherBalance { L, R };
            self.balances.entry(buyer_pubkey_x).write(cipher);

            // Update listing
            listing.keys_sold += 1;
            self.listings.entry(listing_id).write(listing);

            // Update total
            let nonce = self.total_keys_sold.read();
            self.total_keys_sold.write(nonce + 1);

            self
                .emit(
                    KeyPurchased {
                        listing_id, buyer_pubkey_x, buyer_pubkey_y, nonce,
                    },
                );
        }

        /// Get encrypted balance for a buyer.
        fn get_encrypted_balance(
            self: @ContractState,
            buyer_pubkey_x: felt252,
            buyer_pubkey_y: felt252,
        ) -> (felt252, felt252, felt252, felt252) {
            assert(self.buyer_registered.entry(buyer_pubkey_x).read(), 'Buyer not registered');
            assert(
                self.buyer_pubkey_y.entry(buyer_pubkey_x).read() == buyer_pubkey_y,
                'Invalid pubkey y',
            );

            let cipher = self.balances.entry(buyer_pubkey_x).read();
            (cipher.L.x, cipher.L.y, cipher.R.x, cipher.R.y)
        }

        /// Get listing details.
        fn get_listing(
            self: @ContractState,
            listing_id: u64,
        ) -> (u256, felt252, bool, u64) {
            let listing = self.listings.entry(listing_id).read();
            (listing.key_price, listing.key_amount, listing.active, listing.keys_sold)
        }

        fn get_vendor(self: @ContractState) -> ContractAddress {
            self.vendor.read()
        }

        fn get_total_listings(self: @ContractState) -> u64 {
            self.total_listings.read()
        }

        fn get_total_keys_sold(self: @ContractState) -> u64 {
            self.total_keys_sold.read()
        }
    }
}
