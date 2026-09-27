# Progress

[한국어](PROGRESS.md)

## Final goal

Provide a local practice environment that reproduces, in one place, common security misconfigurations in Apache httpd and Apache Tomcat along with common web application vulnerabilities. Three profiles — hardened (`default`), exposed (`vulnerable`), and exposed-with-fix-notes (`answer`) — are switched by a script so the server behavior before and after a configuration change can be compared directly.

## Current implementation status

Status was verified against the actual code and configuration in the repository, and by running `vuln-app` on Tomcat 9.0.115 with JDK 21 in this container.

### Infrastructure / profiles

| Feature | Status | Code location |
|---------|--------|---------------|
| Profile switch script | Implemented | `switch-profile.sh` (`HTTPD_HOME`/`TOMCAT_HOME` env vars, auto-injects `Define SRVROOT`) |
| Hardened profile (default) | Implemented | `conf/profiles/default/httpd.conf`, `tomcat-profiles/default/*` |
| Vulnerable profile | Implemented | `conf/profiles/vulnerable/httpd.conf`, `tomcat-profiles/vulnerable/*` |
| Answer profile (fix notes) | Implemented | `conf/profiles/answer/httpd.conf` (13 FIX notes) |
| mod_jk integration | Implemented | `conf/extra/httpd-jk.conf`, `conf/workers.properties` |

### Apache httpd misconfigurations

| Item | Status | Code location |
|------|--------|---------------|
| Directory listing | Implemented | `conf/profiles/vulnerable/httpd.conf` `Options Indexes` |
| Server version/signature disclosure | Implemented | `ServerTokens Full`, `ServerSignature On` |
| TRACE method | Implemented | `TraceEnable On` |
| Filesystem root access | Implemented | `<Directory /> Require all granted` |
| server-status / server-info | Implemented | `<Location /server-status>`, `<Location /server-info>` |
| CGI command injection | Implemented | `cgi-bin/cmd.sh` (`eval "$CMD"`), `AddHandler cgi-script .sh` |
| conf / logs Alias exposure | Implemented | `Alias /conf`, `Alias /logs` |
| .htaccess / .htpasswd access | Implemented | `<Files ".ht*"> Require all granted` |
| AllowOverride All | Implemented | `AllowOverride All` |
| FollowSymLinks | Implemented | `Options ... FollowSymLinks` |
| AllowEncodedSlashes | Implemented | `AllowEncodedSlashes On` |

### Tomcat misconfigurations

| Item | Status | Code location |
|------|--------|---------------|
| Weak Manager password | Implemented | `tomcat-profiles/vulnerable/tomcat-users.xml` (admin/admin, tomcat/tomcat) |
| Manager IP restriction removed | Implemented | `tomcat-profiles/vulnerable/manager-context.xml` |
| Brute-force protection (LockOutRealm) removed | Implemented | `tomcat-profiles/vulnerable/server.xml` |
| Unrestricted AJP exposure (GhostCat) | Implemented | `server.xml` `address="0.0.0.0"`, `secretRequired="false"` |
| Exposed shutdown port | Implemented | `server.xml` `<Server port="8005" shutdown="SHUTDOWN">` |
| Version/info disclosure | Implemented | `server.xml` `xpoweredBy`, `showServerInfo`, `showReport` |
| autoDeploy enabled | Implemented | `server.xml` `autoDeploy="true"` |
| Example apps (examples) enabled | Not started (environment-dependent) | No example app in the repository; depends on `webapps/examples` in a stock Tomcat install |

### Vulnerable web application (vuln-app)

| Item | Status | Code location / result |
|------|--------|------------------------|
| Reflected / Stored XSS | Implemented | `vuln-app/xss.jsp` — verified running (input reflected without escaping) |
| File upload | Implemented | `vuln-app/upload.jsp` — compiles and responds |
| SSRF | Implemented | `vuln-app/ssrf.jsp` — verified running (http targets). `file://` is unsupported because the code casts to `HttpURLConnection` |
| OS command injection | Implemented | `vuln-app/cmd.jsp` — verified running (returns command output) |
| Session info leak / fixation | Implemented | `vuln-app/session.jsp` — verified running (session ID and attributes exposed) |
| XXE | Implemented | `vuln-app/xxe.jsp` — compiles and responds |
| SQL Injection | Partial | `vuln-app/sqli.jsp` — code is present, but the SQLite JDBC driver (`WEB-INF/lib/`, excluded by `.gitignore`) is absent, so it throws `ClassNotFoundException: org.sqlite.JDBC` at runtime |
| LFI (Local File Inclusion) | Not started (broken) | `vuln-app/lfi.jsp` — the local variable `page` collides with the JSP implicit object `page`, so it fails to compile ("Duplicate local variable page") and does not run as-is |

## Work history

Dates are in KST (Asia/Seoul). The original commits are already recorded with the `+0900` offset.

- 2026-03-18 01:23 KST — Initial Apache httpd + Tomcat practice environment (profiles, httpd/Tomcat configs, CGI, htdocs)
- 2026-03-18 01:55 KST — Added vuln-app: XSS, SQLi, file upload, LFI, SSRF, command injection, session, XXE
- 2026-09-27 KST — Removed personal info, moved the detail doc (`PRACTICE_LAB.md`) into `docs/`, wrote Korean/English READMEs and this progress record, added screenshots
