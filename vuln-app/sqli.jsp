<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*, java.io.*" %>
<%
  // [VULN] SQL Injection - 사용자 입력을 SQL 쿼리에 직접 연결
  // [FIX] PreparedStatement 사용:
  //   PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE name = ?");
  //   ps.setString(1, input);

  String dbPath = application.getRealPath("/WEB-INF/vuln.db");
  String searchName = request.getParameter("name");
  if (searchName == null) searchName = "";

  // SQLite DB 초기화
  Connection conn = null;
  String result = "";
  String queryUsed = "";
  try {
      Class.forName("org.sqlite.JDBC");
      conn = DriverManager.getConnection("jdbc:sqlite:" + dbPath);
      Statement stmt = conn.createStatement();

      // 테이블 생성 (없으면)
      stmt.executeUpdate("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, email TEXT, password TEXT, role TEXT)");

      // 샘플 데이터 (없으면)
      ResultSet check = stmt.executeQuery("SELECT COUNT(*) FROM users");
      if (check.next() && check.getInt(1) == 0) {
          stmt.executeUpdate("INSERT INTO users VALUES (1, 'admin', 'admin@corp.com', 'sup3r_s3cret!', 'admin')");
          stmt.executeUpdate("INSERT INTO users VALUES (2, 'user1', 'user1@corp.com', 'password123', 'user')");
          stmt.executeUpdate("INSERT INTO users VALUES (3, 'user2', 'user2@corp.com', 'qwerty', 'user')");
          stmt.executeUpdate("INSERT INTO users VALUES (4, 'guest', 'guest@corp.com', 'guest', 'guest')");
      }
      check.close();

      if (!searchName.isEmpty()) {
          // [VULN] 문자열 연결로 SQL 조합
          String query = "SELECT id, name, email, role FROM users WHERE name = '" + searchName + "'";
          queryUsed = query;
          ResultSet rs = stmt.executeQuery(query);
          StringBuilder sb = new StringBuilder();
          sb.append("<table border='1'><tr><th>ID</th><th>Name</th><th>Email</th><th>Role</th></tr>");
          while (rs.next()) {
              sb.append("<tr>");
              sb.append("<td>").append(rs.getString(1)).append("</td>");
              sb.append("<td>").append(rs.getString(2)).append("</td>");
              sb.append("<td>").append(rs.getString(3)).append("</td>");
              sb.append("<td>").append(rs.getString(4)).append("</td>");
              sb.append("</tr>");
          }
          sb.append("</table>");
          rs.close();
          result = sb.toString();
      }
      stmt.close();
  } catch (Exception e) {
      // [VULN] 에러 메시지에 SQL 쿼리와 스택 트레이스 노출
      StringWriter sw = new StringWriter();
      e.printStackTrace(new PrintWriter(sw));
      result = "<pre style='color:red'>" + sw.toString() + "</pre>";
  } finally {
      if (conn != null) try { conn.close(); } catch(Exception e) {}
  }
%>
<html>
<head><title>SQLi Lab</title></head>
<body>
<h2>SQL Injection Lab</h2>
<form method="GET">
  사용자 검색: <input type="text" name="name" value="<%=searchName%>" size="40">
  <input type="submit" value="검색">
</form>

<% if (!queryUsed.isEmpty()) { %>
  <p><b>실행된 쿼리:</b> <code><%=queryUsed%></code></p>
<% } %>

<%=result%>

<hr>
<h3>테스트 페이로드</h3>
<pre>
전체 조회:     ' OR '1'='1
UNION 공격:    ' UNION SELECT id,name,password,role FROM users--
테이블 조회:   ' UNION SELECT name,sql,null,null FROM sqlite_master--
에러 유발:     ' AND 1=CAST((SELECT password FROM users LIMIT 1) AS INT)--
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
