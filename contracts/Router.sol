// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import {IQuinoaBaseVault} from "./interfaces/IQuinoaBaseVault.sol";
import {INftManager} from "./interfaces/INftManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Router is Ownable {
    using Math for uint256;

    uint256 public protocolFee = 0;
    address public protocolTreasury;
    address public vaultFactory;
    INftManager public _nftManager;

    constructor(address _protocolTreasury) {
        require(
            _protocolTreasury != address(0),
            "Router: Zero address for protocolTreasury is not allowed"
        );
        require(
            _nftManager != address(0),
            "Router: Zero address for NftManager is not allowed"
        );
        protocolTreasury = _protocolTreasury;
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier onlyVaultFactory() {
        require(
            msg.sender == vaultFactory,
            "Router: only vaultFactory is allowed"
        );
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Fees
    //////////////////////////////////////////////////////////////*/

    function updateProtocolFee(uint256 newProtocolFee) public onlyOwner {
        require(
            0 <= newProtocolFee && newProtocolFee <= 1e18,
            "Router: Invalid Protocol Fee Percent"
        );
        protocolFee = newProtocolFee;
    }

    /*///////////////////////////////////////////////////////////////
                            VaultStats
    //////////////////////////////////////////////////////////////*/


    function setVaultFactory(address _vaultFactory) public onlyOwner {
        require(
            _vaultFactory != address(0),
            "Router: vaultFactory address cannot be zero"
        );
        vaultFactory = _vaultFactory;
    }


    /*///////////////////////////////////////////////////////////////
                            Buying
    //////////////////////////////////////////////////////////////*/

    function buy(address _vault, uint256 _amount) external {
        IQuinoaBaseVault vault = IQuinoaBaseVault(_vault);
        IERC20 vaultToken = IERC20(_vault);
        IERC20 assetToken = IERC20(vault.asset());

        // get asset from client
        assetToken.transferFrom(msg.sender, address(this), _amount);

        // get protocol fee and send it to protocol treasury
        uint256 depositAmount = _amount;

        uint256 protocolFeeAmount = _amount.mulDiv(
            protocolFeePercent,
            1e18,
            Math.Rounding.Down
        );
        depositAmount -= protocolFeeAmount;
        assetToken.transfer(protocolTreasury, protocolFeeAmount);

        // exchange asset - vaultToken with Vault
        uint256 currentAmount = vaultToken.balanceOf(address(this));
        assetToken.approve(address(vault), depositAmount);
        uint256 vaultTokenAdded = vault.deposit(depositAmount, address(this));

        require(
            vaultToken.balanceOf(address(this)) - currentAmount ==
                vaultTokenAdded,
            "Router: Amount of shareToken to relay has unexpected value"
        );

        // send vaultToken to NFTManager
        vaultToken.transfer(address(NFTManager), qvTokenAdded);
        NFTManager.deposit(msg.sender, address(vault), qvTokenAdded);
        
    }

    /*///////////////////////////////////////////////////////////////
                            Selling
    //////////////////////////////////////////////////////////////*/

    function sell(uint256 tokenId, uint256 amount) external {
        require(
            NftManager.ownerOf(tokenId) == msg.sender,
            "only owner of token can change token state"
        );
        (
            address _vault,
            uint256 _vaultTokenAmount,
            bool isFullyRedeemed
        ) = NftManager.depositInfo(tokenId);
        require(
            !isFullyRedeemed && amount <= _vaultTokenAmount,
            "not enough token to withdraw"
        );

        IVault vault = IVault(_vault);
        IERC20 vaultToken = IERC20(_vault);
        IERC20 assetToken = IERC20(vault.asset());

        // withdraw vaultToken from NFTManager
        uint256 currentAmount = vaultToken.balanceOf(address(this));
        NftManager.withdraw(tokenId, address(vault), amount);

        require(
            vaultToken.balanceOf(address(this)) - currentAmount == amount,
            "Router: Amount of qvToken to relay has unexpected value"
        );

        // send vaultToken to Vault and redeem it
        uint256 beforeRedeem = assetToken.balanceOf(address(this));
        //qvToken.transfer(address(vault), amount);
        uint256 addedAsset = vault.redeem(amount, address(this), address(this));
        require(
            assetToken.balanceOf(address(this)) - beforeRedeem == addedAsset,
            "Router: Amount of assetToken to relay has unexpected value"
        );

        // send asset to client
        assetToken.transfer(msg.sender, addedAsset);
    }
}
