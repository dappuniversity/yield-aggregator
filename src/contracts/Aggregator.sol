pragma solidity ^0.5.16;

// Interface for ERC20 DAI contract
interface DAI {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}

// Interface for Compound's cDAI contract
interface cDAI {
    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);
}

// Interface for Aave's lending pool contract
interface AaveLendingPool {
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
    // Variables
    string public test = "Contract Smoke Test";

    // Events
    event Deposit(string selectedExchange);

    // Constructor
    constructor() public {}

    // Functions

    function deposit(
        address _DAI,
        address _cDAI,
        address _AaveLendingPool
    ) public {
        // Instiantiate contracts
        DAI dai = DAI(_DAI);
        cDAI cDai = cDAI(_cDAI);
        AaveLendingPool lendingPool = AaveLendingPool(_AaveLendingPool);

        string memory selectedExchange;

        // Fetch interest rates
        uint256 compoundRate = getCompoundExchangeRate(_cDAI);
        uint256 aaveRate = getAaveExchangeRate(_AaveLendingPool, _DAI);

        // Compare interest rates
        if (compoundRate > aaveRate) {
            // Deposit into Compound
            selectedExchange = "Compound";
        } else {
            // Deposit into Aave
            selectedExchange = "Aave";
        }

        // Emit Deposit event
        emit Deposit(selectedExchange);
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
}
