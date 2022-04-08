# 파일 형식

PE파일 이므로 Windows 실행파일이며 IDA를 실행하면 다음과 같은 내용을 볼 수 있다.

Possible file format: Portable executable for AMD64 (PE) (C:\Program Files\IDA Freeware 7.7\loaders\pe64.dll)

64비트 PE파일이다.

# 64비트에서의 매개변수 전달 방식

[windows - PE]
Parameter 1 – RCX
Parameter 2 – RDX
Parameter 3 – R8
Parameter 4 – R9

# IDA Pro를 통한 분석

## IDA Pro를 통해 본 전체구조 및 main 함수 분석

![전체구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0829af7e-c018-4dc3-8202-803810045a49/전체구조.png)

이번에도 main함수에서 test eax,eax를 통해 비교 한 뒤 두가지 분기가 있음을 알 수 있다. 

좌측은 puts 함수를 통해 Correct를 출력한다. (거짓일 때 실행됨)

우측은 puts 함수를 통해 Wrong을 출력한다. (참일 때 실행됨)

즉 main함수의 분기에 따라 결과가 나오므로 main 함수에서 호출되는 함수

1. sub_1400011B0
2. sub_140001210
3. sub_140001000

을 분석하면 프로그램 진행을 알 수 있다.

sub_1400011B0의 경우 매개변수로 “Input : “이라는 문자열을 받는다. 따라서 printf 함수임을 추측할 수 있다.

sub_140001210의 경우 rdx로 공간과 rcx로 %256s 두개의 매개변수를 받는다. 따라서 scanf 함수임을 추측할수 있다. 

즉 sub_140001000함수에서의 결과값 eax를 리턴하고 그 값을 통해서 Correct나 Wrong을 출력함을 추측할 수 있다.

## sub_140001000함수 분석

![Inkedsub_140001000전체구조_LI.jpg](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b509d30b-1dc2-43de-ab03-509faf8b1ea7/Inkedsub_140001000전체구조_LI.jpg)

sub_140001000 함수는 위와 같이 구성된다.

1번이 가장 먼저 실행되고 그다음 2번이 실행되는것 까지는 확정이다.  

이 때 1번 구문은

mov     [rsp+arg_0], rcx ; 매개변수로 받은 값을 rsp+arg_0주소값에 저장
sub     rsp, 18h ; 스택 공간 할당
mov     [rsp+18h+var_18], 0 ; rsp+18h+var_18위치에 0 저장
jmp     short loc_7FF74F2B101A

으로 크게 중요한건 없고 rsp+arg_0에 rcx매개변수로 받은값을 저장하고 rsp+18h+var_18위치에 0을 저장한다고만 알면된다.

6번의 경우 eax에 1값을 넣고 바로 8번으로 진행되며 ret 되므로 종료구문이다. 

따라서 8번으로 향하는 5번도 eax에 값을 넣고 종료하는 구문을 알 수 있다.

1

**남은것은 2-3-4-7구문이고 그림을 보면 2-3-4-7-2로 계속 반복되는 것을 알 수 있다. 즉 반복 구문이며 이 부분이 우리가 핵심적으로 봐야하는 부분이다.**

이 때 2번의 내용을 보면

cmp rax,12h ; rax에 들어있는 값과 12(16진수) 비교

jnb short loc_7FF74F2B1048  ; 만약 작지 않다면(jump not below) 6번으로 이동 

임을 알 수 있다.

**rax값이 0x12보다 작을때는 계속 반복구문을 실행한다는 것을 알 수 있다. 즉 반복을 0~0x12까지 총 18번 수행한다.** 

핵심적인 부분은 3번 부분이다.

movsxd  rax, [rsp+18h+var_18] ; rax에 rsp+18h+var_18h에 저장된 값(0)을 저장함. 
lea     rcx, aC         ; "C" aC에 있는 주소 값을 rcx에 복사함. 
movsxd  rdx, [rsp+18h+var_18] ; rdx에 rsp+18h+var_18h에 저장된 값(0)을 저장함.
mov     r8, [rsp+18h+arg_0] ; r8에 매개변수로 받은 값을 저장.
movzx   edx, byte ptr [r8+rdx] ; r8+ rdx 주소값에서 바이트만큼 가져와서 edx에 저장.
cmp     [rcx+rax*4], edx ; edx와 [rcx+rax*4]에 저장된 값 비교함. rcx에는 aC에 있는 값(”C”)가 저장
jz      short loc_7FF74F2B1046

여기서 핵심적인 부분은 aC에 있는 주소값을 rcx에 복사하고 rcx에서 rax*4만큼 떨어진값을 비교한다. 이때는 rax에 0이 저장되어있으나 3번 구문이 끝나고 실행되는 이후 7번 구문을 보면

mov     eax, [rsp+18h+var_18]
inc     eax
mov     [rsp+18h+var_18], eax

eax값을 1증가시킴을 알 수 있다. 

즉 정리하면 다음과 같다.

movzx   edx, byte ptr [r8+rdx]  ; 이때 rdx값도 [rsp+18h+var_18]이므로 r8(사용자 입력값)의 다음 바이트가 저장된다.  

cmp     [rcx+rax*4], edx ; rcx에 저장된 aC주소값에서 4바이트 다음 값을 비교한다.

따라서 aC주소값에 우리가 비교하고자 하는 문자들이 존재하고 그 문자들을 합치면 우리가 찾고자 하는 문자열이 있다고 추측할 수 있다.

aC주소를 더블클릭하여 따라가면 다음과 같은 값들을 볼 수 있다.

.data:00007FF74F2B3000 aC db 'C',0                             ; DATA XREF: sub_7FF74F2B1000+28↑o

.data:00007FF74F2B3002 align 4

.data:00007FF74F2B3004 aO db 'o',0

.data:00007FF74F2B3006 align 8

.data:00007FF74F2B3008 aM db 'm',0

.data:00007FF74F2B300A align 4

.data:00007FF74F2B300C aP db 'p',0

.data:00007FF74F2B300E align 10h

.data:00007FF74F2B3010 a4 db '4',0

.data:00007FF74F2B3012 align 4

.data:00007FF74F2B3014 aR db 'r',0

.data:00007FF74F2B3016 align 8

.data:00007FF74F2B3018 aE db 'e',0

.data:00007FF74F2B301A align 4

.data:00007FF74F2B301C db '_*',0

.data:00007FF74F2B301E align 20h

.data:00007FF74F2B3020 aT db 't',0

.data:00007FF74F2B3022 align 4

.data:00007FF74F2B3024 db 'h',0

.data:00007FF74F2B3026 align 8

.data:00007FF74F2B3028 aE_0 db 'e',0

.data:00007FF74F2B302A align 4

.data:00007FF74F2B302C db '_*',0

.data:00007FF74F2B302E align 10h

.data:00007FF74F2B3030 aA db 'a',0

.data:00007FF74F2B3032 align 4

.data:00007FF74F2B3034 aR_0 db 'r',0

.data:00007FF74F2B3036 align 8

.data:00007FF74F2B3038 aR_1 db 'r',0

.data:00007FF74F2B303A align 4

.data:00007FF74F2B303C a4_0 db '4',0

.data:00007FF74F2B303E align 20h

.data:00007FF74F2B3040 aY db 'y',0


여기서 보면 aC값인 00007FF74F2B3000를 기점으로 4바이트마다 문자가 하나씩 저장되어 있는 것을 볼 수 있다. 

00007FF74F2B3000 : C

00007FF74F2B3004 : o

00007FF74F2B3008 : m

00007FF74F2B300C : p

00007FF74F2B3010 : 4

00007FF74F2B3014 : r

00007FF74F2B3018 : e

00007FF74F2B301C : _

*00007FF74F2B3020 : t*

*00007FF74F2B3024 : h*

*00007FF74F2B3028 : e*

*00007FF74F2B302C : _* 

00007FF74F2B3030 : a

00007FF74F2B3034 : r

00007FF74F2B3038 : r

00007FF74F2B303C : 4

00007FF74F2B3040 : y

즉 Comp4re_the_arr4y 라는 글자와 사용자가 입력한 값을 한바이트씩 비교하고 있는 것이다. 이 값이 FLAG 값임을 알 수 있다.
