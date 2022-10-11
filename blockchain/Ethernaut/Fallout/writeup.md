https://teberr.notion.site/Ethernaut-FALLOUT-f36f7be4e5de4f47a9d42ba58e07f78a

![fallout.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/77be0995-9035-4759-9f6b-09b7170a4489/fallout.png)

> 
> 
> 
> 이번 문제를 해결하기 위해서는
> 
> 1. 컨트랙트의 ownership 권한을 획득해야합니다.
> 
> 힌트
> 
> - Remix IDE를 사용해보세요.

코드는 아래와 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract Fallout {
  
  using SafeMath for uint256;
  mapping (address => uint) allocations;
  address payable public owner;

  /* constructor */
  function Fal1out() public payable {
    owner = msg.sender; // owner는 이 컨트랙트의 인스턴스를 만든 주소가 owner임
    allocations[owner] = msg.value; // owner가 인스턴스를 만들 때 보낸 값을 allocations에 owner의 주소와 매핑 
  }

  modifier onlyOwner { //모디파이어
	        require(
	            msg.sender == owner, // 요청한 주소가 owner 여야함.
	            "caller is not the owner"
	        );
	        _;
	    }

  function allocate() public payable { 
    allocations[msg.sender] = allocations[msg.sender].add(msg.value);
  } // 호출자의 주소와 매핑된 값에 같이 보내준 이더를 더함.

  function sendAllocation(address payable allocator) public { //주소를 매개변수로 받음
    require(allocations[allocator] > 0); // allocations[주소] 가 0보다 커야함
    allocator.transfer(allocations[allocator]); //allocations[파라미터]를 allocation 주소로 보냄.
  } //이 컨트랙트에 저장되어있는 allocator(주소)에 매핑된 이더를 allocator에 보냄.

  function collectAllocations() public onlyOwner {// owner만 호출 가능함
    msg.sender.transfer(address(this).balance); // 호출자에게 이 컨트랙트의 balance(자산)을 전부 보냄
  }

  function allocatorBalance(address allocator) public view returns (uint) {
    return allocations[allocator]; // 매개변수로 준 allocator 주소에 들어있는 값을 보여줌.
  }
}
```

# 코드 분석 및 공격 설계

이번 문제의 목적은 컨트랙트의 ownership 권한을 획득하는 것이다. 그런데 이 문제에서 owner의 값을 조절하는 함수는 Fal1out() 함수밖에 없다. 

처음에 Fal1out() 함수를 보고 처음에 헷갈렸던게 솔리디티 구버전에서는 constructor 생성자를 만들때 함수 이름을 컨트랙트 이름이랑 똑같이 만들었었고 주석으로도 constructor라고 써져있어서 생성자로 생각했다.

```solidity
  /* constructor */
  function Fal1out() public payable {
    owner = msg.sender; // owner는 이 컨트랙트의 인스턴스를 만든 주소가 owner임
    allocations[owner] = msg.value; // owner가 인스턴스를 만들 때 보낸 값을 allocations에 owner의 주소와 매핑 
  }
```

하지만 실제로는 이름도 컨트랙트와 같지 않았고 솔리디티 버전도 0.6.0으로 생성자는 constructor()로 써주는 버전이므로 이 함수는 constructor가 아니었다. 즉 이 Fal1out 함수를 사용자가 이더를 보내면서 호출하면 사용자가 owner가 되고 이 컨트랙트의 allocations에 owner로 보낸 값을 매핑해준다.

이 Fal1out 함수를 사용자가 호출하면 owner로 변할 것이다.

# 익스플로잇

![시작.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5453e84f-f198-463e-b1b2-1fecc8aaf47c/%EC%8B%9C%EC%9E%91.png)

먼저 인스턴스를 생성해주자 Get new instance를 눌러주면 메타마스크에서 트랜잭션 허용을 해달라는 창이 뜨고 트랜잭션을 허용해 주면 인스턴스가 생성된다.

![인스턴스 생성.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1fe4e3fb-9525-4226-a7b0-26c9f2d463d0/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%83%9D%EC%84%B1.png)

Fallout 인스턴스가 생성되었으므로 Fal1out함수를 호출하여 owner 권한을 획득하자.

```solidity
await contract.Fal1out.sendTransaction({value:toWei('0.0001')})
```

![sendTransaction.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9e41c0d0-cbe7-4fe1-b526-482ac28571c2/sendTransaction.png)

그러면 메타마스크에서 트랜잭션을 허용해달라는 창이 뜨고 확인을 누른다. 트랜잭션이 컨펌될때 까지 기다린다.

```solidity
await contract.owner()
'0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
```

그리고나서 contract의 owner를 호출해보면 내 메타마스크 지갑으로 변경되어있음을 알 수 있다. 이번 문제의 목적인 owner 권한을 얻었으므로 submit instance를 통해 제출해준다.

![submit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ccfe3800-42a9-4403-b4ad-708c7c9c30b8/submit.png)

submit instance를 하고나면 트랜잭션 확인이 뜨고 트랜잭션을 제출하고나면

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3d7b4f7c-19a5-4af5-926d-bb40f7b5406a/%EC%84%B1%EA%B3%B5.png)

개발자도구 콘솔에서 성공했다고 뜬다.
