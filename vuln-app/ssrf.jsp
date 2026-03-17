<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.io.*, java.net.*" %>
<%
  // [VULN] SSRF - 사용자가 지정한 URL을 서버가 대신 요청
  // [FIX] 1) URL 화이트리스트 (허용된 도메인만)
  //       2) 내부 IP 대역 차단 (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
  //       3) 프로토콜 제한 (http/https만)
  //       4) DNS rebinding 방지: URL 파싱 후 IP로 변환하여 검증

  String targetUrl = request.getParameter("url");
  if (targetUrl == null) targetUrl = "";
  String result = "";

  if (!targetUrl.isEmpty()) {
      try {
          // [VULN] 아무 URL이나 요청 가능 - 내부망, 로컬호스트 포함
          URL url = new URL(targetUrl);
          HttpURLConnection conn = (HttpURLConnection) url.openConnection();
          conn.setRequestMethod("GET");
          conn.setConnectTimeout(5000);
          conn.setReadTimeout(5000);

          BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream()));
          StringBuilder sb = new StringBuilder();
          String line;
          while ((line = br.readLine()) != null) {
              sb.append(line).append("\n");
          }
          br.close();
          result = sb.toString();
      } catch (Exception e) {
          result = "Error: " + e.getMessage();
      }
  }
%>
<html>
<head><title>SSRF Lab</title></head>
<body>
<h2>SSRF (Server-Side Request Forgery)</h2>
<form method="GET">
  URL: <input type="text" name="url" value="<%=targetUrl%>" size="60">
  <input type="submit" value="요청">
</form>

<% if (!result.isEmpty()) { %>
  <h3>응답:</h3>
  <pre><%=result.replace("<","&lt;").replace(">","&gt;")%></pre>
<% } %>

<hr>
<h3>테스트 페이로드</h3>
<pre>
내부 서비스:     ?url=http://localhost:8080/manager/html
Apache 상태:    ?url=http://localhost:8881/server-status
AJP 포트 스캔:  ?url=http://localhost:8009/
내부망 스캔:    ?url=http://192.168.0.1/
클라우드 메타:  ?url=http://169.254.169.254/latest/meta-data/ (AWS)
파일 프로토콜:  ?url=file:///etc/passwd
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
