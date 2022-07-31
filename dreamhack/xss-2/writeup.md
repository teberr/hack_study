https://honey-push-30b.notion.site/xss-2-0ef120feccb54432a1b28699cf13817c

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7a727e49-bfa7-48e3-bbaf-96cb24c59f00/_.png)

Xss-2 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

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

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/vuln")
def vuln():
    return render_template("vuln.html")

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

![index.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/923c6aa2-6454-4d85-be13-ebd8571d9a9e/index.png)

즉 실제로 접속했을 때 위와 같은 페이지가 나오고 이때가 index 페이지다.

# vuln 함수

```python
@app.route("/vuln")
def vuln():
    return render_template("vuln.html")
```

xss-1 문제와 달라진 부분이다. 예전에는 get으로 받은 부분을 아무런 검증 없이 보여줬다면 이번엔 render_template으로 한번 검증을 거친다. 

![vuln(1).PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/04e8b2b9-e63f-4f2a-b90f-db99ee2fd03c/vuln(1).png)

vuln페이지에 들어가보면 위와 같이 /vuln?param=<script>alert(1)</script>가 기본값으로 되어있고 param의 값인 <script>alert(1)</script>가 실행이 되지 않는다는 것을 확인할 수 있다.

그렇기에 이번에는 페이지 소스보기를 통해서 param으로 받은 값이 어떤식으로 진행되는지 확인해야 한다.

![페이지 소스보기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b7f06abc-a14b-4e16-8ac4-970c741d195c/_.png)

vuln 페이지에서 마우스 우클릭을 통해 페이지 소스보기 창을 열어 확인한 결과

```python
<div id='vuln'></div>
    <script>var x=new URLSearchParams(location.search); document.getElementById('vuln').innerHTML = x.get('param');</script>
```

위와 같은 부분을 확인할 수 있다.

이는 param에 들어온 값을 innerHTML을 이용해서 내부적으로 실행한다는 것인데 이 innerHTML로 인해서 <script>태그가 먹히지 않은 것이다. 

- innerHTML의 특징은 입력한 값을 html 코드로 인식한다는 점 (innerText와 다른 핵심)
- innerHTML은 <script>태그를 막는다는 점

그래서 vuln 페이지를 이용해서 호스트의 쿠키 값(FLAG)을 얻어야 하는데 내가 직접 이 param에 document.cookie를 호출하게 되면 호스트가 아닌 ‘나’의 쿠키 값이 나오게 되므로 호스트 측에서 이 페이지에 접근하게 하여 read_url함수를 통해 실행되게 해야한다. 단 xss-1과는 다르게 <script>태그는 사용할 수 없다는 것이 핵심이다.

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

 

![memo페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/41866e71-4105-424c-8747-cdc854a93a6d/memo.png)

실제로 접속해보면 /memo?memo=hello로 되어있기에 hello를 화면에 보여준다. 

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

즉 flag 함수의 POST를 이용하여 호스트의 쿠키값을 <script>태그를 제외한 방법으로 알아내면 된다.

![답안.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/67fc0f62-9ecc-418a-a8cc-d192620774ab/.png)

이 페이지에서 POST로 보내는 방법은 빈칸에 입력값을 넣고 ‘제출’버튼을 누르면 POST로 보내진다. (python의 request모듈을 이용해 코드를 직접 작성해도 된다.)

# 문제 해결

다음과 같은 과정을 통해서 문제를 해결하면 된다.

1. flag 페이지에서 입력한 값은 연결된 호스트의 쿠키(FLAG)값을 가지고 vuln페이지에 param으로 전달되기 때문에 스크립트를 이용해서 호스트의 쿠키(FLAG)를 알아내야 한다.
2. 보통 호출하는 측의 쿠키를 알아내기 위해서는 document.cookie를 사용하는데 문제는 이 값을 어디에 써놓을 수 있는 방법이 없으면 blind로 한글자씩 비교해 가며 알아내야 한다.
3. 하지만 이 문제에서는 원하는 값을 memo 페이지에 memo에 저장하여 전달하면 화면에 띄워주기 때문에 document.cookie값을 memo에 전달해 주면된다.

xss-1과 똑같은 구조이지만 한가지 고려해야 하는 점은 <script>태그를 사용하면 안된다는 것. 그래서 innerHTML Xss를 검색해서 여러 곳을 참고했지만 결국 최종적으로 인용한건 아래 사이트다.

[https://falsy.me/웹-취약점-공격-방법인-xss-csrf에-대하여-간단하게-알아보/](https://falsy.me/%EC%9B%B9-%EC%B7%A8%EC%95%BD%EC%A0%90-%EA%B3%B5%EA%B2%A9-%EB%B0%A9%EB%B2%95%EC%9D%B8-xss-csrf%EC%97%90-%EB%8C%80%ED%95%98%EC%97%AC-%EA%B0%84%EB%8B%A8%ED%95%98%EA%B2%8C-%EC%95%8C%EC%95%84%EB%B3%B4/)

이를 참고해서 만든 최종 답안은

<img src="#" onerror="window.location.href='/memo?memo=' + document.cookie;">이다

img 태그를 이용한건데 img src(이미지 경로)를 #으로 해서 무조건 에러가 뜨게 만든 뒤 그 에러를 window.location.href를 이용해 /memo로 해서 메모 페이지로 넘긴다음 memo 파라미터의 값을 호스트의 cookie 값으로 설정해주었다.

![답안.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0aaa9e5a-4153-48d2-9286-37c66f1c9063/.png)

img 태그를 입력해주고 제출을 해준다.

![정답.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/733b1a3b-444d-4259-b4cd-8ee9c3f4331e/.png)

그리고 나서 memo페이지에 다시 들어가보게 되면 FLAG값인 `flag=DH{3c01577e9542ec24d68ba0ffb846508f}`이 존재하는 것을 볼 수 있다.
