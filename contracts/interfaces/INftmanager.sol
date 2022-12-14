// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INftManager is IERC721 {

    //event
    event NewNftMinted(address recipient, uint256 tokenId, uint256 vaultTokenAmount);
    event FullyRedeemed(address vaultAddress, address tokenOwner, uint256 tokenId);
   
    event NftVaultTokenAdded(uint256 tokenId, address vault, address tokenOwner, uint256 addedAmount, uint256 currentAmount);
    event NftVaultTokenSubtracted(uint256 tokenId, address vault, address tokenOwner, uint256 subtractedAmount, uint256 currentAmount);
    
    //info function
    function getTokenId(address user, address vault) external view returns(uint256 tokenId);
    function getUserVaultTokenAmount(address user, address vault) external view returns(uint256);
    function depositInfo(uint tokenId)external view returns (address vault, uint256 vaultTokenAmount, bool isFullyRedeemed);
    
    //withdraw
    function withdraw(address user, address vault, uint256 amount) external;

    //deposit
    function deposit(address user, address vault, uint256 vaultTokenAmount) external returns(uint256);

}
