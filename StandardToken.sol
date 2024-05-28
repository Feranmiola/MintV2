//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Factory.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}


contract PurpleToken01 is ERC20{
    
    using SafeERC20 for IERC20;
    bool public enabledTrading;
    address public pair;
    mapping (address => bool) private isAllowedToAddToLiquidity;
    event pairChanged(address indexed oldPair, address indexed newPair);

    constructor(address Owner, string memory tokenName, string memory tokenSymbols, uint8 decimals__, uint totalSupply, address router) ERC20(tokenName, tokenSymbols, decimals__) Ownable(Owner) {
        // transferOwnership(Owner);
        _mint(Owner, totalSupply * 10 ** decimals());
        isAllowedToAddToLiquidity[Owner] = true;
        pair = IUniswapV2Factory(IUniswapV2Router01(router).factory()).createPair(address(this), IUniswapV2Router01(router).WETH());
    }


    function _transfer(address from, address to, uint256 amount) internal virtual override{
        
        address _pair = pair;
        bool pairTransfer = from == _pair || to == _pair;
        
        if (!enabledTrading) {
            if (pairTransfer && !isAllowedToAddToLiquidity[from]) {
                revert("Trading not started");
            }
        }

        super._transfer(from, to, amount);
        
    }

    function addLiquidityAdders(address adder) external onlyOwner{
        require(!isAllowedToAddToLiquidity[adder], "Address already added");
        isAllowedToAddToLiquidity[adder] = true;
    }
    function removeLiquidityAdder(address adder) external onlyOwner{
        require(isAllowedToAddToLiquidity[adder], "Address not already added");
        isAllowedToAddToLiquidity[adder] = false;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function setPair(address pair_) external onlyOwner{
        address oldPair;
        pair = pair_;

        emit pairChanged(oldPair, pair_);
    }

    function getPair() external view returns(address){
        return pair;
    }

    function enableTrading() public onlyOwner {
        enabledTrading = true;
    }

    function isTradingEnabled() public view returns(bool){
        return enabledTrading;
    }

    function renounceOwnership() public onlyOwner override {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public onlyOwner override {
        _transferOwnership(newOwner);
    }

    function claimStuckTokens(address tokenAddress, uint256 amount, address reciever) public onlyOwner {
        IERC20(tokenAddress).safeTransfer(reciever,  amount);        
        
    }


}

struct fessAndWallets{
        address router_;
        address marketingWallet_;
        uint256 burnFee_;
        uint256 marketingFeeBps_;
        uint256 swapTokensAtAmount_;

}

contract PurpleToken02 is ERC20 {
    // Mapping to exclude addresses from fees
    mapping (address => bool) private isExcludedFromFees;

    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address private pair;

    
    uint256 private marketingFeeBps;
    uint256 private burnfeebps;
    
    uint256 private totalFeePercentage;
    uint256 public feeLimit;


    // Marketing wallet
    address private marketingWallet;

    // Swap tokens at amount
    uint256 private swapTokensAtAmount;

    // LP swap router
    IUniswapV2Router02 private lpSwapRouter;

    // Total fees
    uint256 public totalFees;

    // Enabled trading
    bool private enabledTrading;

    bool private inSwap;

    mapping (address => bool) private isAllowedToAddToLiquidity;

    event burnFeeChanged(uint oldFee, uint newFee);
    event marketingFeeChanged(uint oldFee, uint newFee);
    event marketingWalletChanged(address indexed oldWallet, address indexed newWallet);
    event routerChanged(address indexed oldRouter, address indexed newRouter);
    event pairChanged(address indexed oldPair, address indexed newPair);
    event includedInFees(address indexed account);
    event excludedFromFees(address indexed account);

    constructor(address owner, string memory name_, string memory symbol_, uint8 decimals_, uint256 totalSupply_, fessAndWallets memory fandw) ERC20(name_, symbol_, decimals_) Ownable(owner) {
        
        // transferOwnership(owner);
        _mint(owner, totalSupply_ * 10 ** decimals_);

        marketingWallet = fandw.marketingWallet_;
        // buyTaxFeeBps = fandw.buyTaxFeeBps_;
        // transferTaxFeeBps = fandw.transferTaxFeeBps_;
        // sellTaxFeeBps = fandw.sellTaxFeeBps_;

        marketingFeeBps = fandw.marketingFeeBps_;
        swapTokensAtAmount = fandw.swapTokensAtAmount_;

        

        burnfeebps = fandw.burnFee_;

        totalFeePercentage = marketingFeeBps + burnfeebps;
        feeLimit = totalFeePercentage;
        
        lpSwapRouter = IUniswapV2Router02(fandw.router_);
        pair = IUniswapV2Factory(lpSwapRouter.factory()).createPair(address(this), lpSwapRouter.WETH());

        enabledTrading = false;

        isExcludedFromFees[owner] = true;
        isAllowedToAddToLiquidity[owner] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[marketingWallet]= true;
        isExcludedFromFees[address(lpSwapRouter)]= true;

    }


    receive() external payable {
        payable(marketingWallet).transfer(address(this).balance);
    }

      modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }


    function swap(uint tokenAmount) internal lockTheSwap{
        address[] memory path = new address[](2);

        path[0] = IUniswapV2Pair(pair).token0();
        path[1] = lpSwapRouter.WETH();

        if(path[0] != address(this)){
            path[0] = address(this);
        }

        _approve(address(this), address(lpSwapRouter), type(uint256).max);

        // make the swap
        lpSwapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );

    }


    function _transfer(address from, address to, uint256 amount) internal virtual override {
        
        address _pair = pair;
        bool pairTransfer = from == _pair || to == _pair;
        
        if (!enabledTrading) {
            if (pairTransfer && !isAllowedToAddToLiquidity[from]) {
                revert("Trading not started");
            }
        }

        
        uint256 _marketingFeeBps = marketingFeeBps;
        
        if (pairTransfer && _marketingFeeBps > 0 && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            uint256 feetaken;

            feetaken = amount * marketingFeeBps / 10000;

            uint256 newTotalFees = totalFees + feetaken;
            
            totalFees = newTotalFees;

            super._transfer(from, address(this), feetaken);

            amount -= feetaken;
            
            //Swapping only if to is pair
            if ((newTotalFees >= swapTokensAtAmount) && !inSwap && (to == _pair)) {
                swap(newTotalFees);
                totalFees = 0;
            }
        }
        super._transfer(from, to, amount);
    }

    function addLiquidityAdders(address adder) external onlyOwner{
        require(!isAllowedToAddToLiquidity[adder], "Address already added");
        isAllowedToAddToLiquidity[adder] = true;
    }
    function removeLiquidityAdder(address adder) external onlyOwner{
        require(isAllowedToAddToLiquidity[adder], "Address not already added");
        isAllowedToAddToLiquidity[adder] = false;
    }


    function claimStuckTokens(address tokenAddress, uint256 amount, address receiver) public onlyOwner {
        IERC20(tokenAddress).safeTransfer(receiver,  amount);        
    }

    function deleteFees() public onlyOwner{
        delete burnfeebps;
        delete marketingFeeBps;
        delete totalFeePercentage;
    }

    
    function getTotalFeeBPS() public view returns(uint){
        return  _updateFees();
    }

    function _updateFees() internal view returns(uint){
        return (marketingFeeBps + burnfeebps);
    }


    function setMarketingWallet(address wallet) public onlyOwner {
        address oldWallet = marketingWallet;
        require(wallet != oldWallet && wallet != address(0) && wallet != address(this), "Unvalid Wallet");
        
        isExcludedFromFees[oldWallet] = false;
        marketingWallet = wallet;
        isExcludedFromFees[wallet] = true;

        emit marketingWalletChanged( oldWallet,  wallet);

    }

    function getMarketingWallet() public view returns(address){
        return marketingWallet;
    }

    function setMarketingFees(uint256 feeBps) public onlyOwner {
        uint oldFee = marketingFeeBps;
        if((feeBps + burnfeebps) > feeLimit){
            revert("lR");
        }else{
            marketingFeeBps = feeBps;
            totalFeePercentage = _updateFees();

            emit marketingFeeChanged(oldFee, feeBps);
        }
    }

    function getMarketingFees() public view returns(uint){
        return marketingFeeBps;
    }

    function setSwapTokensAtAmount(uint256 amount) public onlyOwner {
        swapTokensAtAmount = amount;
    }

    function getSwapTokenAtAmount() public view returns(uint){
        return swapTokensAtAmount;
    }

    function setLpSwapRouter(address router) public onlyOwner {
        
        address oldRouter = address(lpSwapRouter);
        isExcludedFromFees[(oldRouter)]= false;

        decreaseAllowance((oldRouter), IERC20(address(this)).allowance(address(this), (oldRouter)));
        
        lpSwapRouter = IUniswapV2Router02(router);

        isExcludedFromFees[(router)]= true;

        emit routerChanged( oldRouter,  router);
    }

    function getRouter() public view returns(IUniswapV2Router02){
        return lpSwapRouter;
    }

    function setTokenLPPair(address _pair) public onlyOwner{
        address oldPair = pair;
        pair = _pair;

        emit pairChanged( oldPair,  _pair);
    }

    function getPair() public view returns(address){
        return pair;
    }

    function setBurnFee(uint256 feeBps) public onlyOwner {
        uint oldFee = burnfeebps;
        if((feeBps + marketingFeeBps) > feeLimit){
            revert("lR");
        }else{
            burnfeebps = feeBps;
            totalFeePercentage = _updateFees();

            emit burnFeeChanged(oldFee, feeBps);
        }
    }

    function getBurnFee() public view returns(uint){
        return burnfeebps;
    }

    function excludeFromFees(address account) public onlyOwner {
        
        isExcludedFromFees[account] = true;
        emit excludedFromFees( account);
    }

    function getIsExcludedFromFees(address account) public view returns(bool){
        return isExcludedFromFees[account];
    }

    function includeInFees(address account) public onlyOwner {
        isExcludedFromFees[account] = false;
        emit includedInFees( account);
    }

    function enableTrading() public onlyOwner {
        enabledTrading = true;
    }

    function isTradingEnabled() public view returns(bool){
        return enabledTrading;
    }

    function renounceOwnership() public onlyOwner override {
        isExcludedFromFees[owner()] = false;
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public onlyOwner override {
        isExcludedFromFees[owner()] = false;
        _transferOwnership(newOwner);
        isExcludedFromFees[newOwner] = true;
    }

   function burn(uint256 amount) public {
        address sender = _msgSender();
        if(isExcludedFromFees[sender]){
            _burn(sender, amount);
        }else{
            uint feetaken;
            feetaken += amount.mul(burnfeebps).div(10000);
            totalFees += feetaken;

            super._transfer(sender, address(this), feetaken);

            amount -= feetaken;

            _burn(sender, amount);

            if ((totalFees >= swapTokensAtAmount) && !inSwap) {
                swap(totalFees);
                totalFees = 0;
            }
        }
    }

  
}