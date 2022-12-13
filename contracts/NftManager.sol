//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/IQuinoaBaseVault.sol";


contract NFtManager is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    using Math for uint256;

    event NewNftMinted(address recipient, uint256 tokenId);
    event FullyRedeemed(address vaultAddress, address redeemedBy, uint256 tokenId);

    // NFT로 warpping 될 예치 정보
    struct DepositInfo {
        // 예치된 vault 주소
        address vault;
        // 예치증명 토큰 개수
        uint256 vaultTokenAmount;
        bool isFullyRedeemed;
    }

    /// @dev tokenID - depoit data
    mapping (uint256 => DepositInfo) private _deposits; 
    address public router;

    /// @dev (user address : ( vault address : tokenid))
    mapping(address => mapping(address  => uint256)) private _userAssets;


    constructor(address router_)
    ERC721("Quinoa Deposit Certificate NFT", "QUI-CER-NFT"){
        // token id should starts with 1
        _tokenIdCounter.increment();
        router = router_; 
    }

    /*///////////////////////////////////////////////////////////////
                            Modifier
    //////////////////////////////////////////////////////////////*/

    modifier onlyRouter { // check the msg.sender is router
        require(msg.sender == router);
        _;
    }

    /*///////////////////////////////////////////////////////////////
                    Create NFT image and TokenURL
    //////////////////////////////////////////////////////////////*/


    /*///////////////////////////////////////////////////////////////
                         Get NFT Information
    //////////////////////////////////////////////////////////////*/

    function getTokenIds(address _user, address _vault) external view onlyRouter returns(uint256[] memory tokenIds){
        return _userAssets[_user][_vault];
    }


    function getUserVaultTokenAmount(address _user, address _vault) external view returns(uint256){
        uint256[] memory tokens = _userAssets[_user][_vault];
        uint256 sum = 0;
        for(uint i=0; i<tokens.length; i++) {
            sum += _deposits[tokens[i]].vaultTokenAmount;
        }
        return sum;
    }

    /*///////////////////////////////////////////////////////////////
                Withdraw Process - burn or update NFT
    //////////////////////////////////////////////////////////////*/

    function getVaultTokenAmount(uint256 tokenId) public view returns(uint256){
        return _deposits[tokenId].vaultTokenAmount;
    }

    function isFullWithdraw(uint256 tokenId, uint256 amount) internal view returns(bool){
        return amount == getVaulTokenAmount(tokenId);
    }

    function withdraw(address user, address vault, uint256 amount)external onlyRouter {
    
        require(IERC20(vault).balanceOf(address(this)) > amount, "NftWrappingManager: Don't have enough qToken to redeem!");
        
        if (isFullWithdraw(tokenId, amount) ) {// full withdraw      
            burn(tokenId); 
            _deposits[tokenId].isFullyRedeemed = true;
            _userAssets[user][vault] = 0;
            emit FullyRedeemed(vault, msg.sender, tokenId);

        } else{ // partial withdraw. update Nft info
            _deposits[tokenId].vaultTokenAmount -= amount;
        }
        IERC20(vault).transfer(router, amount);
    }

    ///@dev redeem the whole deposit amount
    function burn(uint256 tokenId) internal {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NftWrappingManager: caller is not token owner nor approved");
        _burn(tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                Deposit Process - create or update NFT
    //////////////////////////////////////////////////////////////*/

    function depositInfo(uint tokenId)
        external
        view
        returns (
            address vault,
            uint256 vaultTokenAmount,
            bool isFullyRedeemed
        ){
        DepositInfo memory _deposit = _deposits[tokenId];
        return (
            _deposit.vault,
            _deposit.qTokenAmount,
            _deposit.isFullyRedeemed
        );
    }

    function deposit(
        address user,
        address vault,
        uint256 vaultTokenAmount
    ) onlyRouter external returns(uint256)
    {
        uint256 tokenId = _userAssets[user][vault]; 
        if ( tokenId == 0 ) { // first time to deposit to vault
            DepositInfo memory _deposit = DepositInfo(vault, qTokenAmount, false);
            uint256 tokenId = _tokenIdCounter.current();
            _deposits[tokenId] = _deposit;
            _tokenIdCounter.increment();
            _safeMint(user,tokenId);
            _userAssets[user][vault] = tokenId;
        } else { // additional deposit
            _deposits[tokenId].vaultTokenAmount += vaultTokenAmount;
        }
        return tokenId;
    }










}