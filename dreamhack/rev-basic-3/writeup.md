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

![전체구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f51fc5a0-2b34-4e72-8225-e7c605980fb9/전체구조.png)

이제는 익숙한 전체 구조이다. sub_1400011B0은 printf함수, sub_140001210은 scanf 함수, sub_140001000의 반환값 eax를 통해 Correct혹은 Wrong을 출력하는 함수이다.

따라서 sub_140001000이 핵심이므로 sub_140001000함수를 분석한다.

# sub_140001000

![sub140001000전체구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4056eba4-39a6-4fcc-8cc4-57f72c13672f/sub140001000전체구조.png)

sub_140001000함수의 전체구조이다. rev-basic-2에서 봤듯이 반복문 구조이며 아래와 같은 패턴으로 작동한다.

## sub_140001000진입점

mov     [rsp+arg_0], rcx

sub     rsp, 18h

mov     [rsp+18h+var_18], 0

jmp     short loc_14000101A


rsp+arg_0에 매개변수로 받은 rcx를 넣는다. 이 함수가 실행되기 전에 scanf로 사용자에게서 입력을 받았으므로 rcx에는 사용자가 입력한 문자열의 주소가 들어있을 것이다.

그리고 rsp값을 18만큼 빼준다. 이는 스택의 크기를 확보하는 것이다.

rsp+18h+var_18의 주소 위치에 0을 넣고 14000101A를 실행한다.

즉 사용자로부터 받은 입력값을 [rsp+arg_0]에 넣고 rsp+18h+var_18을 0으로 초기화하는 부분이다.

## 14000101A


movsxd  rax, [rsp+18h+var_18]

cmp     rax, 18h

jnb     short loc_140001053


별 내용은 없다. rax에 초기화 했던 0값을 넣고 0x18보다 작다면 140001053으로 이동한다. 

## 140001053

1.movsxd  rax, [rsp+18h+var_18]

2.lea     rcx, unk_140003000

3.movzx   eax, byte ptr [rcx+rax]

4.movsxd  rcx, [rsp+18h+var_18]

5.mov     rdx, [rsp+18h+arg_0]

6.movzx   ecx, byte ptr [rdx+rcx]

7.xor     ecx, [rsp+18h+var_18]

8.mov     edx, [rsp+18h+var_18]

9.lea     ecx, [rcx+rdx*2]

10.cmp     eax, ecx

jz      short loc_140001051


1.rax에 rsp+18h+var_18에 들어있는 값인 0을 넣어준다. 

2.그리고 rcx에는 unk_140003000 주소를 복사한다.

3.eax에 rcx(주소값)+rax(0)을 바이트만큼 가져온다.

4.그리고 다시 rcx값에 [rsp+18h+var_18]에 들어있는 값 0 을 넣어준다.

5.rdx에 [rsp+18h+arg_0]에 들어있는 값(사용자가 입력한 값이 들어있는 주소)을 가져온다.

6.ecx에 rdx(사용자입력값주소)+rcx(0)에서 한바이트만 가져온다.

7.ecx(사용자가 입력한 첫 문자)랑 [rsp+18h+arg_0](0)이랑 xor 연산을 하여 넣는다.

8.edx에는 rsp+18h+var_18(0)을 넣는다.

9.ecx에 rcx+rdx*2값을 복사한다.

1. eax(저장되었던값)과 ecx(사용자입력값과 xor연산한값  + rsp_18h_var_18*2)값을 비교한다.
2. 두 값이 같다면 140001051로 점프한다.

여기서 핵심은 일단 unk_140003000에 flag 값이 저장되어 있다는 점이다. 단 사용자가 입력한 값을 rsp_18h_var_18과 xor하고 + rsp_18h_var_18*2한 값이 저 값과 같아야 하므로 rev-basic-2때와 같이 평문으로 되어있지는 않을 것이다.

실제로 unk_140003000을 확인하면

![unk_140003000.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/08879390-1f78-4c6f-8b5a-5181067d16c4/unk_140003000.png)

140003000~140003017까지 값들이 저장되어 있는것을 확인 할 수 있다.

그럼 (사용자가 입력한 값 xor [rsp_18h_var_18] + [rsp_18h_var_18]*2)한 값이 저 값과 같아야 하는데 이 때 rsp_18h_var_18이 무엇인지 알아야한다.  이는 140001012에서 확인할 수 있다.

loc_140001012:
mov     eax, [rsp+18h+var_18]
inc     eax
mov     [rsp+18h+var_18], eax

1씩 늘어나는 값이다. 언제까지 늘어나나면 14000101A에서 확인했듯이 0x18까지 늘어난다. 따라서 다음과 같이 이해하면된다.

for(i=0;i<0x18;i++)일 때

140003000부터 저장된 값(x라 한다)이  (사용자 입력값 xor i)+i*2과 같다면 된다.

즉 식으로 하면

x = input xor i + i *2 이므로 우리가 구하고자 하는 것은 input값이니 

(x-i*2) = input xor i이다.이때 xor연산의 특징으로 xor연산을 두번하면 원래의 값이 나오므로

(x-i*2) xor i = input이다.

식은 세웠는데 일일이 계산하기는 귀찮으므로 코드로 짜봤다.

 이 때 x의 값은 0x49,0x60,0x67,0x74,0x63,0x67,0x42,0x66,0x80,0x78,0x69,0x69,0x7B,0x99,0x6D,0x88,0x68,0x94,0x9F,0x8D,0x4D,0xA5,0x9D,0x45이다.

![코드를 통한 계산.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f8e84a02-ea04-4e2c-ba99-aed6e1539e8f/코드를_통한_계산.png)

코드를 통해 계산하면 `I_am_X0_xo_Xor_eXcit1ng` 로 값이 나와준다.  

### 코드

flag="0x49,0x60,0x67,0x74,0x63,0x67,0x42,0x66,0x80,0x78,0x69,0x69,0x7B,0x99,0x6D,0x88,0x68,0x94,0x9F,0x8D,0x4D,0xA5,0x9D,0x45".split(",")

for i in range(len(flag)):
temp = int(flag[i],16)
result=(temp-i*2)^i
print(chr(result),end='')

https://honey-push-30b.notion.site/rev-basic-3-afcc9d0b4d1348f09c897b5e3d95866e
