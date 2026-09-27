#!/bin/bash
# 프로필 전환 스크립트
# 사용법: ./switch-profile.sh [default|vulnerable|answer]
# 설치 경로는 HTTPD_HOME, TOMCAT_HOME 환경 변수로 지정합니다.
# 예) HTTPD_HOME=/opt/httpd-2.4.66 TOMCAT_HOME=/opt/tomcat ./switch-profile.sh vulnerable

HTTPD_HOME="${HTTPD_HOME:-$HOME/httpd-2.4.66}"
TOMCAT_HOME="${TOMCAT_HOME:-$HOME/tomcat}"
PROFILE="$1"

if [ "$PROFILE" != "default" ] && [ "$PROFILE" != "vulnerable" ] && [ "$PROFILE" != "answer" ]; then
    echo "사용법: $0 [default|vulnerable|answer]"
    echo "  default    - 초기값 (보안 설정)"
    echo "  vulnerable - 취약점 연습용"
    echo "  answer     - 취약 설정 + 수정 방법 주석 포함"
    exit 1
fi

echo "=== 서비스 중지 ==="
$HTTPD_HOME/bin/apachectl stop 2>/dev/null
$TOMCAT_HOME/bin/shutdown.sh 2>/dev/null
sleep 2

echo "=== $PROFILE 프로필 적용 ==="
cp "$HTTPD_HOME/conf/profiles/$PROFILE/httpd.conf" "$HTTPD_HOME/conf/httpd.conf"
sed -i "s|^Define SRVROOT .*|Define SRVROOT \"$HTTPD_HOME\"|" "$HTTPD_HOME/conf/httpd.conf"
cp "$TOMCAT_HOME/conf/profiles/$PROFILE/server.xml" "$TOMCAT_HOME/conf/server.xml"
cp "$TOMCAT_HOME/conf/profiles/$PROFILE/tomcat-users.xml" "$TOMCAT_HOME/conf/tomcat-users.xml"
cp "$TOMCAT_HOME/conf/profiles/$PROFILE/manager-context.xml" "$TOMCAT_HOME/webapps/manager/META-INF/context.xml"
cp "$TOMCAT_HOME/conf/profiles/$PROFILE/manager-context.xml" "$TOMCAT_HOME/webapps/host-manager/META-INF/context.xml"

echo "=== 서비스 시작 ==="
$TOMCAT_HOME/bin/startup.sh
sleep 3
$HTTPD_HOME/bin/apachectl start

echo ""
echo "=== $PROFILE 프로필로 전환 완료 ==="
echo "  Apache: http://localhost:8881"
echo "  Tomcat: http://localhost:8080"
