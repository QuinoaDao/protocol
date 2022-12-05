// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title BaseStrategy
 * @author Quinoa Investments
 *
 * Base Strategy contract. Belongs to a product. Abstract.
 * Will be extended from specific category strategy contracts made and deployed by DAC.
 */

abstract contract BaseStrategy is AccessControl, Pausable {
    /*///////////////////////////////////////////////////////////////
                                Public
    //////////////////////////////////////////////////////////////*/
    address public vault;
    address public swapRouter;
    address public dac;
    address public keeper;
    address public governance;
    bytes32 public constant DAC_ROLE = keccak256("DAC_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bool public isEmergency = false;

    /*///////////////////////////////////////////////////////////////
                                Modifier
    //////////////////////////////////////////////////////////////*/
    modifier onlyGovernance() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Caller is not authorized");
        _;
    }
    
    modifier onlyDAC() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender) || hasRole(DAC_ROLE, msg.sender), "Caller is not authorized");
        _;
    }

    /*///////////////////////////////////////////////////////////////
                                Event
    //////////////////////////////////////////////////////////////*/
    event SetVault(address vault);
    event SetSwapRouter(address swapRouter);
    event SetDAC(address dac);
    event SetKeeper(address keeper);
    event SetGovernance(address governance);

    /*///////////////////////////////////////////////////////////////
                                Configuration
    //////////////////////////////////////////////////////////////*/
    uint256 internal protocolFee;
    uint256 internal performanceFee;
    IERC20 underlying;

    constructor(address _vault, address _underlying, address _swapRouter, address _dac, address _keeper, address _governance) {
        vault = _vault;
        underlying = IERC20(_underlying);
        swapRouter = _swapRouter;
        dac = _dac;
        keeper = _keeper;
        governance = _governance;
        _setupRole(DEFAULT_ADMIN_ROLE, governance);
        _grantRole(DAC_ROLE, dac);
        _grantRole(GOVERNANCE_ROLE, governance);
    }

    // set new vault (only for strategy upgrades)
    function setVault(address _vault) external onlyDAC {
        vault = _vault;
        emit SetVault(_vault);
    }

    // set new swap router
    function setSwapRouter(address _swapRouter) external onlyDAC {
        swapRouter = _swapRouter;
        emit SetSwapRouter(_swapRouter);
    }

    // set new keeper to manage strat
    function setKeeper(address _keeper) external onlyDAC {
        keeper = _keeper;
        emit SetKeeper(_keeper);
    }

    // set new strategist address to receive strat fees
    function setDAC(address _dac) external onlyDAC {
        dac = _dac;
        emit SetDAC(_dac);
    }
    
    function setEmergency(bool _isEmergency) external virtual onlyDAC {
        isEmergency = _isEmergency;
        if(isEmergency) {
            uint returned =  _withdraw(underlying.balanceOf(address(this)));
            underlying.transfer(vault, returned);
        }
    }

    function name() external view virtual returns (string memory);

    function asset() external view returns (address) {
        return address(underlying);
    }

    /// @notice calculate all the values of underlying in strategy and the external protocol(platform)
    /// @dev get the values of the balance in external protocol and add it to the strategy floating balance.
    function balanceOfUnderlying() external virtual returns (uint256);

    function deposit(uint256 amount) external onlyDAC {
        _deposit(amount);
    }

    function _deposit(uint256 amount) virtual internal;
    
    
    function withdraw(uint256 amount) external onlyDAC returns (uint256)  {
        return _withdraw(amount);
    }

    function _withdraw(uint256 amount) virtual internal returns (uint256);

    // function _swap(address _tokenIn, uint256 _amountIn, address _tokenOut) internal virtual returns (uint256 amountOut);
    
    /// @notice get the amount of share token of external defi protocol or platform
    /// @param amount the amount of underlying token to be converted
    /// @dev return (amount * Platform's Total Share) / (platform's total balance in underlying token)
    // function _convertToShare(uint256 amount) internal view virtual returns (uint256 shares);
}