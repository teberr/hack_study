https://honey-push-30b.notion.site/command-injection-1-33be36f526774242ad07319996783c6e

# 문제 접근

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b64db76d-8b5c-4c9d-bf5e-23b183bd60d3/_.png)

command-injection-1 문제의 접속 정보와 문제 설명 및 문제파일을 다운로드 받을 수 있다. main.js 파일을 보면 아래 코드를 볼 수 있다.

```python
#!/usr/bin/env python3
import subprocess

from flask import Flask, request, render_template, redirect

from flag import FLAG

APP = Flask(__name__)

@APP.route('/')
def index():
    return render_template('index.html')

@APP.route('/ping', methods=['GET', 'POST'])
def ping():
    if request.method == 'POST':
        host = request.form.get('host')
        cmd = f'ping -c 3 "{host}"'
        try:
            output = subprocess.check_output(['/bin/sh', '-c', cmd], timeout=5)
            return render_template('ping_result.html', data=output.decode('utf-8'))
        except subprocess.TimeoutExpired:
            return render_template('ping_result.html', data='Timeout !')
        except subprocess.CalledProcessError:
            return render_template('ping_result.html', data=f'an error occurred while executing the command. -> {cmd}')

    return render_template('ping.html')

if __name__ == '__main__':
    APP.run(host='0.0.0.0', port=8000)
```

위 코드에서 다음과 같은 정보를 알 수 있다.

1. 사용자가 입력한 값을 host로 받아서 /bin/sh -c ping -c 3 “host” 를 실행한 결과를 리턴해준다.
2. 이 때 사용자가 입력한 값을 검증하지 않고 cmd 명령 결과를 리턴해서 보여주므로 사용자는 command injection 공격을 시도할 수 있다. 

# 문제 풀이

사용할 방법은 ;를 이용한 명령어 연속 실행이다.  명령 1 ; 명령 2가 되어있으면 명령1의 결과가 에러가 나더라도 명령2가 실행이 되기 때문에 ;를 필터링 하지 않으면 쉽게 원하는 cmd 명령을 추가적으로 실행시킬 수 있다.

/bin/sh -c ping -c 3 “입력값” 이므로 “까지 고려하여 입력을 해주려면

“;cat flag.py”를 넣어서

/bin/sh -c ping -c 3 ““;cat flag.py”” 로 실행시켜주고자 했다

![ping.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8b8586a2-3a15-4b62-8c8c-05e09733b91d/ping.png)

그런데 넣고 나니 요청한 형식과 일치시키라는 내용이 나왔다. 분명 [app.py](http://app.py) 코드를 볼때는 형식을 검증하는 과정이 아예 없었는데 요청한 형식과 일치시키라는 내용이 보이는 것을 보면 프론트단(html)에서 뭔가 필터가 있는 듯 하다. 그래서 페이지 소스 보기를 통해 코드를 살펴보았다.

```python
<!doctype html>
<html>
  <head>
    <link rel="stylesheet" href="/static/css/bootstrap.min.css">
    <link rel="stylesheet" href="/static/css/bootstrap-theme.min.css">
    <link rel="stylesheet" href="/static/css/non-responsive.css">
    <title>ping | Dreamhack Ping Tester</title>
    
  

  </head>
<body>

    <!-- Fixed navbar -->
    <nav class="navbar navbar-default navbar-fixed-top">
      <div class="container">
        <div class="navbar-header">
	<a class="navbar-brand" href="/">Home</a>
        </div>
        <div id="navbar">
          <ul class="nav navbar-nav">
            <li><a href="/ping">Ping</a></li>
          </ul>

        </div><!--/.nav-collapse -->
      </div>
    </nav>

    <div class="container">
      
<h1>Let's ping your host</h1><br/>
<form method="POST">
  <div class="row">
    <div class="col-md-6 form-group">
      <label for="Host">Host</label>
      <input type="text" class="form-control" id="Host" placeholder="8.8.8.8" name="host" pattern="[A-Za-z0-9.]{5,20}" required>
    </div>
  </div>

  <button type="submit" class="btn btn-default">Ping!</button>
</form>

    </div> <!-- /container -->

    <!-- Bootstrap core JavaScript -->
    <script src="/static/js/jquery.min.js"></script>
    <script src="/static/js/bootstrap.min.js"></script> 
</body>
</html>
```

<input type="text" class="form-control" id="Host" placeholder="8.8.8.8" name="host" pattern="[A-Za-z0-9.]{5,20}" required>
이 pattern 부분으로 인해서 요청한 command injection이 제대로 실행되지 않았던 것이다. 이렇게 html로 되어있는 경우 개발자 도구를 이용해서 지워버리면 그만이다.

![지우기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3fb0dab5-4150-41f5-81b2-a1177f8ad240/.png)

개발자 도구의 Elements에서 pattern 부분과 required를 지워버리고 ping을 보내보면

![결과.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4ef144dc-a7c0-491b-9144-2c13cd67fbdf/.png)

`FLAG = 'DH{pingpingppppppppping!!}'` 라는 결과값과 함께 플래그를 찾을 수 있다.
