// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./IQuinoaBaseVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract QuinoaBaseVault is ERC20, IQuinoaBaseVault {
    using Math for uint256;

    IERC20 private immutable _asset;
    uint8 private immutable _decimals;

    // strategy 관련 여러 변수들 선언 필요

    // constructor 수정 필요
    constructor(IERC20 asset_) {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _decimals = success ? assetDecimals : super.decimals();
        _asset = asset_;
    }

        function _tryGetAssetDecimals(IERC20 asset_) private returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) = address(asset_).call(
            abi.encodeWithSelector(IERC20Metadata.decimals.selector)
        );
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    function asset() public view virtual override returns (address) {
        return address(_asset);
    }

    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    // emergency가 아니라면 max로 입금 가능 (asset 기준) -> 이때, 이건 vault 자체에 예치할 수 있는 전체 금액을 의미
    function maxDeposit(address) public view virtual override returns (uint256 maxAssets) {
        // emergency 상황일 땐 모두 예치 불가
        return _isVaultEmergency() ? 0 : type(uint256).max;
    }

    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        require(!_isVaultEmergency(), "ERC4626: cannot deposit in emergency situation");
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");
    
        uint256 shares = previewDeposit(assets);
        require(shares > 0, "ERC4626: deposit less than minimum");

        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    // emergency가 아니라면 max로 입금 가능 (share 기준) -> 이때, 이건 vault 자체에 예치할 수 있는 전체 금액을 의미
    function maxMint(address) public view virtual override returns (uint256) {
        // emergency 상황일 땐 모두 예치 불가
        return _isVaultEmergency() ? 0 : type(uint256).max;
    }

    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        // Rounding.Up 인데, Down으로 바꿀까 ?
        return _convertToAssets(shares, Math.Rounding.Up);
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        require(!_isVaultEmergency(), "ERC4626: cannot mint in emergency situation");
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(shares);
        require(assets > 0, "ERC4626: mint less than minimum");
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    // owner가 가진 share에 맞는 만큼 asset 기준으로 withdraw 가능 (asset 기준)
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Down);
    }

    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        // Rounding.Up인데, Down으로 바꿀까 ?
        return _convertToShares(assets, Math.Rounding.Up);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");

        uint256 shares = previewWithdraw(assets);
        require(shares > 0, "ERC4626: withdraw less than minimum");
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // owner가 가진 share만큼 withdraw 가능 (share 기준)
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return balanceOf(owner);
    }
    
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        uint256 assets = previewRedeem(shares);
        require(assets > 0, "ERC4626: redeem less than minimum");
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    // 구현이 더 필요한 로직들
    function totalAssets() public view virtual override returns (uint256);
    function _isVaultEmergency() internal view virtual returns(bool);

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256);
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256);
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual;
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual;

    // vault attributes
    // DAC == strategiest이기 때문에 조금 고민이 필요할 듯
    function setDAC(address newDac) external;
    function setEmergency(bool isEmergency) external;
    function setFloat(uint newTargetFloat) external;

    // vault get function
    function getDac() external;
    function getStrategies() external;

    // relative with strategy
    function addStrategy(Strategy newStrategy) external;
    function activateStrategy(address strategy) external;
    function deactivateStrategy(address strategy) external;
    function rebalance(address strategy) external;
    function withdrawFromStrategy(uint256 amount, Strategy strategy) external;

    
    // 여기부턴 좀 ;; 생각해봐야 할듯
    function totalFloat() external view returns (uint256);
    function totalFreeFund() external view returns (uint256);
    function calculateLockedProfit() external view returns (uint256);
}