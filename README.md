# reNFT Smart Contracts

Generalised collateral-free and permissionless rentals built on top of Gnosis
Safe and Seaport.

## Testing

### Unit tests

Running all unit tests can be done with Foundry:

```
forge test -vvv
```

### Static Analysis

We use [slither](https://github.com/crytic/slither) to run static analysis. Make
sure it is installed via:

```
pip3 install slither-analyzer
```

To run the static analysis on the contracts:

```
slither .
```

## Deployment
Before deploying, first make sure that all relevant API keys are set in the `.env` file. 
You can reference the `.env.example` as a template for properly formatting the environment variables.

Supported chains for deployment include: 
- `mainnet`: ETH L1 mainnet
- `sepolia`: ETH L1 testnet
- `polygon`: Polygon mainnet
- `mumbai`: Polygon testnet

### Simulating a Deployment
You can simulate the deployment to get a sense of the gas cost and to double check the 
output to make sure the right deployer and server signer addresses are being used:

```shell
make simulate-deploy script=DeployProtocol chain=mainnet gas-price=40000000000
```

This command simulates a mainnet deploy with a max fee per gas of 40 gwei. 
You will get an output that looks something like this: 

```shell
Estimated gas price: 40 gwei

Estimated total gas used for script: 38516728

Estimated amount required: 1.54066912 ETH
```

### Executing the Deployment
If everything looks good and the deployer wallet has enough to cover the costs at estimated 
prices, then you can execute the actual deployment by swapping `simulate-deploy` with `deploy`:

```shell
make deploy script=DeployProtocol chain=mainnet gas-price=40000000000
```

It will take a bit of time to execute the deployment, and the scripts will automatically 
start verifying each contract. It is crucial that the block explorer API keys are set up 
properly. If the verification fails because of an invalid key, then it will have to be 
done manually which is a very tedious process.

## Invariants

- Recipient of ERC721 / ERC1155 tokens is always the reNFT smart contract renter
  wallet
- Recipient of ERC20 tokens is always the Payment Escrow Module
- Stored token balance of the `src/modules/PaymentEscrow.sol` contract should
  never be less than the true token balance of the contract
- Rental safes can never make a call to `setGuard()`
- Rental safes can never make a call to `enableModule()` or `disableModule`
  unless the target has been whitelisted by `src/policies/Admin.sol`
- Rental safes can never make a delegatecall unless the target has been
  whitelisted by `src/policies/Admin.sol`
- ERC721 / ERC1155 tokens cannot leave a rental wallet via `approve()`,
  `setApprovalForAll()`, `safeTransferFrom()`, `transferFrom()`, or
  `safeBatchTransferFrom()`
- Hooks can be specified for ERC721 and ERC1155 items
- Only one hook can act as middleware to a target contract at one time. But,
  there is no limit on the amount of hooks that can execute during rental start
  or stop.
- When control flow is passed to hook contracts, the rental concerning the hook
  will be active and a record of it will be stored in `src/modules/Storage.sol`

## Generalized Rental Guards

### Overview

When signing a rental order, the lender can decide to include an array of `Hook`
structs along with it. These are bespoke restrictions or added functionality
that can be applied to the rented token within the wallet. This protocol allows
for flexibility in how these hooks are implemented and what they restrict. A
common use-case for a hook is to prevent a call to a specific function selector
on a contract when renting a particular token ID from an ERC721/ERC1155
collection.

### Adding a Hook

Adding a hook contract to the protocol is an admin-permissioned action on the
`src/policies/Guard.sol` contract which is done via:

`updateHookStatus()` which enables a hook for use within the protocol.

`updateHookPath()` which specifies the contract which the rental wallet
interacts with that will activate the hook.

### Specifying hooks as a lender

When creating a rental, a `OrderMetadata` struct will be added to the order
which specifies extra parameters to pass along with the rentals:

```
struct OrderMetadata {
    // the type of order being created
    OrderType orderType;
    // the duration of the rental in seconds
    uint256 rentDuration;
    // the hooks that will act as middleware for the items in the order
    Hook[] hooks;
    // any extra data to be emitted upon order fulfillment
    bytes emittedExtraData;
}
```

Hooks can be added here to specify the unique functionality placed upon tokens
in the order. Only hooks which have been enabled by the admin will be valid when
passed to the `address target` field.

```
struct Hook {
    // the hook contract to target
    address target;
    // index of the item in the order to apply the hook to
    uint256 itemIndex;
    // any extra data that the hook will need. This will most likely
    // be some type of bitmap scheme
    bytes extraData;
}
```

### Routing a call to the proper hook

After a renter has successfully rented an ERC721/ERC1155, the
`src/policies/Guard.sol` contract will be invoked each time a transaction
originates from the wallet. The contract will check its mapping for any hooks in
the path of the interacting address.

If a hook exists, the control flow will be handed over to the hook contract for
further processing.

If no hook address was found, the rental guard contract contains basic
restrictions that prevents the usage of ERC721/ERC1155 state-changing functions.

### Implementing a hook

Example implementations of hooks can be found in the
`src/examples/restricted-selector/` folder.

Per each erc721 `GameToken` ID, this hook uses a bitmap which tracks any
function selectors that are restricted for that token ID only. Bitmaps allow
support for up to 256 function selectors on a single contract.

Using a `token ID -> bitmap` mapping allows the property that 2 or more tokens
from the same collection can be restricted in different ways based on how their
lenders defined the permissions.

### Extending a hook

Hooks are extendable. An allowlisted hook for a collection can be expanded even
further to allow for multiple child hooks that are routed to based on logic
defined in the parent hook. This pattern enables granular control flow of the
transaction execution for any requirements or restrictions that a rental may
have.

## Known Limitations

### Disabled Delegate call

Transactions that leverage delegate call on the safe contract are not allowed.
This invariant helps protect the safe from a few attack vectors. If delegate
call were allowed, a transaction could be crafted that would allow an
`approve()` call on a rented NFT even though the guard contract disables calls
to `approve()`. See `test/adversarial/DelegateCallApproveAttack` for more info
on this. Also, allowing delegate call would introduce another attack surface via
the re-initialization of the safe. Because the safe uses delegate call on
instantiation to enable the module and guard contract, the
`initializeRentalSafe()` function could be delegate called again after
instantiation and overwrite the active guard or enable a new module.

To mitigate this attack vector while still allowing delegate call, the contracts
use a whitelist to allow delegate call to specific addresses that are deemed
safe. For example, a contract dedicated to updating a gnosis safe module to a
newer version could be whitelisted by the protocol to allow a rental safe to
call it.

### Dishonest ERC721/ERC1155 Implementations

The `src/policies/Guard.sol` contract can only protect against the transfer of
tokens that faithfully implement the ERC721/ERC1155 spec. A dishonest
implementation that adds an additional function to transfer the token to another
wallet cannot be prevented by the protocol.

### Rebasing or Fee-On-Transfer ERC20 Implementations

The protocol contracts do not expect to be interacting with any ERC20 token
balances that can change during transfer due to a fee, or change balance while
owned by the `src/modules/PaymentEscrow.sol` contract.
