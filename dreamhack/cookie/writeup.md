https://honey-push-30b.notion.site/cookie-1f0afcd9064f472bb26bfba3a530ff17

문제파일 다운로드

cookie 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 문제파일을 다운로드 받으면 app.py 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.
#!/usr/bin/python3
from flask import Flask, request, render_template, make_response, redirect, url_for

app = Flask(__name__)

try:
    FLAG = open('./flag.txt', 'r').read()
except:
    FLAG = '[**FLAG**]'

users = {
    'guest': 'guest',
    'admin': FLAG
}

@app.route('/')
def index():
    username = request.cookies.get('username', None)
    if username:
        return render_template('index.html', text=f'Hello {username}, {"flag is " + FLAG if username == "admin" else "you are not admin"}')
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    elif request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        try:
            pw = users[username]
        except:
            return '<script>alert("not found user");history.go(-1);</script>'
        if pw == password:
            resp = make_response(redirect(url_for('index')) )
            resp.set_cookie('username', username)
            return resp 
        return '<script>alert("wrong password");history.go(-1);</script>'

app.run(host='0.0.0.0', port=8000)
user는 두 종류가 있다. 
‘guest’ : ‘guest’ 와 ‘admin’ : FLAG
여기서 @app.route가 써져 있는 곳은 페이지이고 각 함수들을 다음과 같이 살펴보자 
index 함수
login 함수
index 함수
@app.route('/')
def index():
    username = request.cookies.get('username', None)
    if username:
        return render_template('index.html', text=f'Hello {username}, {"flag is " + FLAG if username == "admin" else "you are not admin"}')
    return render_template('index.html')
cookie중 username 에 담겨있는 값을 받아와서 이 값이 admin이면 flag 값을 보여주고 admin 값이 
아니면 “you are not admin”을 출력해주는 함수이다.

처음 접속하면 아예 쿠키 값이 없기 때문에 아무것도 나오지 않는다.
login 함수
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    elif request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        try:
            pw = users[username]
        except:
            return '<script>alert("not found user");history.go(-1);</script>'
        if pw == password:
            resp = make_response(redirect(url_for('index')) )
            resp.set_cookie('username', username)
            return resp 
        return '<script>alert("wrong password");history.go(-1);</script>'
login 하는 함수인데 GET으로 받으면 login 페이지인 login.html을 보여주고 POST로 받으면 username에 담긴 값과 password에 담긴 값이 users 딕셔너리에 있는지 검증하고 로그인을 시도하는 페이지이다.
이 때 GET으로 접속하는 방법은 첫 페이지(index)에서 우측 상단의 login 버튼을 눌러서 접속하면 그게 GET 방식으로 접속하는 방식이다.

그래서 접속을 하고나면 위와 같이 username 폼과 password 폼이 있다. 이 폼에 username과 password 값을 넣고 Login 버튼을 누르면 그 값들을 통해 로그인을 시도하게 된다.
문제 풀이

먼저 첫 화면에서 우측 상단의 Login을 클릭하여 로그인 페이지로 이동한 후 username과 password에 guest/guest를 입력하여 로그인 해준다. 참고로 이 guest/guest는 소스 파일이 없더라도 첫 화면에서 우클릭을 통한 ‘페이지 소스보기’에도 적혀있다.

guest로 로그인 하고 나면 admin이 아니라는 문자가 나온다. 이는 cookie 중 username이 admin이 아니기 때문에 나타나는 글귀이기 때문에 cookie값을 바꿔주면 된다.
cookie 값을 바꿔주기 위해서는 개발자 도구 (F12)를 켜준다.

개발자 도구가 켜져있는 상태에서 아무것도 뜨지 않는다면 새로고침(F5)을 하여 현재 페이지의 값들을 볼 수 있다. cookie값을 변조하기 위해서는 상단의 Application 탭으로 이동해야하고 Application 탭으로 이동하고 나면 좌측의 Cookies를 클릭해주어 우리 문제 페이지의 cookie 값을 확인할 수 있다.
이 때 username 값의 Value가 guest이고 이 값이 admin이어야 flag값을 볼 수 있으므로 이 값을 더블클릭 후 admin 으로 수정해준다.

수정해준 후 새로 고침을 해주면 flag 값인 DH{7952074b69ee388ab45432737f9b0c56} 를 확인할 수 있다.
