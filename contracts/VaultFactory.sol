// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {QuinoaBaseVault} from "./QuinoaBaseVault.sol";
import {MaticConstantMixYieldFarmingVault} from "./MaticConstantMixYieldFarmingVault.sol";

contract VaultFactory {

    struct VaultInfo {
        address[] asset;
        string name;
        string symbol;
        bool isEmergency;
    }
    address[] vaults;
    mapping(address => uint256) vaultAddresstoArrayIndex;
    mapping(address => VaultInfo) vaultInfos;

    address private _router;
    address private _protocolTreasury;

    constructor(address router_, address protocolTreasury_){
        _router = router_;
        _protocolTreasury = protocolTreasury_;
        // vault 인덱스가 1부터 시작하도록 함
        vaults[0] = address(0);
    }

    // TODO : event should contain more information
    event VaultDeployed(address indexed vaultAddress, string assetName, address indexed user);

    modifier onlyVault() {
        require(
            vaultAddresstoArrayIndex[msg.sender] > 0,
            "Router: sender address is not registered vault address"
        );
        _;
    }

    function updateVaultEmergencyStat(bool stat) public onlyVault {
        vaultInfos[msg.sender].isEmergency = stat;
    }

    function getVaultInfo(address vaultAddr)
        public
        view
        returns (
            string memory,
            string memory,
            bool
        )
    {
        return (
            vaultInfos[vaultAddr].name,
            vaultInfos[vaultAddr].symbol,
            vaultInfos[vaultAddr].isEmergency
        );
    }

    // TODO : 배포하는 vault의 카테고리를 구분하는 로직이 필요함.
    function deployVault(address[] assets, string memory vaultName, string memory vaultSymbol, address dacAddr, string memory dacName, uint16 float, uint16 allowRange) external returns (address) {

        QuinoaBaseVault newVault = new MaticConstantMixYieldFarmingVault(asset, vaultName, vaultSymbol, dacAddr, dacName, float, allowRange);
        vaults.push(address(newVault));
        //emit VaultDeployed(address(newVault), asset.name(), msg.sender);

        vaults.push(address(newVault));
        VaultInfo memory vaultInfo;
        vaultInfo.asset
        address[] storage assetArray;
        assetArray.push(asset);
        VaultInfo memory info = VaultInfo(
            assetArray,
            vaultName,
            vaultSymbol,
            false
        );
        vaultInfos[address(newVault)] = info;
        vaultAddresstoArrayIndex[address(newVault)] = vaults.length - 1;
        return address(newVault);
    }

    function getVault() view external returns (address[] memory) {
        return vaults;
    }
}