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

    struct UserInfo {
        // rewardPerTokenStored
        uint256 userRewardPerTokenPaid;
        // rewards to be claimed
        uint256 reward;
        // staked tokens
        EnumerableSetUpgradeable.UintSet tokens;
    }

    struct PoolInfo {
        // Duration of rewards to be paid out (in blocks)
        uint256 duration;
        // Block number of when the rewards finish
        uint256 finishBlock;
        // Minimum of last updated block and reward finish block
        uint256 lastUpdatedBlock;
        // Reward to be paid out per block
        uint256 rewardRate;
        // Sum of (reward rate * dt * 1e18 / total supply)
        uint256 rewardPerTokenStored;
        // Total staked amount
        uint256 totalSupply;
    }

    // Using tokens contract
    IERC20Upgradeable public rewardsToken;
    IERC721Upgradeable public stakingToken;

    // User address => staked amount
    mapping(address => UserInfo) private _userInfo;
    PoolInfo public poolInfo;

    event Staking(address indexed account, uint256 amount);
    event Unstaking(address indexed account, uint256 amount);
    event Claim(address indexed acouunt, uint256 amount);

    modifier updateReward(address account) {
        poolInfo.rewardPerTokenStored = rewardPerToken();
        poolInfo.lastUpdatedBlock = lastBlockRewardApplicable();

        if(account != address(0)) {
            _userInfo[account].reward = earned(account);
            _userInfo[account].userRewardPerTokenPaid = poolInfo.rewardPerTokenStored;
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
        require(isOnStaking(), "Staking: pool is not opened");

        address account = _msgSender();
        uint256 amount = tokenIds.length;
        require(amount > 0, "Staking: amount must be greater than zero");

        for (uint256 i = 0; i < amount; i++) {
            stakingToken.safeTransferFrom(account, address(this), tokenIds[i]);
            _userInfo[account].tokens.add(tokenIds[i]);
        }

        poolInfo.totalSupply = poolInfo.totalSupply.add(amount);
        emit Staking(account, amount);
    }

    function withdraw(uint256[] calldata tokenIds) external nonReentrant updateReward(_msgSender()) {
        uint256 amount = tokenIds.length;
        require(amount > 0, "Staking: amount must be greater than zero");

        address account = _msgSender();
        for (uint256 i = 0; i < amount; i++) {
            require(_userInfo[_msgSender()].tokens.contains(tokenIds[i]), "Staking: sender is not a token owner");
            stakingToken.transferFrom(address(this), account, tokenIds[i]);
            _userInfo[account].tokens.remove(tokenIds[i]);
        }

        poolInfo.totalSupply = poolInfo.totalSupply.sub(amount);
        emit Unstaking(account, amount);
    }

    function claim() external nonReentrant updateReward(_msgSender()) {
        address account = _msgSender();
        uint256 reward = _userInfo[account].reward;
        require(reward > 0, "Staking: reward is zero");

        _userInfo[account].reward = 0;
        rewardsToken.safeTransfer(account, reward);        

        emit Claim(account, reward);
    }

    function setStakingPool(uint256 duration_, uint256 amount) external onlyOwner updateReward(address(0)) {
        _setRewardsDuration(duration_);
        _setRewardRate(amount);

        require(poolInfo.rewardRate > 0, "reward rate must be greater than zero");
        require(poolInfo.rewardRate.mul(poolInfo.duration) <= rewardsToken.balanceOf(address(this)), "Provided reward too high");

        poolInfo.finishBlock = poolInfo.duration.add(block.number);
        poolInfo.lastUpdatedBlock = block.number;
    }

    function lastBlockRewardApplicable() public view returns (uint256) {
        return poolInfo.finishBlock <= block.number ? poolInfo.finishBlock : block.number;
    }

    function rewardPerToken() public view returns (uint256) {
        if (poolInfo.totalSupply > 0) {
            return poolInfo.rewardPerTokenStored.add(
                    poolInfo.rewardRate.mul(lastBlockRewardApplicable().sub(poolInfo.lastUpdatedBlock)).mul(1e18).div(poolInfo.totalSupply)
                );
        }
        return poolInfo.rewardPerTokenStored;
    }

    function earned(address account) public view returns (uint256) {
        return _userInfo[account].tokens.length().mul(
            rewardPerToken().sub(_userInfo[account].userRewardPerTokenPaid)
        )
        .div(1e18)
        .add(_userInfo[account].reward);
    }

    function isOnStaking() public view returns (bool) {
        return block.number < poolInfo.finishBlock;
    }

    function _setRewardRate(uint256 amount) internal {
        require(amount > 0, "Staking: amount must be greater than zero");

        if (!isOnStaking()) {
            poolInfo.rewardRate = amount.div(poolInfo.duration);
        } else {
            uint256 remainingRewards = poolInfo.finishBlock.sub(block.number).mul(poolInfo.rewardRate);
            poolInfo.rewardRate = amount.add(remainingRewards).div(poolInfo.duration);
        }
    }

    function _setRewardsDuration(uint256 duration_) internal {
        require(!isOnStaking(), "Staking: reward duration not finished");
        require(duration_ > 0, "Staking: duration must be greater than zero");

        poolInfo.duration = duration_;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}