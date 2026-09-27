# Apache httpd + Tomcat 취약점 연습 환경

Apache httpd와 Apache Tomcat의 보안 설정 오류와 웹 애플리케이션 취약점을 직접 재현하고 확인해 보는 로컬 실습 환경입니다.

**한국어** | [English](README.en.md)

> ⚠️ **경고**: 이 저장소는 학습 목적의 의도적으로 취약한 환경입니다. 반드시 외부 네트워크와 분리된 개인 실습 장비(로컬 전용)에서만 사용하세요. 인터넷이나 공용 네트워크에 노출하면 안 됩니다.

## 스크린샷

| 취약 앱 메인 | OS 명령 실행(Command Injection) |
|---|---|
| ![vuln-app 메인 화면](docs/images/index.png) | ![명령 실행 결과](docs/images/cmd.png) |

| 반사형 XSS | 세션 정보 노출 |
|---|---|
| ![Reflected XSS](docs/images/xss.png) | ![세션 정보](docs/images/session.png) |

명령 인젝션 실습 흐름:

![명령 인젝션 흐름](docs/images/cmd-flow.gif)

## 주요 기능

- **세 가지 설정 프로필**: `default`(보안 설정), `vulnerable`(취약 설정), `answer`(취약 설정 + 수정 방법 주석). 한 번의 명령으로 전환합니다.
- **Apache httpd 설정 오류 재현**: 디렉터리 리스팅, 서버 버전 노출, TRACE 메서드, 파일시스템 루트 접근, `server-status`/`server-info` 노출, CGI 명령 인젝션, 설정/로그 디렉터리 Alias 노출, `.htaccess` 접근, `AllowOverride All`, `FollowSymLinks`, `AllowEncodedSlashes`.
- **Tomcat 설정 오류 재현**: 약한 Manager 비밀번호, 브루트포스 방어(LockOutRealm) 제거, AJP(Apache JServ Protocol) 무제한 노출(GhostCat, CVE-2020-1938), Shutdown 포트 노출, 버전 정보 노출, autoDeploy 활성화.
- **취약 웹 애플리케이션(vuln-app)**: XSS, SQL Injection, 파일 업로드, LFI(Local File Inclusion), SSRF(Server-Side Request Forgery), OS 명령 인젝션, 세션 정보 노출, XXE(XML External Entity)를 JSP로 구현.
- **mod_jk 연동**: Apache가 AJP worker를 통해 Tomcat으로 요청을 전달합니다.

각 취약점의 확인 방법과 원인, 수정 방법은 [docs/PRACTICE_LAB.md](docs/PRACTICE_LAB.md)에 정리되어 있습니다.

## 사용 방법

### 사전 준비

이 저장소에는 설정 파일과 실습용 애플리케이션만 들어 있습니다. Apache httpd와 Tomcat 바이너리는 직접 설치해야 합니다.

- Apache httpd 2.4.x (mod_jk 포함) — 예: `2.4.66`
- Apache Tomcat 9.0.x — 예: `9.0.115`
- Java(JDK) 8 이상 — Tomcat 9 구동용 (JDK 21에서 동작 확인)

### 설치

1. httpd와 Tomcat을 원하는 위치에 설치합니다.
2. 이 저장소의 설정과 앱을 각 설치 위치로 복사합니다.

   ```bash
   git clone https://github.com/patissierMongs/httpd-tomcat-vuln-lab.git
   cd httpd-tomcat-vuln-lab

   # httpd 프로필과 CGI, htdocs 배치
   cp -r conf/profiles       "$HTTPD_HOME/conf/profiles"
   cp -r cgi-bin/*           "$HTTPD_HOME/cgi-bin/"
   cp -r htdocs/*            "$HTTPD_HOME/htdocs/"
   cp conf/extra/httpd-jk.conf "$HTTPD_HOME/conf/extra/"
   cp conf/workers.properties  "$HTTPD_HOME/conf/"

   # Tomcat 프로필과 취약 앱 배치
   cp -r tomcat-profiles     "$TOMCAT_HOME/conf/profiles"
   cp -r vuln-app            "$TOMCAT_HOME/webapps/vuln"
   ```

   `$HTTPD_HOME`, `$TOMCAT_HOME`은 각각 httpd와 Tomcat을 설치한 경로입니다.

### 실행

프로필 전환 스크립트가 설정 복사와 서비스 재시작을 함께 처리합니다. 설치 경로는 환경 변수로 지정합니다.

```bash
export HTTPD_HOME=/opt/httpd-2.4.66
export TOMCAT_HOME=/opt/tomcat

# 보안 설정(초기값)으로 기동
./switch-profile.sh default

# 취약 설정으로 전환
./switch-profile.sh vulnerable

# 취약 설정 + 수정 방법 주석 포함
./switch-profile.sh answer
```

전환이 끝나면 다음 주소로 접속합니다.

- Apache httpd: `http://localhost:8881`
- Tomcat: `http://localhost:8080`
- 취약 웹 애플리케이션: `http://localhost:8080/vuln/` (또는 mod_jk 경유 `http://localhost:8881/vuln/`)

> `switch-profile.sh`는 복사한 `httpd.conf` 최상단의 `Define SRVROOT` 값을 `HTTPD_HOME`에 맞게 자동으로 채웁니다. httpd를 직접 기동한다면 `Define SRVROOT`를 실제 설치 경로로 맞춰야 합니다.

### 기본 사용 예시

```bash
# 디렉터리 리스팅 확인
curl http://localhost:8881/secret/

# 서버 버전 헤더 확인
curl -I http://localhost:8881/

# CGI 명령 인젝션
curl "http://localhost:8881/cgi-bin/cmd.sh?cmd=id"

# 취약 앱 - 반사형 XSS
# 브라우저: http://localhost:8080/vuln/xss.jsp?name=<script>alert(1)</script>
```

## 기술 스택

| 구분 | 사용 기술 | 버전 |
|------|-----------|------|
| 웹 서버 | Apache httpd | 2.4.x (예: 2.4.66) |
| 서블릿 컨테이너 | Apache Tomcat | 9.0.x (예: 9.0.115) |
| 연동 모듈 | mod_jk (AJP13) | worker1 |
| 런타임 | Java(JDK) | 8 이상 (21에서 확인) |
| 애플리케이션 | JSP / Servlet | 4.0 (`web.xml`) |
| 데이터베이스 | SQLite (JDBC) | 드라이버 별도 필요 (아래 참고) |
| 스크립트 | Bash | `switch-profile.sh`, CGI |

포트: Apache httpd `8881`, Tomcat HTTP `8080`, AJP `8009`, Shutdown `8005`.

> SQL Injection 실습(`sqli.jsp`)은 SQLite JDBC 드라이버 JAR가 `vuln-app/WEB-INF/lib/`에 있어야 동작합니다. 이 디렉터리는 `.gitignore`로 제외되어 저장소에 포함되지 않으므로 드라이버를 직접 넣어야 합니다.

## 문서

- [docs/PRACTICE_LAB.md](docs/PRACTICE_LAB.md) — 취약점 26종의 확인 방법, 원인, 수정 방법 상세 정리
- [docs/PROGRESS.md](docs/PROGRESS.md) — 프로젝트 목표와 구현 상태, 작업 이력
