// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IQuinoaBaseVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseStrategy as Strategy} from "./strategies/Strategy.sol";


abstract contract QuinoaBaseVault is ERC20, IQuinoaBaseVault {
    using Math for uint256;

    IERC20Metadata private immutable _asset;
    uint8 private immutable _decimals;
    uint16 private _float; // basis

    address dacAddr;
    string dacName;
    uint256 createdAt;

    bool emergencyExit = false;

    /// @notice Strategy's main attributes are need to be initiailized
    /// @dev temporary
    struct StrategyAttr {
        uint8 strategyId; // strategy id(vault 안에서 이용)
        address strategyAddr; // strategy 주소
        bool isActivate; // activate 되었는지, 아닌지
        uint256 strategyBalance; // strategy에서 굴리고 있는 asset의 전체 양
        uint256 strategyProfit; // 이전 harvest에 비해서 얻은 수익
        // allowRange 등 ?? 더 필요한 게 있을 듯 ??
    }

    address[] strategyAddrs;
    mapping(address => StrategyAttr) strategies;

    modifier onlyDac() {
        require(msg.sender == dacAddr, "Vault: Only DAC can call this func");
        _;
    }

    /// @dev TODO needs to be keep updated
    constructor(
        address asset_,
        string memory vaultName_,
        string memory vaultSymbol_,
        address dacAddr_,
        string memory dacName_,
        uint16 float_
    ) ERC20(vaultName_, vaultSymbol_) {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(
            IERC20(asset_)
        );
        _decimals = success ? assetDecimals : super.decimals();
        _asset = IERC20Metadata(asset_);

        dacAddr = dacAddr_;
        dacName = dacName_;

        _float = float_;
        createdAt = block.timestamp;
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
    } // override?

    function convertToShares(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function convertToAssets(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    // emergency가 아니라면 max로 입금 가능 (asset 기준) -> 이때, 이건 vault 자체에 예치할 수 있는 전체 금액을 의미. emergency 상황일 땐 모두 예치 불가
    ///@notice user can deposit underlying assets as much as they want in vault's available except in emergency. In emergency situation, user can't deposit.
    function maxDeposit(address)
        public
        view
        virtual
        override
        returns (uint256 maxAssets)
    {
        return _isVaultEmergency() ? 0 : type(uint256).max;
    }

    function previewDeposit(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        returns (uint256)
    {
        require(
            !_isVaultEmergency(),
            "Vault: cannot deposit in emergency situation"
        );
        require(assets <= maxDeposit(receiver), "Vault: deposit more than max");

        uint256 shares = previewDeposit(assets);
        require(shares > 0, "Vault: deposit less than minimum");

        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    // emergency가 아니라면 max로 입금 가능 (share 기준) -> 이때, 이건 vault 자체에 예치할 수 있는 전체 금액을 의미
    function maxMint(address) public view virtual override returns (uint256) {
        // emergency 상황일 땐 모두 예치 불가
        return _isVaultEmergency() ? 0 : type(uint256).max;
    }

    function previewMint(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        returns (uint256)
    {
        require(
            !_isVaultEmergency(),
            "Vault: cannot mint in emergency situation"
        );
        require(shares <= maxMint(receiver), "Vault: mint more than max");

        uint256 assets = previewMint(shares);
        require(assets > 0, "Vault: mint less than minimum");
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    // owner가 가진 share에 맞는 만큼 asset 기준으로 withdraw 가능 (asset 기준)
    function maxWithdraw(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Down);
    }

    function previewWithdraw(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256)
    {
        // Rounding.Up인데, Down으로 바꿀까 ?
        return _convertToShares(assets, Math.Rounding.Down);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "Vault: withdraw more than max");

        uint256 shares = previewWithdraw(assets);
        require(shares > 0, "Vault: withdraw less than minimum");
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // owner가 가진 share만큼 withdraw 가능 (share 기준)
    function maxRedeem(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return balanceOf(owner);
    }

    function previewRedeem(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _convertToAssets(shares, Math.Rounding.Down);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "Vault: redeem more than max");

        uint256 assets = previewRedeem(shares);
        require(assets > 0, "Vault: redeem less than minimum");
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function _isVaultEmergency() internal view returns (bool) {
        return emergencyExit == true;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        uint256 supply = totalSupply();
        return
            (assets == 0 || supply == 0)
                ? assets.mulDiv(10**decimals(), 10**_asset.decimals(), rounding)
                : assets.mulDiv(supply, totalFreeFund(), rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        uint256 supply = totalSupply();
        return
            (supply == 0)
                ? shares.mulDiv(10**_asset.decimals(), 10**decimals(), rounding) // return x * y / z;
                : shares.mulDiv(totalFreeFund(), supply, rounding);
    }

    // deposit 로직 생각
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {}

    // withdraw 로직 생각
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual {}

    // vault attributes
    // DAC == strategiest이기 때문에 조금 고민이 필요할 듯
    function setDacAddress(address newDacAddress) external override onlyDac {
        require(newDacAddress != dacAddr, "Vault: already set dac address");
        address oldDacAddr = dacAddr;
        dacAddr = newDacAddress;
        emit UpdateDacAddress(oldDacAddr, dacAddr);
    }

    function setDacName(string memory newDacName) external override onlyDac {
        require(
            keccak256(bytes(newDacName)) != keccak256(bytes(dacName)),
            "Vault: already set dac name"
        );
        string memory oldDacName = dacName;
        dacName = newDacName;
        emit UpdateDacName(oldDacName, dacName);
    }

    function setEmergency(bool newEmergencyExit) external override onlyDac {
        require(
            newEmergencyExit != emergencyExit,
            "Vault: already set emergencyExit state"
        );
        emergencyExit = newEmergencyExit;

        if (newEmergencyExit) {
            // emergency 발생 로직
        } else {
            // emergency가 발생했다 사라졌을 때의 로직
        }

        emit UpdateEmergency(dacAddr, newEmergencyExit);
    }

    function setFloat(uint16 newFloat) external override onlyDac {
        // newFloat : 만분율
        // 10000 = 100%, 1000 = 10%, 100 = 1%, 10 = 0.1%, 1 = 0.01%
        require(newFloat > 10000, "Vault: too high target float percent");
        _float = newFloat;
        emit UpdateFloat(dacAddr, newFloat);
    }

    // vault get function
    function getDac() external view override returns (address) {
        return dacAddr;
    }

    // strategy에 대한 논의 끝난 후 작성하는 게 좋을 듯
    function getStrategies() external view override returns (address[] memory) {
        return strategyAddrs;
    }

    /// @param newStrategy 해당 param은 Strategy contract
    function addStrategy(Strategy newStrategy) external override onlyDac {
        // strategy의 params에 대한 유효성 검사
        // 이후 strategyAttr 객체 mapping에 추가하기
        StrategyAttr memory newStrategyAttr;

        // 이후 strategy 추가
        strategyAddrs.push(address(newStrategy));
        strategies[address(newStrategy)] = newStrategyAttr;

        // 이벤트 발생
        emit AddStrategy(dacAddr, address(newStrategy));
    }

    function activateStrategy(address strategyAddr) external override onlyDac {
        require(strategies[strategyAddr].isActivate == false);
        strategies[strategyAddr].isActivate = true;

        // 이후 관련 조치 -> 논의 필요 ?
        // rebalancing 같은 거! 근데 차피 추후에 하니까 상관 없을 거 같기도 함
        emit ActivateStrategy(dacAddr, strategyAddr);
    }

    function deactivateStrategy(address strategyAddr)
        external
        override
        onlyDac
    {
        require(strategies[strategyAddr].isActivate == true);
        strategies[strategyAddr].isActivate = false;

        // 이후 관련 조치 -> 논의 필요 ?
        // rebalancing 같은 거! 근데 차피 추후에 하니까 상관 없을 거 같기도 함
        emit ActivateStrategy(dacAddr, strategyAddr);
    }

    // 논의 필요
    function rebalance(address strategyAddr) external virtual {}

    // 논의 필요
    function withdrawFromStrategy(uint256 amount, address strategyAddr)
        external
        virtual
    {}

    // 현재 vault가 운용하고 있는 asset의 양으로 locked profit 포함
    function totalAssets() public view virtual override returns (uint256) {
        uint256 stLen = strategyAddrs.length;
        uint256 totalStrategyBalance = 0;
        for (uint256 i = 0; i < stLen; i++) {
            totalStrategyBalance += strategies[strategyAddrs[i]]
                .strategyBalance;
        }
        return _asset.balanceOf(address(this)) + totalStrategyBalance;
    }

    // vault가 실제로 보유하고 있는 asset의 양
    function totalFloat() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    // 현재 vault에서 출금할 수 있는 asset의 양으로, locked profit은 미포함
    function totalFreeFund() public view override returns (uint256) {
        return totalAssets() - calculateLockedProfit();
    }

    // locked profit => 흠.. 이건 시간에 따라서 결정되는 거라서 !! 논의 필요
    function calculateLockedProfit() public view returns (uint256) {}
}
