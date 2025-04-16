module escrow::escrow {
    // ===== Imports =====
    use std::string::utf8;
    use sui::coin::{Self, Coin};
    use sui::dynamic_object_field as dof;
    use sui::event::emit;
    use sui::transfer::public_transfer;
    use sui::tx_context::sender;
    use sui::package;
    use sui::clock::{Clock, timestamp_ms};
    use escrow::escrow_utils::{get_coin_from_dof, add_items_to_dof, get_items_from_dof, transfer_items, check_items_ids, check_vector_for_duplicates};

    // ===== Constants =====
    const ERR_WRONG_CREATOR: u64 = 0;
    const ERR_WRONG_RECIPIENT: u64 = 1;
    const ERR_WRONG_COIN_AMOUNT: u64 = 2;
    const ERR_INSUFFICIENT_PAY: u64 = 3;
    const ERR_ZERO_BALANCE: u64 = 4;
    const ERR_EXPIRED: u64 = 5;

    const FEE: u64 = 400_000_000;
    const FEE_RECIPIENT: address = @0xA;
    const SEVEN_DAYS_MS: u64 = 7 * 24 * 60 * 60 * 1000;

    // ===== Structs =====
    public struct Escrow<phantom T: key, phantom N: key + store> has key, store {
        id: UID,
        creator: address,
        creator_items_ids: vector<ID>,
        creator_coin_amount: u64,
        recipient: address,
        recipient_items_ids: vector<ID>,
        recipient_coin_amount: u64,
        expiration: u64,
    }

    public struct AdminCap has key, store {
        id: UID,
        owner: address,
    }

    public struct ESCROW has drop {}

    public struct EscrowCreated has copy, drop { id: ID }
    public struct EscrowCancelled has copy, drop { id: ID }
    public struct EscrowExchanged has copy, drop { id: ID }

    // ===== Init =====
    fun init(otw: ESCROW, ctx: &mut TxContext) {
        public_transfer(package::claim(otw, ctx), sender(ctx));
        public_transfer(AdminCap {
            id: object::new(ctx),
            owner: sender(ctx),
        }, sender(ctx));
    }

    // ===== Functions =====
    entry fun create<T: key, N: key + store>(
        creator_items: vector<N>,
        creator_coin: Coin<T>,
        recipient: address,
        recipient_items_ids: vector<ID>,
        recipient_coin_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(recipient != sender(ctx), ERR_WRONG_RECIPIENT);

        let has_creator_assets = vector::length(&creator_items) > 0 || coin::value(&creator_coin) > 0;
        assert!(has_creator_assets, ERR_ZERO_BALANCE);

        let has_recipient_assets = vector::length(&recipient_items_ids) > 0 || recipient_coin_amount > 0;
        assert!(has_recipient_assets, ERR_ZERO_BALANCE);

        let mut id = object::new(ctx);
        let creator_items_ids = add_items_to_dof(&mut id, creator_items);
        let creator_coin_amount = coin::value(&creator_coin);
        dof::add(&mut id, utf8(b"Creator Coin"), creator_coin);

        check_vector_for_duplicates(&recipient_items_ids);

        let expiration = timestamp_ms(clock) + SEVEN_DAYS_MS;

        let escrow = Escrow<T, N> {
            id,
            creator: sender(ctx),
            creator_items_ids,
            creator_coin_amount,
            recipient,
            recipient_items_ids,
            recipient_coin_amount,
            expiration,
        };

        emit(EscrowCreated { id: object::id(&escrow) });
        transfer::transfer(escrow, sender(ctx));
    }

    entry fun cancel<T: key, N: key + store>(
        escrow: Escrow<T, N>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        let id = object::id(&escrow);
        let Escrow {
            id: mut uid,
            creator,
            creator_items_ids,
            creator_coin_amount: _,
            recipient: _,
            recipient_items_ids: _,
            recipient_coin_amount: _,
            expiration,
        } = escrow;

        let current_time = timestamp_ms(clock);
        assert!(sender(ctx) == creator || current_time > expiration, ERR_WRONG_CREATOR);

        let creator_items = get_items_from_dof<N>(&mut uid, creator_items_ids);
        let creator_coin = get_coin_from_dof<T>(&mut uid);

        object::delete(uid);

        transfer_items(creator_items, sender(ctx));
        public_transfer(creator_coin, sender(ctx));

        emit(EscrowCancelled { id });
    }

    entry fun exchange<T: key, N: key + store>(
        fee_coin: Coin<T>,
        escrow: Escrow<T, N>,
        recipient_items: vector<N>,
        recipient_coin: Coin<T>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        let id = object::id(&escrow);
        let Escrow {
            id: mut uid,
            creator,
            creator_items_ids,
            creator_coin_amount,
            recipient,
            recipient_items_ids,
            recipient_coin_amount,
            expiration,
        } = escrow;

        let current_time = timestamp_ms(clock);
        assert!(current_time <= expiration, ERR_EXPIRED);
        assert!(sender(ctx) == recipient, ERR_WRONG_RECIPIENT);
        assert!(coin::value(&recipient_coin) == recipient_coin_amount, ERR_WRONG_COIN_AMOUNT);
        assert!(coin::value(&fee_coin) >= FEE, ERR_INSUFFICIENT_PAY);

        check_vector_for_duplicates(&recipient_items_ids);
        check_items_ids(&recipient_items, &recipient_items_ids);

        let creator_items = get_items_from_dof<N>(&mut uid, creator_items_ids);
        let creator_coin = get_coin_from_dof<T>(&mut uid);

        object::delete(uid);

        public_transfer(fee_coin, FEE_RECIPIENT);
        transfer_items(creator_items, sender(ctx));
        public_transfer(creator_coin, sender(ctx));

        transfer_items(recipient_items, creator);
        public_transfer(recipient_coin, creator);

        emit(EscrowExchanged { id });
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ESCROW {}, ctx)
    }
}