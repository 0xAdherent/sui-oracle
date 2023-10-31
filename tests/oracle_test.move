#[test_only]
module oracle::oracle_test {
    use sui::test_scenario;
    use sui::clock::{Self};
    use oracle::oracle::{Self, OracleCap, PriceOracle};

    #[test]
    public fun test_permission() {
        let owner = @oracle;
        let owner_a = @0x8;
        let feeder_a = @0x9;
        let owner_scenario = test_scenario::begin(owner);
        let owner_a_scenario = test_scenario::begin(owner_a);
        let feeder_a_scenario = test_scenario::begin(feeder_a);

        let pool_id = 0;
        let token_decimal = 6;
        let initial_token_price = 9900000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut owner_scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut owner_scenario);
            clock::create_for_testing(ctx)
        };

        // function: set_owner(set owner_a to owner rule via owner)
        test_scenario::next_tx(&mut owner_scenario, owner);
        {
            let oracle_cap = test_scenario::take_shared<OracleCap>(&owner_scenario);
            oracle::set_owner(
                &mut oracle_cap,
                owner_a,
                true,
                test_scenario::ctx(&mut owner_scenario),
            );
            test_scenario::return_shared(oracle_cap);
        };

        // function: set_feeder(set feeder_a to feeder rule via owner_a)
        test_scenario::next_tx(&mut owner_a_scenario, owner_a);
        {
            let oracle_cap = test_scenario::take_shared<OracleCap>(&owner_scenario);
            oracle::set_feeder(
                &mut oracle_cap,
                owner_a,
                true,
                test_scenario::ctx(&mut owner_a_scenario),
            );
            test_scenario::return_shared(oracle_cap);
        };

        // function: register_token_price(register token via owner_a)
        test_scenario::next_tx(&mut owner_a_scenario, owner_a);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&owner_a_scenario);
            let oracle_cap = test_scenario::take_shared<OracleCap>(&owner_a_scenario);

            oracle::register_token_price(
                &oracle_cap,
                &mut price_oracle,
                pool_id,
                initial_token_price,
                token_decimal,
                &clock,
                test_scenario::ctx(&mut owner_a_scenario),
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap);
        };
        
        // function: update_token_price(update token price via feeder_a)
        test_scenario::next_tx(&mut feeder_a_scenario, owner_a);
        {
            let new_token_price = 10000000;
            let price_oracle = test_scenario::take_shared<PriceOracle>(&feeder_a_scenario);
            let oracle_cap = test_scenario::take_shared<OracleCap>(&feeder_a_scenario);

            oracle::update_token_price(
                &oracle_cap,
                &mut price_oracle,
                pool_id,
                new_token_price,
                10000,
                test_scenario::ctx(&mut feeder_a_scenario),
            );
            
            let (valid, value, decimal) = oracle::get_token_price(&mut price_oracle, &clock, pool_id);
            assert!(valid, 0);
            assert!(value == new_token_price, 0);
            assert!(decimal == token_decimal, 0);

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(owner_scenario);
        test_scenario::end(owner_a_scenario);
        test_scenario::end(feeder_a_scenario);
    }

    #[test]
    public fun test_register_and_get_price() {
        let owner = @oracle;
        let scenario = test_scenario::begin(owner);

        // paramt
        let pool_id = 0;
        let decimal = 6;
        let initial_token_price = 9900000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // test register token
        test_scenario::next_tx(&mut scenario, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);

            oracle::register_token_price(
                &oracle_cap,
                &mut price_oracle,
                pool_id,
                initial_token_price,
                decimal,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap);
        };

        // test get price and decimals
        test_scenario::next_tx(&mut scenario, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let (valid, value, decimal) = oracle::get_token_price(&mut price_oracle, &clock, pool_id);

            assert!(valid, 0);
            assert!(value == initial_token_price, 0);
            assert!(decimal == decimal, 0);
            test_scenario::return_shared(price_oracle); 
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    public fun test_update_price() {
        let owner = @oracle;
        let scenario = test_scenario::begin(owner);

        // paramt
        let pool_id = 0;
        let decimal = 6;
        let initial_token_price = 9900000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // set feeder
        test_scenario::next_tx(&mut scenario, owner);
        {
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);
            oracle::set_feeder(
                &mut oracle_cap,
                owner,
                true,
                test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(oracle_cap); 
        };

        // test register token
        test_scenario::next_tx(&mut scenario, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);

            oracle::register_token_price(
                &oracle_cap,
                &mut price_oracle,
                pool_id,
                initial_token_price,
                decimal,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap);
        };

        // test update token price
        test_scenario::next_tx(&mut scenario, owner);
        {
            let pool_id = 0;
            let token_decimal = 6;
            let new_token_price = 10000000;

            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);

            oracle::update_token_price(
                &oracle_cap,
                &mut price_oracle,
                pool_id,
                new_token_price,
                100000,
                test_scenario::ctx(&mut scenario),
            );

            let (valid, value, decimal) = oracle::get_token_price(&mut price_oracle, &clock, pool_id);
            assert!(valid, 0);
            assert!(value == new_token_price, 0);
            assert!(decimal == token_decimal, 0);

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap);
        };
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }


    #[test]
    public fun test_invalid_update_price() {
        let owner = @oracle;
        let scenario = test_scenario::begin(owner);

        // paramt
        let pool_id = 0;
        let decimal = 6;
        let initial_token_price = 9900000;

        // package init
        {
            oracle::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        let clock = {
            let ctx = test_scenario::ctx(&mut scenario);
            clock::create_for_testing(ctx)
        };

        // set update interval
        test_scenario::next_tx(&mut scenario, owner);
        {
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            oracle::set_update_interval(
                &oracle_cap,
                &mut price_oracle,
                1000,
                test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap); 
        };

        // set feeder
        test_scenario::next_tx(&mut scenario, owner);
        {
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);
            oracle::set_feeder(
                &mut oracle_cap,
                owner,
                true,
                test_scenario::ctx(&mut scenario),
            );
            test_scenario::return_shared(oracle_cap); 
        };

        // test register token
        test_scenario::next_tx(&mut scenario, owner);
        {
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);

            oracle::register_token_price(
                &oracle_cap,
                &mut price_oracle,
                pool_id,
                initial_token_price,
                decimal,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap);
        };

        // test update token price
        test_scenario::next_tx(&mut scenario, owner);
        {
            let pool_id = 0;
            let token_decimal = 6;
            let new_token_price = 10000000;

            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);
            let oracle_cap = test_scenario::take_shared<OracleCap>(&scenario);

            oracle::update_token_price(
                &oracle_cap,
                &mut price_oracle,
                pool_id,
                new_token_price,
                2000,
                test_scenario::ctx(&mut scenario),
            );

            let (valid, value, decimal) = oracle::get_token_price(&mut price_oracle, &clock, pool_id);
            assert!(valid, 0);
            assert!(value == new_token_price, 0);
            assert!(decimal == token_decimal, 0);

            clock::increment_for_testing(&mut clock, 5000);

            test_scenario::return_shared(price_oracle); 
            test_scenario::return_shared(oracle_cap);
        };

        test_scenario::next_tx(&mut scenario, owner);
        {
            let pool_id = 0;
            let price_oracle = test_scenario::take_shared<PriceOracle>(&scenario);

            let (valid, _, _) = oracle::get_token_price(&mut price_oracle, &clock, pool_id);
            assert!(!valid, 0);

            test_scenario::return_shared(price_oracle);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}