#!/bin/bash
echo "Content-Type: text/plain"
echo ""
echo "=== Environment Variables ==="
env | sort
echo ""
echo "=== System Info ==="
uname -a
echo ""
echo "=== Current User ==="
id
whoami
