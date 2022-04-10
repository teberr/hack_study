https://honey-push-30b.notion.site/rev-basic-4-b44a5210f2d14466890df4ff654b0127 에서 보면 그림이 깨지지 않는다.

# rev-basic-4

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

![전체구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/25c8838c-3550-4595-a187-7d30b859ef15/전체구조.png)

 sub_1400011C0은 printf함수, sub_140001220은 scanf 함수, sub_140001000의 반환값 eax를 통해 Correct혹은 Wrong을 출력하는 함수이다.

이 때 scanf로 받은 값의 주소를 rcx에 저장하여 sub140001000에 넘겨준다.

따라서 sub_140001000이 핵심이므로 sub_140001000함수를 분석한다.

## sub_140001000

![sub_140001000 전체구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a8c2cfa1-b87f-4340-83a6-3a2537475bb5/sub_140001000_전체구조.png)

sub_140001000전체구조이다. 반복되는 형태임을 알 수 있으며 진입점부터 분석한다.

## sub_140001000


1. mov     [rsp+arg_0], rcx
2. 
3.sub     rsp, 18h

3.mov     [rsp+18h+var_18], 0

4.jmp     short loc_14000101A

1.사용자가 입력한 값이 저장된 주소 rcx 를 rsp+arg_0 주소에 저장한다.

1. 스택 공간을 확보한다.
2. rsp+18h+var_18 주소에 0을 저장한다.
3. 14000101A를 실행한다.

## sub_14000101A

loc_14000101A:

1.movsxd  rax, [rsp+18h+var_18]

2.cmp     rax, 1Ch

3.jnb     short loc_140001065

1.rax에 rsp+18h+var_18주소에 저장된 값 0을 저장한다.

2.rax(0)과 0x1C를 비교한다. 

3.rax(0)이 0x1C보다 크다면 140001065로 점프한다.

이 때 140001065주소로 이동해보면 eax에 1을 저장하고 함수가 종료된다. 즉 rax가 0x1C보다 크면 반복문을 탈출하고 함수를 종료한다는 것이다. 첫 실행시에는 rax에 0이 저장되어 0x1C보다 작으므로 이어서 진행한다.

1.movsxd  rax, [rsp+18h+var_18]

2.mov     rcx, [rsp+18h+arg_0]

3.movzx   eax, byte ptr [rcx+rax]

4.sar     eax, 4

5.movsxd  rcx, [rsp+18h+var_18]

6.mov     rdx, [rsp+18h+arg_0]

7.movzx   ecx, byte ptr [rdx+rcx]

8.shl     ecx, 4

9.and     ecx, 0F0h

10.or      eax, ecx

11.movsxd  rcx, [rsp+18h+var_18]

12.lea     rdx, unk_140003000

13.movzx   ecx, byte ptr [rdx+rcx]

14.cmp     eax, ecx

15.jz      short loc_140001063


1.rax에 rsp+18h+var_18에 저장된값(0)을 저장한다.

2.rcx에 rsp+18h+arg_0에 저장된 값(사용자가 입력한 값이 저장된 주소)을 저장한다.

3.eax에 rcx+rax에 저장된 값에서 1바이트를 가져와 저장한다.(사용자가 입력한 값 중 첫번째 바이트)

4,eax값을 오른쪽으로 4비트 쉬프트연산한다.

5.rcx에 rsp+18h+var_18에 저장된값(0)을 저장한다.

6.rdx에 rsp+18h+arg_0에 저장된 값(사용자가 입력한 값이 저장된 주소)을 저장한다.

7.ecx에 rdx+rcx에 저장된 값에서 1바이트를 가져와 저장한다.(사용자가 입력한 값 중 첫번째 바이트)

8.ecx를 좌측으로 4비트 쉬프트연산한다.

9.그리고 ecx값과 0F0을 and 연산한다.

10.eax와 ecx값을 or 연산하여 eax에 저장한다. (사용자가 입력한값에 추가적인 연산 끝)

11.rcx에 rsp+18h+var_18에 저장된값(0)을 저장한다.

12.rdx에 unk_140003000주소를 복사한다.(아마 플래그가 있는 곳)

13.ecx에 rdx+rcx에 저장된 값에서 1바이트를 가져와 저장한다.(플래그 중 첫번째 거)

14.eax와 ecx를 비교한다.(사용자의 입력값에 연산한값이 플래그값과 같은지 비교)

15.같으면 140001063으로 이동한다.

이때 140001063으로 이동하면

loc_140001063:

jmp     short loc_140001012

140001012로 이동하라고 나오고 140001012는

loc_140001012:

mov     eax, [rsp+18h+var_18]

inc     eax

mov     [rsp+18h+var_18], eax

eax값을 1 늘려주고 rsp+18h+var_18에 저장하는 것을 알 수 있다. 즉 이걸 sub_14000101A랑 합치면

1.rsp+18h+var_18은 0부터 0x1C까지 1씩증가하며 0x1C가 되면 반복문에서 탈출한다. 

2.flag값은 unk_140003000주소에 저장되어있다.

3.사용자가 입력한값은 쉬프트 연산을 통해 값이 변화한다.

사용자가 입력한 값이 어떻게 변화하는지 알아봐야한다.

## 사용자 입력값 연산

사용자가 입력한 값이 연산되는 과정은 다음과 같다. 

1. 사용자 입력값을 우측으로 4비트 쉬프트 연산을 한다. (1)
2. 사용자 입력값을 좌측으로 4비트 쉬프트 연산을 한다.
3. 0F0과 and 연산을 한다. (3)
4. (1)과(3)를 or 연산을 한다.

이렇게만 보면 자세히 이해가 안되므로 실제 값으로 연산을 눈에 익게 해본다.

sar eax, 4 -> 입력받은 값을 오른쪽으로 4비트만큼 옮김 
shl ecx 4  -> 입력받은 값을 왼쪽으로 4비트만큼 옮김
and ecx 0F0h -> 4바이트만큼 옮긴 값을 좌측 4비트만 인정하기(ecx는 8비트임)
or eax,ecx -> 둘을 or연산함.

-> 1010 0101 (초기값 A5)
-> 0000 1010= eax (0A)
-> 0101 0000= ecx (50)

or 0101 1010 = or연산 결과

1010 0101(A5)이 연산을 하고나니

0101 1010(5A)이 되었다.

하나 더 해본다.

-> 0100 0011(초기값 43)

-> 0000 0100 =eax(04)
-> 0011 0000 =ecx(30)
-> 0011 0100 =or 연산결과(34)

이번에는 

0100 0011(43)을 연산하고나니

0011 0100(34)가 되었다.

즉 다음과 같은 결론을 낼 수 있다.

결론 -> 4비트씩 나눠서 서로 자리를 바꾸는 연산

그렇다면 이 결론에 의거 flag가 들어있는 곳에서 서로 4비트씩 나눠 자리를 다시 바꾸면 입력해야하는 값이 나올것이다. (53이 들어있으면 35를 입력하면 된다.)

그럼 flag가 들어있는 140003000을 살펴보자.

![unk_140003000.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/819d25a4-68c2-4b58-9b44-f5dac8746429/unk_140003000.png)

24 27 13 C6 C6 13 16 E6  47 F5 26 96 47 F5 46 27
13 26 26 C6 56 F5 C3 C3  F5 E3 E3 00 00 00 00 00

이 들어있는 것을 확인할 수 있다. 이 값 들은 마침 4비트씩 나누어 16진수로 저장되어 있으므로 각각 자리를 바꿔주고 아스키 코드표를 확인하여 치환해주었다.

42 72 31 6C 6C 31 61 6E 74 5F 62 69 74 5F 64 72
B   r   1  l   l   1   a   n  t   _  b  i  t _ d r
31 62 62 6C 65 5F 3C 3C  5F 3E 3E
1  b   b   l    e  _   < <   _  >  >

즉 Br1ll1ant_bit_dr1bble_<<_>>이 flag값이 된다.

