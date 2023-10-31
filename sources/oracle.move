module oracle::oracle {
    use std::vector;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};

    const DEFAULT_UPDATE_INTERVAL: u64 = 30000;

    const ENONEXISTENT_ORACLE: u64 = 50000;
    const EALREADY_EXIST_ORACLE: u64 = 50001;
    const NOT_OWNER: u64 = 50001;
    const NOT_FEEDER: u64 = 50002;
    const LENGTH_NOT_MATCH: u64 = 50003;

    struct OracleCap has key {
        id: UID,
        owner: Table<address, bool>,
        feeder: Table<address, bool>,
    }

    struct PriceOracle has key {
        id: UID,
        price_oracles: Table<u8, Price>,
        update_interval: u64,
    }

    struct Price has store {
        value: u256,
        // 2 decimals should be 100,
        decimal: u8,
        timestamp: u64
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(PriceOracle {
            id: object::new(ctx),
            price_oracles: table::new(ctx),
            update_interval: DEFAULT_UPDATE_INTERVAL
        });

        let owner = table::new<address, bool>(ctx);
        table::add(&mut owner, tx_context::sender(ctx), true);

        transfer::share_object(OracleCap {
            id: object::new(ctx),
            owner: owner,
            feeder: table::new<address, bool>(ctx)
        })
    }

    fun only_feeder(cap: &OracleCap, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let is_contain = table::contains(&cap.feeder, sender);
        assert!(is_contain, NOT_FEEDER);

        let pass = table::borrow(&cap.feeder, sender);
        assert!(*pass, NOT_FEEDER)
    }

    fun only_owner(cap: &OracleCap, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let is_contain = table::contains(&cap.owner, sender);
        assert!(is_contain, NOT_OWNER);

        let pass = table::borrow(&cap.owner, sender);
        assert!(*pass, NOT_OWNER)
    }

    public entry fun set_update_interval(
        cap: &OracleCap,
        price_oracle: &mut PriceOracle,
        update_interval: u64,
        ctx: &mut TxContext
    ) {
        only_owner(cap, ctx);
        price_oracle.update_interval = update_interval;
    }
    
    public entry fun register_token_price(
        cap: &OracleCap,
        price_oracle: &mut PriceOracle,
        pool_id: u8,
        token_price: u256,
        price_decimal: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        only_owner(cap, ctx);

        let price_oracles = &mut price_oracle.price_oracles;
        assert!(!table::contains(price_oracles, pool_id), EALREADY_EXIST_ORACLE);
        table::add(price_oracles, pool_id, Price {
            value: token_price,
            decimal: price_decimal,
            timestamp: clock::timestamp_ms(clock)
        })
    }

    public entry fun update_token_price(
        cap: &OracleCap,
        price_oracle: &mut PriceOracle,
        pool_id: u8,
        token_price: u256,
        timestamp: u64,
        ctx: &mut TxContext
    ) {
        only_feeder(cap, ctx);
        
        let price_oracles = &mut price_oracle.price_oracles;
        assert!(table::contains(price_oracles, pool_id), ENONEXISTENT_ORACLE);
        let price = table::borrow_mut(price_oracles, pool_id);
        price.value = token_price;
        price.timestamp = timestamp;
    }

    public entry fun update_token_price_batch(
        cap: &OracleCap,
        price_oracle: &mut PriceOracle,
        pool_ids: vector<u8>,
        token_prices: vector<u256>,
        timestamps: vector<u64>,
        ctx: &mut TxContext
    ) {
        only_feeder(cap, ctx);

        let len = vector::length(&pool_ids);
        assert!(len == vector::length(&token_prices), LENGTH_NOT_MATCH);
        assert!(len == vector::length(&timestamps), LENGTH_NOT_MATCH);

        let i = 0;
        let price_oracles = &mut price_oracle.price_oracles;
        while (i < len) {
            let pool_id = vector::borrow(&pool_ids, i);
            assert!(table::contains(price_oracles, *pool_id), ENONEXISTENT_ORACLE);

            let price = table::borrow_mut(price_oracles, *pool_id);
            price.value = *vector::borrow(&token_prices, i);
            price.timestamp = *vector::borrow(&timestamps, i);
            i = i + 1;
        }
    }

    public fun get_token_price(price_oracle: &PriceOracle, clock: &Clock, pool_id: u8): (bool, u256, u8) {
        let price_oracles = &price_oracle.price_oracles;
        assert!(table::contains(price_oracles, pool_id), ENONEXISTENT_ORACLE);
        let price = table::borrow(price_oracles, pool_id);
        let current_ts = clock::timestamp_ms(clock);
        let valid = current_ts <= price.timestamp + price_oracle.update_interval;
        (valid, price.value, price.decimal)
    }

    public fun set_owner(cap: &mut OracleCap, owner: address, val: bool, ctx: &mut TxContext) {
        only_owner(cap, ctx);

        let is_contain = table::contains(&cap.owner, owner);
        if (!is_contain) {
            if (val) {
                table::add(&mut cap.owner, owner, val)
            }
        } else {
            if (!val) {
                _ = table::remove(&mut cap.owner, owner)
            }
        };
    }

    public fun set_feeder(cap: &mut OracleCap, feeder: address, val: bool, ctx: &mut TxContext) {
        only_owner(cap, ctx);

        let is_contain = table::contains(&cap.feeder, feeder);
        if (!is_contain) {
            if (val) {
                table::add(&mut cap.feeder, feeder, val)
            }
        } else {
            if (!val) {
                _ = table::remove(&mut cap.feeder, feeder)
            }
        };
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        transfer::share_object(PriceOracle {
            id: object::new(ctx),
            price_oracles: table::new(ctx),
			update_interval: DEFAULT_UPDATE_INTERVAL
        });
        
        let owner = table::new<address, bool>(ctx);
        table::add(&mut owner, tx_context::sender(ctx), true);

        transfer::share_object(OracleCap {
            id: object::new(ctx),
            owner: owner,
            feeder: table::new<address, bool>(ctx),
        })
    }
}