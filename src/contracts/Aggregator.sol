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

    function withdraw(
        address asset,
        uint256 amount,
        address to
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
    string public name = "Yield Aggregator";
    mapping(address => uint256) public balances; // Keep track of user balance
    mapping(address => address) public locations; // Keep track of where the user balance is stored

    // Events
    event Deposit(address owner, uint256 amount, address depositTo);
    event Withdraw(address owner, uint256 amount, address withdrawFrom);
    event Rebalance(address owner, uint256 amount, address depositTo);

    // Constructor
    constructor() public {}

    // Functions

    function deposit(
        address _DAI,
        address _cDAI,
        address _aaveLendingPool,
        uint256 _amount
    ) public {
        require(_amount > 0);

        // Rebalance in the case of a protocol with the higher rate after their initial deposit,
        // is no longer the higher interest rate during this deposit...
        if (balances[msg.sender] > 0) {
            rebalance(_DAI, _cDAI, _aaveLendingPool);
        }

        // Instiantiate DAI contract
        DAI dai = DAI(_DAI);

        dai.transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);

        // Fetch interest rates
        uint256 compoundRate = getCompoundInterestRate(_cDAI);
        uint256 aaveRate = getAaveInterestRate(_aaveLendingPool, _DAI);

        // Compare interest rates
        if (compoundRate > aaveRate) {
            // Deposit into Compound
            require(_depositToCompound(_DAI, _cDAI, _amount) == 0);

            // Update location
            locations[msg.sender] = _cDAI;
        } else {
            // Deposit into Aave
            _depositToAave(_DAI, _aaveLendingPool, _amount);

            // Update location
            locations[msg.sender] = _aaveLendingPool;
        }

        // Emit Deposit event
        emit Deposit(msg.sender, _amount, locations[msg.sender]);
    }

    function withdraw(
        address _DAI,
        address _cDAI,
        address _aaveLendingPool
    ) public {
        require(balances[msg.sender] > 0);

        // Instiantiate contracts
        DAI dai = DAI(_DAI);

        // Determine where the user funds are stored
        if (locations[msg.sender] == _cDAI) {
            require(_withdrawFromCompound(_cDAI) == 0);
        } else {
            // Withdraw from Aave
            _withdrawFromAave(_DAI, _aaveLendingPool);
        }

        // Once we have the funds, transfer back to owner
        dai.transfer(msg.sender, balances[msg.sender]);

        emit Withdraw(msg.sender, balances[msg.sender], locations[msg.sender]);

        // Reset user balance
        balances[msg.sender] = 0;
    }

    function rebalance(
        address _DAI,
        address _cDAI,
        address _aaveLendingPool
    ) public {
        // Make sure funds are already deposited...
        require(balances[msg.sender] > 0);

        // Fetch interest rates
        uint256 compoundRate = getCompoundInterestRate(_cDAI);
        uint256 aaveRate = getAaveInterestRate(_aaveLendingPool, _DAI);

        // Compare interest rates
        if ((compoundRate > aaveRate) && (locations[msg.sender] != _cDAI)) {
            // If compoundRate is greater than aaveRate, and the current
            // location of user funds is not in compound, then we transfer funds.

            _withdrawFromAave(_DAI, _aaveLendingPool);

            _depositToCompound(_DAI, _cDAI, balances[msg.sender]);

            // Update location
            locations[msg.sender] = _cDAI;

            emit Rebalance(
                msg.sender,
                balances[msg.sender],
                locations[msg.sender]
            );
        } else if (
            (aaveRate > compoundRate) &&
            (locations[msg.sender] != _aaveLendingPool)
        ) {
            // If aaveRate is greater than compoundRate, and the current
            // location of user funds is not in aave, then we transfer funds.

            _withdrawFromCompound(_cDAI);

            _depositToAave(_DAI, _aaveLendingPool, balances[msg.sender]);

            // Update location
            locations[msg.sender] = _aaveLendingPool;

            emit Rebalance(
                msg.sender,
                balances[msg.sender],
                locations[msg.sender]
            );
        }
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

    function _depositToAave(
        address _DAI,
        address _aaveLendingPool,
        uint256 _amount
    ) internal returns (uint256) {
        // Instiantiate contracts
        DAI dai = DAI(_DAI);
        AaveLendingPool lendingPool = AaveLendingPool(_aaveLendingPool);

        require(dai.approve(address(lendingPool), _amount));

        lendingPool.deposit(_DAI, _amount, address(this), 0);
    }

    function _withdrawFromAave(address _DAI, address _aaveLendingPool)
        internal
    {
        AaveLendingPool lendingPool = AaveLendingPool(_aaveLendingPool);

        lendingPool.withdraw(_DAI, balances[msg.sender], address(this));
    }

    // ---

    // Get Compound's interest rate
    function getCompoundInterestRate(address _cDAI) public returns (uint256) {
        cDAI token = cDAI(_cDAI);
        uint256 exchangeRate = (token.exchangeRateCurrent() / 10); // Fetch exchange rate

        return exchangeRate;
    }

    // Get Aave's interest rate
    function getAaveInterestRate(address _aaveLendingPool, address _DAI)
        public
        returns (uint128)
    {
        AaveLendingPool lendingPool = AaveLendingPool(_aaveLendingPool);

        (, , , uint128 currentLiquidityRate, , , , , , , , ) = lendingPool
            .getReserveData(_DAI);

        return currentLiquidityRate;
    }

    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }

    function balanceWhere(address _user) public view returns (address) {
        return locations[_user];
    }
}
