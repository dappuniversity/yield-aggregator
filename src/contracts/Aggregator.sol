pragma solidity ^0.5.16;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

// Interface for ERC20 DAI contract
interface DAI {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

// Interface for Compound's cDAI contract
interface cDAI {
    function mint(uint256) external returns (uint256);

    function redeemUnderlying(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);
}

// Interface for Aave's lending pool contract
interface AaveLendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function safeDeposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function getReserveData(address asset)
        external
        returns (
            uint256 configuration,
            uint128 liquidityIndex,
            uint128 variableBorrowIndex,
            uint128 currentLiquidityRate,
            uint128 currentVariableBorrowRate,
            uint128 currentStableBorrowRate,
            uint40 lastUpdateTimestamp,
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress,
            address interestRateStrategyAddress,
            uint8 id
        );
}

contract Aggregator {
    using SafeMath for uint256;

    // Variables
    string public test = "Contract Smoke Test";
    mapping(address => uint256) balances; // Keep track of user balance
    mapping(address => address) locations; // Keep track of where the user balance is stored

    // Events
    event Deposit(address owner, uint256 amount, address depositTo);
    event Withdraw(address owner, uint256 amount, address withdrawFrom);

    // Constructor
    constructor() public {}

    // Functions

    function deposit(
        address _DAI,
        address _cDAI,
        address _AaveLendingPool,
        uint256 _amount
    ) public {
        require(_amount > 0);

        // Instiantiate contracts
        DAI dai = DAI(_DAI);

        dai.transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);

        // Fetch interest rates
        uint256 compoundRate = getCompoundExchangeRate(_cDAI);
        uint256 aaveRate = getAaveExchangeRate(_AaveLendingPool, _DAI);

        // Compare interest rates
        if (true) {
            // Deposit into Compound
            require(_depositToCompound(_DAI, _cDAI, _amount) == 0);

            // Update location
            locations[msg.sender] = _cDAI;
        } else {
            // Deposit into Aave
        }

        // Emit Deposit event
        emit Deposit(msg.sender, _amount, locations[msg.sender]);
    }

    function withdraw(
        address _DAI,
        address _cDAI,
        address _AaveLendingPool
    ) public {
        require(balances[msg.sender] > 0);

        // Instiantiate contracts
        DAI dai = DAI(_DAI);

        // Determine where the user funds are stored
        if (locations[msg.sender] == _cDAI) {
            require(_withdrawFromCompound(_cDAI) == 0);
        } else {
            // Withdraw from Aave
        }

        // Once we have the funds, transfer back to owner
        dai.transfer(msg.sender, balances[msg.sender]);

        emit Withdraw(msg.sender, balances[msg.sender], locations[msg.sender]);

        // Reset user balance
        balances[msg.sender] = 0;
    }

    function _depositToCompound(
        address _DAI,
        address _cDAI,
        uint256 _amount
    ) internal returns (uint256) {
        // Instiantiate contracts
        DAI dai = DAI(_DAI);
        cDAI cDai = cDAI(_cDAI);

        require(dai.approve(address(cDai), _amount));

        uint256 result = cDai.mint(_amount);
        return result;
    }

    function _withdrawFromCompound(address _cDAI) internal returns (uint256) {
        // Instiantiate contract & redeem
        cDAI cDai = cDAI(_cDAI);

        uint256 result = cDai.redeemUnderlying(balances[msg.sender]);
        return result;
    }

    // ---

    // Get Compound's interest rate
    function getCompoundExchangeRate(address _cDAI) public returns (uint256) {
        cDAI token = cDAI(_cDAI);
        uint256 exchangeRate = (token.exchangeRateCurrent() / 10); // Fetch exchange rate

        return exchangeRate;
    }

    // Get Aave's interest rate
    function getAaveExchangeRate(address _AaveLendingPool, address _DAI)
        public
        returns (uint128)
    {
        AaveLendingPool lendingPool = AaveLendingPool(_AaveLendingPool);

        (, , , uint128 currentLiquidityRate, , , , , , , , ) = lendingPool
            .getReserveData(_DAI);

        return currentLiquidityRate;
    }

    // ---
    function balanceOf() public view returns (uint256) {
        return balances[msg.sender];
    }

    function balanceWhere() public view returns (address) {
        return locations[msg.sender];
    }
}
