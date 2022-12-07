// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./QuinoaBaseVault.sol";

contract MaticConstantMixYieldFarmingVault is QuinoaBaseVault {

    uint16 allowRange;
    mapping(address => uint) public validAllocationRange;

    constructor(        
        address asset_,
        string memory vaultName_,
        string memory vaultSymbol_,
        address dacAddr_,
        string memory dacName_,
        uint16 float_,
        uint16 allowRange_
        ) 
    QuinoaBaseVault(
        asset_,
        vaultName_,
        vaultSymbol_,
        dacAddr_,
        dacName_,
        float_
        ) {
            allowRange = allowRange_;
        }
    

    function rebalance(address strategyAddr) override external {}
    function _updateBalanceOfUnderlying() internal {}
    function _getAllocationbalance() internal {}
    function _reallocation() internal {}

}