https://honey-push-30b.notion.site/Textbook-DH-66bd88f14b0f418485807e249e6de32c 에서 보면 그림이 깨지지 않는다.

# Textbook-DH

## 문제 파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/62ef32b3-2920-44b6-876b-f615937abfc7/문제파일_다운로드.png)

Alice와 Bob이 통신을 하고 있고 키교환 과정에서 허점을 찾아 플래그를 획득하는 문제이다.

문제파일 다운로드를 통해 파일을 다운로드 받으면 [Challenge.py](http://Challenge.py)파일을 얻을 수 있다.

![challenge.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3bfc7590-39ab-44b4-abc9-f4be8ecba8ba/challenge.png)

[challenge.py](http://challenge.py) 코드 내용인데 이를 분석해 어떤식으로 작동하는지 알아보자.

## Class Person

```python
class Person(object):
	def **init**(self, p):
		self.p = p
		self.g = 2
		self.x = random.randint(2, self.p - 1)
	def calc_key(self):
    self.k = pow(self.g, self.x, self.p)
    return self.k

	def set_shared_key(self, k):
    self.sk = pow(k, self.x, self.p)
    aes_key = hashlib.md5(str(self.sk).encode()).digest()
    self.cipher = AES.new(aes_key, AES.MODE_ECB)

	def encrypt(self, pt):
    return self.cipher.encrypt(pad(pt, 16)).hex()

	def decrypt(self, ct):
    return unpad(self.cipher.decrypt(bytes.fromhex(ct)), 16)

```

### 1. **init**

객체가 처음 생성될 때 실행되는 init 함수이다. 

1. 사용자가 매개변수로 입력한 p를 self.p에 저장한다.
2. self.g에 2를 저장한다.
3. x는 2 ~ p-1값사이 랜덤 값으로 저장한다.

### 2. calc_key(self)

key값인 self.k값을 구하는 함수이다.

1. pow(x,y,z) 는 x^y를 z로 나눈 나머지이다. 즉 아래 식과 같다.

![pow(x,y,z).PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/db396af6-7350-45b1-ab79-f510435d1370/pow(xyz).png)

1. 따라서 pow(self.g,self.x,self.p)는 다음과 같다.

![key_calc.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bb8c02c6-a803-4349-8841-65a06fbaf98a/key_calc.png)

1. 근데 우리는 init에서 g에 2를 저장하는 것이 확정이므로 위 식은 최종적으로 아래가 된다.

![최종key_calc.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6cb0d8d6-f53e-49d6-a046-a8b22d55a282/최종key_calc.png)

이 때 조건은 2≤x≤p-1 이고 p는 사용자가 제공한 매개변수이다.

### 3. set_shared_key(self,k)

key값을 통해 공유되는 shared key 즉 sk를 구하는 함수다.

1. sk는 pow(k,self.x,self.p)이다. 근데 이 때의 k는 위의 calc_key에서 구했다. 즉 아래 식이 된다.

![shared_key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fdb12848-606c-4f6d-8426-dcfa081cd3ef/shared_key.png)

1. 근데 이 mod 연산자 성질 중 다음과 같은 성질이 있다. (정보보안기사책 Diffie-Hellman참조)

![모듈러 연산의 성질.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/302f65f5-2230-460d-a7f4-67ba53460836/모듈러_연산의_성질.png)

1. 따라서 sk는 정리하면 아래 식이 된다.

![최종 shared_key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c7fe0e98-8d60-41e5-8b8e-03a0ca3eee08/최종_shared_key.png)

1. 이 sk값을 해쉬함수를 통해 aes_key를 만든다.
2. aes_key 값을 통해서 ECB모드로 cipher값을 만든다.

즉 sk값에 따라서 cipher 값이 정해진다. (해쉬함수는 입력값이 같으면 결과값이 같으므로)

### 4. encrypt(self, pt)

1. AES에서 사용하는 ECB 모드의 경우 블록 크기가 16바이트로 사용된다.
2. 따라서 사용자가 넘겨준 매개변수 pt를 16바이트 단위로 패딩하여 암호화한다.

### 5. decrypt(self, ct)

1. 16바이트 단위로 패딩한것을 패딩을 없애준다.
2. 암호화된 암호문을 복호화 한다.

### 결론

Diffie-Hellman 알고리즘의 경우 공유된 키(Shared_key)를 통해서 암호화하므로 핵심은 sk값이다.

![최종 shared_key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ae245df5-9c7b-4ae3-a5c9-bc8ae2b30cfc/최종_shared_key.png)

## main 코드

```python
flag = open("flag", "r").read().encode()
prime = getPrime(1024)
print(f"Prime: {hex(prime)}")
alice = Person(prime)
bob = Person(prime)
------------------------------------1번-----------------------------------------

alice_k = alice.calc_key()
print(f"Alice sends her key to Bob. Key: {hex(alice_k)}")
print("Let's inturrupt !")
alice_k = int(input(">> "))
if alice_k == alice.g:
exit("Malicious key !!")
bob.set_shared_key(alice_k)
------------------------------------2번-----------------------------------------

bob_k = bob.calc_key()
print(f"Bob sends his key to Alice. Key: {hex(bob_k)}")
print("Let's inturrupt !")
bob_k = int(input(">> "))
if bob_k == bob.g:
exit("Malicious key !!")
alice.set_shared_key(bob_k)
------------------------------------3번-----------------------------------------

print("They are sharing the part of flag")
print(f"Alice: {alice.encrypt(flag[:len(flag) // 2])}")
print(f"Bob: {bob.encrypt(flag[len(flag) // 2:])}")
------------------------------------4번-----------------------------------------

```

### 1번 코드

```python
flag = open("flag", "r").read().encode()
prime = getPrime(1024)
print(f"Prime: {hex(prime)}")
alice = Person(prime)
bob = Person(prime)
------------------------------------1번-----------------------------------------
```

1. 변수 flag에 flag에 들어있는 값을 인코딩 해서 불러와 저장한다.
2. 변수 prime 에 1024비트 짜리 소수를 만든다.
3. 변수 prime 값을 출력한다.
4. alice와 bob에게 prime을 매개변수로 하여 Person 객체를 생성한다.

이 때 둘 다 같은 소수로 Person 객체를 만들었으므로 매개변수로 들어가는 소수 p는 동일하다. 즉 여기서 둘의 키 값을 구할 수 있다. 

Person 객체의 calc_key는 아래 그림과 같이 구할 수 있다. 

![최종key_calc.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ee8322d1-6fd5-494e-8a31-fbaa02f304ee/최종key_calc.png)

이 때 x는 2≤x≤p-1의 임의의 수이므로 아마 앨리스의 x값과 bob의 x값이 다를 것이다.  따라서 Alice와 Bob의 키 값은 다음과 같다.

![Alice Bob Key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ca7ef475-0e34-436d-add0-c807f6c9c302/Alice_Bob_Key.png)

### 2번 코드

```python
alice_k = alice.calc_key()
print(f"Alice sends her key to Bob. Key: {hex(alice_k)}")
print("Let's inturrupt !")
alice_k = int(input(">> "))
if alice_k == alice.g:
exit("Malicious key !!")
bob.set_shared_key(alice_k)
------------------------------------2번-----------------------------------------
```

1. alice_k에 alice.calc_key()결과 값을 저장한다. 즉 alice_key에는 다음과 같은 값이 저장되어있다.

![Alice key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5a4c6647-2926-405e-b61a-05d0f7068a03/Alice_key.png)

1. alice의 key 값을 출력해주고 사용자로 부터 입력을 받는다.
2. 사용자로 부터 정수를 입력받아 alice_k에 **덮어씌운다.** 이 때 사용자가 입력한 값이 alice.g와 같으면 안되므로 2를 입력하면 안된다.
3. bob이 사용자가 입력한 alice_key로 공유키(shared_key)를 설정한다.  이 때 공유키 값은

![shared_key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fdb12848-606c-4f6d-8426-dcfa081cd3ef/shared_key.png)

로 정해져 있으므로 alice_key값을 대입하면 

![alice_key2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4bfbdbba-c831-44f4-8bb8-c29da1f784a2/alice_key2.png)

이 된다. 근데 우리는 이 때 alice_key값을 사용자 값으로 대체할 수 있음을 3번 과정을 통해 알았다. 

![alice 대체.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c6a65aad-fd4d-483b-9d3f-533c730a0ec7/alice_대체.png)

따라서 Bob의 sk(shared_key)는 아래와 같이 된다.

![Bob_shared_key](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8cf4c4d3-66c8-4ab9-9093-6ac37488ce32/bob_shared_key.png)

Bob_shared_key

### 3번 코드

```python
bob_k = bob.calc_key()
print(f"Bob sends his key to Alice. Key: {hex(bob_k)}")
print("Let's inturrupt !")
bob_k = int(input(">> "))
if bob_k == bob.g:
exit("Malicious key !!")
alice.set_shared_key(bob_k)
------------------------------------3번-----------------------------------------
```

1. bob_k에 bob.calc_key()결과 값을 저장한다. 즉 bob_key에는 다음과 같은 값이 저장되어있다.

![Bob key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b7d4e2bf-fa26-4269-88db-723b6169aab3/Bob_key.png)

1. bob의 key 값을 출력해주고 사용자로 부터 입력을 받는다.
2. 사용자로 부터 정수를 입력받아 bob_k에 **덮어씌운다.** 이 때 사용자가 입력한 값이 bob.g와 같으면 안되므로 2를 입력하면 안된다.
3. alice는 사용자가 입력한 bob_key로 공유키(shared_key)를 설정한다. 이 때 공유키 값은 위의 2번 코드와 같은 과정을 거쳐 다음과 같이 설정된다.

![Alice_shared_key](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b20079e2-8cd8-459b-af82-165eb5aba4de/alice_shared_key.png)

Alice_shared_key

### 4번 코드

```python
print("They are sharing the part of flag")
print(f"Alice: {alice.encrypt(flag[:len(flag) // 2])}")
print(f"Bob: {bob.encrypt(flag[len(flag) // 2:])}")
------------------------------------4번-----------------------------------------
```

Alice가 shared_key값을 이용해 flag의 앞부분을 암호화하였고 Bob이 shared_key 값을 이용해 flag의 뒷부분을 암호화 하였다. 

## 풀이

복호화를 하기 위해서는 shared key값만 있으면 되기 때문에 내가 shared key값을 알 수 있어야 한다.

![최종 Alice Bob Key.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/234a08ad-4a90-4947-9e70-d449b591ec84/최종_Alice_Bob_Key.png)

이 때 Alice의 x값과 Bob의 x값은 랜덤으로 정해지므로 둘이 다를 가능성이 크고 유추하기가 어렵다. 

**하지만 입력값에 1을 넣어주면 Alice의 x값과 Bob의 x값과 상관없이 1 mod prime으로 고정되므로 내가 원하는 값으로 만들어 줄 수 있다**.

즉 둘의 shared_key값은 1 mod prime인데 prime값은 소수이고 2이상이므로 어떤 값이든 1을 prime으로 나눈 나머지는 1이 된다. **즉 둘의 shared_key값은 1이 된다.**

![접속정보.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5778760d-50c4-46f7-90e7-616abbf70282/접속정보.png)

nc [host1.dreamhack.games](http://host1.dreamhack.games) 15611로 연결해준다.

![실행결과.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7ef7b419-6c9c-4d74-a92c-6c3ebfd1132e/실행결과.png)

실행해주고 1값을 넣어서 Alice와 Bob의 값을 알았다.

Alice: e48e9174a9103e249f4bb809e13d58d49283e2438954799030be4854328adacbeb310c79bce3e91719f218158359af0d

Bob: 2a69648d494907e551b69b74676f2e528644a526e5f7bc8b6300f1bd8ad5f091a9e40939960ea5bd0ad2ceff23a14f96

그럼이제 [challenge.py](http://challenge.py) 파일에 있던 decrypt 코드를 이용하여 이 값들을 복호화한다.

```python
from Crypto.Util.Padding import pad, unpad
from Crypto.Cipher import AES
import hashlib

Alice="e48e9174a9103e249f4bb809e13d58d49283e2438954799030be4854328adacbeb310c79bce3e91719f218158359af0d"
Bob="2a69648d494907e551b69b74676f2e528644a526e5f7bc8b6300f1bd8ad5f091a9e40939960ea5bd0ad2ceff23a14f96"
sk= 1
aes_key = hashlib.md5(str(sk).encode()).digest()
cipher = AES.new(aes_key, AES.MODE_ECB)

print(unpad(cipher.decrypt(bytes.fromhex(Alice)), 16))
print(unpad(cipher.decrypt(bytes.fromhex(Bob)),16))
```

이 코드를 실행하고 나면 값이 조금 이상하게 나온다.

![복호화.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0575cb73-5cbb-4ce0-8fc1-67137ac7e405/복호화.png)

 
솔직히 처음 보고 DH 안에 있는 값들이 암호화가 되어있는줄 알았다. 그래서 막 이것저것 찾아보다가 결국 못찾고 저 값 자체를 제출해봤는데 답이었다.
