#!/bin/bash
# [취약] command injection 연습용 CGI
echo "Content-Type: text/html"
echo ""

# QUERY_STRING에서 cmd 파라미터 추출
CMD=$(echo "$QUERY_STRING" | sed -n 's/.*cmd=\([^&]*\).*/\1/p' | python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null)

echo "<html><head><title>Command Exec</title></head><body>"
echo "<h2>Command Execution Lab</h2>"
echo "<form method='GET'>"
echo "<input type='text' name='cmd' value='$CMD' size='60'>"
echo "<input type='submit' value='Run'>"
echo "</form>"
echo "<pre>"

if [ -n "$CMD" ]; then
    eval "$CMD" 2>&1
fi

echo "</pre>"
echo "</body></html>"
