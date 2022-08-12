https://honey-push-30b.notion.site/web-misconf-1-18fb5378b151479ebec694603b049d78

# 문제 설명

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e55460c5-97a3-4628-8188-499e1f05fc32/Untitled.png)

기본 설정을 사용한 서비스로 로그인하면 플래그를 볼 수 있다.

# 문제 풀이

![admin입력.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2832b9a3-2b33-4082-86b5-ea28627d0cf7/admin%EC%9E%85%EB%A0%A5.png)

아무런 설명 없이 로그인 창이 뜬다. 기본 설정을 사용했다고 문제 설명이 되어 있으므로 admin/admin을 입력해준다.

![로그인.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/923f34c8-19a2-4297-b09c-1b93b045e19d/%EB%A1%9C%EA%B7%B8%EC%9D%B8.png)

admin/admin, guest/guest root/root 등 기본적으로 쓰는 것들을 시도하려 했는데 바로 패스워드 변경창으로 이동해버렸다. admin/admin이 로그인 된것을 알 수 있다.

![답.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/48da4477-364f-41e2-a8a9-df50af26687c/%EB%8B%B5.png)

로그인 하였으므로 좌측의 가장 아래 설정인 Server Admin의 Setting에서 찾아보면 플래그 값인 DH{default_account_is very dangerous}를 찾을 수 있다.
