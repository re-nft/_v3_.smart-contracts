# Test Fixtures

The test fixtures are a series of layered contracts to build up the state needed to perform tests. These fixtures can be found in `test/fixtures/`. When creating tests that use the fixtures, it is as simple as importing `test/BaseTest.sol` into the test file and inheriting it. 

The fixtures are broken up into three parts: External, Protocol, and Engine.

### External

These fixtures are all related to non-protocol contracts. To facilitate replicable tests, protocol contracts such as Seaport and Gnosis Safe are deployed from scratch as part of the test setup.

The external fixtures are comprised of: 
- `Create2Deployer.sol`: Setup of the Create2Deployer contract
- `Seaport.sol`: Setup of all Seaport protocol contracts (Seaport.sol, ConduitController.sol, Conduit.sol)
- `Safe.sol`: Setup of all Gnosis Safe protocol contracts (SafeProxyFactory.sol, SafeL2.sol, TokenCallbackHandler.sol)

The inheritance chain for these fixtures is as follows:
```
Create2Deployer.sol        Seaport.sol                Safe.sol
        |                       |                        |
        |                       |                        |
        --------------------------------------------------
                                |
                                v
                          BaseExternal.sol        

```

### Protocol

These fixtures are related to the composition of the V3 protocol. Here, the V3 protocol contracts are deployed as well as the setup needed to create test accounts which interact with the protocol. 

The protocol fixtures are comprised of: 
- `Protocol.sol`: Setup of the V3 protocol contracts
- `AccountCreator.sol`: Setup of test accounts and associated rental safes, deploys mock tokens, and distributes funds

The inheritance chain for these fixtures is as follows:
```
BaseExternal.sol
      |
      |
      v
 Protocol.sol
      |
      |
      v
AccountCreator.sol
      |
      |
      v
BaseProtocol.sol

```

### Engine

These fixtures are related to the test engine. The order creation and order fulfillment components of the test engine are split up into their own fixtures for use during integration tests. For any tests that do not need the test engine, there exists an alternate fixture called `BaseTestWithoutEngine` that omits the test engine fixtures. 

The engine fixtures are comprised of: 
- `OrderCreator.sol`: Setup of the order creator portion of the test engine
- `OrderFulfiller.sol`: Ssetup of the order fulfiller portion of the test engine

The inheritance chain for these fixtures is as follows:
```
BaseProtocol.sol
      |
      |
      v
OrderCreator.sol
      |
      |
      v
OrderFulfiller.sol
      |
      |
      v
  BaseTest.sol

```


# Test Engine

The testing engine is responsible for both orchestrating the initial state of the testing environment and for carrying out modifications to that state throughout the lifetime of the test to ensure composability and modularity. Because testing the protocol is tightly coupled with Seaport, most tests will operate in 2 distinct phases: order creation and order fulfillment. 

Within each of those phases, the test engine operates in a series of stages: Generation, Amendment, and Finalization.

 
## Order Creation

During the order creation phase, a Seaport order struct is built up using mock ERC20 tokens and mock ERC721 tokens. By the end of this phase, the result is a signed and ready to be fulfilled Seaport order which contains all the necessary metadata with it to be fulfilled by the rental protocol. The code for order creation can be found in `test/utils/OrderCreator.sol`.

### Generation

Orders are generated with a call to `createOrder` which will add generic offer items, generic consideration items, a standard `OrderMetadata` struct, and a offerer account to storage. All these items are automatically generated and approved by the testing suite. Once these items are created, they are stored in a `OrderToCreate` struct. This struct will remain in storage until the finalization stage, where it will be cleared. 

`createOrder` has the flexibility to allow for the creation of any of the protocol's standard order types: BASE, PAY, and PAYEE. It also allows for the configuration of any combination of offer and consideration items, and whether those are ERC20 or ERC721. For example, to create a base order with alice as an offerer where 2 NFTs are lent out in exchange for 2 different ERC20 tokens can be done via: 

```
createOrder({
    offerer: alice,
    orderType: OrderType.BASE,
    erc721Offers: 2,
    erc20Offers: 0,
    erc721Considerations: 0,
    erc20Considerations: 2
});
```

### Amendment

Orders can be amended throught a series of helper functions which operate on the `OrderToCreate` struct that was generated in the previous stage. Amendment functions can change the offerer, add new offer items, delete old consideration items, etc. Amendments are useful because they allow for the testing of potentially invalid or adversarial data packages. 

Some example amendments include: 

- `withOfferer`: changes the offerer that was originally set on the order
- `withReplacedOfferItems`: clears all the generated offer items and replaces it with custom offer items
- `withOfferItem`: appends a new offer item to the order
- `popOfferItem`: pops the last offer item off the order

### Finalization

Finalization takes place after all amendments have been made. In the case of order creation, the finalization step represents the act of the offerer signing a Seaport order. Once the order is signed, it is returned to the testing environment and is cleared from storage. From there, other orders can be created in the same manner or the test can move on to the order fulfillment stage. 

To finalize an `orderToCreate` struct, a call to `finalizeOrder` can be made. The `OrderToCreate` struct  that is actively in storage when the finalization call is made will be signed by the offerer, converted to order parameters, and packaged into a seaport `Order` struct. It is then returned so that it can be handled during order fulfillment. 

## Order Fulfillment

During the order fulfillment stage, a signed order is used to interact with seaport to initiate a rental. By the end of this phase, the result is an active rental which was processed by the v3 protocol. The code for order fulfillment can be found in `test/utils/OrderFulfiller.sol`.

### Generation

Fulfillments are generated with a call to `createOrderFulfillment` which will add an `OrderFulfillment` struct, a payload which is signed by the backend protocol signer key, a converted advanced order, and a fulfiller account into contract test storage. Unlike order creation, multiple fulfillments can be created before needing to finalize. These order fulfillments are all stored in a `OrderToFulfill[]` array, and will be cleared once finalization occurs.

### Amendment

Depending on the type of fulfillment, extra data may be needed by seaport to complete the fulfillment. For example, using `FulfillAvailableAdvancedOrders` to fulfill multiple orders at once requires two arrays of `FulfillmentComponent[]`. The `withBaseOrderFulfillmentComponents` amendment can automatically process the offer and consideration items in each order, and add a new fulfillment to it for execution. This same process is needed when using `MatchAdvancedOrders` for PAY and PAYEE orders. The `withLinkedPayAndPayeeOrders` amendment can be used to generate an array of seaport `Fulfillment` structs to be passed along with the order. 

Some fulfillment amendments include: 

- `withBaseOrderFulfillmentComponents`: generates an array of `FulfillmentComponent` which is used to link up all the base orders into one rental.
- `withAdvancedOrder`: replaces a particular index in the `OrderToFulfill[]` array with a new advanced order. 
- `withLinkedPayAndPayeeOrders`: links a PAY order and a PAYEE order together to be used in `matchAdvancedOrders`.

### Finalization

After all amendments have been made, the prepared orders can finally be fulfilled using one of Seaport's fulfillment functions: `fulfillAdvancedOrders`, `fulfillAvailableAdvancedOrders`, or `MatchAdvancedOrders`. Depending on the types of orders created, different fulfillment functions can be used during finalization. For single orders, there are the `finalizeBaseOrderFulfillment` and `finalizePayOrderFulfillment` finalization functions. For multiple orders for a batch fulfillment, there are the `finalizeBaseOrdersFulfillment` and `finalizePayOrdersFulfillment` functions. 