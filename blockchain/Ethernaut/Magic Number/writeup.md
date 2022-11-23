https://teberr.notion.site/Ethernaut-MagicNumber-80a7af71b7724415aac2579f0d8853d4

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/948cffa4-823d-41fe-bad1-e287520a1cbe/Untitled.png)

> 이 단계를 클리어하기 위해서는 whatIsTheMeaningOfLife() 함수를 호추하면 알맞은 숫자로 응답해주는 컨트랙트를 만들어야 합니다.

너무 간단하다구요? 하지만 만들어야할 컨트랙트 코드는 매우 매우 작아야 합니다. 아무리 커도 10 opcode 내로 만들어야 합니다.

이 문제에서는 솔리디티 컴파일러의 편의성에서 잠깐 벗어나 직접 EVM bytecode로 작성하는 것이 좋을겁니다. 행운을 빕니다.

솔리디티 컨트랙트 분해 설명 시리즈 : 
- [https://blog.openzeppelin.com/deconstructing-a-solidity-contract-part-i-introduction-832efd2d7737/](https://blog.openzeppelin.com/deconstructing-a-solidity-contract-part-i-introduction-832efd2d7737/)
- [https://blog.openzeppelin.com/deconstructing-a-solidity-contract-part-ii-creation-vs-runtime-6b9d60ecb44c/](https://blog.openzeppelin.com/deconstructing-a-solidity-contract-part-ii-creation-vs-runtime-6b9d60ecb44c/) (초기화 OPCODE, Creation, runtime)
- [https://dev.to/nvn/ethernaut-hacks-level-18-magic-number-27ep](https://dev.to/nvn/ethernaut-hacks-level-18-magic-number-27ep)
- [https://medium.com/@blockchain101/solidity-bytecode-and-opcode-basics-672e9b1a88c2](https://medium.com/@blockchain101/solidity-bytecode-and-opcode-basics-672e9b1a88c2)
-[https://medium.com/coinmonks/ethernaut-lvl-19-magicnumber-walkthrough-how-to-deploy-contracts-using-raw-assembly-opcodes-c50edb0f71a2](https://medium.com/coinmonks/ethernaut-lvl-19-magicnumber-walkthrough-how-to-deploy-contracts-using-raw-assembly-opcodes-c50edb0f71a2)
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MagicNum {

  address public solver;

  constructor() {}

  function setSolver(address _solver) public {
    solver = _solver;
  }

  /*
    ____________/\\\_______/\\\\\\\\\_____        
     __________/\\\\\_____/\\\///////\\\___       
      ________/\\\/\\\____\///______\//\\\__      
       ______/\\\/\/\\\______________/\\\/___     
        ____/\\\/__\/\\\___________/\\\//_____    
         __/\\\\\\\\\\\\\\\\_____/\\\//________   
          _\///////////\\\//____/\\\/___________  
           ___________\/\\\_____/\\\\\\\\\\\\\\\_ 
            ___________\///_____\///////////////__
  */
}
```

### WhatIsTheMeaningOfLife()

문제만 읽고 어떤 값을 리턴해야 하는지 정확하게는 모르지만 주석으로 그려져있는 숫자는 42이다. 그래서 구글에 `What Is the Meaning Of Life`를 검색을 해봤는데 

![what is the meaning of life.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d0cc3894-d3fc-4392-b5d1-2576ca9a1fc1/what_is_the_meaning_of_life.png)

삶의 의미라는 뜻과 함께 42라는 이미지가 보인다. 아마 이 함수의 리턴 값은 42이면 되는것 같다.

# 코드 분석 및 공격 설계

```solidity
  address public solver;

  constructor() {}

  function setSolver(address _solver) public {
    solver = _solver;
  }

```

solver에 내가 만든 컨트랙트 주소를 넣어주면 되는 것 같다.

이 때 내가 만든 컨트랙트는

1. opcode가 최대 10개일 정도로 작은 컨트랙트여야 하고
2. 리턴값은 42(0x2a)여야 한다.

컨트랙트를 만드는 과정을 살펴보기 위해서는 EVM의 구조를 먼저 알아야한다.

### EVM (이더리움 가상 머신)

이더리움 스마트 컨트랙트의 ByteCode를 실행하는 32바이트 스택 기반의 실행환경으로 스택의 최대 크기는 1024바이트이다. 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/887a04b4-f0a9-4296-bcb7-735dea193a05/Untitled.png)

이더리움의 각 노드는 EVM을 포함하고 있으며 EVM을 통해 ByteCode를 OPCODE로 변환후 내부에서 실행한다.

EVM은 메모리에 바이트 배열 형태로 스택의 항목들을 저장한다. EVM은 ByteCode를 내부 OPCODE로 변환하여 재해석한다. 즉 Solidity로 작성한 컨트랙트를 컴파일 후 생성되는 ByteCode를 EVM에서 OPCODE로 치환되어 실행한다는 의미이다.

EVM의 특징으로는 4바이트와 8바이트 워드는 크기가 너무 작아 비효율적이기 때문에 32바이트 워드 크기를 지원한다. 즉 하나의 슬롯이 32바이트인 이유이다. 

### ByteCode로 컨트랙트가 생성되는 과정

이제 이 EVM이 ByteCode를 어떻게 해석하여 컨트랙트를 생성하는지 살펴보자.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1642a712-e2d7-46a2-90a1-cdb5cbe17444/Untitled.png)

1. Solidity로 작성한 코드(data)를 바탕으로 계정에서 컨트랙트를 생성하는 트랜잭션을 발생시킨다.
2. EVM 컴파일러가 코드를 byteCode로 바꾼다. (data가 아예 바이트코드로 전달되어도 됨)
3. ByteCode가 stack에 담기고 이 ByteCode는 initialization부분과 runtime부분으로 나뉜다.
    1. Initialization → EVM은 스택에서 STOP이나 Return을 만날 때 까지 계속해서 초기화 코드만 실행한다. solidity 언어기준 constructor()가 실행되어 컨트랙트의 초기상태를 설정하고 컨트랙트의 주소가 생성되며 메모리에 복사한 런타임 코드의 복사본을 반환한다. 
    2. runtime → 초기화 코드가 실행되면 런타임 코드만이 스택에 남아있게된다. 이 런타임 코드는 실제로 실행될 로직 코드이다. 
4. EVM은 리턴된 남은 코드를 새로운 컨트랙트 주소와 관련하여 State Storage에 저장한다. 이는 향후 컨트랙트에 대한 모든 호출에서 스택에 의해 실행될 런타임 코드이다. (EVM에서 자동으로 이루어짐)

따라서 opcode가 최대 10개여야 할 정도로 작은 컨트랙트라는 의미는 이 EVM에 반환된 runtime byteCode 부분이 opcode 10개로 이루어져 있어야 한다는 의미이다.

EVM에서 4번 단계는 자동으로 이루어지므로 우리는 3번 단계의 ByteCode를 작성해야 한다.

따라서 다음과 같이 ByteCode를 작성해야 한다.

1. Initialization 단계 → 컨트랙트 생성 및 초기화, runtime 코드를 메모리에 복사후 메모리를 리턴한다.
2. runtime 코드 → 42(0x2a)를 리턴하되 10개의 opcode 이내로 작성되어야한다. 

# 공격

[https://solidity-kr.readthedocs.io/ko/latest/assembly.html](https://solidity-kr.readthedocs.io/ko/latest/assembly.html) 

[https://ethereum.org/en/developers/docs/evm/opcodes/](https://ethereum.org/en/developers/docs/evm/opcodes/) 

두 사이트에 있는 Instruction을 토대로 opcode 를 작성하자.

## ByteCode의 runtime 부분

먼저 문제의 목적인 42(0x2a)를 리턴하는 runtime 부분을 먼저 작성하자. 

- return(ost, len) → 메모리 위치 ost부터 크기 len 만큼을 가져와 반환해준다.

| Stack(OPCode) | Name | Gas | Initial Stack(Parameter) | 최종 Stack | Notes |
| --- | --- | --- | --- | --- | --- |
| F3 | RETURN | 0* | ost, len | . | return mem[ost:ost+len-1] |

이를 OPCODE로 작성해주려면 단순히 F3이지만 이때 스택에는 0x2a(42)가 들어가 있는 메모리 위치와 이 0x2a(42)가 저장된 크기가 스택에 있어야 한다.

즉 메모리에 이미 0x2a가 저장되어 있어야 하므로 이를 위한 OPCODE가 필요하다.

- mstore (ost,val) → 메모리 위치 ost에 값 val을 저장한다.

| Stack(OPCode) | Name | Gas | Initial Stack(Parameter) | 최종 Stack | Notes |
| --- | --- | --- | --- | --- | --- |
| 52 | MSTORE | 3* | ost, val | . | write a word to memory |

sstore는 상태변수이므로 메모리에 저장하는 mstore를 사용하는 것이 맞다. 

스택에 매개변수들을 넣어줘야 하므로 스택에 값을 넣어주는 OPCODE인 PUSH 또한 필요하다.

| Stack(OPCode) | Name | Gas | Initial Stack(Parameter) | 최종 Stack | Notes |
| --- | --- | --- | --- | --- | --- |
| 60 | PUSH1 | 3 | . | uint8 | push 1-byte value onto stack |

정리하면 runtime 코드는 다음과 같다.

1. mstore (ost,0x2a)
2. return (ost,0x20)

이를 조금 더 상세하게 하면

1. PUSH1 0x2a
2. PUSH1 ost
3. mstore
4. PUSH1 0x20
5. PUSH1 ost
6. return

이 된다. 이 때 매개 변수 중 뒤의 것을 먼저 넣어주는 이유는 스택의 구조 때문인데 스택은 FILO 형식으로 마지막으로 넣은 것이 POP으로 가장 먼저 나오기 때문에 0x2a, ost 순서로 넣어주면 나올때는 ost,0x2a로 나와서 실행하기 때문이다.

ost는 0x2a를 저장할 임의의 위치인데 메모리에는 opcode가 복사되어 있어야 하는 공간이 필요하므로 앞부분은 넉넉하게 할당해 주기 위해 0x80에 저장해주기로 한다. 그리고 복사해주는 크기는 EVM의 워드 단위는 32바이트이므로 32바이트를 복사해준다.

OPCODE도 16진수로 바꿔주면 위의 코드는 아래와 같이 변한다.

1. 60 2A (PUSH1 0x2a)
2. 60 80 (PUSH1 0x80)
3. 52 (mstore)
4. 60 20 (PUSH 0x20)
5. 60 80 (PUSH 0x80)
6. F3

총 10바이트로 문제에서 원하는 최대 크기(OPCODE 10개)를 겨우 만족할 수 있었다.

runtime 코드는 이를 이은 602A60805260206080F3이 된다.

## ByteCode의 Initialization 부분

Initialization 부분은 위에서 살펴본 바와 같이 다음과 같이 구성된다.

1. 컨트랙트의 constructor()가 실행되어 초기화를 진행한다.  
2. runtime 코드를 메모리에 저장한다.
3. 복사한 메모리를 리턴한다.

우리가 작성하는 컨트랙트는 생성자가 존재하지 않으므로 runtime 코드를 메모리에 저장하고 그 메모리를 리턴하는 부분만 작성하면 된다.

메모리에 코드를 복사하는 OPCODE는 CODECOPY이다.

- CODECOPY(dst0st, ost, len) → code의 ost부터 len만큼을 memory의 dest0st에 복사하는 OPCODE이다.

| Stack(OPCode) | Name | Gas | Initial Stack(Parameter) | 최종 Stack | Notes |  |
| --- | --- | --- | --- | --- | --- | --- |
| 39 | CODECOPY | A3 | dstOst, ost, len | . | mem[dstOst:dstOst+len-1] := this.code[ost:ost+len-1] | copy executing contract's bytecode |

 즉 다음과 같이 구성된다.

1. dst0st → 복사할 bytecode가 담길 memory의 위치 0x00으로 설정
2. ost → runtime bytecode가 시작되는 바이트의 offset 
3. len → runtime bytecode의 길이 (10바이트이므로 0a가 된다.)

아직 Initialization 의 길이가 결정나지 않아 runtime bytecode가 시작되는 바이트 위치를 알지 못하므로 이는 나중에 결정하자.

- return(ost, len) → 메모리 위치 ost부터 크기 len 만큼을 가져와 반환해준다.

| Stack(OPCode) | Name | Gas | Initial Stack(Parameter) | 최종 Stack | Notes |
| --- | --- | --- | --- | --- | --- |
| F3 | RETURN | 0* | ost, len | . | return mem[ost:ost+len-1] |

위에서 runtime code가 담길 memory의 위치를 0x00으로 설정해 주었고 runtime code의 길이는 0x10이므로 runtime(0x00,0x0a)이 된다.

정리하면 execute code는 다음과 같다.

1. CODECOPY(0x00, ?? , 0x0a)
2. return(0x00,0x0a)

이를 조금 더 상세하게 하면

1. PUSH1 0x0a
2. PUSH1 0x??
3. PUSH1 0x00
4. CODECOPY
5. PUSH1 0x0a
6. PUSH1 0x00
7. RETURN

이 된다.

OPCODE도 16진수로 바꿔주면 위의 코드는 아래와 같이 변한다.

1. 60 0a (PUSH1 0x0a)
2. 60 ?? (PUSH1 0x??)
3. 60 00 (PUSH1 0x00)
4. 39 (CODECOPY)
5. 60 0a (PUSH 0x0a)
6. 60 00 (PUSH 0x00)
7. F3

총 12바이트이므로 runtime code가 시작되는 오프셋은 12번째(0부터 시작이므로) 즉 0x0c가 된다.

따라서 다음과 같이된다.

1. 60 0a (PUSH1 0x0a)
2. 60 0c (PUSH1 0x0c)
3. 60 00 (PUSH1 0x00)
4. 39 (CODECOPY)
5. 60 0a (PUSH 0x0a)
6. 60 00 (PUSH 0x00)
7. F3

즉 runtime 코드는 이를 이은 600a600c600039600a6000f3이 된다.

따라서 최종 ByteCode는 600a600c600039600a6000f3602A60805260206080F3 이 된다.

이제 이를 web3.eth.sendTransaction을 사용해서 컨트랙트를 만들고 그 주소를 알아내자.

```jsx
bytecode='600a600c600039600a6000f3602A60805260206080F3'
------------------------------------------------------------------------
txn = await web3.eth.sendTransaction({from:player,data:bytecode})
------------------------------------------------------------------------ 
{blockHash: '0x9142d9db36a19686ff92b4449cf772900649711c6dea232b4d952502304b2bbc', blockNumber: 2344527, contractAddress: '0xd7c38810D31F3928c152F01797E5AE1694C4DCE8', cumulativeGasUsed: 55352, effectiveGasPrice: 2500000007, …}
blockHash : "0x9142d9db36a19686ff92b4449cf772900649711c6dea232b4d952502304b2bbc"
blockNumber : 2344527
contractAddress : "0xd7c38810D31F3928c152F01797E5AE1694C4DCE8"
cumulativeGasUsed : 55352
effectiveGasPrice:2500000007
from:"0x83b26d6a3d3fabd9f0a5f1d69dca1ce6cc4ea39a"
gasUsed:55352
logs:[]
logsBloom:"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
status:true
to:null
transactionHash:"0x21462d061749597eb13d7d9eeb709055ac5f6f8ac525ef1768b3226064fa1bec"
transactionIndex:0
type:"0x2"
[[Prototype]]:Object
```

만들어진 contract의 주소인 “0xd7c38810D31F3928c152F01797E5AE1694C4DCE8”를 setsolver로 설정해주면 된다. 이는 txn으로받았으므로 txn.contractAddress로 해주어도 된다.

```jsx
await contract.setSolver(txn.contractAddress)
```

문제의 목표인 opcode가 10개인 42를 리턴해주는 주소로 인스턴스의 solver를 설정해주었으므로 주소 인스턴스를 제출하면 된다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/aa72cfad-82ac-4734-afeb-929594fce7aa/%EC%84%B1%EA%B3%B5.png)
