---
title: (Vietnamese) ACS EDU Practial Test Writeup
date: 2025-08-27 00:00:00 +0007
categories: [Write-up]
tags: [SQLi, XSS, English]

image:
  path: /assets/img/2025-08-27-ACSEDUPraticalTest/cover.jpg

description: "My write-up for ACS EDU 4th Practical Test"

---

> The ASEAN Cyber Shield is a cybersecurity program for all 11 ASEAN countries. I participated in the program as a student from PTIT – Vietnam. In the past two years, HUST and KMA won the final round of the ASEAN Cyber Shield. I still haven’t figured out how to officially get the permission to join it, but hopefully this year, my team and I from PTIT will fight our way to first place.
{: .prompt-info }

## Challenge 1 - Boolean-based Blind SQLi

> Challenge 1 description as below:
{: .prompt-info }

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image0.png" | relative_url }})

Since the target injection point was inside the search box, I assumed the underlying query could look like: `SELECT * FROM … WHERE … LIKE ‘%{user_input}%’`. This means any user input was directly concatenated into the LIKE condition. Therefore, it was possible to inject additional conditions after closing the string. 

By trial and error, I discovered that a payload such as: `admin’ AND ‘1%’=’1 `=> The full query would be `SELECT * FROM … WHERE … LIKE ‘%admin’ AND ‘1%’=’1%’` returned normal results, while: `admin' AND '1%'='2` would return no results found for the search.

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image1.png" | relative_url }})

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image2.png" | relative_url }})

So at this point, I had already confirmed the injection and established a working boolean-based SQLi payload. All that was left was to craft a payload capable of extracting data using conditional logic. Since I am quite familiar with this type of approach, I could proceed relatively quickly.

The general idea was to structure the payload as below, by replacing `{extract_data_logic_condition}` with specific tests against the user() function, I would be able to derive the database username character by character => `'admin' AND {extract_data_logic_condition} AND '1%'='1`

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image5.png" | relative_url }})

Given the hint from the problem statement, I focused on the user() function.
- The format is {dbname}@localhost.
- I only needed to extract the {dbname} part (up to 5 lowercase letters).
To extract characters, I used predicates such as:
`ASCII(SUBSTR(SUBSTRING_INDEX(USER(),'@',1), i, 1)) >= x`
- where i is the character position (1 to 5) and x is the ASCII value tested. By observing TRUE/FALSE differences, I could perform binary search or bruteforce in range 97-122 which means a – z to deduce each character.

`Payload explaination:`
- `USER()`: A built-in MySQL function that returns the current database user in the format {dbname}@localhost.
- `SUBSTRING_INDEX(str, delim, count)`: Splits a string by a delimiter and returns part of it. For example, SUBSTRING_INDEX(USER(),'@',1) gives only the {dbname} part before @.
- `SUBSTR(str, pos, len)`: Extracts a substring starting at position pos. Here it was used to select a single character from the DB name.
- `ASCII(char)`: Returns the ASCII code of a character, e.g. ASCII('a')=97. By comparing ASCII values (=, <, >=), I could determine each character of the DB name using boolean conditions.

Using BurpSuite’s Intruder with this idea, I found out the DB USER name is infos

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image3.png" | relative_url }})

I carefully check it out for the last time, and the result did not disappoint me. The final result for the DB USER name is `infos@localhost`

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image4.png" | relative_url }})

> Flag: `infos@localhost`
{: .prompt-tip }

## Challenge 2: Reflected XSS

> Challenge description as below:
{: .prompt-info }

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image6.png" | relative_url }})

My first sense of approach was to look for any functionality on the page where user input is accepted and subsequently displayed back in the browser. Such points of interaction are potential injection points for malicious payloads. Typical areas to test include search boxes, comment fields, or parameters passed through the URL.

After navigating through the website, the search function at the home page appeared to be the only candidate worth deeper inspection because there were no comments, no others places that could take in user input. To verify if user input was being reflected in the response, I injected a benign test string “findme” into the search box.

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image7.png" | relative_url }})

Since this was a Reflected XSS challenge, my first idea was to attempt breaking out of the current HTML context. Specifically, the user input was being reflected inside the value attribute of `an <input> tag`. This meant that if I could successfully close the value attribute, I might be able to inject additional HTML or JavaScript code.

To test this theory, I constructed a payload designed to escape the value attribute and then inject a new event handler. For instance, adding an attribute such as `onfocus=alert(1)`would cause a JavaScript alert to trigger once the input field gains focus.

With that idea in mind, I tested out the following basic Reflected XSS payload: `findme" autofocus onfocus="alert('XSS')`. The underlying idea here was to prematurely close the existing value attribute and then inject a new attribute into the element. By using autofocus together with an onfocus event, the payload ensures that the browser automatically triggers the malicious code as soon as the page is parsed, without requiring any user interaction (a zero-click trigger). As it turned out to be not working as expected

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image8.png" | relative_url }})

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image12.png" | relative_url }})

As it said, it seemed likely that certain characters or event attributes were being blacklisted. After experimenting for a while, I noticed that the search box was not the only place where user input was reflected back into the page. Realized this, I began fuzzing all the reflected parameters using the same test payload `findme”`.

Upon reviewing the results, I noticed that most of the reflected inputs were properly encoded, which prevented my payload from breaking out of the attribute context. However, one parameter stood out: the pageIndex field. Unlike the others, this input did not encode the double quotes ("), which meant that my injected payload could effectively terminate the existing attribute and append new HTML or JavaScript. This subtle inconsistency became the key entry point for a successful XSS injection.

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image9.png" | relative_url }})

As soon as I found out the pageIndex param is vulnerable, I attemp to put the previous payload `findme” autofocus onfocus=”alert(1)` to test for XSS

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image10.png" | relative_url }})

Now that we can see although everything seems to work fine, but the pop-up alert didn’t appear. I did some research to find out why, it turned out that it’s because the type of the input tag is set to “hidden”. If a thing was not a visible input like `type=text, checkbox` then it are not a parts of the interactive DOM => The JS won’t be executed

Figured out the reason, I changed the payload to `"><img src=x onerror=alert('XSS')>` which the idea is to close the current input tag, create a new image tag that has 2 attribute, an invalid source and onerror event 

`=> Solved the challenge`

![image]({{ "/assets/img/2025-08-27-ACSEDUPraticalTest/image11.png" | relative_url }})