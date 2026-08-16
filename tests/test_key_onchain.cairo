use core::ec::{EcPoint, EcPointTrait, EcStateTrait, NonZeroEcPoint};
use core::ec::stark_curve::{GEN_X, GEN_Y};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use starknet::contract_address_const;
use key_onchain::key_onchain::IKeyOnChainDispatcher;
use key_onchain::key_onchain::IKeyOnChainDispatcherTrait;

/// Deploy the KeyOnChain contract with the given vendor address.
fn deploy_contract(vendor: ContractAddress) -> (ContractAddress, IKeyOnChainDispatcher) {
    let contract = declare("KeyOnChain").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![vendor.into()]).unwrap();
    let dispatcher = IKeyOnChainDispatcher { contract_address };
    (contract_address, dispatcher)
}

/// Compute g^private_key on the Stark curve (public key derivation).
fn compute_public_key(private_key: felt252) -> (felt252, felt252) {
    let g: EcPoint = EcPointTrait::new(GEN_X, GEN_Y).unwrap();
    let pub_ec: EcPoint = g.mul(private_key);
    let pub_nz: NonZeroEcPoint = pub_ec.try_into().unwrap();
    let (x, y) = pub_nz.coordinates();
    (x, y)
}

/// ElGamal decryption: recover m from ciphertext (L, R) given private key x.
/// Verify: g^m * R^x == L (homomorphic property).
/// Brute-force discrete log for small values.
fn elgamal_decrypt(
    private_key: felt252,
    L_x: felt252,
    L_y: felt252,
    R_x: felt252,
    R_y: felt252,
) -> felt252 {
    let L_nz: NonZeroEcPoint = EcPointTrait::new_nz(L_x, L_y).unwrap();
    let R_nz: NonZeroEcPoint = EcPointTrait::new_nz(R_x, R_y).unwrap();
    let g: EcPoint = EcPointTrait::new(GEN_X, GEN_Y).unwrap();
    let g_nz: NonZeroEcPoint = g.try_into().unwrap();

    let mut m: felt252 = 1;
    loop {
        if m == 10000 {
            break;
        }
        // Verify: g^m * R^private_key == L
        let mut s = EcStateTrait::init();
        s.add_mul(m, g_nz);
        s.add_mul(private_key, R_nz);
        let check_L: EcPoint = s.finalize();

        let (clx, cly) = check_L.try_into().unwrap().coordinates();
        if clx == L_x && cly == L_y {
            return m;
        }
        m += 1;
    };
    0
}

// ============================================================
// Tests
// ============================================================

#[test]
fn test_mint_and_read_encrypted_key() {
    let vendor: ContractAddress = contract_address_const::<0x1234>();
    let (_addr, dispatcher) = deploy_contract(vendor);

    // Generate buyer keypair (private=42)
    let private_key: felt252 = 42;
    let (pub_x, pub_y) = compute_public_key(private_key);

    // The secret key we want to deliver: 1337
    let key_amount: felt252 = 1337;
    let randomness: felt252 = 7777;

    // Vendor mints the encrypted key
    start_cheat_caller_address(_addr, vendor);
    dispatcher.mint_key(pub_x, pub_y, key_amount, randomness);
    stop_cheat_caller_address(_addr);

    // Verify total keys
    assert(dispatcher.get_total_keys() == 1, 'Total keys should be 1');

    // Read encrypted balance
    let (L_x, L_y, R_x, R_y) = dispatcher.get_encrypted_balance(pub_x, pub_y);

    // Verify: L and R should not be zero (encryption happened)
    assert(L_x != 0 || L_y != 0, 'L should not be zero');
    assert(R_x != 0 || R_y != 0, 'R should not be zero');

    // Decrypt off-chain using the private key
    let decrypted = elgamal_decrypt(private_key, L_x, L_y, R_x, R_y);

    // The decrypted value should equal the key amount
    assert(decrypted == key_amount, 'Decrypted key should match');
}

#[test]
#[should_panic(expected: 'Only vendor can mint keys')]
fn test_non_vendor_cannot_mint() {
    let vendor: ContractAddress = contract_address_const::<0x1234>();
    let attacker: ContractAddress = contract_address_const::<0xBEEF>();
    let (_addr, dispatcher) = deploy_contract(vendor);

    let private_key: felt252 = 42;
    let (pub_x, pub_y) = compute_public_key(private_key);

    // Attacker tries to mint — should fail
    start_cheat_caller_address(_addr, attacker);
    dispatcher.mint_key(pub_x, pub_y, 1337, 7777);
    stop_cheat_caller_address(_addr);
}

#[test]
#[should_panic(expected: 'Pubkey not registered')]
fn test_read_unregistered_pubkey() {
    let vendor: ContractAddress = contract_address_const::<0x1234>();
    let (_addr, dispatcher) = deploy_contract(vendor);

    // Try to read balance for a pubkey that was never registered
    dispatcher.get_encrypted_balance(123, 456);
}

#[test]
fn test_multiple_keys_different_buyers() {
    let vendor: ContractAddress = contract_address_const::<0x1234>();
    let (_addr, dispatcher) = deploy_contract(vendor);

    // Buyer 1: private_key=42, key_amount=100
    let pk1: felt252 = 42;
    let (px1, py1) = compute_public_key(pk1);
    let key1: felt252 = 100;
    let rand1: felt252 = 1111;

    // Buyer 2: private_key=99, key_amount=200
    let pk2: felt252 = 99;
    let (px2, py2) = compute_public_key(pk2);
    let key2: felt252 = 200;
    let rand2: felt252 = 2222;

    // Mint for both
    start_cheat_caller_address(_addr, vendor);
    dispatcher.mint_key(px1, py1, key1, rand1);
    dispatcher.mint_key(px2, py2, key2, rand2);
    stop_cheat_caller_address(_addr);

    assert(dispatcher.get_total_keys() == 2, 'Total keys should be 2');

    // Read and decrypt for buyer 1
    let (L1_x, L1_y, R1_x, R1_y) = dispatcher.get_encrypted_balance(px1, py1);
    let dec1 = elgamal_decrypt(pk1, L1_x, L1_y, R1_x, R1_y);
    assert(dec1 == key1, 'Buyer 1 key mismatch');

    // Read and decrypt for buyer 2
    let (L2_x, L2_y, R2_x, R2_y) = dispatcher.get_encrypted_balance(px2, py2);
    let dec2 = elgamal_decrypt(pk2, L2_x, L2_y, R2_x, R2_y);
    assert(dec2 == key2, 'Buyer 2 key mismatch');
}
