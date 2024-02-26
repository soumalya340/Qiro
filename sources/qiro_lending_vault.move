module qiro::lending_vault {
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_std::type_info::TypeInfo;
    use aptos_std::simple_map::SimpleMap;
    use switchboard::aggregator; // For reading aggregators
    use switchboard::feed;

    // Resources
    struct Whitelist has key{
        whitelist: vector<address>,
    }

    struct Balance has key, store {
        coins: u64,
        lp_tokens: u64,
        last_deposit_time: u64,
    }

     struct AggregatorInfo has copy, drop, store, key {
        aggregator_addr: address,
        latest_result: u128,
        latest_result_scaling_factor: u8,
    }

    // Error codes
    const ERR_NOT_ADMIN: u64 = 1;
    const ERR_USER_NOT_WHITELISTED: u64 = 42;
    const ERR_INSUFFICIENT_BALANCE: u64 = 101;
    const ERR_ALREADY_WHITELISTED: u64 = 102;

    const EAGGREGATOR_INFO_EXISTS:u64 = 0;
    const ENO_AGGREGATOR_INFO_EXISTS:u64 = 1;

    // Events
    #[event]
    struct DepositedEvent has drop,store{
        user: address,
        amount: u64,
        lp_tokens: u64,
    }

    #[event]
    struct WithdrewEvent has drop,store{
        user: address,
        amount: u64,
        lp_tokens_burned: u64,
    }

    #[event]
    struct InterestAccruedEvent has drop,store {
        total_interest: u64,
    }

    // Initialize vault with initial amount and whitelist
    fun init_module(_admin: &signer, initial_amount: u64) {
        assert!(signer::address_of(_admin) == ADMIN_ADDRESS, ERR_NOT_ADMIN);
        move_to(_admin, Whitelist { whitelist: vector::empty() });
        // Optionally add initial funding logic here
        // Event for interest accrued could be initialized here if needed
    }    

    // add AggregatorInfo resource with latest value + aggregator address
    public entry fun log_aggregator_info(
        account: &signer,
        aggregator_addr: address, 
    ) {       
        assert!(!exists<AggregatorInfo>(signer::address_of(account)), EAGGREGATOR_INFO_EXISTS);

        // get latest value 
        let (value, credit_factor, _neg) = feed::unpack(aggregator::latest_value(aggregator_addr)); 
        move_to(account, AggregatorInfo {
            aggregator_addr: aggregator_addr,
            latest_result: value,
            latest_result_scaling_factor: scaling_factor
        });
    }

    // Admin Features
    public entry fun add_to_whitelist(_admin: &signer, addresses: vector<address>) acquires Whitelist {
        assert!(signer::address_of(_admin) == ADMIN_ADDRESS, ERR_NOT_ADMIN);
        let whitelist = borrow_global_mut<Whitelist>(ADMIN_ADDRESS);
        let len = vector::length(&addresses);

        let i = 0;
        while (i < len) {
            let addr = vector::borrow(&addresses, i);
            // Ensure user is not already whitelisted
            assert!(!vector::contains(&whitelist.whitelist, addr), ERR_ALREADY_WHITELISTED);
            vector::push_back(&mut whitelist.whitelist, *addr);
            i = i + 1;
        }
    }

    // Checks if an address is whitelisted
    #[view]
    public entry fun is_whitelisted(addr: &signer): bool acquires Whitelist {
        let whitelist = borrow_global<Whitelist>(ADMIN_ADDRESS);
        let user = signer::address_of(addr);
        vector::contains(&whitelist.whitelist, user);
    }

    // Deposit Functionality with Minting

    public fun deposit(_account: &signer, amount: u64) acquires Balance,Whitelist {
        let acc_addr = signer::address_of(_account);
        assert!(is_whitelisted(acc_addr), ERR_USER_NOT_WHITELISTED);

        let time_now = timestamp::now_seconds();
        let balance = if (exists<Balance>(acc_addr)) {
            borrow_global_mut<Balance>(acc_addr)
        } else {
            move_to(_account, Balance { coins: 0, lp_tokens: 0, last_deposit_time: time_now });
            borrow_global_mut<Balance>(acc_addr)
        };

        // Calculate interest earned since last deposit
        let time_passed = time_now - balance.last_deposit_time;
        let interest_earned = calculate_interest(balance.coins, time_passed);

        // Update balance and mint LP tokens
        balance.coins = balance.coins + amount + interest_earned; // Add deposited amount and accrued interest
        balance.lp_tokens = balance.lp_tokens + amount; // Mint LP tokens equal to deposited amount
        balance.last_deposit_time = time_now;

        // Emit event for deposit
        let event = Deposited {
            user: acc_addr,
            amount: amount,
            lp_tokens: balance.lp_tokens,
        };
        0x1::event::emit(event);

    }

    // Withdrawal Mechanism with Burning
    public fun withdraw(_account: &signer, amount: u64) acquires Balance,Whitelist {
        let acc_addr = signer::address_of(_account);
        assert!(is_whitelisted(acc_addr), ERR_USER_NOT_WHITELISTED);
        let balance = borrow_global_mut<Balance>(acc_addr);

        assert!(balance.coins >= amount, ERR_INSUFFICIENT_BALANCE);

        // Calculate interest earned since last deposit
        let time_passed = timestamp::now_seconds() - balance.last_deposit_time;
        let interest_earned = calculate_interest(balance.coins, time_passed);
        balance.coins = balance.coins + interest_earned; // Add accrued interest to withdrawable amount

        // Subtract withdrawal amount from both coins and LP tokens
        balance.coins =balance.coins - amount;
        balance.lp_tokens = balance.lp_tokens - amount;
        balance.last_deposit_time = timestamp::now_seconds();

        // Emit event for withdrawal
        let event = Withdrew {
            user: acc_addr,
            amount: amount,
            lp_tokens_burned: amount, // Assuming 1:1 withdrawal
        };
        0x1::event::emit(event);
    }

    // Function to calculate interest based on a simple formula
    #[view]
    fun calculate_interest(principal: u64, time_passed: u64): u64 {
        let annual_interest_rate = 10; // 10% annual interest rate
        let interest_for_period = (principal * annual_interest_rate * time_passed) / (365 * 24 * 60 * 60 * 100);
        interest_for_period
    }
    
}

