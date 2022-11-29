//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract ERC721Staking is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct Staker {
        // rewardPerTokenStored
        uint256 userRewardPerTokenPaid;
        // rewards to be claimed
        uint256 reward;
        // staked tokens
        EnumerableSetUpgradeable.UintSet tokens;
    }

    // Using tokens contract
    IERC20Upgradeable public rewardsToken;
    IERC721Upgradeable public stakingToken;

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration;
    // Block number of when the rewards finish
    uint256 public finishBlock;
    // Minimum of last updated block and reward finish block
    uint256 public lastUpdatedBlock;
    // Reward to be paid out per block
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // Total staked amount
    uint256 public totalSupply;
    // User address => staked amount
    mapping(address => Staker) private _stakerInfo;

    event Staking(address indexed account, uint256 amount);
    event Unstaking(address indexed account, uint256 amount);
    event Claim(address indexed acouunt, uint256 amount);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdatedBlock = lastBlockRewardApplicable();

        if(account != address(0)) {
            _stakerInfo[account].reward = earned(account);
            _stakerInfo[account].userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;   
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address rewardsToken_, address stakingToken_) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        rewardsToken = IERC20Upgradeable(rewardsToken_); 
        stakingToken = IERC721Upgradeable(stakingToken_);
    }

    function stake(uint256[] calldata tokenIds) external nonReentrant updateReward(_msgSender()) {
        address account = _msgSender();
        uint256 amount = tokenIds.length;
        require(amount > 0, "Staking: amount must be greater than zero");

        for (uint256 i = 0; i < amount; i++) {
            stakingToken.safeTransferFrom(account, address(this), tokenIds[i]);
            _stakerInfo[account].tokens.add(tokenIds[i]);
        }

        totalSupply = totalSupply.add(amount);
        emit Staking(account, amount);
    }

    function withdraw(uint256[] calldata tokenIds) external nonReentrant updateReward(_msgSender()) {
        uint256 amount = tokenIds.length;
        require(amount > 0, "Staking: amount must be greater than zero");

        address account = _msgSender();
        for (uint256 i = 0; i < amount; i++) {
            require(_stakerInfo[_msgSender()].tokens.contains(tokenIds[i]), "Staking: sender is not a token owner");
            stakingToken.transferFrom(address(this), account, tokenIds[i]);
            _stakerInfo[account].tokens.remove(tokenIds[i]);
        }

        totalSupply = totalSupply.sub(amount);
        emit Unstaking(account, amount);
    }

    function claim() external nonReentrant updateReward(_msgSender()) {
        address account = _msgSender();
        uint256 reward = _stakerInfo[account].reward;
        require(reward > 0, "Staking: reward is zero");

        _stakerInfo[account].reward = 0;
        rewardsToken.safeTransfer(account, reward);        

        emit Claim(account, reward);
    }

    function setStakingPool(uint256 duration_, uint256 amount) external onlyOwner updateReward(address(0)) {
        _setRewardsDuration(duration_);
        _setRewardRate(amount);

        require(rewardRate > 0, "reward rate must be greater than zero");
        require(rewardRate.mul(duration) <= rewardsToken.balanceOf(address(this)), "Provided reward too high");

        finishBlock = duration.add(block.number);
        lastUpdatedBlock = block.number;
    }

    function lastBlockRewardApplicable() public view returns (uint256) {
        return finishBlock <= block.number ? finishBlock : block.number;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply > 0) {
            return rewardPerTokenStored.add(
                    rewardRate.mul(lastBlockRewardApplicable().sub(lastUpdatedBlock)).mul(1e18).div(totalSupply)
                );
        }
        return rewardPerTokenStored;
    }

    function earned(address account) public view returns (uint256) {
        return _stakerInfo[account].tokens.length().mul(
            rewardPerToken().sub(_stakerInfo[account].userRewardPerTokenPaid)
        )
        .div(1e18)
        .add(_stakerInfo[account].reward);
    }

    function _setRewardRate(uint256 amount) internal {
        require(amount > 0, "Staking: amount must be greater than zero");

        if (block.number >= finishBlock) {
            rewardRate = amount.div(duration);
        } else {
            uint256 remainingRewards = finishBlock.sub(block.number).mul(rewardRate);
            rewardRate = amount.add(remainingRewards).div(duration);
        }
    }

    function _setRewardsDuration(uint256 duration_) internal {
        require(block.number > finishBlock, "Staking: reward duration not finished");
        require(duration_ > 0, "Staking: duration must be greater than zero");

        duration = duration_;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}