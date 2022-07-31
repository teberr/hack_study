https://honey-push-30b.notion.site/xss-1-37f9819a398b466387c0edae37f2cd77 

# 문제파일 다운로드

![문제파일.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/37f1f3c0-42a7-42d4-9561-6db7db06e9ab/.png)

Xss-1 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

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
    param = request.args.get("param", "")
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

![첫화면.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b7683371-96c3-4bfe-a945-6e6783f77ce8/.png)

즉 실제로 접속했을 때 위와 같은 페이지가 나오고 이때가 index 페이지다.

# vuln 함수

```python
@app.route("/vuln")
def vuln():
    param = request.args.get("param", "")
    return param
```

get으로 param의 값을 받아오고 띄워주는데 문제는 이 param의 값을 검증하지 않는다. vuln페이지에 직접 접속해보면

![vuln페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/35071d1b-c961-48d5-874e-d57c3c3dba24/vuln.png)

위와 같이 /vuln?param=<script>alert(1)</script>가 기본값으로 되어있고 param의 값인 <script>alert(1)</script>가 실행이 되어버리는 모습을 볼 수 있다. 

- get으로 파라미터를 받을 때는 ‘?변수명=값’으로 받는다. 즉 param변수에 <script>alert(1)</script>를 받은 것이다.

즉 vuln페이지에 get으로 param의 값에 내가 원하는 스크립트를 보내면 실행이 되는 것이 핵심이다.

그래서 이를 이용해서 호스트의 쿠키 값(FLAG)을 얻어야 하는데 내가 직접 이 param에 document.cookie를 호출하게 되면 호스트가 아닌 ‘나’의 쿠키 값이 나오게 되므로 호스트 측에서 이 페이지에 접근하게 하여 read_url함수를 통해 실행되게 해야한다.  

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

즉 flag 함수의 POST를 이용하여 호스트의 쿠키값을 스크립트를 이용하여 알아내면 된다.

![script location.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c20ef1a0-cebf-47e3-9aea-8c45f892cf0f/script_location.png)

이 페이지에서 POST로 보내는 방법은 빈칸에 입력값을 넣고 ‘제출’버튼을 누르면 POST로 보내진다. (python의 request모듈을 이용해 코드를 직접 작성해도 된다.)

# 문제 해결

다음과 같은 과정을 통해서 문제를 해결하면 된다.

1. flag 페이지에서 입력한 값은 연결된 호스트의 쿠키(FLAG)값을 가지고 vuln페이지에 param으로 전달되기 때문에 스크립트를 이용해서 호스트의 쿠키(FLAG)를 알아내야 한다.
2. 보통 호출하는 측의 쿠키를 알아내기 위해서는 document.cookie를 사용하는데 문제는 이 값을 어디에 써놓을 수 있는 방법이 없으면 blind로 한글자씩 비교해 가며 알아내야 한다.
3. 하지만 이 문제에서는 원하는 값을 memo 페이지에 memo에 저장하여 전달하면 화면에 띄워주기 때문에 document.cookie값을 memo에 전달해 주면된다.

즉 위와 같은 과정을 통해서 우리는 flag 페이지를 통해 vuln 페이지에 넘겨야 하는 스크립트는 아래와 같다.

<script>location.href=”/memo?memo=”+document.cookie</script>

location.href를 이용해서 vuln 페이지에서 memo 페이지를 호출하되 cookie값(호스트의 cookie값이므로 FLAG)을 memo의 값으로 주어서 memo페이지에 쿠키 값이 출력되도록 하면 된다.

![script location.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f2c6b5fa-edd5-463a-80cd-62e88ef89bfc/script_location.png)

위와 같이 스크립트를 작성해서 제출해주면 POST로 넘어가게 되고

![good.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5399f7f9-e2ed-4a31-9aef-15ddb253f8b3/good.png)

 잘 되었다는 good 응답이 오게 된다.

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c06625fb-7802-478e-a710-ff4fac771d51/flag.png)

그리고 나서 memo페이지에 다시 들어가보게 되면 FLAG값인 `flag=DH{2c01577e9542ec24d68ba0ffb846508e}` 이 존재하는 것을 볼 수 있다.
