# 진행 상황

[English](PROGRESS.en.md)

## 최종 목표

Apache httpd와 Apache Tomcat의 대표적인 보안 설정 오류와 웹 애플리케이션 취약점을 한 곳에서 재현하는 로컬 실습 환경을 제공합니다. 안전 설정(`default`), 취약 설정(`vulnerable`), 수정 방법 주석 포함(`answer`) 세 가지 프로필을 스크립트로 전환하며, 설정을 바꾸기 전후의 서버 동작을 직접 비교할 수 있게 합니다.

## 현재 구현 상태

상태는 저장소의 실제 코드와 설정을 확인하고, 이 환경에서 Tomcat 9.0.115 + JDK 21로 `vuln-app`을 실제 구동하여 검증했습니다.

### 인프라 / 프로필

| 기능 | 상태 | 코드 위치 |
|------|------|-----------|
| 프로필 전환 스크립트 | 구현됨 | `switch-profile.sh` (`HTTPD_HOME`/`TOMCAT_HOME` 환경 변수, `Define SRVROOT` 자동 주입) |
| 안전 프로필(default) | 구현됨 | `conf/profiles/default/httpd.conf`, `tomcat-profiles/default/*` |
| 취약 프로필(vulnerable) | 구현됨 | `conf/profiles/vulnerable/httpd.conf`, `tomcat-profiles/vulnerable/*` |
| 정답 프로필(answer, 수정 주석) | 구현됨 | `conf/profiles/answer/httpd.conf` (FIX 주석 13곳) |
| mod_jk 연동 | 구현됨 | `conf/extra/httpd-jk.conf`, `conf/workers.properties` |

### Apache httpd 설정 취약점

| 항목 | 상태 | 코드 위치 |
|------|------|-----------|
| 디렉터리 리스팅 | 구현됨 | `conf/profiles/vulnerable/httpd.conf` `Options Indexes` |
| 서버 버전/시그니처 노출 | 구현됨 | `ServerTokens Full`, `ServerSignature On` |
| TRACE 메서드 | 구현됨 | `TraceEnable On` |
| 파일시스템 루트 접근 | 구현됨 | `<Directory /> Require all granted` |
| server-status / server-info | 구현됨 | `<Location /server-status>`, `<Location /server-info>` |
| CGI 명령 인젝션 | 구현됨 | `cgi-bin/cmd.sh` (`eval "$CMD"`), `AddHandler cgi-script .sh` |
| conf / logs 디렉터리 Alias 노출 | 구현됨 | `Alias /conf`, `Alias /logs` |
| .htaccess / .htpasswd 접근 | 구현됨 | `<Files ".ht*"> Require all granted` |
| AllowOverride All | 구현됨 | `AllowOverride All` |
| FollowSymLinks | 구현됨 | `Options ... FollowSymLinks` |
| AllowEncodedSlashes | 구현됨 | `AllowEncodedSlashes On` |

### Tomcat 설정 취약점

| 항목 | 상태 | 코드 위치 |
|------|------|-----------|
| 약한 Manager 비밀번호 | 구현됨 | `tomcat-profiles/vulnerable/tomcat-users.xml` (admin/admin, tomcat/tomcat) |
| Manager IP 제한 제거 | 구현됨 | `tomcat-profiles/vulnerable/manager-context.xml` |
| 브루트포스 방어(LockOutRealm) 제거 | 구현됨 | `tomcat-profiles/vulnerable/server.xml` |
| AJP 무제한 노출(GhostCat) | 구현됨 | `server.xml` `address="0.0.0.0"`, `secretRequired="false"` |
| Shutdown 포트 노출 | 구현됨 | `server.xml` `<Server port="8005" shutdown="SHUTDOWN">` |
| 버전/정보 노출 | 구현됨 | `server.xml` `xpoweredBy`, `showServerInfo`, `showReport` |
| autoDeploy 활성화 | 구현됨 | `server.xml` `autoDeploy="true"` |
| 예제 앱(examples) 활성화 | 미구현(환경 의존) | 저장소에 예제 앱 없음. 실제 Tomcat 설치본의 `webapps/examples`에 의존 |

### 취약 웹 애플리케이션(vuln-app)

| 항목 | 상태 | 코드 위치 / 확인 결과 |
|------|------|-----------------------|
| Reflected / Stored XSS | 구현됨 | `vuln-app/xss.jsp` — 구동 확인(입력이 이스케이프 없이 반영됨) |
| 파일 업로드 | 구현됨 | `vuln-app/upload.jsp` — 컴파일/응답 확인 |
| SSRF | 구현됨 | `vuln-app/ssrf.jsp` — 구동 확인(http 대상). `file://`은 코드에서 `HttpURLConnection` 캐스팅으로 미지원 |
| OS 명령 인젝션 | 구현됨 | `vuln-app/cmd.jsp` — 구동 확인(명령 결과 반환) |
| 세션 정보 노출 / 고정 | 구현됨 | `vuln-app/session.jsp` — 구동 확인(세션 ID·속성 노출) |
| XXE | 구현됨 | `vuln-app/xxe.jsp` — 컴파일/응답 확인 |
| SQL Injection | 부분 구현 | `vuln-app/sqli.jsp` — 코드는 존재하나 SQLite JDBC 드라이버(`WEB-INF/lib/`, `.gitignore` 제외) 부재로 실행 시 `ClassNotFoundException: org.sqlite.JDBC` 발생 |
| LFI(Local File Inclusion) | 미구현(오류) | `vuln-app/lfi.jsp` — JSP 암묵 객체 `page`와 지역 변수 `page`가 충돌하여 컴파일 실패("Duplicate local variable page"). 현재 상태로는 동작하지 않음 |

## 작업 이력

날짜는 KST(Asia/Seoul)로 표기합니다. 원본 커밋은 이미 `+0900` 오프셋으로 기록되어 있습니다.

- 2026-03-18 01:23 KST — Apache httpd + Tomcat 보안 취약점 연습 환경 초기 구성 (프로필, httpd/Tomcat 설정, CGI, htdocs)
- 2026-03-18 01:55 KST — 취약 웹앱(vuln-app) 추가: XSS, SQLi, 파일 업로드, LFI, SSRF, Command Injection, Session, XXE
- 2026-09-27 KST — 개인정보 제거, 상세 문서(`PRACTICE_LAB.md`)를 `docs/`로 이동, 한국어/영어 README 및 진행 상황 문서 작성, 스크린샷 추가
