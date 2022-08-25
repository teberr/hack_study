https://honey-push-30b.notion.site/SingleByteXor-23f260696ae64baba9d7b50ec371cb18

# 문제

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/88d1fa3b-be95-4b44-8ea0-9dcaa283fb10/%EB%AC%B8%EC%A0%9C.png)

54586b6458754f7b215c7c75424f21634f744275517d6d 을 단일 바이트와 XOR 하여 원본을 찾으면 된다. 

1. 단일바이트는 0x00~0xff까지 즉 0부터 255까지다.
2. flag는 DH로 시작하니까 XOR한 결과값이 DH로 시작하는 경우를 출력하면 된다.

노가다는 파이썬 코드로 작성하여 컴퓨터가 대신해줬다.

 

```python
target='54586b6458754f7b215c7c75424f21634f744275517d6d'

for byte in range(0,256):
    answer=''
    for i in range(0,len(target),2):
        answer+=chr(int(target[i:i+2],16)^byte)
    if 'DH' in answer:
        print(answer)
```

코드를 실행하고나면

```python
= RESTART: C:/Users/민성/Desktop/reversing/x64_86 정리/드림핵 샘플/singlebytexor/answer.py
DH{tHe_k1LleR_1s_dReAm}
>>>
```

flag값이 나온다.
