<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.io.*, java.nio.file.*" %>
<%
  // [VULN] Local File Inclusion - 사용자 입력으로 파일 경로를 직접 지정
  // [FIX] 1) 화이트리스트: 허용된 파일명만 매핑 (Map<String,String>)
  //       2) Path traversal 차단: 정규화 후 기준 디렉터리 내인지 검증
  //         Path base = Paths.get("/allowed/dir").toRealPath();
  //         Path target = base.resolve(input).toRealPath();
  //         if (!target.startsWith(base)) throw new SecurityException();

  String page = request.getParameter("page");
  if (page == null) page = "";
  String content = "";

  if (!page.isEmpty()) {
      try {
          // [VULN] 경로 검증 없이 파일 읽기
          content = new String(Files.readAllBytes(Paths.get(page)), "UTF-8");
      } catch (Exception e) {
          content = "Error: " + e.getMessage();
      }
  }
%>
<html>
<head><title>LFI Lab</title></head>
<body>
<h2>Local File Inclusion (LFI)</h2>
<form method="GET">
  파일 경로: <input type="text" name="page" value="<%=page%>" size="60">
  <input type="submit" value="읽기">
</form>

<% if (!content.isEmpty()) { %>
  <h3>파일 내용:</h3>
  <pre><%=content.replace("<","&lt;").replace(">","&gt;")%></pre>
<% } %>

<hr>
<h3>테스트 페이로드</h3>
<pre>
시스템 파일:     ?page=/etc/passwd
Tomcat 설정:    ?page=/opt/tomcat/conf/server.xml
Tomcat 유저:    ?page=/opt/tomcat/conf/tomcat-users.xml
앱 소스코드:    ?page=/opt/tomcat/webapps/vuln/WEB-INF/web.xml
Apache 설정:    ?page=/opt/httpd-2.4.66/conf/httpd.conf
SSH 키:         ?page=$HOME/.ssh/id_rsa
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
