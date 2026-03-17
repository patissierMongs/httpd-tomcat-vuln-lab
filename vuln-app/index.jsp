<%@ page contentType="text/html; charset=UTF-8" %>
<html>
<head><title>Vuln Practice App</title></head>
<body>
<h1>Vulnerable Practice App</h1>
<ul>
  <li><a href="xss.jsp">XSS (Cross-Site Scripting)</a></li>
  <li><a href="sqli.jsp">SQL Injection</a></li>
  <li><a href="upload.jsp">File Upload</a></li>
  <li><a href="lfi.jsp">Local File Inclusion (LFI)</a></li>
  <li><a href="ssrf.jsp">SSRF (Server-Side Request Forgery)</a></li>
  <li><a href="cmd.jsp">OS Command Injection</a></li>
  <li><a href="session.jsp">Session Info Leak</a></li>
  <li><a href="xxe.jsp">XXE (XML External Entity)</a></li>
</ul>
<hr>
<small><%=application.getServerInfo()%> | Java <%=System.getProperty("java.version")%></small>
</body>
</html>
