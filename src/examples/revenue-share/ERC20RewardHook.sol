// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IHook} from "@src/interfaces/IHook.sol";
import {ISafe} from "@src/interfaces/ISafe.sol";

// Info stored about each rental
struct RentInfo {
    uint256 amount;
    uint256 lastRewardBlock;
}

// Info about the revenue share
struct RevenueShare {
    address lender;
    uint256 lenderShare;
}

contract ERC20RewardHook is IHook {
    // privileged policy contracts
    address public createPolicy;
    address public stopPolicy;

    // ERC20 tokens
    address public gameToken;
    IERC20 public rewardToken;

    // award 1 gwei of reward token per block
    uint256 public immutable rewardPerBlock = 1e9;

    // hold info about an asset
    mapping(bytes32 assetHash => RentInfo rentInfo) public rentInfo;

    // hold info about accrued rewards
    mapping(address rewardedAddress => uint256 rewards) public accruedRewards;

    constructor(
        address _createPolicy,
        address _stopPolicy,
        address _gameToken,
        address _rewardToken
    ) {
        createPolicy = _createPolicy;
        stopPolicy = _stopPolicy;
        gameToken = _gameToken;
        rewardToken = IERC20(_rewardToken);
    }

    modifier onlyCreatePolicy() {
        require(msg.sender == createPolicy, "not callable unless create policy");
        _;
    }

    modifier onlyStopPolicy() {
        require(msg.sender == stopPolicy, "not callable unless stop policy");
        _;
    }

    modifier onlySupportedTokens(address token) {
        require(token == gameToken, "token is not supported");
        _;
    }

    // This function will not be used in this hook, so it is unimplemented
    function onTransaction(
        address safe,
        address to,
        uint256 value,
        bytes memory data
    ) external view {}

    // hook handler for when a rental has started
    function onStart(
        address safe,
        address token,
        uint256 identifier,
        uint256 amount,
        bytes memory data
    ) external onlyCreatePolicy onlySupportedTokens(token) {
        // Decode the revenue split data
        RevenueShare memory revenueShare = abi.decode(data, (RevenueShare));

        // require that the split adds to 100
        require(
            revenueShare.lenderShare <= 100,
            "split value must be less than or equal to 100"
        );

        // calculate the hash for this asset
        bytes32 assetHash = keccak256(abi.encode(safe, token, identifier));

        // get the last block that the rewards were accrued
        uint256 lastBlock = rentInfo[assetHash].lastRewardBlock;

        // get the amount currently stored
        uint256 currentAmount = rentInfo[assetHash].amount;

        // if the last block that a reward was accrued exists and the amount is nonzero,
        // calculate the latest reward. Otherwise, this is a first-time deposit so
        // there are no rewards earned.
        if (lastBlock > 0 && currentAmount > 0) {
            // place safe on stack to avoid stack too deep
            address _safe = safe;

            // The amount of blocks to reward
            uint256 blocksToReward = block.number - lastBlock;

            // since the last time reward were accrued, the reward is distributed per block per token stored.
            // Divide by 1e18 to account for token decimals
            uint256 latestAccruedRewards = (blocksToReward *
                rewardPerBlock *
                currentAmount) / 1e18;

            // determine the split of the rewards for the lender
            uint256 lenderAccruedRewards = (latestAccruedRewards *
                revenueShare.lenderShare) / 100;

            // determine the split of the rewards for the renter
            uint256 renterAccruedRewards = latestAccruedRewards - lenderAccruedRewards;

            // Effect: accrue rewards to the lender
            accruedRewards[revenueShare.lender] += lenderAccruedRewards;

            // Effect: accrue rewards to the safe/renter
            accruedRewards[_safe] += renterAccruedRewards;
        }

        // Effect: update the amount of tokens currently rented
        rentInfo[assetHash].amount += amount;

        // Effect: update the latest block that rewards were accrued
        rentInfo[assetHash].lastRewardBlock = block.number;
    }

    // handler for when a rental has stopped
    function onStop(
        address safe,
        address token,
        uint256 identifier,
        uint256 amount,
        bytes memory data
    ) external onlyStopPolicy onlySupportedTokens(token) {
        // Decode the revenue split data
        RevenueShare memory revenueShare = abi.decode(data, (RevenueShare));

        // require that the split adds to 100
        require(
            revenueShare.lenderShare <= 100,
            "split value must be less than or equal to 100"
        );

        // calculate the hash for this asset
        bytes32 assetHash = keccak256(abi.encode(safe, token, identifier));

        // get the last block that the rewards were accrued
        uint256 lastBlock = rentInfo[assetHash].lastRewardBlock;

        // get the amount currently stored
        uint256 currentAmount = rentInfo[assetHash].amount;

        // on a stop, the last block since rewards were accrued and the amount should both be nonzero
        require(lastBlock > 0 && currentAmount > 0, "values should be nonzero");

        // place safe on stack to avoid stack too deep
        address _safe = safe;

        // The amount of blocks to reward
        uint256 blocksToReward = block.number - lastBlock;

        // since the last time reward were accrued, the reward is distributed per block per token stored.
        // Divide by 1e18 to account for token decimals
        uint256 latestAccruedRewards = (blocksToReward * rewardPerBlock * currentAmount) /
            1e18;

        // determine the split of the rewards for the lender
        uint256 lenderAccruedRewards = (latestAccruedRewards * revenueShare.lenderShare) /
            100;

        // determine the split of the rewards for the renter
        uint256 renterAccruedRewards = latestAccruedRewards - lenderAccruedRewards;

        // Effect: accrue rewards to the lender
        accruedRewards[revenueShare.lender] += lenderAccruedRewards;

        // Effect: accrue rewards to the safe/renter
        accruedRewards[_safe] += renterAccruedRewards;

        // Effect: update the amount of tokens currently rented
        rentInfo[assetHash].amount -= amount;

        // Effect: update the latest block that rewards were accrued
        rentInfo[assetHash].lastRewardBlock = block.number;
    }

    function claimRewards(address rewardedAddress) external {
        // check if the caller is the lender or is a rental safe
        bool isClaimer = msg.sender == rewardedAddress;

        // make sure the caller is the claimer, or they are the owner
        // of the safe
        require(
            isClaimer || ISafe(rewardedAddress).isOwner(msg.sender),
            "not allowed to access rewards for this safe"
        );

        // store the amount to withdraw
        uint256 withdrawAmount = accruedRewards[rewardedAddress];

        // Effect: update the accrued rewards
        accruedRewards[rewardedAddress] = 0;

        // Interaction: Transfer the accrued rewards
        rewardToken.transfer(msg.sender, withdrawAmount);
    }
}
