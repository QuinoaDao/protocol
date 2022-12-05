//SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0 <0.9.0;

interface IBeefyVaultV6 {

    function totalSupply() view external returns (uint256);

    function balanceOf(address account) external;

    function depositAll() external;
    
    function deposit(uint _amount) external;
    
    function withdrawAll() external;
    
    function withdraw(uint _shares) external;

    function getPricePerFullShare() external;

    function balance() view external returns (uint256);
}
