<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.util.*" %>
<%
  // [VULN] 세션 정보 노출 + 세션 고정 공격 가능
  // [FIX] 1) 세션 정보 페이지 제거 또는 인증 필수
  //       2) 로그인 성공 시 세션 ID 재발급: request.changeSessionId()
  //       3) 쿠키에 HttpOnly, Secure, SameSite 설정

  // 세션 속성 설정
  String key = request.getParameter("key");
  String value = request.getParameter("value");
  if (key != null && !key.isEmpty() && value != null) {
      session.setAttribute(key, value);
  }

  // 세션 속성 삭제
  String removeKey = request.getParameter("remove");
  if (removeKey != null) {
      session.removeAttribute(removeKey);
  }
%>
<html>
<head><title>Session Lab</title></head>
<body>
<h2>Session Info Leak</h2>

<h3>세션 정보</h3>
<table border="1">
  <tr><td>Session ID</td><td><%=session.getId()%></td></tr>
  <tr><td>생성 시간</td><td><%=new Date(session.getCreationTime())%></td></tr>
  <tr><td>마지막 접근</td><td><%=new Date(session.getLastAccessedTime())%></td></tr>
  <tr><td>Max Inactive (초)</td><td><%=session.getMaxInactiveInterval()%></td></tr>
  <tr><td>Is New</td><td><%=session.isNew()%></td></tr>
</table>

<h3>세션 속성</h3>
<table border="1">
  <tr><th>Key</th><th>Value</th><th>삭제</th></tr>
  <%
    Enumeration<String> names = session.getAttributeNames();
    while (names.hasMoreElements()) {
        String n = names.nextElement();
  %>
  <tr>
    <td><%=n%></td>
    <td><%=session.getAttribute(n)%></td>
    <td><a href="?remove=<%=n%>">삭제</a></td>
  </tr>
  <% } %>
</table>

<h3>세션 속성 추가</h3>
<form method="GET">
  Key: <input type="text" name="key" size="20">
  Value: <input type="text" name="value" size="20">
  <input type="submit" value="추가">
</form>

<hr>
<h3>테스트 시나리오</h3>
<pre>
1) 세션 고정: 공격자가 자신의 JSESSIONID를 피해자에게 전달
   → 피해자 로그인 후 공격자가 같은 세션으로 접근
2) 세션 속성 조작: ?key=role&value=admin
   → 권한 상승 시뮬레이션
3) 세션 ID 노출: 이 페이지 자체가 세션 ID를 보여줌
   → URL에 JSESSIONID가 포함되면 Referer 헤더로 유출
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
