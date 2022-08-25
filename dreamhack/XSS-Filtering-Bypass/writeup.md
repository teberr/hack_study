https://honey-push-30b.notion.site/XSS-Filtering-Bypass-5da1541d6e484e258aed5db32469eae3

# 문제 파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/489cc9ee-a2a9-4baf-81b9-526af319cd8b/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

Xss Filtering Bypass 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

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
        # return str(e)
        return False
    driver.quit()
    return True

def check_xss(param, cookie={"name": "name", "value": "value"}):
    url = f"http://127.0.0.1:8000/vuln?param={urllib.parse.quote(param)}"
    return read_url(url, cookie)

def xss_filter(text):
    _filter = ["script", "on", "javascript"]
    for f in _filter:
        if f in text.lower():
            text = text.replace(f, "")
    return text

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/vuln")
def vuln():
    param = request.args.get("param", "")
    param = xss_filter(param)
    return param

@app.route("/flag", methods=["GET", "POST"])
def flag():
    if request.method == "GET":
        return render_template("flag.html")
    elif request.method == "POST":
        param = request.form.get("param")
        if not check_xss(param, {"name": "flag", "value": FLAG.strip()}):
            return '<script>alert("wrong??");history.go(-1);</script>'

        return '<script>alert("good");history.go(-1);</script>'

memo_text = ""

@app.route("/memo")
def memo():
    global memo_text
    text = request.args.get("memo", "")
    memo_text += text + "\n"
    return render_template("memo.html", memo=memo_text)

app.run(host="0.0.0.0", port=8000)
```

여기서 @app.route가 써져 있는 곳은 페이지이고 각 함수들을 다음과 같이 살펴보자 

1. check_xss함수
2. read_url함수
3. index 함수
4. vuln 함수
5. memo 함수
6. flag 함수
7. xss_filter함수

# Check_xss 함수

```python
def check_xss(param, cookie={"name": "name", "value": "value"}):
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

# vuln 함수

```python
@app.route("/vuln")
def vuln():
    param = request.args.get("param", "")
    param = xss_filter(param)
    return param
```

get으로 param의 값을 받아오고 그대로 띄워주는데 띄워주기전 xss_filter로 한번 검증을 한다.

# memo 함수

```python
@app.route("/memo")
def memo():
    global memo_text
    text = request.args.get("memo", "")
    memo_text += text + "\n"
    return render_template("memo.html", memo=memo_text)
```

따로 특별한 건 없고 memo_text에 있는 값에다가 memo에 담긴 값을 덧붙여서 화면에 보여주는 함수이다.

# flag 함수

```python
@app.route("/flag", methods=["GET", "POST"])
def flag():
    if request.method == "GET":
        return render_template("flag.html")
    elif request.method == "POST":
        param = request.form.get("param")
        if not check_xss(param, {"name": "flag", "value": FLAG.strip()}):
            return '<script>alert("wrong??");history.go(-1);</script>'

        return '<script>alert("good");history.go(-1);</script>'
```

GET으로 이 페이지가 열렸을 때는 flag 페이지가 열린다. POST로 이 페이지를 요청했을 때는 param에 들어있는 값을 담아서 check_xss 함수를 실행한다.

이 때 check_xss함수는 param으로 받은값을 read_url로 전달하는 함수고 read_url은 호스트의 쿠키값을 가지고 전달받은 url을 실행하는 함수다.

## Xss_filter 함수

```python
def xss_filter(text):
    _filter = ["script", "on", "javascript"]
    for f in _filter:
        if f in text.lower():
            text = text.replace(f, "")
    return text
```

vuln에 전달하기 전 param 값을 한번 검증하는 필터인데 xss에 주로 사용되는 script, on ,javascript 문자열이 있으면 한번 없애주는 것을 볼 수 있다.

# 문제 해결

XSS_filter의 필터링 방식에서는 큰 취약점이 있는데 바로 oonn에서 on을 한번 치환해주고 나면 새롭게 on이 생기는데도 이를 알아차리지 못하고 지나간다는 점이다.  따라서 이를 이용해서 script 를 scrscriptipt로 써주면 내부 script 가 필터링 되고 script가 남도록 하면 원하는 스크립트를 실행시킬 수 있다.

![exploit예시.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0a03c3bd-4de5-4bcf-8363-9ea00551f57c/exploit%EC%98%88%EC%8B%9C.png)

script가 제거되고 나면 <script>alert(1)</script>가 되어 필터링을 우회한 것을 볼 수 있다.

즉 필터링 없이 해야 하는 구문이 <script>location.href=
”/memo?memo=”+document.cookie</script>이면 여기서 script와 location에 들어있는 on을 필터링이후에도 남아있도록 써주면 된다.

![exploit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9de2fbf6-7141-45eb-b102-ab5a9b483289/exploit.png)

즉<scrscriptipt>locatioonn.href=”/memo?memo=”+document.cookie</scrscriptipt>를 통하여 필터링을 우회할 수 있다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/87dad707-94bd-4ef3-be95-3ca46ecd6ecf/%EC%84%B1%EA%B3%B5.png)

`flag=DH{81cd7cb24a49ad75b9ba37c2b0cda4ea}`값이 올바르게 출력된 것을 확인할 수 있다.
