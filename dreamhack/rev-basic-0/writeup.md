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

![전체 구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2e025588-9e99-4145-9935-68486e3a11cb/전체_구조.png)

main함수에서 test eax,eax를 통해 비교 한 뒤 두가지 분기가 있음을 알 수 있다. 

좌측은 puts 함수를 통해 Correct를 출력한다.

우측은 puts 함수를 통해 Wrong을 출력한다.

즉 main함수의 분기에 따라 결과가 나오므로 main 함수에서 호출되는 함수

1. sub_140001190
2. sub_1400011F0
3. sub_140001000

을 분석하면 프로그램 진행을 알 수 있다.

## sub_140001190 함수 분석

64비트의 PE 파일에서 매개변수는 rcx,rdx,r8,r9순서이므로 sub_140001190 

lea     rcx, aInput     ; "Input : "
call    sub_140001190

다음과 같은 부분에서 sub_140001190 함수는 rcx에 “Input :”이라는 문자열을 입력받고 이 문자열을 매개변수로 실행됨을 알 수 있다. 

sub_140001190함수 내부로 들어가면 다음구조가 보인다.

![sub_140001190.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/89fd3f56-88b3-4299-ad4f-a838ef1139f2/sub_140001190.png)

이 중 함수 호출하는 부분과 매개변수를 본다.

mov     ecx, 1          ; Ix
call    cs:__acrt_iob_func

여기서도 acrt_iob_func를 호출하고 그 매개변수로 1을 넘겨주는 것이 보인다.

acrt_iob_func(1) → printf 함수이다. 즉 sub_140001190 은 printf함수를 호출하는 내부 구조를 가지고있다.

즉 sub_140001190은 printf(”Input : “)함수이다.

![sub_140001190_dec.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d9f966d2-55a5-444f-81ad-5e4e579fc2ba/sub_140001190_dec.png)

IDA의 Tab을 통해 디컴파일 한 구조는 위와같다.

## sub_1400011F0

이 함수도 먼저 어떤 것을 매개변수로 받는지 살펴본다.

lea rdx, [rsp+138h+var_118]

lea     rcx, a256s      ; "%256s"
call    sub_1400011F0

%256s과 [rsp+138h+var_118]을 매개변수로 받는 것을 알 수 있다.

내부 구조는 다음과 같다.

![sub_1400011F0.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c19a6dd2-f842-4227-969d-1080b0a99f75/sub_1400011F0.png)

xor     ecx, ecx        ; Ix
call    cs:__acrt_iob_func

xor 연산은 같으면 0 다르면 1이 나오는 연산이다. 

xor ecx,ecx를 한다는 것은 ecx에 0을 넣는 것과 같다. 

즉 arct_iob_func(0)을 의미하며 이는 scanf 함수를 의미한다.

따라서 처음 매개변수와 합치면 scanf(”%256s”,[rsp+138h+var_118])일것이다.

![sub_1400011F0_dec.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c33b37ef-9a2f-4eea-a7e2-fbea6442a083/sub_1400011F0_dec.png)

그리고 이는 IDA에서 Tab 기능을 통해 디컴파일한 결과는 위와 같다. 

## sub_140001000

우리는 sub_1400011F0의 결과값이 [rsp+138h+var_118]에 저장되는 것을 확인했다.

lea     rcx, [rsp+138h+var_118]
call    sub_140001000

그리고 그 값은 scanf를 통해 사용자로 부터 읽어들인 값이다.

즉 사용자로 부터 읽어들인 값을 매개변수로 sub_140001000을 호출한다.

![sub_140001000.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b69aae7e-9ca0-476a-a26f-bb4a69ea8a5c/sub_140001000.png)

mov     [rsp+Str1], rcx ; 사용자로 부터 읽은 값을 [rsp+Str1]에 옮긴다.
sub     rsp, 38h ; rsp값에서 38h를 뺀다.
lea     rdx, Str2       ; "Compar3_the_str1ng"
mov     rcx, [rsp+38h+Str1] ; Str1 즉 사용자로 부터 읽은값
call    strcmp

rdx에 문자열, rcx에 사용자로 부터 입력받은 문자열 두개를 매개변수로 strcmp함수를 호출한다. 즉

strcmp(Str1,Str2)이다. 이때 반환값은 eax에 저장되며 strcmp는 두 값이 같으면 0이 나온다. 따라서 **사용자가 입력한 값이 Str2값과 같으면 eax에는 0이 저장**된다.

test eax eax -> 두 연산자에 AND 비트연산 취하고, 둘다 0일경우 ZF플래그 설정이 되는 연산이다.

즉 사용자로부터 입력받은값이 Str2와 같으면 ZF플래그가 설정된다.

jnz short loc_140001028 ; jump not zero 즉 ZF플래그가 설정이 안되면 140001028로 점프하라는 건데 사용자로부터 입력값과 같으면 ZF가 설정되므로 아래 사진에서 빨간색 분기가 실행된다.

![분기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fb4a4beb-a093-4ed5-a012-7d6357e40e45/분기.png)

따라서 rsp+38h+var_18에 1이들어가고

![결과.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d870471d-fe64-4537-b800-b82579e9a250/결과.png)

rsp+38h+var_18에 들어간 1을 eax에 넣어 함수의 결과값으로 반환해 준다. 

**만약 사용자가 입력한 값이 다르다면?** 

strcmp(Str1,Str2)의 결과가 0이 아닐것이고 test eax eax 연산 때 eax가 0이 아니므로  ZF플래그가 설정되지 않을 것이다.  

![분기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d1548db7-4c5a-428e-9451-4670587ecf2b/분기.png)

즉 초록색 분기가 실행될 것이고 rsp+38h+var_18에는 0이 들어간다.

### 결론 : 사용자의 입력값이 문자열 X와 같으면 sub_140001000함수는 1을반환 다르면 0을 반환한다.

# 다시 main으로 돌아와서

![다시main.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/83457830-3d3e-481d-a335-0b6e0ddec858/다시main.png)

## sub_140001000의 결과값이 1일경우 (사용자의 입력값이 문자 X와 같을경우)

test eax, eax연산은 ZF가 설정되지 않는다. 따라서 JZ연산은 ZF가 설정되어야 참이므로 거짓인 빨간색 분기가 실행된다.

Correct를 매개변수로 puts함수를 호출하므로 puts(”Correct”)가 실행된다 볼수 있다.

## sub_140001000의 결과값이 0일경우 (사용자의 입력값이 문자 X와 다를경우)

test eax, eax연산에서 ZF가 설정되므로 참인 분기인 초록색 분기가 실행된다.

즉 puts(”Wrong”)이 실행된다.

# 결론

사용자의 입력값은 sub_140001000에서 레지스터 rdx에 저장된 Str2값 "Compar3_the_str1ng”과 같을 때 Correct가 출력되므로 저 값이 FLAG이다.

# 번외

shfit + F12를 통해 문자열을 확인하면 딱봐도 의심스러워 보이는 문자열이 있다. 이걸로도 확인이 가능하다.

![문자열.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/511f0613-9112-4e35-9cc5-98f1997d89e4/문자열.png)

https://honey-push-30b.notion.site/rev-basic-0-d9bd007d801f4f8b8ecbe44ea32fd240
