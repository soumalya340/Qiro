module qiro::lending_vault{
use std::signer;
use aptos_framework::account;
use aptos_framework::tx_context::TxContext;
use std::vector;
use aptos_framework::timestamp;
use aptos_framework::coin;
use aptos_framework::managed_coin;
use aptos_std::type_info;
use aptos_std::simple_map::{Self, SimpleMap};

const ADMIN_ADDRESS: address =  0x1;

// Resources
struct Whitelist has key, store, drop {
    whitelist: vector<address>,
}

struct Coins has store {
    val: u64,
}

struct Balance has key {
    coins: Coins,
    lp_tokens: u64, // Added: Track LP tokens
}

/// Error codes
const ERR_BALANCE_NOT_EXISTS: u64 = 101;
const ERR_USER_NOT_EXISTS: u64 = 42;
const ERR_BALANCE_EXISTS: u64 = 102;
const EINSUFFICIENT_BALANCE: u64 = 1;
const EALREADY_HAS_BALANCE: u64 = 2;
const EEQUAL_ADDR: u64 = 4;

// Events
#[event]
struct Deposited {
    user: address,
    amount: u64,
    lp_tokens: u64,
}
#[event]
struct Withdrew {
    user: address,
    amount: u64,
    lp_tokens_burned: u64,
}
#[event]
struct InterestAccrued {
    total_interest: u64,
}

// Admin Features
public entry fun add_to_whitelist(addresses: vector<address>) acquires Whitelist {
    assert!(signer::address_of(&signer) == ADMIN_ADDRESS,1);
    let whitelist = borrow_global_mut<Whitelist>(signer::address_of(account));
    let len = vector::length(&addresses);
    let i = 0;

    while (i < len) {
        let addr = *vector::borrow(&addresses, i);
        // Ensure user is not already whitelisted
        assert!(!vector::contains(&whitelist.whitelist, addr), EALREADY_HAS_BALANCE);
        vector::push_back(&mut whitelist.whitelist, addr);
        i = i + 1;
    }
}

// Deposit Functionality with Minting
public fun deposit(acc_addr: address, coins: Coins) acquires Balance {
    assert!(is_whitelisted(acc_addr),ERR_USER_NOT_EXISTS);

    let mut balance = ensure_balance_exists(acc_addr); // Create balance if it doesn't exist

    // Calculate interest earned since last deposit
    let time_passed = timestamp::get_time() - balance.last_deposit_time; // Calculate time since last deposit
    let interest_earned = calculate_interest(balance.coins.val, time_passed); // Calculate interest based on formula

    // Update balance and mint LP tokens
    balance.coins.val += coins.val + interest_earned; // Add deposited amount and accrued interest
    balance.lp_tokens += coins.val; // Mint LP tokens equal to deposited amount
    move_to(acc, balance);

    emit_event(Deposited {
        user: acc_addr,
        amount: coins.val,
        lp_tokens: balance.lp_tokens,
    });
}

// Withdrawal Mechanism with Burning
public fun withdraw(acc_addr: address, amount: u64) acquires Balance {
    assert!(is_whitelisted(acc_addr), "User is not whitelisted");

    let mut balance = ensure_balance_exists(acc_addr);

    assert!(balance.coins.val >= amount, EINSUFFICIENT_BALANCE);

    // Calculate interest earned since last deposit
    let time_passed = timestamp::get_time() - balance.last_deposit_time;
    let interest_earned = calculate_interest(balance.coins.val, time_passed);
    balance.coins.val += interest_earned; // Add accrued interest to withdrawable amount

    // Subtract withdrawal amount from both coins and LP tokens
    balance.coins.val -= amount;
    balance.lp_tokens -= amount;

    // Handle minimum balance requirements (if applicable)
    if balance.coins.val < get_minimum_balance() { // Replace with your minimum balance function
        panic!("Withdrawal would result in less than minimum balance");
    }

    // Burn LP tokens and emit event
    let burned_lp_tokens = amount; // Ensure amount matches withdrawn LP tokens
    burn_lp_tokens(burned_lp_tokens);
    emit_event(Withdrew {
        user: acc_addr,
        amount: amount,
        lp_tokens_burned: burned_lp_tokens,
    });

    move_to(acc, balance);

    return balance;
    }

    // Function to ensure balance exists, creating it if necessary
fun ensure_balance_exists(acc_addr: address): &mut Balance acquires Balance {
    if (!balance_exists(acc_addr)) {
        create_balance(acc_addr);
    }
    borrow_global_mut<Balance>(acc_addr)
}

// Function to create a new balance resource
fun create_balance(acc_addr: address) {
    assert!(!balance_exists(acc_addr), ERR_BALANCE_EXISTS);
    let zero_coins = Coins { val: 0 };
    let initial_lp_tokens = 0; // Initialize LP tokens to 0
    move_to(acc, Balance { coins: zero_coins, lp_tokens: initial_lp_tokens, last_deposit_time: timestamp::get_time() });
}

// Function to calculate interest based on a formula (replace with your specific formula)
#[view]
fun calculate_interest(principal: u64, time_passed: u64): u64 {
    // Replace with your interest calculation formula, considering annual rate, time passed, and compounding if applicable
    let annual_interest_rate = 10; // 10% annual interest rate (example)
    let daily_interest_rate = annual_interest_rate / 365;
    let interest_earned = principal * daily_interest_rate * time_passed;
    interest_earned
}

// Prefilled Money with Event Logging
public entry fun initialize_vault(amount: u64) {
    assert!(signer::address_of(&signer) == ADMIN_ADDRESS, 1);

    let prefilled_coins = Coins { val: amount };
    move_to(account::self_address(), prefilled_coins);

    emit_event(InterestAccrued {
        total_interest: 0, // Initially no interest accrued
    });
}
 #[view]
    public fun balance(owner: address): u64 acquires Balance {
        borrow_global<Balance>(owner).coins.val
    }

}