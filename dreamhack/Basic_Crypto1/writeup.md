# 문제파일 다운로드

![문제파일.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2c013d8c-6a85-4f51-944e-a76ad4a028e6/%EB%AC%B8%EC%A0%9C%ED%8C%8C%EC%9D%BC.png)

로마 제국 암호를 사용했다고 설명이 나와있다. 로마제국의 황제 Caeser 가 사용한 암호는 암호의 가장 간단한 형태로 특정 숫자 만큼의 뒤의 문자로 바꿔주는 방식이다.

예를 들어 알파벳은 “ABCDEFGHIJKLMNOPQRSTUVWXYZ”로 되어있고 APPLE을 2칸 씩 뒤의 문자로 바꾼다고 해보자. 그러면 A→C, P→ R, L→N, E→G이므로 APPLE→ CRRNG로 바뀐다. 

문제파일을 다운로드 하면 encode.txt파일이 존재하는데

```python
EDVLF FUBSWR GUHDPKDFN
```

로 되어있다. 근데 이게 알파벳은 총 26개라서 몇칸 씩 뒤로 밀었는지 일일이 해보기는 귀찮으므로 파이썬 코드를 이용해서 대신 노가다를 뛰게 했다. 이 때 문제에 나온 설명대로빈칸은 _로 치환해주었다.

```python
alpha="ABCDEFGHIJKLMNOPQRSTUVWXYZ"

target="EDVLF FUBSWR GUHDPKDFN"

for i in range(0,len(alpha)):
    encode_result=""
    for j in target:
        if j==" ":
            encode_result=encode_result+"_"
            continue
        index=alpha.find(j)+i
        if index>=len(alpha):
            index=index-len(alpha)
        encode_result=encode_result+alpha[index]
    print(encode_result)
```

실행 결과 다음과 같은 목록들이 나타났다.

```python
EDVLF_FUBSWR_GUHDPKDFN
FEWMG_GVCTXS_HVIEQLEGO
GFXNH_HWDUYT_IWJFRMFHP
HGYOI_IXEVZU_JXKGSNGIQ
IHZPJ_JYFWAV_KYLHTOHJR
JIAQK_KZGXBW_LZMIUPIKS
KJBRL_LAHYCX_MANJVQJLT
LKCSM_MBIZDY_NBOKWRKMU
MLDTN_NCJAEZ_OCPLXSLNV
NMEUO_ODKBFA_PDQMYTMOW
ONFVP_PELCGB_QERNZUNPX
POGWQ_QFMDHC_RFSOAVOQY
QPHXR_RGNEID_SGTPBWPRZ
RQIYS_SHOFJE_THUQCXQSA
SRJZT_TIPGKF_UIVRDYRTB
TSKAU_UJQHLG_VJWSEZSUC
UTLBV_VKRIMH_WKXTFATVD
VUMCW_WLSJNI_XLYUGBUWE
WVNDX_XMTKOJ_YMZVHCVXF
XWOEY_YNULPK_ZNAWIDWYG
YXPFZ_ZOVMQL_AOBXJEXZH
ZYQGA_APWNRM_BPCYKFYAI
AZRHB_BQXOSN_CQDZLGZBJ
BASIC_CRYPTO_DREAMHACK
CBTJD_DSZQUP_ESFBNIBDL
DCUKE_ETARVQ_FTGCOJCEM
```

이중에서 딱봐도 정상적인 단어의 조합이 보인다. 바로 BASIC_CRYPTO_DREAMHACK이다. 이것이 바로 원본 FLAG이다. 즉 FLAG값은 DH{BASIC_CRYPTO_DREAMHACK}이다.
