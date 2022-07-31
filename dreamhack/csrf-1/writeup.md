https://honey-push-30b.notion.site/CSRF-1-855d698c5ce249d995bb29d38743a59d
# CSRF-1

# 문제파일 다운로드

CSRF-1 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template
from selenium import webdriver
import urllib
import os

app = Flask(__name__)
app.secret_key = os.urandom(32)

try:
    FLAG = open("./flag.txt", "r").read()
except:
    FLAG = "[**FLAG**]"

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
    return render_template("index.html")

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

memo_text = ""

@app.route("/memo")
def memo():
    global memo_text
    text = request.args.get("memo", None)
    if text:
        memo_text += text
    return render_template("memo.html", memo=memo_text)

@app.route("/admin/notice_flag")
def admin_notice_flag():
    global memo_text
    if request.remote_addr != "127.0.0.1":
        return "Access Denied"
    if request.args.get("userid", "") != "admin":
        return "Access Denied 2"
    memo_text += f"[Notice] flag is {FLAG}\n"
    return "Ok"

app.run(host="0.0.0.0", port=8000)
```

여기서 @app.route가 써져 있는 곳은 페이지이고 각 함수들을 다음과 같이 살펴보자 

1. check_csrf함수
2. read_url함수
3. index 함수
4. vuln 함수
5. memo 함수
6. flag 함수
7. admin_notice_flag 함수

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
        # return str(e)
        return False
    driver.quit()
    return True
```

서버가 돌아가고 있는 127.0.0.1의 쿠키로 업데이트한다. 서버측의 쿠키에는 FLAG가 들어있기 떄무에 이 read_url 함수를 통해서 서버측의 쿠키를 갖게 할 수 있다. 그리고 driver.get(url)을 통해 매개변수로 받은 url로 실행 한다고 보면된다.

# Index 함수

```python
@app.route("/")
def index():
    return render_template("index.html")
```

/에 접속했을 때 index.html을 화면에 보여주는 함수이다.

![index.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/923c6aa2-6454-4d85-be13-ebd8571d9a9e/index.png)

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

![vuln 페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/04e0f449-80dd-40fa-b7b9-0dcc3d6a1299/vuln_.png)

vuln페이지에 들어가보면 위와 같이 /vuln?param=<script>alert(1)</script>가 기본값으로 되어있고 script가 *로 치환되어 <**>alert(1)로 나온 것을 볼 수 있다.

그렇기에 이번에는 script, frame, on 은 포함되지 않은 상태로 시도해야 하는 것이 핵심이다.

# memo 함수

```python
@app.route("/memo")
def memo():
    global memo_text
    text = request.args.get("memo", None)
    if text:
        memo_text += text
    return render_template("memo.html", memo=memo_text)
```

따로 특별한 건 없고 memo_text에 있는 값에다가 memo에 담긴 값을 덧붙여서 화면에 보여주는 함수이다.

실제로 접속해보면 /memo?memo=hello로 되어있기에 hello를 화면에 보여준다. 

![메모.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e7cee7c4-2e49-4ad3-a798-5393a375be4b/.png)

# flag 함수

```python
@app.route("/flag", methods=["GET", "POST"])
def flag():
    if request.method == "GET":
        return render_template("flag.html")
    elif request.method == "POST":
        param = request.form.get("param", "")
        if not check_csrf(param):
            return '<script>alert("wrong??");history.go(-1);</script>'

        return '<script>alert("good");history.go(-1);</script>'
```

GET으로 이 페이지가 열렸을 때는 flag 페이지가 열린다. POST로 이 페이지를 요청했을 때는 param에 들어있는 값을 담아서 check_csrf 함수를 실행한다.

이 때 check_csrf함수는 param으로 받은값을 read_url로 전달하는 함수고 read_url은 호스트의 쿠키값을 가지고 전달받은 url을 실행하는 함수다.

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/05a184d3-5496-4cb1-8bd0-5410335a2430/flag.png)

이 페이지에서 POST로 보내는 방법은 빈칸에 입력값을 넣고 ‘제출’버튼을 누르면 POST로 보내진다. (python의 request모듈을 이용해 코드를 직접 작성해도 된다.)

# admin_notice_flag 함수

```python
@app.route("/admin/notice_flag")
def admin_notice_flag():
    global memo_text
    if request.remote_addr != "127.0.0.1":
        return "Access Denied"
    if request.args.get("userid", "") != "admin":
        return "Access Denied 2"
    memo_text += f"[Notice] flag is {FLAG}\n"
    return "Ok"
```

/admin/notice_flag 이며 이 페이지에 접속했을 때의 ip주소가 127.0.0.1 즉 호스트가 아니면 접근이 거부당하고 127.0.0.1이더라도 get으로 받은 파라미터 userid의 값이 admin이 아니라면 접근이 거부된다. 

![notice_flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/83d6749a-26d0-4ea7-b37f-7ba4cdff3d83/notice_flag.png)

그냥 접속하게 되면 127.0.0.1에서 접속한게 아니기 때문에 Access Denied가 뜬다.

만약 127.0.0.1에서 접속했고 get으로 받은 파라미터 userid의 값이 admin이라면 memo_text에 FLAG값을 추가해준다.

즉 이 함수를 이용해서 flag값을 memo페이지에 출력할 수 있다.

# 문제 해결

다음의 조건을 준수하면 flag값을 찾을 수 있다.

1. /admin/notice_flag 페이지에 userid 파라미터 값을 admin으로 보내줘야 한다.
    1. 즉 get으로 보내므로 /admin/notice_flag?userid=admin 로 보내줘야한다.
2. “/admin/notice_flag?userid=admin”을 127.0.0.1 즉 서버측에서 실행해줘야한다.
3. Read_url 함수는 127.0.0.1에서 전달받은 url을 실행시키는 함수이며 이는 flag에서 post로 보내준 param이다.
4. 단 이 때 script, frame, on은 사용되면 안된다.

즉 <img src=“/admin/notice_flag?userid=admin”>를 flag에 params로 전달하자.

![flag에 태그넣기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/63f1166e-9c61-4b6d-92ea-21a7d05c5b04/flag_.png)

check_csrf함수를 거치고 read_url 함수를 거쳐 로컬호스트에서는 이 img 태그를 실행하기 때문에 저 /admin/notice_flag?userid=admin에 접근하게 되고 memo에 flag값이 써지게 된다.

![답안.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/25aab546-1ebd-4eaf-9558-ab15744c02b4/.png)

`[Notice] flag is DH{11a230801ad0b80d52b996cbe203e83d}` 의 값을 얻어냈다.
