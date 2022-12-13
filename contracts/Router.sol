// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import {IQuinoaBaseVault} from "./interfaces/IQuinoaBaseVault.sol";
import {INftManager} from "./interfaces/INftManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Router is Ownable {
    using Math for uin256;

    uint256 public protocolFee = 0;
    address public protocolTreasury;
    address public vaultFactory;
    INftManager public nftManager;

    struct VaultInfo {
        address[] asset;
        string name;
        string symbol;
        bool isActivate;
        bool isEmergency;
    }
    address[] vaults;
    mapping(address => uint256) vaultAddresstoArrayIndex;
    mapping(address => VaultInfo) vaultInfos;

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
        // vault 인덱스가 1부터 시작하도록 함
        vaults[0] = address(0);
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier onlyVault() {
        require(
            vaultAddresstoArrayIndex[msg.sender] > 0,
            "Router: sender address is not registered vault address"
        );
        _;
    }

    modifier onlyVaultFactory() {
        require(
            msg.sender == vaultFactory,
            "Router: only vaultFactory is allowed"
        );
    }

    /*///////////////////////////////////////////////////////////////
                            Fees
    //////////////////////////////////////////////////////////////*/

    function updateProtocolFee(uint256 newProtocolFee) public onlyOwner {
        require(
            0 <= newProtocolFee && newProtocolFee <= 1e18,
            "Router: Invalid Protocol Fee Percent"
        );
        protocolFeePercent = newProtocolFee;
    }

    /*///////////////////////////////////////////////////////////////
                            VaultStats
    //////////////////////////////////////////////////////////////*/

    function getVaultInfo(address vaultAddr)
        public
        view
        returns (
            string,
            string,
            bool,
            bool
        )
    {
        return (
            vaultInfos[vaultAddr].name,
            vaultInfos[vaultAddr].symbol,
            vaultInfos[vaultAddr].isActivate,
            vaultInfos[vaultAddr].isEmergency
        );
    }

    function updateVaultActiateStat(bool stat) public onlyVault {
        vaultInfos[msg.sender].isActivate = stat;
    }

    function updateVaultEmergencyStat(bool stat) public onlyVault {
        vaultInfos[msg.sender].isEmergency = stat;
    }

    function setVaultFactory(address _vaultFactory) onlyOwner {
        require(
            _vaultFactory != address(0),
            "Router: vaultFactory address cannot be zero"
        );
        vaultFactory = _vaultFactory;
    }

    function registerVault(
        address vaultAddr,
        string _name,
        string _symbol,
        bool _isActivate,
        bool _isEmergency
    ) {
        require(
            vaultAddresstoArrayIndex[vaultAddr] == 0,
            "Router: vault is already registered"
        );
        vaults.push(vaultAddr);
        VaultInfo info = new VaultInfo(
            _name,
            _symbol,
            _isActivate,
            _isEmergency
        );
        vaultInfos[vaultAddr] = info;
        vaultAddresstoArrayIndex[vaultAddr] = vaults.length - 1;
    }

    /*///////////////////////////////////////////////////////////////
                            Buying
    //////////////////////////////////////////////////////////////*/

    function buy(address _vault, uint256 _amount) external {
        IQuinoaBaseVault vault = IQuinoaBAseVault(_vault);
        IERC20 vaultToken = IERC20(vault);
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
