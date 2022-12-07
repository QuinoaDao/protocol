// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
// import {IVault} from "./interfaces/IVault.sol";
import {IQuinoaBaseVault as IVault} from "../IQuinoaBaseVault.sol";
import {IBalancerVault} from "../interfaces/IBalancerVault.sol";
import {IBeefyVaultV6} from "../interfaces/IBeefyVaultV6.sol";
import {BaseStrategy} from "./Strategy.sol";
import "hardhat/console.sol";


contract StrategyBalancerWMaticStMatic is BaseStrategy {
    using SafeERC20 for ERC20;
    /*///////////////////////////////////////////////////////////////
                                Public
    //////////////////////////////////////////////////////////////*/
    address public vaultAddress;
    // address public swapRouter;
    address public poolVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer Vault On Matic;
    address public topOnVault;
    address public topOnVaultInput = 0x8159462d255C1D24915CB51ec361F700174cD994; // TODO get from calldata;
    address[] public lpTokens;
    bytes32 public poolId;
    

    /*///////////////////////////////////////////////////////////////
                            Configuration
    //////////////////////////////////////////////////////////////*/
    bool emergency = false;
    ERC20 UNDERLYING;

    /// TODO moves to the other contract and this contract inherits should inherit them.
    /// @param _underlying_address The address of underlying tokens to deposit/withdraw to the strategy : "wmatic"; 
    constructor(address _underlying_address, address _vaultAddress, bytes32 _poolId, address _topOnVault, address keeper_) BaseStrategy(_vaultAddress, _underlying_address, poolVault, _msgSender(), keeper_) {
        UNDERLYING = ERC20(_underlying_address);
        vaultAddress = _vaultAddress;
        poolId = _poolId;
        topOnVault = _topOnVault;
        (lpTokens,,) = IBalancerVault(poolVault).getPoolTokens(poolId); // TODO make more universial of the interface IBalancerVault
        swapRouter = poolVault;
    }

    function name() external pure override returns (string memory) {
        return "StrategyBalancerWMaticStMatic";
    }

    /// @notice set the 
    function setPoolVault(address _poolVault) external onlyDAC {
        poolVault = _poolVault;
    }

    /// @param _poolId the address of the pool Id of the platform
    function setPoolId(bytes32 _poolId) external onlyDAC {
        poolId = _poolId;
    }

    /// @notice get LP Token with underlying asset from the protocol where if necessary
    /// @param _amountIn the address of the protocol where the LP is held -> balancer address
    function joinPool(uint256 _amountIn) public {
        uint256[] memory amounts = new uint256[](lpTokens.length);
        for (uint256 i=0; i < amounts.length; i++) {
            amounts[i] = lpTokens[i] == address(UNDERLYING) ? _amountIn : 0;
        }
        bytes memory userData = abi.encode(1, amounts, 1);
        IBalancerVault.JoinPoolRequest memory request = IBalancerVault.JoinPoolRequest(lpTokens, amounts, userData, false);
        IBalancerVault(poolVault).joinPool(poolId, address(this), address(this), request);
    }

    // function addLiquidity() public {
    //     uint256 nativeBal = IERC20(UNDERLYING).balanceOf(address(this));
    //     address pool = 0x8159462d255C1D24915CB51ec361F700174cD994;
    //     _swap(address(UNDERLYING), nativeBal, pool);

    //     uint256 inputBal = IERC20(pool).balanceOf(address(this));
    //     joinPool(inputBal);
    // }

    /// @notice deposit funds to DAC's strategy after obtaining DAC's vault's input
    /// @param amount the amount of underlying asset to be sent to the topOnVault;
    function _deposit(uint256 amount) override internal {
        // uint inputBal = _swap(address(UNDERLYING), amount, topOnVaultInput);
        uint inputBal = _swap(address(UNDERLYING), UNDERLYING.balanceOf(address(this)), topOnVaultInput);
        IERC20(topOnVaultInput).approve(topOnVault, inputBal);
        IBeefyVaultV6(topOnVault).deposit(inputBal);
    }

    function _withdraw(uint256 amount) override internal returns (uint256) {
        uint shareToWithdraw = _convertToShare(amount);
        // IERC20(topOnVault).approve(to, inputBal);
        IBeefyVaultV6(topOnVault).withdraw(shareToWithdraw);
        // uint inputBal = _swap(address(UNDERLYING), UNDERLYING.balanceOf(address(this)), topOnVaultInput);
        uint redeemedUnderlying = _swap(topOnVaultInput, shareToWithdraw, address(UNDERLYING));
        return redeemedUnderlying;
    }

    function balanceOfUnderlying() external view override returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    // function _redeemUnderlying(uint256 amount) internal returns (uint256) {
    //     uint shareToWithdraw = _convertToShare(amount);
    //     // IERC20(topOnVault).approve(to, inputBal);
    //     IBeefyVaultV6(topOnVault).withdraw(shareToWithdraw);
    //     // uint inputBal = _swap(address(UNDERLYING), UNDERLYING.balanceOf(address(this)), topOnVaultInput);
    //     uint redeemedUnderlying = _swap(topOnVaultInput, shareToWithdraw, address(UNDERLYING));
    //     return redeemedUnderlying;
    // }

    function _swap(address _tokenIn, uint256 _amountIn, address _tokenOut) internal returns (uint256 amountOut) {
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement(address(this), false, payable(address(this)), false);
        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap(poolId, IBalancerVault.SwapKind.GIVEN_IN, _tokenIn, _tokenOut, _amountIn, "");
        IERC20(UNDERLYING).approve(swapRouter, type(uint256).max);
        return IBalancerVault(swapRouter).swap(singleSwap, funds, 1, block.timestamp);   
    }

    /// @param amount the amount to be converted into the share of the external platform
    /// @dev   amount : balance  == x : totalShare
    function _convertToShare(uint256 amount) internal view returns (uint256 shares) {
        uint256 BSupply = IBeefyVaultV6(topOnVault).totalSupply();
        uint256 BBalance = IBeefyVaultV6(topOnVault).balance();
        return (amount * BSupply) / BBalance;
     }

}
