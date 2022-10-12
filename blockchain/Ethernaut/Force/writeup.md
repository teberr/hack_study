https://teberr.notion.site/Ethernaut-Force-e3d68e5e88754190a259314b9282de5b

![Force.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4e79f09b-4d19-4b43-a595-47adcf80c7e7/Force.png)

> 이번 문제를 해결하기 위해서는
> 
> 1. 문제의 컨트랙트의 잔고를 0보다 크게 만들면 성공입니다.
> 
> 힌트는 다음과 같습니다.
> 
> - Fallback 함수
> - 가끔식 컨트랙트를 공격하는 가장 좋은 방법은 다른 컨트랙트로 공격하는 겁니다.

코드는 아래와 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Force {/*

                   MEOW ?
         /\_/\   /
    ____/ o o \
  /~____  =ø= /
 (______)__m_m)

*/}
```

# 코드 분석 및 공격 설계

이번 컨트랙트의 코드는 말 그대로 아무것도 없다. recieve 함수도, fallback 함수도 존재하지 않기에 이더를 전송받을 함수가 없어 Force 컨트랙트로 직접적으로 이더를 전송할 수 없다.  

하지만 솔리디티의 selfdestruct 함수를 이용하면 이러한 것을 우회할 수 있다.

![selfdestruct.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/006eb514-79ba-4a40-bffd-abf0d19fd749/selfdestruct.png)

selfdestruct(address payable recipient) 형태로 구성되는 함수이며 현재 컨트랙트를 파괴하고 이 컨트랙트에 있는 이더들을 recipient 주소로 보내는 함수이다. 

이 함수는 특징이 있는데

- 이더를 받는 쪽의 컨트랙트의 receive 함수가 실행되지 않는다. (이로 인해 receive 없어도 보내기가 됨)
- 파괴되는 컨트랙트는 트랜잭션이 완료될 때 삭제되기 때문에 트랜잭션이 revert된다면 컨트랙트는 파괴되지 않는다.

즉 이더를 소유하는 컨트랙트를 하나 생성한 후 이 컨트랙트를 selfdestruct를 호출하며 파괴하면서 문제의 Force 컨트랙트로 가지고 있는 이더를 전부 보내게 하면 receive함수가 없어도(실행되지 않아도) Force 컨트랙트는 이더를 받아서 가지게 된다. 

# 공격

먼저 문제 컨트랙트의 인스턴스를 생성한 후 컨트랙트의 주소를 보면 아래와 같다.

![컨트랙트 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c1a07981-59c6-430a-a4e3-733482b1fc84/%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_%EC%A3%BC%EC%86%8C.png)

```solidity
contract.address
'0xcEF6844f84A4f312A90898BC83AC34b67B74019A'
```

나만의 컨트랙트를 하나 생성하여 그 컨트랙트에 이더를 보낸 후 문제 컨트랙트의 인스턴스 주소로 가진 이더를 전부 보내도록 selfdestrut 함수를 실행시키면 된다.

![공격 컨트랙트.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/91da87eb-7940-476a-93af-2ec07373f3a1/%EA%B3%B5%EA%B2%A9_%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8.png)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
contract ForceAttack{

    function attack(address payable _recipient) public {
        selfdestruct(_recipient);
    }

    receive() external payable{

    }

}
```

따라서 공격 컨트랙트를 리믹스에서 작성해준다.

selfdestruct함수를 실행하기전 이 컨트랙트로 이더를 보내야 selfdestruct를 실행하며 문제 컨트랙트로 가진 이더를 보내므로 receive 함수를 추가하여 이더를 받을 수 있게 해주었다. (이더가 없으면 0개 보내니까!)

 attack 함수는 매개변수로 주소를 받아서 그 주소에게 자신의 컨트랙트를 파괴하며 이더를 보내는 selfdestruct 함수를 실행하는 함수이다. 

![컴파일.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3188506e-e85b-4694-8a98-b79dcf7602ed/%EC%BB%B4%ED%8C%8C%EC%9D%BC.png)

컴파일 해주고

![Deploy.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6f66bdf3-2c6c-40b8-9952-62261a5f2ba9/Deploy.png)

공격 컨트랙트를 배포해 준다.

![배포완료.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2b583dd2-32f9-478c-bcdc-934a446b600d/%EB%B0%B0%ED%8F%AC%EC%99%84%EB%A3%8C.png)

공격 컨트랙트를 배포해주고 나면 컨트랙트의 주소가 생성이 된다.

```solidity
'0x2075F96AcA194a78be819532497BdfFE6bbe3A88'
```

이 주소로 먼저 이더를 보내도록 하자

![내 컨트랙트로 보내기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3076464f-b8f0-44d4-9be6-4eada4cd93fa/%EB%82%B4_%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8%EB%A1%9C_%EB%B3%B4%EB%82%B4%EA%B8%B0.png)

![이더 도착.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1239e190-3366-48b6-b6d9-1d715bc9cf49/%EC%9D%B4%EB%8D%94_%EB%8F%84%EC%B0%A9.png)

내 컨트랙트로 이더를 보내고나면 배포된 컨트랙트 란에서 Balance가 바뀐걸 볼 수 있다.

![공격.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6bd50e9f-94b3-47a6-921c-703dadca4063/%EA%B3%B5%EA%B2%A9.png)

그리고 나면 이제 attack 함수를 실행시켜 내 공격 컨트랙트를 파괴하며 문제 컨트랙트의 인스턴스로 이더를 보내자.

![공격 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/90d8ec4c-b839-42a2-a0de-df59ce1188ba/%EA%B3%B5%EA%B2%A9_%EC%84%B1%EA%B3%B5.png)

이더를 보내고 나서 getBalance를 통해 문제 인스턴스의 주소에 이더가 들어있는지 확인해보면 의도한대로 들어가 있는 것을 확인할 수 있다.

![submit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1cca7c59-6e57-4571-b37c-32fd7c1829db/submit.png)

문제 목적을 달성했으므로 인스턴스를 제출하면

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1496149e-0488-440b-a69b-35a31d6452df/%EC%84%B1%EA%B3%B5.png)

성공했다는 글귀를 콘솔에서 확인할 수 있다.

# 문제 후기

솔리디티에서는 컨트랙트가 이더를 받기 위해서는 fallback함수가 payable로 명시되어 있어야 한다. 그러나 selfdestruct를 통해서 공격자가 이더를 보내는 것을 막을 방법이 없기 때문에 `address(this).balance == 0`과 같은 불변성에 의존하는 로직을 사용하지 않는 것이 중요하다.
