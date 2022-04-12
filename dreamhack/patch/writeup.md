# patch

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

## 실행해보기

![캡처.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c41b954d-2ce8-4ed2-b38c-b2c3e45cd560/캡처.png)

Patch.exe를 실행해보면 위와같이 창이 하나 뜨고 flag값이 있어야 할 자리에 막 덧칠되어서 가려져있는 것을 볼 수 있다. 

# IDA Pro를 통한 분석

## IDA Pro를 통해 본 전체구조 및 main 함수 분석

![전체구조.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/396bf7e8-5382-41fe-98bb-03205c2f4f39/전체구조.png)

전체구조는 1) main에서 진입하고 2) 진행을 하다가 3)반복을 하고 4) 종료된다.

일직선으로 너무 길어서 한눈에 보기 힘들어 tab을 이용해 디컴파일 기능을 사용하였다.

![디컴파일한 결과.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/74e2e113-12a2-4bf6-96f0-2a40e7f9cc53/디컴파일한_결과.png)

디컴파일한 결과는 위와 같았다. 우리는 여기서 사용되는 함수들을 볼 수 있다.

1. LoadStringW(HINSTANCE hInstance(인스턴스 핸들), UINT uID(문자열의 리소스의 ID), LPTSTR lpBuffer(문자열을 읽을 버퍼), int nBufferMax(버퍼의 크기)) : 리소스에서 문자열을 읽어 지정한 버퍼lpBuffer에 채워준다. 
2. sub_1400032F0 
3. LoadIconW(HINSTANCE hInstance(아이콘 리소스를 갖고 있는 핸들), LPCTSTR lpIconName(읽을 아이콘 리소스를 지정하는 포인터)) : 표준 아이콘 또는 응용 프로그램의 리소스에 정의되어 있는 아이콘을 읽어온다. (선물 상자 모양의 아이콘이다)
4. LoadCursorW(HINSTANCE hInstance(커서 리소스를 갖고 있는 핸들), LPCTSTR lpCursorName(커서 리소스를 지정하는 포인터)) : 커서를 가져온다. 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/664a4018-9ab3-4cd0-af80-d9ff6840e1ba/Untitled.png)

1. RegisterClassExW(CONST WNDCLASS *lpWndClass(등록할 윈도우 클래스의 특성)) : 윈도우 클래스를 등록 
2. CreateWindowExW(LPCTSTR lpClassName(생성할 윈도우 클래스), LPCTSTR lpWindowName(윈도우 타이틀 바에 나타날 캡션 문자열), DWORD dwStyle(윈도우 스타일), int x, int y, int nWidth, int nHeight, HWND hWndParent(부모윈도우 또는 소유주 윈도우의 핸들), HMENU hMenu(오버랩드 윈도우나 팝업 윈도우의 경우 메뉴의 핸들), HANDLE hInstance(이 윈도우를 생성하는 인스턴스의 핸들), LPVOID lpParam(WM_CREATE메시지의 lParam으로 전달될 CREATESTRUCT 구조체를의 포인터)) : 윈도우 클래스와 이 함수의 인수 정보를 바탕으로 하여 윈도우 생성
3. GdiplusStartup :  gdi+를 사용하기 전에 초기화 해주는 함수
4. ShowWindow(HWND hWnd(대상윈도우 핸들), int nCmdShow(지정하고자 하는 보이기 상태)) :  윈도우의 보이기상태(보이기/숨기기/최대화/최소화/복구)를 지정
5. LoadAcceleratorsW(HINSTANCE *hInstance* , LPCTSTR *lpTableName(액셀러레이터 테이블의 이름 문자열 포인터* ) : 리소스에서 액셀러레이터(단축키) 테이블을 읽은 후 그 핸들값을 리턴  , 액셀러레이터는 Ctrl+P를 누르면 프린터 설정기능이 곧바로 실행되도록 하는 것과 같은 단축키를 의미
6. GetMessageW(LPMSG lpMsg(메시지를 받을 구조체), HWND hWnd(메시지를 받을 윈도우,이 윈도우로 보내지는 메시지를 조사), UINT wMsgFilterMin(조사할 메시지의 최소값), UINT wMsgFilterMax(조사할 메시지의 최대값)) : 호출한 스레드에서 메세지를 꺼내 lpMsg에 구조체에 채워준다. 호출 스레드의 메시지를 조사함.
7. TranslateMessage(CONST MSG *lpMsg(메시지구조체)) : lpMsg를 읽기만 하며 이 lpMsg는 GetMessage나 PeekMessage함수에 의해 읽혀진 것이다. 메시지 루프내에서 키보드 메시지를 문자 메시지로 변환하기 위한 목적으로만 사용한다.
8. DispatchMessageW(CONST MSG *lpmsg(메시지구조체)) : GetMessage가 읽은 메시지를 이 메시지를 처리할 윈도우로 보낸다. 

## 함수 분석

위 함수들을 보면 창이 뜨게 해주는 함수는 CreateWindowExW함수로 창을 만들어주고 ShowWindow함수로 창을 뜨게해주는 것이라고 추측할 수 있다. 

![showWindow실행시.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9d9af6d5-644b-46f3-858b-66d36432b57a/showWindow실행시.png)

실제로 bp를 걸고 한 줄씩 실행하면 showWindow함수를 실행하자마자 창이 뜨는 것을 확인할 수 있다. 그런데 여전히 flag값자리에는 글씨가 써져있다. CreateWindowExW전에 그럼 저 글씨를 써주는 함수가 있을 것이다. 그렇다면 후보는 LoadStringW,sub_1400032F0,LoadIconW,LoadCursorW인데 문자열, 아이콘, 커서를 가져오는 함수는 저 글씨를 쓸 수 없으므로 sub_1400032F0으로 글씨를 쓴다고 추측할 수 있다. 따라서 sub_1400032F0함수를 분석해야 한다.

## Sub_1400032F0 함수

sub_1400032F0함수도 어셈블리어 형태로는 구조를 한번에 담을 수 없어 tab을 하여 디컴파일 형태로 캡쳐하였다.

![sub_1400032F0.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/62c8c07b-1207-4d70-81c5-1fe8acd0ef80/sub_1400032F0.png)

switch문 형태로 이루어져 있는데 case:0xFu 부분을 보면 그리기에 핵심적인 함수를 볼 수 있다. 

BeginPaint 함수인데 이 함수는 그림을 그리기 위한 핸들을 리턴해주는 함수이다. 

gdipAlloc는 GDI+를 위해 메모리를 할당하는 함수이므로 이건 그림을 그리는 함수는 아니고

GdipCreatefromHDC함수도 GDI+객체 를 만드는 함수이므로 그림을 그리는 함수는 아니다.

그럼이제 sub_140002C40함수는 알수 없지만 이 이후에는 GdipDeleteGraphics,GdipFree로 그림을 그리는 GDI+가 해제되는걸 보아 sub_140002C40에 그림을 그리는 내용이 있을 것으로 추측된다.

따라서 sub_140002C40을 분석해본다.

## sub_140002C40

![sub_140002C40.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/dba00593-317c-4a7d-9f80-e289596e49f1/sub_140002C40.png)

수많은 함수들이 있는 것을 볼 수 있다.

그 중 sub_140002B80은 반복적으로 불러지고나머지 함수들은 각각 한번씩 호출되는 것을 보아 sub_140002B80부터 내용을 본다.

![sub_140002B80.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8ad37f25-ca76-46a9-8d46-8e7326bdbf5e/sub_140002B80.png)

sub_140002B80의 내용인데 GdipCreatePen1을 통해 펜을 만들고 GdipDrawLineI를 통해 선을 하나 긋는것을 알 수 있다. GdipSetSmoothingMode는 품질에 영향을 주는 함수이고 GdipDeletePen을 통해 펜을 없애서 그리기를 종료하는 것을 볼 수 있다.

sub_1400017A0의 내용을 확인하면 sub_140002B80과 다르게 조금 긴 것을 확인할 수 있다.

![sub_1400017A0.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2245265e-ea5d-4811-9f84-068c8edd61c6/sub_1400017A0.png)

보면 sub_140002B80과 다르게 펜을 만들고 선긋고 펜을 지우고, 펜을만들고 선긋고 펜을지우고를 반복하는 것을 볼 수 있다. 이 때 다시 patch.exe를 실행시켰을 때 나왔던 창을 생각해보면

![캡처.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/daf284b1-8b5d-4bdf-a910-2250b68eafbc/캡처.png)

저 덧칠되어있는 부분 뒤에는 글자가 숨겨져 있을 거라고 추측할 수 있다면 저 덧칠되어 있는 부분을 지운다면 뒤에 있는 글자가 나오지 않을까? 라는 추측이 가능하다. 

그리고 앞에 DH를 보면 알겠지만 D를 그리려면 최소 세 번의 직선을 그려야하므로 D를 그릴 때도 우리는 펜을 만들고 선긋고 펜을지우고를 여러번 반복했다고 연결할 수 있다.

따라서 flag값 위에 덧칠된 부분은 sub_140002B80함수로 하나의 직선을 긋는 함수를 여러번 호출하는 방식을 통해서 flag 값을 가린 것으로 생각할 수 있다.

그렇다면 sub_140002B80함수가 호출되었을 때 선을 긋지 않고 바로 리턴되게 하면 될 것이다.

    

![sub_140002B80 진입점.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ce03982e-4e67-44a1-8c24-8c56eb9511b5/sub_140002B80_진입점.png)

이게 sub_140002B80의 진입점인데 이 진입점으로 들어오자마자 ret을 해서 아예 실행이 되지 않도록 바꿀 것이다. 

![edit-patch.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ec5366bd-5daa-417d-b290-f942b5749212/edit-patch.png)

Edit-Patch program-Assemble 을 첫 위치를 클릭하고 실행하면 다음과 같이 창이 뜬다.

![mov.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c0f09dcf-931e-4fde-9938-27c8e016ddb1/mov.png)

이 부분을 ret으로 바꾸어주면 함수에 진입하자마자 다시 자신을 호출한 위치로 돌아갈 것이다.

![ret.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/03897e7f-8655-47f2-972e-a7206ac50c1f/ret.png)

![변경저장.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3cfecef4-c466-4ab4-abc1-7a667bcaafee/변경저장.png)

ret로 변경해주고 나면 우리가 패치한 부분을 적용해야한다. 따라서 적용하기 위하여 Edit - Patch program - Apply patches to input file을 클릭해준다.

![apply patch.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ce4fa0f7-497d-4216-bed0-0f644c50cf29/apply_patch.png)

그럼 위와같은 창이 뜨는데 OK를 눌러서 패치를 적용해주면 된다.

그럼 flag값 위에 덧칠된 직선을 없애주는 패치를 적용해주었으니 이제 다시 실행하여 flag값을 찾으면 된다. F9를 통해 다시 실행하면 flag값을 얻을 수 있다.
