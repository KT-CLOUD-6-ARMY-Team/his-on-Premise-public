#!/usr/bin/env bash
# 릴레이서버(192.168.100.100) — pfSense 로그 수신 + Kafka 포워딩
set -euo pipefail

KAFKA_BROKER="${KAFKA_BROKER:-a45121fd7e81f48029ea165552856f1c-2b9c36bf124aa15b.elb.ap-northeast-2.amazonaws.com:9092}"

echo "[1/3] rsyslog + rsyslog-kafka 설치"
sudo apt update
sudo apt install -y rsyslog rsyslog-kafka
sudo systemctl enable --now rsyslog

echo "[2/3] 10-relay.conf 설치 (pfSense 수신 + 로그종류별 Kafka 토픽 분기)"
sudo tee /etc/rsyslog.d/10-relay.conf > /dev/null <<EOF
module(load="imudp")
input(type="imudp" port="5140")
module(load="/usr/lib/x86_64-linux-gnu/rsyslog/omkafka.so")

# ============================================================
# 템플릿 정의
# ============================================================
template(name="firewall_json" type="list") {
    constant(value="{")
    constant(value="\"timestamp\":\"")
    property(name="timereported" dateFormat="rfc3339")
    constant(value="\",\"host\":\"")
    property(name="hostname")
    constant(value="\",\"interface\":\"")
    property(name="msg" field.delimiter="44" field.number="5")
    constant(value="\",\"action\":\"")
    property(name="msg" field.delimiter="44" field.number="7")
    constant(value="\",\"direction\":\"")
    property(name="msg" field.delimiter="44" field.number="8")
    constant(value="\",\"protocol\":\"")
    property(name="msg" field.delimiter="44" field.number="17")
    constant(value="\",\"src_ip\":\"")
    property(name="msg" field.delimiter="44" field.number="19")
    constant(value="\",\"dst_ip\":\"")
    property(name="msg" field.delimiter="44" field.number="20")
    constant(value="\",\"src_port\":\"")
    property(name="msg" field.delimiter="44" field.number="21")
    constant(value="\",\"dst_port\":\"")
    property(name="msg" field.delimiter="44" field.number="22")
    constant(value="\",\"raw_message\":\"")
    property(name="msg" format="json")
    constant(value="\"}")
}
template(name="openvpn_json" type="list") {
    constant(value="{")
    constant(value="\"timestamp\":\"")
    property(name="timereported" dateFormat="rfc3339")
    constant(value="\",\"host\":\"")
    property(name="hostname")
    constant(value="\",\"username\":\"")
    property(name="\$.uname")
    constant(value="\",\"client_ip\":\"")
    property(name="\$.cip")
    constant(value="\",\"client_port\":\"")
    property(name="\$.cport")
    constant(value="\",\"auth_username\":\"")
    property(name="\$.authuser")
    constant(value="\",\"event_type\":\"")
    property(name="\$.evttype")
    constant(value="\",\"message\":\"")
    property(name="msg" format="json")
    constant(value="\"}")
}
template(name="config_json" type="list") {
    constant(value="{")
    constant(value="\"timestamp\":\"")
    property(name="timereported" dateFormat="rfc3339")
    constant(value="\",\"host\":\"")
    property(name="hostname")
    constant(value="\",\"page\":\"")
    property(name="msg" regex.type="ERE" regex.expression="(/[a-zA-Z0-9_./-]+\\\\.php)" regex.submatch="1")
    constant(value="\",\"user\":\"")
    property(name="msg" regex.type="ERE" regex.expression="([a-zA-Z0-9_.-]+)['@]" regex.submatch="1")
    constant(value="\",\"source_ip\":\"")
    property(name="msg" regex.type="ERE" regex.expression="([0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3})" regex.submatch="1")
    constant(value="\",\"message\":\"")
    property(name="msg" format="json")
    constant(value="\"}")
}
template(name="etc_json" type="list") {
    constant(value="{")
    constant(value="\"timestamp\":\"")
    property(name="timereported" dateFormat="rfc3339")
    constant(value="\",\"host\":\"")
    property(name="hostname")
    constant(value="\",\"program\":\"")
    property(name="programname")
    constant(value="\",\"pid\":\"")
    property(name="procid")
    constant(value="\",\"message\":\"")
    property(name="msg" format="json")
    constant(value="\"}")
}

# ============================================================
# 라우팅 — 로그 종류별로 로컬 파일 + Kafka 토픽 분기
# ============================================================
if \$inputname == "imudp" then {
    action(type="omfile" file="/var/log/pf-relay.log")
    if \$programname == "filterlog" then {
        action(type="omfile" file="/var/log/pf-firewall-test.json" template="firewall_json")
        action(type="omkafka" topic="pf-firewall-log"
            broker=["${KAFKA_BROKER}"]
            template="firewall_json" confParam=["compression.codec=snappy"])
    }
    else if \$programname == "openvpn" then {
        set \$.uname = "";
        set \$.cip = "";
        set \$.cport = "";
        set \$.authuser = "";
        set \$.evttype = "";
        if re_match(\$msg, "[0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3}:[0-9]+") then {
            set \$.cip = re_extract(\$msg, "([0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3}):[0-9]+", 0, 1, "");
            set \$.cport = re_extract(\$msg, "[0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3}\\\\.[0-9]{1,3}:([0-9]+)", 0, 1, "");
        }
        if re_match(\$msg, "user '[a-zA-Z0-9_.-]+' address '[0-9.]+:[0-9]+' - [a-z]+") then {
            set \$.uname = re_extract(\$msg, "user '([a-zA-Z0-9_.-]+)'", 0, 1, "");
            set \$.evttype = re_extract(\$msg, "- ([a-z]+)\$", 0, 1, "");
        }
        else if re_match(\$msg, "user '[a-zA-Z0-9_.-]+' authenticated") then {
            set \$.authuser = re_extract(\$msg, "user '([a-zA-Z0-9_.-]+)' authenticated", 0, 1, "");
            set \$.evttype = "authenticated";
        }
        else if re_match(\$msg, "TCP connection established") then {
            set \$.evttype = "TCP connection established";
        }
        action(type="omfile" file="/var/log/pf-openvpn-test.json" template="openvpn_json")
        action(type="omkafka" topic="pf-vpn-openvpn-log"
            broker=["${KAFKA_BROKER}"]
            template="openvpn_json" confParam=["compression.codec=snappy"])
    }
    else if \$programname == "php-fpm" then {
        action(type="omfile" file="/var/log/pf-config-test.json" template="config_json")
        action(type="omkafka" topic="pf-config-log"
            broker=["${KAFKA_BROKER}"]
            template="config_json" confParam=["compression.codec=snappy"])
    }
    else {
        action(type="omkafka" topic="pf-etc-log"
            broker=["${KAFKA_BROKER}"]
            template="etc_json" confParam=["compression.codec=snappy"])
    }
}
EOF

sudo systemctl restart rsyslog

echo "[3/3] 방화벽 활성화"
sudo apt install -y ufw
sudo ufw allow from 10.10.10.1 to any port 5140 proto udp
sudo ufw allow 22/tcp
sudo ufw allow 9100/tcp
sudo ufw --force enable

echo "완료. 참고: 이 스크립트는 openvpn_json 템플릿의 일부 부가 분기(peer info/WARN/Fatal 등)는 생략된 축약판입니다 — 전체 원문은 relay-server/README.md 2절 참고."
