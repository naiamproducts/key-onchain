/// # KeyOnChain
///
/// A confidential key distribution system using ElGamal encryption on the Starknet curve.
///
/// ## Architecture
/// - `KeyOnChain`: Simple contract for vendor-to-buyer key distribution
/// - `KeyMarket`: Marketplace with listings, payments, and encrypted balances
///
/// ## Key Insight
/// The transfer amount IS the secret key. ElGamal encryption hides the amount on-chain,
/// so only the buyer can decrypt it using their private key.

/// Simple key distribution contract (vendor mints directly).
pub mod key_onchain {
    /// Interface for the KeyOnChain contract.
    #[starknet::interface]
    pub trait IKeyOnChain<TContractState> {
        /// Mints an encrypted key for a buyer. Only the vendor can call this.
        fn mint_key(
            ref self: TContractState,
            buyer_pubkey_x: felt252,
            buyer_pubkey_y: felt252,
            key_amount: felt252,
            randomness: felt252,
        );

        /// Returns the encrypted balance (L_x, L_y, R_x, R_y) for a given public key.
        fn get_encrypted_balance(
            self: @TContractState,
            pubkey_x: felt252,
            pubkey_y: felt252,
        ) -> (felt252, felt252, felt252, felt252);

        /// Returns the vendor's address.
        fn get_vendor(self: @TContractState) -> starknet::ContractAddress;

        /// Returns the total number of keys minted.
        fn get_total_keys(self: @TContractState) -> u64;
    }

    /// KeyOnChain Contract
    #[starknet::contract]
    pub mod KeyOnChain {
        use core::ec::{EcPoint, EcPointTrait, EcStateTrait, NonZeroEcPoint};
        use core::ec::stark_curve::{GEN_X, GEN_Y};
        use starknet::storage::{
            Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        };
        use starknet::{ContractAddress, get_caller_address};

        /// Represents a point on the Stark curve.
        #[derive(Drop, Copy, Serde, starknet::Store)]
        struct StarkPoint {
            x: felt252,
            y: felt252,
        }

        /// ElGamal ciphertext: (L, R)
        #[derive(Drop, Copy, Serde, starknet::Store)]
        struct CipherBalance {
            L: StarkPoint,
            R: StarkPoint,
        }

        #[storage]
        struct Storage {
            vendor: ContractAddress,
            balances: Map<felt252, CipherBalance>,
            registered: Map<felt252, bool>,
            pubkey_y: Map<felt252, felt252>,
            total_keys: u64,
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            KeyMinted: KeyMinted,
        }

        #[derive(Drop, starknet::Event)]
        struct KeyMinted {
            buyer_pubkey_x: felt252,
            buyer_pubkey_y: felt252,
            nonce: u64,
        }

        #[constructor]
        fn constructor(ref self: ContractState, vendor: ContractAddress) {
            self.vendor.write(vendor);
            self.total_keys.write(0);
        }

        #[abi(embed_v0)]
        impl KeyOnChainImpl of super::IKeyOnChain<ContractState> {
            fn mint_key(
                ref self: ContractState,
                buyer_pubkey_x: felt252,
                buyer_pubkey_y: felt252,
                key_amount: felt252,
                randomness: felt252,
            ) {
                let caller = get_caller_address();
                assert(caller == self.vendor.read(), 'Only vendor can mint keys');
                assert(key_amount != 0, 'Key amount cannot be zero');
                assert(randomness != 0, 'Randomness cannot be zero');

                let g_ec: EcPoint = EcPointTrait::new(GEN_X, GEN_Y).expect('Invalid generator');
                let g_nz: NonZeroEcPoint = g_ec.try_into().expect('Generator is zero');

                let buyer_pubkey: NonZeroEcPoint = EcPointTrait::new_nz(
                    buyer_pubkey_x,
                    buyer_pubkey_y,
                )
                    .expect('Invalid buyer public key');

                let R_ec: EcPoint = g_ec.mul(randomness);
                let R_nz: NonZeroEcPoint = R_ec.try_into().expect('R is zero point');

                let mut state = EcStateTrait::init();
                state.add_mul(key_amount, g_nz);
                state.add_mul(randomness, buyer_pubkey);
                let L_nz: NonZeroEcPoint = state.finalize_nz().expect('L is zero point');

                let (lx, ly) = L_nz.coordinates();
                let (rx, ry) = R_nz.coordinates();
                let L = StarkPoint { x: lx, y: ly };
                let R = StarkPoint { x: rx, y: ry };

                let cipher = CipherBalance { L, R };
                self.balances.entry(buyer_pubkey_x).write(cipher);
                self.registered.entry(buyer_pubkey_x).write(true);
                self.pubkey_y.entry(buyer_pubkey_x).write(buyer_pubkey_y);

                let nonce = self.total_keys.read();
                self.total_keys.write(nonce + 1);

                self.emit(KeyMinted { buyer_pubkey_x, buyer_pubkey_y, nonce });
            }

            fn get_encrypted_balance(
                self: @ContractState,
                pubkey_x: felt252,
                pubkey_y: felt252,
            ) -> (felt252, felt252, felt252, felt252) {
                assert(self.registered.entry(pubkey_x).read(), 'Pubkey not registered');
                assert(self.pubkey_y.entry(pubkey_x).read() == pubkey_y, 'Invalid pubkey y');

                let cipher = self.balances.entry(pubkey_x).read();
                (cipher.L.x, cipher.L.y, cipher.R.x, cipher.R.y)
            }

            fn get_vendor(self: @ContractState) -> ContractAddress {
                self.vendor.read()
            }

            fn get_total_keys(self: @ContractState) -> u64 {
                self.total_keys.read()
            }
        }
    }
}

/// Marketplace with listings, payments, and encrypted balances.
pub mod key_market {
    /// Interface for the KeyMarket contract.
    #[starknet::interface]
    pub trait IKeyMarket<TContractState> {
        /// Create a new key listing.
        fn create_listing(
            ref self: TContractState,
            key_price: u256,
            key_amount: felt252,
            description: felt252,
        );

        /// Deactivate a listing.
        fn deactivate_listing(ref self: TContractState, listing_id: u64);

        /// Register a buyer with their public key.
        fn register_buyer(
            ref self: TContractState,
            pubkey_x: felt252,
            pubkey_y: felt252,
        );

        /// Buy a key from a listing.
        fn buy_key(
            ref self: TContractState,
            listing_id: u64,
            buyer_pubkey_x: felt252,
            buyer_pubkey_y: felt252,
            randomness: felt252,
        );

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
        fn get_total_keys_sold(self: @TContractState) -> u64;
    }

    /// KeyMarket Contract
    #[starknet::contract]
    pub mod KeyMarket {
        use core::ec::{EcPoint, EcPointTrait, EcStateTrait, NonZeroEcPoint};
        use core::ec::stark_curve::{GEN_X, GEN_Y};
        use starknet::storage::{
            Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        };
        use starknet::{ContractAddress, get_caller_address};

        /// Minimal ERC20 interface for payment transfers.
        #[starknet::interface]
        trait IERC20<TContractState> {
            fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
            fn transfer_from(
                ref self: TContractState,
                sender: ContractAddress,
                recipient: ContractAddress,
                amount: u256,
            ) -> bool;
            fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
        }

        /// Represents a point on the Stark curve.
        #[derive(Drop, Copy, Serde, starknet::Store)]
        struct StarkPoint {
            x: felt252,
            y: felt252,
        }

        /// ElGamal ciphertext: (L, R)
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
            vendor: ContractAddress,
            payment_token: ContractAddress,
            listings: Map<u64, Listing>,
            total_listings: u64,
            balances: Map<felt252, CipherBalance>,
            buyer_registered: Map<felt252, bool>,
            buyer_pubkey_y: Map<felt252, felt252>,
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

            fn deactivate_listing(ref self: ContractState, listing_id: u64) {
                let caller = get_caller_address();
                assert(caller == self.vendor.read(), 'Only vendor can deactivate');

                let mut listing = self.listings.entry(listing_id).read();
                listing.active = false;
                self.listings.entry(listing_id).write(listing);

                self.emit(ListingDeactivated { listing_id });
            }

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

                // ElGamal encryption
                let g_ec: EcPoint = EcPointTrait::new(GEN_X, GEN_Y).expect('Invalid generator');
                let g_nz: NonZeroEcPoint = g_ec.try_into().expect('Generator is zero');

                let buyer_pubkey: NonZeroEcPoint = EcPointTrait::new_nz(
                    buyer_pubkey_x,
                    buyer_pubkey_y,
                )
                    .expect('Invalid buyer public key');

                let R_ec: EcPoint = g_ec.mul(randomness);
                let R_nz: NonZeroEcPoint = R_ec.try_into().expect('R is zero point');

                let mut state = EcStateTrait::init();
                state.add_mul(listing.key_amount, g_nz);
                state.add_mul(randomness, buyer_pubkey);
                let L_nz: NonZeroEcPoint = state.finalize_nz().expect('L is zero point');

                let (lx, ly) = L_nz.coordinates();
                let (rx, ry) = R_nz.coordinates();
                let L = StarkPoint { x: lx, y: ly };
                let R = StarkPoint { x: rx, y: ry };

                let cipher = CipherBalance { L, R };
                self.balances.entry(buyer_pubkey_x).write(cipher);

                listing.keys_sold += 1;
                self.listings.entry(listing_id).write(listing);

                let nonce = self.total_keys_sold.read();
                self.total_keys_sold.write(nonce + 1);

                self
                    .emit(
                        KeyPurchased {
                            listing_id, buyer_pubkey_x, buyer_pubkey_y, nonce,
                        },
                    );
            }

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
}
