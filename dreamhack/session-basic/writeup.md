https://honey-push-30b.notion.site/Session-basic-462c4e7315a54f64866dd914daa41b94 에서 사진깨짐 없이 볼 수 있다.

# 문제파일 다운로드

![캡처.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/651ee529-fe18-4379-a461-8d860cd4ba15/캡처.png)

Session-basic 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template, make_response, redirect, url_for

app = Flask(__name__)

try:
    FLAG = open('./flag.txt', 'r').read()
except:
    FLAG = '[**FLAG**]'

users = {
    'guest': 'guest',
    'user': 'user1234',
    'admin': FLAG
}

# this is our session storage 
session_storage = {
}

@app.route('/')
def index():
    session_id = request.cookies.get('sessionid', None)
    try:
        # get username from session_storage 
        username = session_storage[session_id]
    except KeyError:
        return render_template('index.html')

    return render_template('index.html', text=f'Hello {username}, {"flag is " + FLAG if username == "admin" else "you are not admin"}')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    elif request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        try:
            # you cannot know admin's pw 
            pw = users[username]
        except:
            return '<script>alert("not found user");history.go(-1);</script>'
        if pw == password:
            resp = make_response(redirect(url_for('index')) )
            session_id = os.urandom(32).hex()
            session_storage[session_id] = username
            resp.set_cookie('sessionid', session_id)
            return resp 
        return '<script>alert("wrong password");history.go(-1);</script>'

@app.route('/admin')
def admin():
    # what is it? Does this page tell you session? 
    # It is weird... TODO: the developer should add a routine for checking privilege 
    return session_storage

if __name__ == '__main__':
    import os
    # create admin sessionid and save it to our storage
    # and also you cannot reveal admin's sesseionid by brute forcing!!! haha
    session_storage[os.urandom(32).hex()] = 'admin'
    print(session_storage)
    app.run(host='0.0.0.0', port=8000)
```

여기서 주요 부분은 네가지이다.  

1. Flag값을 가져와서 users 딕셔너리에 ‘admin’:FLAG로 admin의 패스워드를 생성한 것과 ‘guest’:’guest’와 같은 다른 아이디 비밀번호가 공개되어있는 것
2. index 함수
3. login함수
4. admin함수이다.

main함수같은 경우에는 session_storage의 임의의값(session_id)가 admin임을 확인할 수 있다. 즉 매번 새로운 값이 admin의 session_id이기 때문에 이 값은 정해져있지 않다.

## index 함수

```python
@app.route('/')
def index():
    session_id = request.cookies.get('sessionid', None)
    try:
        # get username from session_storage 
        username = session_storage[session_id]
    except KeyError:
        return render_template('index.html')

    return render_template('index.html', text=f'Hello {username}, {"flag is " + FLAG if username == "admin" else "you are not admin"}')

```

사용자의 쿠키에서 sessionid를 가져와 session_id에 저장하고 session_storage에서 session_id와 일치하는 username을 찾는다.  이 때 username이 admin인 경우 FLAG값을 출력해준다. 즉 admin으로 로그인 하면 첫 페이지에 FLAG가 뜨는 것을 확인할 수 있다.

@app.route(’/’)라는 것은 현재 접속 정보의 경우[http://host1.dreamhack.games:22626](http://host1.dreamhack.games:22626/)인데 여기에 path로 /를 붙인 [http://host1.dreamhack.games:22626/](http://host1.dreamhack.games:22626/) 가 index라고 보면 된다.

## login 함수

```python
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    elif request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        try:
            # you cannot know admin's pw 
            pw = users[username]
        except:
            return '<script>alert("not found user");history.go(-1);</script>'
        if pw == password:
            resp = make_response(redirect(url_for('index')) )
            session_id = os.urandom(32).hex()
            session_storage[session_id] = username
            resp.set_cookie('sessionid', session_id)
            return resp 
        return '<script>alert("wrong password");history.go(-1);</script>'
```

이 또한 login함수로 GET의 경우 login.html을 리턴하고 POST의 경우는 사용자가 입력한 username과 password를 이용해서 users 딕셔너리에 username과 일치하는 pw를 가져와 사용자가 입력한 password와 같은지를 체크한다.

만약 사용자가 입력한 password와 서버에 저장된 username과 일치하는 pw가 같다면 사용자에게 session_id를 생성해준다.

## admin 함수

```python
@app.route('/admin')
def admin():
    # what is it? Does this page tell you session? 
    # It is weird... TODO: the developer should add a routine for checking privilege 
    return session_storage
```

이 문제의 핵심인 admin함수이다. 이 함수의 @app.route(’/admin’)을 보면 이 함수는 [http://host1.dreamhack.games:22626](http://host1.dreamhack.games:22626/)/admin임을 알 수 있다. 이 admin함수의 경우 session_stroage를 반환해 준다. 즉 admin의 세션도 알 수 있고 지금 로그인한 계정의 세션도 저장된 내역을 다 알려준다는 것이다.

따라서 시나리오는 다음과 같이 흘러간다.

1. admin페이지에서 session_storage에 저장되어 있는 admin의 세션 id를 메모한다.
2. guest 아이디로 로그인한다.
3. 세션 값을 admin의 세션 값으로 바꾼다.
4. 새로 고침하면 index 페이지에서 admin으로 로그인한 결과인 FLAG값이 나온다.

### 1. admin 페이지에서 session_id 복사

![admin session id.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/06c0a6a4-ebfe-4aa4-a765-c240e3db2cac/admin_session_id.png)

admin 페이지에서 admin의 session_id를 복사한다. 원래는 이렇게 많지 않은데 이것저것 로그인 하느라 session_storage에 저장된 값이 많아졌다... 이중에 admin session_id만 보면 된다.

### 2. guest 아이디로 로그인

users에 있는 guest,guest로 로그인하고 나서 F12를 눌러 개발자 도구를 열어 application 부분에서 session id를 확인한다.

![수정전.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3b38916f-cbd2-4e4a-96f7-b66e598e97df/수정전.png)

이제 이 session_id의 Value값을 admin의 session_id 값으로 바꾸어준다.

### 3. session_id값 변경

![수정후.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/48f4c90c-0d90-486d-bb5c-08e939722531/수정후.png)

session_id값을 변경해주었다. 이제 새로고침을 하면 admin으로 로그인 한상태가 된다.

### 4.새로고침 후 flag값 확인

![flag값.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/498afe9f-8670-4336-8091-440f41e02065/flag값.png)

새로고침을 하면 flag값을 얻을 수 있다.

![정답.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/96bc9e03-8812-4886-a479-ccba2676fec2/정답.png)
