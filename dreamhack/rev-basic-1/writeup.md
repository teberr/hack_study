# rev-basic-1

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

![전체구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3132437a-e398-4781-9473-f000bdffb581/전체구조.png)

main함수에서 test eax,eax를 통해 비교 한 뒤 두가지 분기가 있음을 알 수 있다. 

좌측은 puts 함수를 통해 Correct를 출력한다.

우측은 puts 함수를 통해 Wrong을 출력한다.

즉 main함수의 분기에 따라 결과가 나오므로 main 함수에서 호출되는 함수

1. sub_1400013E0
2. sub_140001440
3. sub_140001000

을 분석하면 프로그램 진행을 알 수 있다.

그런데 sub_1400013E0은 매개변수로 “Input:”이 나오는 것을 보면 printf함수 임이 추측 가능하고 sub_140001440은 rdx에 저장공간과, rcx에 %256s로 매개변수를 받는거보면 scanf함수임이 추측이 가능하다.

printf함수와 scanf함수를 분석하는 것은 rev-basic-0에서 자세히 했으므로 생략한다.

## sub_140001000 함수 분석

![시작구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/180fed0e-8cbc-48f6-bc41-9d05b5bafc28/시작구조.png)

mov     [rsp+arg_0], rcx  // rcx(매개변수)로 받은 값을 rsp+arg_0 위치에 저장
mov     eax, 1                 // eax에 1값 저장
imul    rax, 0                  // rax에0곱함 즉 rax는 0
mov     rcx, [rsp+arg_0] // rcx에 저장했던 곳 주소 저장.
movzx   eax, byte ptr [rcx+rax] //rcx+rax에 저장된 값 byte로 가져와 eax랑 비교
cmp     eax, 43h ; 'C' // eax에 저장된 값이 C인지 비교
jz      short loc_140001023

여기서 만약 eax가 ‘C’가 아니라면 빨간색 선(false)가 실행되어 함수는 return이 되고 ‘C’라면 참이되어 초록샌 선이 실행되어 비교를 진행한다.

즉 byte 단위로 한글자씩 비교하는 함수이며 그 값은 초록색 선만 따라가면 

43, C

6F, o

6D, m

70, p

61, a

72, r

33, 3

5F, _ 

74, t

68, h

65, e

5F, _

63, c

68, h

34, 4

72, r

61, a

63, c

74, t

33, 3

72, r

이므로 조합하면 FLAG값은 Compar3_the_ch4ract3r 이 된다.

## (tab)Decompile 기능으로 본 sub_140001000함수

{
if ( *a1 != 67 )
return 0i64;
if ( a1[1] != 111 )
return 0i64;
if ( a1[2] != 109 )
return 0i64;
if ( a1[3] != 112 )
return 0i64;
if ( a1[4] != 97 )
return 0i64;
if ( a1[5] != 114 )
return 0i64;
if ( a1[6] != 51 )
return 0i64;
if ( a1[7] != 95 )
return 0i64;
if ( a1[8] != 116 )
return 0i64;
if ( a1[9] != 104 )
return 0i64;
if ( a1[10] != 101 )
return 0i64;
if ( a1[11] != 95 )
return 0i64;
if ( a1[12] != 99 )
return 0i64;
if ( a1[13] != 104 )
return 0i64;
if ( a1[14] != 52 )
return 0i64;
if ( a1[15] != 114 )
return 0i64;
if ( a1[16] != 97 )
return 0i64;
if ( a1[17] != 99 )
return 0i64;
if ( a1[18] != 116 )
return 0i64;
if ( a1[19] != 51 )
return 0i64;
if ( a1[20] == 114 )
return a1[21] == 0;
return 0i64;
}

이므로 FLAG 값은 배열 a1에 저장이 되어있고 각 숫자들을 아스키 코드표에 대조해서 문자로 바꾸면 FLAG 값을 찾을 수 있다.

https://honey-push-30b.notion.site/rev-basic-1-556c7c00155d4210be0bbe7258dca547
