https://teberr.notion.site/Ethernaut-Hello-Ethernaut-3443e2370b624c5a94a054a1379c6d9e

![Hello Ethernaut.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9eee8e36-be34-4888-bf8f-57c0fe674856/Hello_Ethernaut.png)

Ethernaut에서 튜토리얼의 개념으로 가장 낮은 난이도를 가지고 있는 Hello Ethernaut 문제이다. 

문제의 의도는 게임을 플레이하는 기본적인 방법을 가이드와 함께 문제 형태로 직접 실습하며 익힐 수 있도록 하는 것이다. 그래서 가이드만 따라서 가도 문제가 풀릴 정도로 설명도 되게 자세하게 나와있다. 

# 문제 풀이 가이드

## 1. 메타마스크 설치

문제 진행을 위해서는 메타마스크 지갑이 필요하므로 없으면 메타마스크를 설치해주고 실제 메인넷에서 하게 되면 가스비(수수료)가 많이 나오기 때문에 테스트 네트워크에서 진행한다. 테스트 네트워크 중에서는 Rinkeby 테스트 네트워크를 선택해준다. 만약 메타마스크 지갑에서 테스트 네트워크가 보이지 않는다면 [테스트 네트워크 설정하기](https://www.notion.so/cce2a3580d994c5fba335a1667d4f211) 를 참고해서 설정해준 후 수수료로 쓸 이더도 어느 정도 챙겨 놓는다.

## 2. 개발자 도구를 이용해서 문제 풀이

F12를 이용해서 개발자 도구를 켜주면 게임과 관련된 메시지가 콘솔창에 뜬다. 

![가이드 2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1b17f058-8f02-432e-ae2b-acff1cfeaab9/%EA%B0%80%EC%9D%B4%EB%93%9C_2.png)

그리고 player 를 입력해주면 지금 Ethernaut에 연결된 내 메타마스크 주소(플레이어)를 볼 수 있다. 

![내 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/82269160-34b5-446a-9f9e-b83d06dfc810/%EB%82%B4_%EC%A3%BC%EC%86%8C.png)

![내 메타마스크주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/22227c96-6f57-4f56-8796-d969cc6a5d99/%EB%82%B4_%EB%A9%94%ED%83%80%EB%A7%88%EC%8A%A4%ED%81%AC%EC%A3%BC%EC%86%8C.png)

게임 플레이 중에 경고나 에러가 큰 힌트가 되기 때문에 경고나 에러를 유의깊게 봐야 한다.

## 3. help()함수를 이용하기

콘솔에서 getBalance(player)를 입력하면 Player 주소에서 이더가 얼마나 있는지 알 수 있다.

 

![getBalance.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c1c29f88-9011-4582-90e6-8e8f9d3ef3da/getBalance.png)

만약 위 사진에서와 같이 Promise가 나온다면 await getBalance(Player)로 await를 이용해주면 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/349d7523-56bd-459c-9b99-571da8ed7532/Untitled.png)

이외에도 help()함수를 통해서 내가 사용할 수 있는 유틸리티 함수들을 볼 수 있다.

![help.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d292118b-89ad-46ab-a0ac-6d34582b0c6d/help.png)

## 4. ethernaut 컨트랙트

console 에서 ethernaut을 입력하면 문제에서 사용되는 메인 스마트 컨트랙트를 볼 수 있다. 콘솔을 통해서 직접 상호 작용 해도 되지만 앱에서 자동으로 해주기 때문에 굳이 ㅎ..

## 5. ABI를 통해서 상호작용

ethernaut은 트러플(Truffle)컨트랙트객체로 ethernaut.sol 파일로 블록체인에 배포되어 있다.

이렇게 배포되어 있는 ethernaut.sol 파일의 public 함수에 접근하기 위해서는 ABI를 이용해야 하는데 그 중 대표적인 것이 owner이다.  await ethernaut.owner()를 통해서 ethernaut 컨트랙트 owner의 주소를 알 수 있다.

![ethernaut owner.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fded32fd-b733-4a95-9f1a-7371cf443fac/ethernaut_owner.png)

 

## 6. 테스트를 위한 가상 이더 얻기

문제를 풀기 위해서는 가스비(수수료)가 필요하다 이미 [https://faucets.chain.link/rinkeby](https://faucets.chain.link/rinkeby) 에서 메타마스크 지갑에 이더를 내 메타마스크 지갑에 넣어놓았다면 상관이 없지만 안넣었다면 저 사이트에서 내 메타마스크 지갑에 수수료로 쓸 이더를 넣어둬야 문제를 진행할 수 있다.

0.1이더가 감질맛난다면 [https://faucet.metamask.io/](https://faucet.metamask.io/) 에서 잔뜩 받아놔도 상관은 없다(어차피 가짜라서)

## 7. 문제 인스턴스 얻기

문제를 풀기 위해서는 문제 인스턴스를 얻어야 한다. 근데 이 때 새로운 인스턴스를 생성할 때 수수료가 들기 때문에 가상 이더가 필요하다. 문제 인스턴스를 새롭게 만들기 위해서는 문제 하단에 있는 get new Instance 버튼을 클릭해 주면 된다.

![get new Instance.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a203c9e6-0d0e-4f11-a30b-b15ca61d7966/get_new_Instance.png)

그러면 연결된 메타마스크에서 트랜잭션을 허용할 것인지 여부가 뜬다. 당연히 새로운 인스턴스를 만들것이기 때문에 허용해준다.

![get new ins2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bf05906d-a9fb-4095-8306-bf3b5f648986/get_new_ins2.png)

트랜잭션을 허용해 주고 나면 새 컨트랙트를 배포하기 때문에 시간이 조금 걸려서 콘솔에서 잠시 기다리라고 뜨고 조금 기다리면 인스턴스가 생성되었음과 동시에 인스턴스의 주소를 알려준다.

![인스턴스 생성.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a509ad1b-60dd-47c2-8ecc-c3a542a7896d/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%83%9D%EC%84%B1.png)

## 8. 컨트랙트 확인하기

ethernaut 컨트랙트는 ABI를 통해서 public 함수들을 호출할 수 있다고 했다. 이 public 함수들의 목록을 알기위해서는 콘솔에서 contract를 입력해주면 public 함수들을 확인할 수 있다.

![ABI 목록.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9f96a4fb-b8eb-4e34-bd31-49f6d01c443e/ABI_%EB%AA%A9%EB%A1%9D.png)

## 9. 문제를 풀고나서

각 문제 레벨별로 내가 무엇을 해야하는지(목표) await contract.info()에 담겨있다. 

![contract info.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/03a5c6d6-bcdc-4958-8db1-3531c780f65d/contract_info.png)

문제를 해결하고 나서는 하단의 Submit Instance를 통해서 인스턴스를 완료했음을 검증하면 다음 단계로 넘어갈 수 있다.

 

![제출.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5f4e698d-c79f-4e4e-9309-3c857086e413/%EC%A0%9C%EC%B6%9C.png)

## 팁 : 컨트랙트의 ABI를 계속해서 확인해야 함

# 문제 풀이

이제 문제에대한 가이드와 함께 인스턴스도 생성하고 abi 목록도 확인 하였으며 문제 풀이 목적인 contract.info()를 따라가면서 문제를 해결하자. 

```jsx
await contract.info()
'You will find what you need in info1().'
```

[contract.info](http://contract.info) (문제 목적)을 컨트랙트에 요구하자 info1()에서 무엇이 필요한지 찾아야 한다고 한다.

다시 ABI 목록을 확인해보면

```jsx
abi: 
	Array(11)
		0:{inputs: Array(1), stateMutability: 'nonpayable', type: 'constructor', constant: undefined, payable: undefined}
		1:{inputs: Array(1), name: 'authenticate', outputs: Array(0), stateMutability: 'nonpayable', type: 'function', …}
		2:{inputs: Array(0), name: 'getCleared', outputs: Array(1), stateMutability: 'view', type: 'function', …}
		3:{inputs: Array(0), name: 'info', outputs: Array(1), stateMutability: 'pure', type: 'function', …}
		4:{inputs: Array(0), name: 'info1', outputs: Array(1), stateMutability: 'pure', type: 'function', …}
		5:{inputs: Array(1), name: 'info2', outputs: Array(1), stateMutability: 'pure', type: 'function', …}
		6:{inputs: Array(0), name: 'info42', outputs: Array(1), stateMutability: 'pure', type: 'function', …}
		7:{inputs: Array(0), name: 'infoNum', outputs: Array(1), stateMutability: 'view', type: 'function', …}
		8:{inputs: Array(0), name: 'method7123949', outputs: Array(1), stateMutability: 'pure', type: 'function', …}
		9:{inputs: Array(0), name: 'password', outputs: Array(1), stateMutability: 'view', type: 'function', …}
		10:{inputs: Array(0), name: 'theMethodName', outputs: Array(1), stateMutability: 'view', type: 'function', …}
```

info1이 abi에 존재하고 inputs(매개변수)의 개수가 Array(0)인것을 보아 매개변수 없이 바로 호출하면 될 것으로 보인다. 

stateMutability가 view나 pure인 것은 

- View : function 밖의 변수들을 읽을 수 있으나 변경은 불가능
- pure : function 밖의 변수들을 읽지도 못하고 변경도 불가능

의 차이인데 함수 실행을 시키는 것이 목적이므로 여기서는 크게 중요하지 않다.

그럼 await contract.info1()로 info1 함수를 실행해보자.

```jsx
await contract.info1()
'Try info2(), but with "hello" as a parameter.'
```

info2함수를 실행하되 매개변수로 “hello”문자열을 넣어주라고 한다. 

5:{inputs: Array(1), name: 'info2', outputs: Array(1), stateMutability: 'pure', type: 'function', …}

실제로 abi에서 5번째 줄인 info2는 inputs: Array(1)로 매개변수가 하나 필요한데 그 값이 “hello”임을 알 수 있다.

그럼 await contract.info2(”hello”)로 info2 함수를 실행해보자.

```jsx
await contract.info2("hello")
'The property infoNum holds the number of the next info method to call.'
```

infoNum 의 프로퍼티가 다음에 호출해야 할 info 함수의 숫자를 가지고 있다고 한다.

infoNum 함수는 ABI의 7번째에서 찾을 수 있다. 

7:{inputs: Array(0), name: 'infoNum', outputs: Array(1), stateMutability: 'view', type: 'function', …}

inputs:Array(0)인 것을 보아 매개변수가 없어 바로 호출하면 된다.

그럼 await contract.infoNum()을 통해 infoNum()함수를 실행해보자. 

```jsx
await contract.infoNum()
o {negative: 0, words: Array(2), length: 1, red: null}
	length:1
	negative:0
	red:null
	words:Array(2)
		0:42
		length:2
		[[Prototype]]:Array(0)
	[[Prototype]]:Object
```

이 infoNum의 프로퍼티중 words의 첫번째 프로퍼티가 42임을 알 수 있다. 즉 info2다음에 실행해야할 info 함수의 숫자는 info42이다. 

6:{inputs: Array(0), name: 'info42', outputs: Array(1), stateMutability: 'pure', type: 'function', …}

info42또한 매개변수가 존재하지 않으므로 contract.info42()로 바로 실행시켜준다.

```jsx
await contract.info42()
'theMethodName is the name of the next method.'
```

theMethodName이 다음 함수라고 하는데 이또한 ABI에 존재한다.

10:{inputs: Array(0), name: 'theMethodName', outputs: Array(1), stateMutability: 'view', type: 'function', …}

마찬가지로 입력값 매개변수가 없으므로 바로 contract.theMethodName()으로 호출해준다.

```jsx
await contract.theMethodName()
'The method name is method7123949.'
```

아.. method7123949를 실행시키라는 뜻이다.

8:{inputs: Array(0), name: 'method7123949', outputs: Array(1), stateMutability: 'pure', type: 'function', …}
이 또한 입력값 매개변수가 없으므로 contract.method7123949()로 호출해준다.

```jsx
await contract.method7123949()
'If you know the password, submit it to authenticate().'
```

패스워드를 안다면 authenticate함수에 제출하라고 한다. 패스워드 함수는 ABI 9번째에서 찾을 수 있다.

9:{inputs: Array(0), name: 'password', outputs: Array(1), stateMutability: 'view', type: 'function', …}

입력값 매개변수 없이 호출하면 하나 리턴해주는 것이 아마 패스워드 값을 리턴해 주는 것 같다.

authenticate 함수 또한 ABI 1번째에서 찾을 수 있다.

1:{inputs: Array(1), name: 'authenticate', outputs: Array(0), stateMutability: 'nonpayable', type: 'function', …}

입력값 매개변수 하나가 필요한데 contract.method7123949()의 결과값으로 우리는 이 매개변수 값이 password임을 알 수 있다. 

즉 contract.password()를 통해 패스워드를 알아내서 contract.authenticate(password)로 제출하면 끝이다.

```jsx
await contract.password()
'ethernaut0'
```

패스워드는 ethernaut0이다.

이제 이 패스워드를 매개변수로 넣어 authenticate 함수를 호출해주자.

```jsx
await contract.authenticate('ethernaut0')
```

그러면 메타마스크가 열리면서 트랜잭션을 허용해 달라는 창이 뜬다.

![authenticate.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2e94e2f8-66cd-44da-bc3a-d76e3d3347ae/authenticate.png)

이 트랜잭션을 허용해주고 나면 콘솔창에 다음과 같이 트랜잭션이 완료되었다고 뜬다.

![auth.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b8c478fd-ee67-4567-86a6-6f6b8a18861b/auth.png)

추가적으로 더 나오는 것이 없으므로 contract.info(목표)를 따라서 끝까지 진행한 것 같아 하단의 submit instance로 완료했는지 검증을 요청했다. submit instance 버튼을 누르면 메타마스크가 열리면서 트랜잭션 허용을 요구한다.

![submit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/047da1f5-0716-4d46-89d2-bfa3a42895eb/submit.png)

왜냐하면 블록체인 상에 내 메타마스크 지갑이 이 hello ehternaut을 풀었는지 기록을 할 것이기 때문에 트랜잭션이 발생하기 때문에 이 과정을 거쳐야 한다. 트랜잭션을 허용하고 잠시 기다리면

 

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/58bbf5be-64cf-4d8d-b679-a99ef82c832a/%EC%84%B1%EA%B3%B5.png)

단계를 클리어 했다는 내용이 콘솔창에 뜨며 페이지는 Hello Ethernaut의 스마트 컨트랙트 코드를 보여준다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Instance {

  string public password;
  uint8 public infoNum = 42;
  string public theMethodName = 'The method name is method7123949.';
  bool private cleared = false;

  // constructor
  constructor(string memory _password) public {
    password = _password;
  }

  function info() public pure returns (string memory) {
    return 'You will find what you need in info1().';
  }

  function info1() public pure returns (string memory) {
    return 'Try info2(), but with "hello" as a parameter.';
  }

  function info2(string memory param) public pure returns (string memory) {
    if(keccak256(abi.encodePacked(param)) == keccak256(abi.encodePacked('hello'))) {
      return 'The property infoNum holds the number of the next info method to call.';
    }
    return 'Wrong parameter.';
  }

  function info42() public pure returns (string memory) {
    return 'theMethodName is the name of the next method.';
  }

  function method7123949() public pure returns (string memory) {
    return 'If you know the password, submit it to authenticate().';
  }

  function authenticate(string memory passkey) public {
    if(keccak256(abi.encodePacked(passkey)) == keccak256(abi.encodePacked(password))) {
      cleared = true;
    }
  }

  function getCleared() public view returns (bool) {
    return cleared;
  }
}
```

클리어!
