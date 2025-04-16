# 🔐 Sui Escrow Contract

This Move module implements a simple **escrow system** on the Sui blockchain.

It allows two parties (creator and recipient) to safely exchange assets (coins and items) with fee payment and expiration logic. The assets are held in escrow until both sides fulfill their requirements, or the escrow is canceled after timeout.

---

## 🧠 How It Works

- The **creator** deposits:
  - A list of assets (NFTs or fungible tokens)
  - A coin of type `T` (e.g. USDC, SUI)
  - An expectation of what the **recipient** will provide
- The **recipient** can fulfill the escrow by:
  - Providing matching items and coins
  - Paying a protocol fee (fixed `FEE` amount)
- On fulfillment, both parties receive their respective assets.
- If the escrow is not fulfilled in 7 days, the creator can cancel and reclaim assets.

---

## 📐 Architecture Diagram

```text
+----------------+                +------------------+
|    Creator     |                |    Recipient     |
+----------------+                +------------------+
        |                               |
        |  1. create()                  |
        |------------------------------>|
        |  locks assets into Escrow     |
        |                               |
        |                               |
        |                               |
        |                2. exchange()  |
        |<------------------------------|
        |     provides expected assets  |
        |     + fee                     |
        |                               |
        |                               |
        |        Assets routed:         |
        |  - Creator gets recipient's   |
        |    items & coin               |
        |  - Recipient gets creator's   |
        |    items & coin               |
        |  - Protocol gets fee          |
        |<------------------------------|
```

## 🔁 Flow Overview

### Creator calls `create()`:
- Supplies assets and coin
- Specifies recipient and expected assets
- Escrow object is created and transferred to creator's address (they hold it)

### Recipient calls `exchange()`:
- Must provide exact items (by ID) and coin amount
- Must pay a fixed fee (`FEE`) in a specific token (e.g. USDC)
- If successful, assets are exchanged and escrow is deleted

### Optional Cancel:
- If recipient doesn't fulfill the escrow within 7 days, the creator can call `cancel()`
- Creator gets all their assets back

---

## 🧑‍🎤 User Story (Frontend)

**Jill is selling a rare NFT for 10 USDC using escrow. Jack is the buyer.**

### Step-by-step:

1. Jill signs in with her Sui wallet on the frontend  
2. She selects the NFT to trade and enters Jack’s wallet address and desired price  
3. Frontend sends:
   ```ts
   POST /create-escrow
   ```
Backend returns a **serialized unsigned transaction**, Jill signs with her wallet  
4. Transaction is sent → **Escrow is created on-chain**

---

5. Jack logs in and sees a **pending escrow offer**  
6. He confirms he owns the required USDC and NFT(s), and clicks **"Accept"**

7. Frontend sends:
```ts
POST /exchange  
```
-> Jack signs and submits -> Escrow is fulfilled, assets are exchanged

---
8. If Jack doesn't respond within 7 days, Jill clicks **"Cancel"**, triggering: 
```ts
POST /cancel
```
-> Her assets are returned, escrow is deleted
---

## 🛡️ Security Notes

- ✅ **Exact match required**: Item IDs and coin values must match what's declared
- ✅ **Expiration logic**: Escrow can only be canceled after 7 days (uses `Clock::now_ms`)
- ✅ **Fee enforcement**: Fee must be paid in a fixed token (e.g. USDC), routed to `FEE_RECIPIENT`
- ⚠️ **Escrow object must be held by the creator** — this is enforced through frontend/backend logic

---

## 🧱 Built With

- Move Language
- Sui Blockchain
- Sui Primitives:
  - `UID`
  - `Coin<T>`
  - `dynamic_object_field`
  - `Clock`

---

## 📂 Modules

| Module             | Purpose                                       |
|--------------------|-----------------------------------------------|
| `escrow.move`      | Core logic for `create`, `cancel`, `exchange`|
| `escrow_utils.move`| Helper functions for coin/item handling       |

---

## 📜 License

Apache 2.0
