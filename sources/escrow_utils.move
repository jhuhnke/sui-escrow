module escrow::escrow_utils {
    // ===== Imports =====
    use std::string::{utf8, String};
    use sui::coin::Coin;
    use sui::dynamic_object_field as dof;
    use sui::transfer::public_transfer;
    use sui::vec_set;

    // ===== Constants =====
    const ERR_WRONG_ITEM: u64 = 6;

    // ===== Helper Functions =====
    public fun get_coin_from_dof<T: key>(uid: &mut UID): Coin<T> {
        dof::remove<String, Coin<T>>(uid, utf8(b"Creator Coin"))
    }

    public fun add_items_to_dof<N: key + store>(uid: &mut UID, mut items: vector<N>): vector<ID> {
        let mut items_ids = vector::empty<ID>();
        while (!vector::is_empty(&items)) {
            let item = vector::pop_back(&mut items);
            let item_id = object::id(&item);
            dof::add(uid, item_id, item);
            vector::push_back(&mut items_ids, item_id);
        };
        vector::destroy_empty(items);
        items_ids
    }

    public fun get_items_from_dof<N: key + store>(uid: &mut UID, mut items_ids: vector<ID>): vector<N> {
        let mut items = vector::empty<N>();
        while (!vector::is_empty(&items_ids)) {
            let item_id = vector::pop_back(&mut items_ids);
            let item = dof::remove<ID, N>(uid, item_id);
            vector::push_back(&mut items, item);
        };
        vector::destroy_empty(items_ids);
        items
    }

    public fun transfer_items<N: key + store>(mut items: vector<N>, to: address) {
        while (!vector::is_empty(&items)) {
            public_transfer(vector::pop_back(&mut items), to);
        };
        vector::destroy_empty(items);
    }

    public fun check_items_ids<N: key + store>(items: &vector<N>, ids: &vector<ID>) {
        assert!(vector::length(items) == vector::length(ids), ERR_WRONG_ITEM);
        let mut i = 0;
        while (i < vector::length(items)) {
            assert!(vector::contains(ids, &object::id(vector::borrow(items, i))), ERR_WRONG_ITEM);
            i = i + 1;
        };
    }

    public fun check_vector_for_duplicates<N: copy + drop>(items: &vector<N>) {
        let mut set = vec_set::empty<N>();
        let mut i = 0;
        while (i < vector::length(items)) {
            vec_set::insert(&mut set, *vector::borrow(items, i));
            i = i + 1;
        };
    }
}