// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PropertyRentToken
 * @notice ERC-20 token representing fractional ownership of a real estate
 * asset, with proportional rent distribution to holders in USDC.
 * @dev Uses the reward-per-token accumulator pattern (pull over push) to
 * avoid unbounded loops over holders when distributing rent income.
 */
contract PropertyRentToken is ERC20, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    //@roles
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    //@constants
    uint256 public constant MAX_PRICE_PERCENT = 10; // 10%
    uint256 public constant NUM_TOKENS = 50_000;
    uint256 public constant FEE_PERCENT = 2; // 2% management fee

    //@addresses and external integrations
    IERC20 public immutable usdc;
    address public immutable feeCollector;

    //@Mutable state variables
    uint256 public PROPERTY_VALUATION_EUR = 5_000_000;
    uint256 public PRICE_TOKEN = 100;
    uint256 public rewardPerTokenStored;

    //@mappings
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(uint256 => bool) public checkPeriod;

    //@events
    event PriceUpdate(uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event RentIncomeReported(uint256 amount);
    event RentDeposited(uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        address admin_,
        address usdcAddress_
    ) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ORACLE_ROLE, admin_);

        _mint(admin_, NUM_TOKENS * 10 ** decimals());

        usdc = IERC20(usdcAddress_);
        feeCollector = admin_;
    }

   /**
     * @dev Updates the token's market price, limited by a circuit
     * breaker of maximum MAX_PRICE_PERCENT variation relative to the current price.
     * @param newPrice New price per token, in euros (unscaled to 18 decimals).
     */
    function updatePrice(uint256 newPrice_) external onlyRole(ORACLE_ROLE) {
        uint256 maxDelta_ = (PRICE_TOKEN * MAX_PRICE_PERCENT) / 100;
        uint256 oldPrice_ = PRICE_TOKEN;

        require(newPrice_ > 0, "invalid price");
        require(newPrice_ <= PRICE_TOKEN + maxDelta_, "price increase exceeds max delta");
        require(newPrice_ >= PRICE_TOKEN - maxDelta_, "price decrease exceeds max delta");

        PRICE_TOKEN = newPrice_;

        emit PriceUpdate(oldPrice_, newPrice_, block.timestamp);
    }

    /**
     * @dev Registers the rental income for a period and updates the global
     * reward accumulator. Protected against duplicate reports for the same period.
     * @param amount Rental amount to be distributed, already scaled to 18 decimals.
     * @param periodId Unique identifier of the reported period (e.g., month/year).
     */
    function reportRentIncome(uint256 amount_, uint256 periodId_) external onlyRole(ORACLE_ROLE) {
        require(totalSupply() > 0, "no holders");
        require(!checkPeriod[periodId_], "period already reported");

        checkPeriod[periodId_] = true;
        rewardPerTokenStored += (amount_ * 1e18) / totalSupply();

        emit RentIncomeReported(amount_);
    }

    /**
     * @dev Allows a holder to claim all of their accrued pending rent in USDC.
     * Follows the Checks-Effects-Interactions pattern to prevent
     * reentrancy attacks.
     */
    function claimRent() external {
        _updateReward(msg.sender);

        uint256 amount_ = rewards[msg.sender];
        require(amount_ > 0, "nothing to claim");

        rewards[msg.sender] = 0;

        usdc.safeTransfer(msg.sender, amount_);
    }

   /**
     * @dev Deposits USDC into the contract to fund the rent distribution,
     * automatically deducting the management fee (FEE_PERCENT) towards
     * feeCollector. Requires prior approval (usdc.approve) from the caller.
     * @param amount Total amount in USDC to deposit, including the fee.
     */
    function depositRent(uint256 amount_) external onlyRole(ORACLE_ROLE) {
        require(amount_ > 0, "invalid amount");

        uint256 fee_ = (amount_ * FEE_PERCENT) / 100;
        uint256 netAmount_ = amount_ - fee_;

        usdc.transferFrom(msg.sender, address(this), amount_);
        usdc.safeTransfer(feeCollector, fee_);

        emit RentDeposited(netAmount_);
    }

    /**
     * @dev Calculates the pending reward of 'account' since its last
     * claim and updates its reference marker.
     * @param account Address of the holder whose reward is being recalculated.
     */
    function _updateReward(address account_) internal {
        uint256 diff_ = rewardPerTokenStored - userRewardPerTokenPaid[account_];
        rewards[account_] += (balanceOf(account_) * diff_) / 1e18;
        userRewardPerTokenPaid[account_] = rewardPerTokenStored;
    }
}
