// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseStrategy as Strategy}  from "./strategies/Strategy.sol";


interface IQuinoaBaseVault is IERC20, IERC20Metadata {
    // event

    event UpdateDacAddress(address indexed oldDacAddr, address indexed newDacAddr);
    event UpdateDacName(address indexed oldDacName, address indexed newDacName);
    event UpdateEmergency(address indexed dacAddr, bool indexed newEmergencyExit);
    event UpdateFloat(address indexed dacAddr, uint16 newFloat);

    event AddStrategy(address indexed dacAddr, address indexed strategyAddr);
    event ActivateStrategy(address indexed dacAddr, address indexed strategyAddr);
    event DeactivateStrategy(address indexed dacAddr, address indexed strategyAddr);

    event Rebalance();
    event Harvest(); 
    event Reallocate();

    event WithdrawFromStrategy();

    event Deposit(
        address indexed sender, 
        address indexed owner, 
        uint256 assets, 
        uint256 shares)
    ;

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // function
    
    // base vault logic
    function asset() external view returns (address assetTokenAddress);
    function totalAssets() external view returns (uint256 totalManagedAssets);

    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function maxDeposit(address receiver) external view returns (uint256 maxAssets);
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function maxMint(address receiver) external view returns (uint256 maxShares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    function maxWithdraw(address owner) external view returns (uint256 maxAssets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function maxRedeem(address owner) external view returns (uint256 maxShares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    // vault attributes
    function setDacAddress(address newDacAddress) external;
    function setDacName(string memory newDacName) external;
    function setEmergency(bool newEmergencyExit) external;
    function setFloat(uint16 newFloat) external;

    // vault get function
    function getDac() external returns(address);
    function getStrategies() external returns(address[] memory);

    // relative with strategy
    function addStrategy(Strategy newStrategy) external;
    function activateStrategy(address strategyAddr) external;
    function deactivateStrategy(address strategyAddr) external;
    function rebalance(address strategyAddr) external;
    function withdrawFromStrategy(uint256 amount, address strategyAddr) external;

    
    // 여기부턴 좀 ;; 생각해봐야 할듯
    function totalFloat() external view returns (uint256);
    function totalFreeFund() external view returns (uint256);
    function calculateLockedProfit() external view returns (uint256);
}