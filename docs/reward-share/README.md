# Reward Share

Reward share generally implies that players of a web3 game receive tokens or
other rewards for playing the game. For example, SLP token for playing Axie
Infinity.

Solution to this problem, however, must generalise beyond on-chain rewards. In
general, any on-chain or off-chain rewarding mechanism must be supported. This
can only be achieved with a flexible architecture.

A problem of reward share is similar in nature to that of airdrops. How do we
know if a particular transfer into the wallet is a reward for playing the game /
using the NFT? There is no way to answer this question with 100% certainty. Even
if we knew the answer to that question, imagine renter wallet is rewarded with
ERC20 tokens (which are sent directly into renter's wallet). Who is now
responsible for transferring portion of these to renter and any other parties?
How do we match this reward to potentailly multiple NFTs that the player might
be playing with; which all come from different listings and might contribute to
the reward in different proportions? Therefore, the only appropriate approach is
to allow the project / game design their own reward share mechanisms.

## On-chain rewards

Let's define specifically a few cases of on-chain rewards:

- erc20 tokens received into renter wallet

- erc721 tokens received into renter

- erc1155 tokens received into renter wallet

## Off-chain rewards

- some in-game points accumulation system that is tied to a user's wallet
  address

We facilitate off-chain rentals by allowing arbitrary length bytes in listing
data. This data can then be used by the game to store any information it wants
to help it determine how to handle the rewards.

## Limitations

- non fungible tokens like erc721 cannot be split

- requires game to implement reward share mechanism

## Implementation Details

If we take up a module design similar to Gnosis Safe, we would need users
enabling modules for every reward share component they wish to interact with.
This is less than optimal from the UX standpoint. Alternative is to have a proxy
design, where renft simply changes which contract the calls are proxied into,
allowing seamless UX. Problem with the latter approach is inferior security. If
a bug is found in the latter, it will affect all the wallets. Whilst, if you go
with the former approach, the bug will only affect wallets that have enabled
that reward share component module. In fact, there is a multi send contract on
Gnosis that allows the caller to batch a number of transactions into one. As
such, we can batch the transaction to register a new reward share module along
with the transaction to rent. Therefore, module manager approach to reward share
will be taken.

Since rental guards is to be written by projects themselves too, in conjunction
with reward share modules projects are given a lot of flexibility. For example,
they can invoke reward share module's code on check transaction or after
transaction execution. Also, reward share module can be used as a standalone
solution. For example, a project might reward the players on their own criteria
at a time of their choosing by invoking reward or similar on their reward share
module.

How would reward share module development look like from renft standpoint?
Interested projects develop their modules, they can PR into our repo and we can
then mark these as official modules. Then, on the FE for given collections we
would be able to construct a transaction for users to enable these official
modules and nothing else.

Rental Manager is a standalone contract, it's not a safe, it's a module in
itself. Having it inherit from ModuleManager would cause a plethora of issues.
For example, it would not be possible to upgrade to a new rental manager module
without losing the state of the previous version (by state, I mean what reward
share components were registered for a particular wallet). As such, the best
course of action is to have reward share components modules in themselves that
interact with Rental Manager module (if we need them to).

TODO: enable projects to write guards after transaction execution, not just
before
