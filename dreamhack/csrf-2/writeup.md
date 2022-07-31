https://honey-push-30b.notion.site/CSRF-2-4956e63d376849dbbad40d1bbf4cdf2f

# 문제파일 다운로드

CSRF-2 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template, make_response, redirect, url_for
from selenium import webdriver
import urllib
import os

app = Flask(__name__)
app.secret_key = os.urandom(32)

try:
    FLAG = open("./flag.txt", "r").read()
except:
    FLAG = "[**FLAG**]"

users = {
    'guest': 'guest',
    'admin': FLAG
}

session_storage = {}

def read_url(url, cookie={"name": "name", "value": "value"}):
    cookie.update({"domain": "127.0.0.1"})
    try:
        options = webdriver.ChromeOptions()
        for _ in [
            "headless",
            "window-size=1920x1080",
            "disable-gpu",
            "no-sandbox",
            "disable-dev-shm-usage",
        ]:
            options.add_argument(_)
        driver = webdriver.Chrome("/chromedriver", options=options)
        driver.implicitly_wait(3)
        driver.set_page_load_timeout(3)
        driver.get("http://127.0.0.1:8000/")
        driver.add_cookie(cookie)
        driver.get(url)
    except Exception as e:
        driver.quit()
        print(str(e))
        # return str(e)
        return False
    driver.quit()
    return True

def check_csrf(param, cookie={"name": "name", "value": "value"}):
    url = f"http://127.0.0.1:8000/vuln?param={urllib.parse.quote(param)}"
    return read_url(url, cookie)

@app.route("/")
def index():
    session_id = request.cookies.get('sessionid', None)
    try:
        username = session_storage[session_id]
    except KeyError:
        return render_template('index.html', text='please login')

    return render_template('index.html', text=f'Hello {username}, {"flag is " + FLAG if username == "admin" else "you are not an admin"}')

@app.route("/vuln")
def vuln():
    param = request.args.get("param", "").lower()
    xss_filter = ["frame", "script", "on"]
    for _ in xss_filter:
        param = param.replace(_, "*")
    return param

@app.route("/flag", methods=["GET", "POST"])
def flag():
    if request.method == "GET":
        return render_template("flag.html")
    elif request.method == "POST":
        param = request.form.get("param", "")
        session_id = os.urandom(16).hex()
        session_storage[session_id] = 'admin'
        if not check_csrf(param, {"name":"sessionid", "value": session_id}):
            return '<script>alert("wrong??");history.go(-1);</script>'

        return '<script>alert("good");history.go(-1);</script>'

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    elif request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        try:
            pw = users[username]
        except:
            return '<script>alert("not found user");history.go(-1);</script>'
        if pw == password:
            resp = make_response(redirect(url_for('index')) )
            session_id = os.urandom(8).hex()
            session_storage[session_id] = username
            resp.set_cookie('sessionid', session_id)
            return resp 
        return '<script>alert("wrong password");history.go(-1);</script>'

@app.route("/change_password")
def change_password():
    pw = request.args.get("pw", "")
    session_id = request.cookies.get('sessionid', None)
    try:
        username = session_storage[session_id]
    except KeyError:
        return render_template('index.html', text='please login')

    users[username] = pw
    return 'Done'

app.run(host="0.0.0.0", port=8000)
```

여기서 @app.route가 써져 있는 곳은 페이지이고 각 함수들을 다음과 같이 살펴보자 

1. check_csrf함수
2. read_url함수
3. index 함수
4. vuln 함수
5. login 함수
6. flag 함수
7. change_password 함수

다음 코드내용은 아래와 같다.

```python
users = {
    'guest': 'guest',
    'admin': FLAG
}

session_storage = {}
```

ID: guest pw: guest

ID: admin pw : FLAG 로 두명의 유저가 있으며 session 저장소에는 비어있는 상태다.

# Check_csrf 함수

```python
def check_csrf(param, cookie={"name": "name", "value": "value"}):
    url = f"http://127.0.0.1:8000/vuln?param={urllib.parse.quote(param)}"
    return read_url(url, cookie)

```

name과 value값을 쿠키로 가지고 param으로 받은 값을 param의 값으로 전달하여 read_url 함수를 호출해 vuln페이지를 호출한다.

# Read_url 함수

```python
def read_url(url, cookie={"name": "name", "value": "value"}):
    cookie.update({"domain": "127.0.0.1"})
    try:
        options = webdriver.ChromeOptions()
        for _ in [
            "headless",
            "window-size=1920x1080",
            "disable-gpu",
            "no-sandbox",
            "disable-dev-shm-usage",
        ]:
            options.add_argument(_)
        driver = webdriver.Chrome("/chromedriver", options=options)
        driver.implicitly_wait(3)
        driver.set_page_load_timeout(3)
        driver.get("http://127.0.0.1:8000/")
        driver.add_cookie(cookie)
        driver.get(url)
    except Exception as e:
        driver.quit()
        print(str(e))
        # return str(e)
        return False
    driver.quit()
    return True
```

서버가 돌아가고 있는 127.0.0.1의 쿠키로 업데이트한다. 그리고 driver.get(url)을 통해 매개변수로 받은 url로 실행 한다고 보면된다.

# Index 함수

```python
@app.route("/")
def index():
    session_id = request.cookies.get('sessionid', None)
    try:
        username = session_storage[session_id]
    except KeyError:
        return render_template('index.html', text='please login')

    return render_template('index.html', text=f'Hello {username}, {"flag is " + FLAG if username == "admin" else "you are not an admin"}')

```

/에 접속했을 때 index.html을 화면에 보여주는 함수인데 sessionid를 가져오고 session_storage에 저장되어있는 session_id와 매핑되어있는 값을 username에 저장한다. 그리고 이 때 username이 admin이면 FLAG값을 출력해준다.

![index.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/648709f1-393a-4db5-a5b0-2b50df716aee/index.png)

즉 실제로 접속했을 때 위와 같은 페이지가 나오고 이때가 index 페이지다.

# vuln 함수

```python
@app.route("/vuln")
def vuln():
    param = request.args.get("param", "").lower()
    xss_filter = ["frame", "script", "on"]
    for _ in xss_filter:
        param = param.replace(_, "*")
    return param
```

xss_filter로 frame,script,on 이 param으로 전달한 값에 존재할 시에 *로 변환하여 공격을 막은 모습이다. 따라서 frame, script, on은 사용할 수 없다.  

![vuln.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/63724448-fe7d-4e6e-8c96-d6d396f1b4e9/vuln.png)

vuln페이지에 들어가보면 위와 같이 /vuln?param=<script>alert(1)</script>가 기본값으로 되어있고 script가 *로 치환되어 <**>alert(1)로 나온 것을 볼 수 있다.

그렇기에 이번에는 script, frame, on 은 포함되지 않은 상태로 시도해야 하는 것이 핵심이다.

# flag 함수

```python
@app.route("/flag", methods=["GET", "POST"])
def flag():
    if request.method == "GET":
        return render_template("flag.html")
    elif request.method == "POST":
        param = request.form.get("param", "")
        session_id = os.urandom(16).hex()
        session_storage[session_id] = 'admin'
        if not check_csrf(param, {"name":"sessionid", "value": session_id}):
            return '<script>alert("wrong??");history.go(-1);</script>'

        return '<script>alert("good");history.go(-1);</script>'
```

GET으로 요청하면 flag 화면을 리턴해주고 POST로 요청하는 경우 사용자가 입력한 param값을 param에 저장하고 session_id를 생성하여 이 sesssion_id와 admin을 매핑한다. check_csrf에 이 session_id값과 param에 들어있는 값을 담아서 check_csrf 함수를 호출한다. 

이 때 check_csrf함수는 param으로 받은값을 vuln 페이지 뒤의 매개변수로 넣어 read_url로 url을 전달하는 함수고 read_url은 호스트의 쿠키값을 가지고 전달받은 url을 실행하는 함수다.

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b9615648-6692-4fce-9c8f-847afb42d422/flag.png)

# login 함수

```python
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    elif request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        try:
            pw = users[username]
        except:
            return '<script>alert("not found user");history.go(-1);</script>'
        if pw == password:
            resp = make_response(redirect(url_for('index')) )
            session_id = os.urandom(8).hex()
            session_storage[session_id] = username
            resp.set_cookie('sessionid', session_id)
            return resp 
        return '<script>alert("wrong password");history.go(-1);</script>'
```

GET으로 이 페이지가 열렸을 때는 login 페이지가 열린다. POST로 이 페이지를 요청했을 때는 사용자가 입력한 username과 password를 받아서 user 딕셔너리에 있는지 검사한다.(guest/guest,admin/flag) 만약 있으면 session_id를 생성하고 session_id와 username을 매핑한다.

![login.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0c01be90-6c7e-4391-b0a6-1982fbf808e7/login.png)

# change_password 함수

```python
@app.route("/change_password")
def change_password():
    pw = request.args.get("pw", "")
    session_id = request.cookies.get('sessionid', None)
    try:
        username = session_storage[session_id]
    except KeyError:
        return render_template('index.html', text='please login')

    users[username] = pw
    return 'Done'
```

/change_password 이며 이 페이지는 사용자로부터 pw를 get 형태의 인자로 전달받는다.(즉 url에 
”/change_password?pw=”형태로 입력받는다.)

이 때 쿠키에서 session_id 값을 읽어들이는데 이 session_id 값에 맞는 매핑되어있는 username을 session_storage에서 가져오고 이 username의 패스워드를 인자로 전달한 pw에 담긴 값으로 변경한다.

# 문제 해결

다음의 조건을 준수하면 flag값을 찾을 수 있다.

1. /flag 페이지에서 POST로 요청을 보내면 **session_id를 admin**으로 설정하고 url을 check_csrf와 read_url함수를 거쳐서 vuln페이지 뒤의 param으로 보내서 vuln페이지에서 내가 원하는 요청을 로컬호스트(127.0.0.1)의 권한으로 실행 시킬수 있다. 
2. 이 때 /flag에서 POST 요청을 통해 change_password 함수를 실행시킨다면 session_id와 연결된 username이 admin으로 설정되어 있기 때문에 admin의 패스워드를 변경할 수 있다. 
3. 단 이 때 script, frame, on은 사용되면 안된다.

즉 <img src=“/change_password?pw=admin”>를 flag에 params로 전달하자.

![정답.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/87232a06-454c-4b3f-b803-c7dc33c30a91/.png)

flag 페이지에서 session_id를 생성하여 admin과 매핑시킨 후 param과 함께 session_id를 담아 check_csrf함수를 거치고 read_url 함수를 거쳐 로컬호스트에서는 이 img 태그를 실행하기 때문에 저 /change_password?pw=admin에 접근하게 되고 이 때 session_id와 매핑된 username이 admin이므로 admin의 패스워드가 admin으로 변경된다. 

![다시로그인.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d897821a-4b8b-4fb8-a661-be86e9c49a0d/.png)

따라서 이제 admin과 변경한 패스워드인 admin으로 로그인을 해주면

![끝.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c742374c-5099-4ee1-a8d1-eb671534c34f/.png)

****DH{c57d0dc12bb9ff023faf9a0e2b49e470a77271ef} 를 얻을 수 있다.****
