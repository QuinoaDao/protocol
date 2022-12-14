// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRouter {

    event Buy(address user, address vault, uint256 amount); 
    event Sell(address user, address vault, uint256 amount);

    function buy(address vault, uint256 _amount) external;
    function sell(uint256 tokenId, uint256 amount) external;
}

 