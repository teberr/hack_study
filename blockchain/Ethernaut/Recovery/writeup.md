https://teberr.notion.site/Ethernaut-Recovery-f5175c17f4cf40bfbd89a76a41fce249

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e21c4a1b-7212-414b-af2d-d3e66ecb2d1b/Untitled.png)

> 컨트랙트 제작자는 간단한 토큰 팩토리 컨트랙트를 만들었습니다. 누구나 쉽게 토큰을 만들 수 있습니다. 첫 토큰 컨트랙트를 deploy한 후 제작자는 더 많은 토큰을 얻기 위해 0.001 이더를 전송했습니다. 그리고 지금 토큰 컨트랙트의 주소를 잊었습니다.

이 문제에서는 잊어버린 컨트랙트 주소에서 0.001이더를 되찾거나 제거하면 성공입니다.
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Recovery {

  //generate tokens
  function generateToken(string memory _name, uint256 _initialSupply) public {
    new SimpleToken(_name, msg.sender, _initialSupply);
  
  }
}

contract SimpleToken {

  string public name;
  mapping (address => uint) public balances;

  // constructor
  constructor(string memory _name, address _creator, uint256 _initialSupply) {
    name = _name;
    balances[_creator] = _initialSupply;
  }

  // collect ether in return for tokens
  receive() external payable {
    balances[msg.sender] = msg.value * 10;
  }

  // allow transfers of tokens
  function transfer(address _to, uint _amount) public { 
    require(balances[msg.sender] >= _amount);
    balances[msg.sender] = balances[msg.sender] - _amount;
    balances[_to] = _amount;
  }

  // clean up after ourselves
  function destroy(address payable _to) public {
    selfdestruct(_to);
  }
}
```

# 코드 분석 및 공격 설계

```solidity
  // clean up after ourselves
  function destroy(address payable _to) public {
    selfdestruct(_to);
  }
```

먼저 문제에서 눈에 띄는 것은 destroy 함수이다. 

문제 성공 조건을 생각해보면 컨트랙트 제작자가 자신이 만든 SimpleToken 컨트랙트에 0.001 이더를 보내었고 이 0.001이더가 SimpleToken 컨트랙트에서 없어지게 하는 것이 성공조건이다. SimpleToken 컨트랙트의 함수들 중 유일하게 이더를 빼낼 수 있게 하는 함수는 destroy함수 뿐이며 이 함수는 public으로 공개 되어 외부에서 호출할 수 있다.

즉 public으로 공개되어있는 destroy함수를 호출하기만 하면 selfdestruct로 SimpleToken 컨트랙트가 사라지면서 문제 성공 조건을 만족하게 된다.

따라서 문제를 해결하기 위해서는 컨트랙트 제작자가 잊어버린 SimpleToken 컨트랙트의 주소만 알아내면 된다.

# 공격

인스턴스를 받아오며 문제를 진행해보자.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/23910e27-afed-4d89-b827-eafdbc22445a/Untitled.png)

```solidity
=> Level address
0xAF98ab8F2e2B24F42C661ed023237f5B7acAB048
=> Player address
0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a
=> Ethernaut address
0xa3e7317E591D5A0F1c605be1b3aC4D2ae56104d6
=> Instance address
0x31E448f46E69AEa6e5B7771D4A1df44D8791Db7E
```

인스턴스를 받아오면 직접적으로 상호작용할 수 있는 컨트랙가 무엇인지 알기 위해 abi로 호출할 수 있는 함수 이름을 확인해 보았다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a2ef3b24-d6b6-4b52-8a74-bc5f3a71f431/Untitled.png)

```solidity
await contract.abi
[{…}]
	0: {inputs: Array(2), name: 'generateToken', outputs: Array(0), stateMutability: 'nonpayable', type: 'function', …}
	length: 1
	[[Prototype]]: Array(0)
```

인스턴스로 받아온 주소는 Recovery 컨트랙트이다. Recovery 컨트랙트의 경우 사용할 수 있는 함수가 generateToken밖에 존재하지 않고 이는 기존의 컨트랙트 제작자가 만든 SimpleToken의 주소를 파악하는데 직관적인 방법이 없다.

그래서 든 생각은 두 가지인데

1.  generateToken을 여러번 실행시켜 보면서 생성되는 주소의 패턴을 알아내어 컨트랙트 제작자가 생성한 첫 SimpleToken의 주소를 유추하기
2. Recovery 컨트랙트 주소를 알고있으므로 이더스캔에서 Recovery 컨트랙트 주소를 검색해 컨트랙트 제작자가 이 Recovery 컨트랙트 주소에서 만든 SimpleToken의 주소를 찾기

1번은 패턴이 찾아진다는 보장도 없고 2번이 훨씬 간단할 것 같아서 2번으로 진행했다.

![sepolia 이더스캔.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cda1651c-cc09-4252-b160-067db6835ba8/sepolia_%EC%9D%B4%EB%8D%94%EC%8A%A4%EC%BA%94.png)

[https://sepolia.etherscan.io/](https://sepolia.etherscan.io/) 

현재 이더넛 문제를 Sepolia Testnet 에서 진행중이므로 Sepolia 이더스캔으로 접속했다.

인스턴스의 주소(`0x31E448f46E69AEa6e5B7771D4A1df44D8791Db7E`)를 검색해보니 내부 트랜잭션으로 두 개를 확인할 수 있다. 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3b64cac0-b159-4cc5-8da6-66911229cc3f/Untitled.png)

트랜잭션의 From 주소를 확인해 보면 두 개가 있다.

1. 0x31e4…
2. 0xaf98… 

 여기서 0xaf98..은 level address로 Recovery 인스턴스를 생성한 트랜잭션이다(처음 참고). 따라서 컨트랙트 제작자가 이 인스턴스에서 SimpleToken 컨트랙트를 생성하게된 트랜잭션은 From 주소가 0x31e4… 인 트랜잭션으로 보인다. 따라서 생성된 To 주소의 Contract Creation 링크를 눌러 트랜잭션을 따라가보자.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cb8f66d6-e299-487a-87b8-b0a96c543526/Untitled.png)

컨트랙트 주소 **0x02cb6E52803d8E380b644E2bA95DFDdC1e31C4Ff** 가 생성되었고 0.001 이더를 받은 것을 확인할 수 있다. 

문제에서 설명한 컨트랙트 제작자가 보냈다던 0.001이더가 이 컨트랙트임이 거의 분명해졌다. 따라서 이 컨트랙트 주소의 destroy 함수를 실행시키는 코드를 작성하여 공격하자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISimpleToken{
    function destroy(address) external;
}
contract RecoveryAttack{
    address public target = 0x02cb6E52803d8E380b644E2bA95DFDdC1e31C4Ff;
    function attack()public{
        ISimpleToken(target).destroy(msg.sender);
    }
}
```

SimpleToken 컨트랙트의 destroy 함수를 이용하여 selfdestruct를 내 메타마스크 주소로 이더를 보내면서 실행하도록 하였다.

![실행 전.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d6fe3016-41ab-4443-a430-6111c6ef654f/%EC%8B%A4%ED%96%89_%EC%A0%84.png)

공격 전 2.5742 SepoliaETH을 보유하고 있었는데

![실행 후.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/639402ba-1564-4c45-a330-ab0884b86068/%EC%8B%A4%ED%96%89_%ED%9B%84.png)

공격 후 2.5752 SeploiaETH로 0.001이더가 늘면서 공격이 제대로 성공했음을 느꼈다. 문제 성공 조건을 충족하였으므로 인스턴스를 제출하면 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0a0e29b1-0653-419d-865a-1ce287d7827b/Untitled.png)

# 문제 후기

컨트랙트 주소는 결정적이고 `keccak256(address, nonce)` 에 의해서 계산된다. 이 때 address는 컨트랙트의 주소(또는 트랜잭션을 발생시킨 이더리움 주소)이고 nonce는 파생된 컨트랙트가 만든 컨트랙트의 수(혹은 일반적인 트랜잭션의 경우 트랜잭션 nonce)가 된다.

이 때문에 개인키가 아직 존재하지 않는 미리 결정된 주소로 이더를 먼저 보내고 나중에 이더를 복구하는 컨트랙트를 만들 수 있다.(아직 주소가 확정나기전에 미리 만들어지기로 예측되는 주소로 이더를 보낸 후 이더 복구)

이는 개인키를 보유하지 않고 이더를 저장하는 비직관적이고 위험한 방법이다.

Martin Swende는 이에 대한 가능성있는 용례를 [blog post](https://swende.se/blog/Ethereum_quirks_and_vulns.html)에 올려놓았다.

만약 이 기술을 사용하기 위해서는 nonce 값을 놓치면 안된다. 그러면 이더를 영구적으로 잃어버릴 수도 있다..

문제를 풀고 나오는 글귀를 해석해보니 이더스캔으로 푸는 내 방법이 의도했던 방법이 아니었던듯 하다… 하여튼 주소가 결정되기 전에 미리 예측되는 주소에 이더를 보내는 방법은 상당히 위험한 방법으로 다른 사람이 이를 캐치하여 그 주소로 만들어 버리게 된다면 보낸 이더는 전부 빼앗기게 되므로 이더를 미리 보내는 것은 지양하는 것이 좋다.
