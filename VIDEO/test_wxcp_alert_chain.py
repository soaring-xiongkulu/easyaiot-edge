#!/usr/bin/env python3
"""企业微信告警通知全链路测试脚本"""
import json
import sys
import time
import uuid
import requests

GATEWAY = "http://localhost:48080/admin-api"
VIDEO = "http://localhost:6000"
TENANT_ID = "1"
LOGIN = {"username": "admin", "password": "admin123"}

# 用户提供的企微应用凭证
WXCP_CORP_ID = "ww0e9c041c3a7f8bcb"
WXCP_AGENT_ID = "1000017"
WXCP_SECRET = "GGCCqQInjiOFnOCakSJwAEIobDRyO0S6f9zvh-_AmI8"
WXCP_USER_ID = "19377231530"  # 企业微信成员 UserID（用户填写）


def login():
    r = requests.post(
        f"{GATEWAY}/system/auth/login",
        json=LOGIN,
        headers={"tenant-id": TENANT_ID},
        timeout=30,
    )
    r.raise_for_status()
    data = r.json()
    if data.get("code") != 0:
        raise RuntimeError(f"登录失败: {data}")
    return data["data"]["accessToken"]


def api(method, path, token, **kwargs):
    headers = {"tenant-id": TENANT_ID, "Authorization": f"Bearer {token}"}
    headers.update(kwargs.pop("headers", {}))
    r = requests.request(method, f"{GATEWAY}{path}", headers=headers, timeout=60, **kwargs)
    return r.json()


def step(title):
    print(f"\n{'='*60}\n>>> {title}\n{'='*60}")


def main():
    token = login()
    print("✅ 登录成功")

    # 1. 更新企业微信消息配置
    step("1. 配置企业微信 corpId / agentId / secret")
    configs = api("GET", "/message/config/query?msgType=4", token)
    cfg_list = configs.get("data") or []
    config_body = {
        "msgType": 4,
        "configuration": json.dumps({
            "wxCpCorpId": WXCP_CORP_ID,
            "wxCpApp": [{
                "appName": "告警通知应用",
                "agentId": WXCP_AGENT_ID,
                "secret": WXCP_SECRET,
                "id": 0,
            }],
        }, ensure_ascii=False),
    }
    if cfg_list:
        config_body["id"] = cfg_list[0]["id"]
        result = api("POST", "/message/config/update", token, json=config_body)
    else:
        result = api("POST", "/message/config/add", token, json=config_body)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result.get("code") not in (0, 200):
        print("❌ 配置失败"); sys.exit(1)
    print("✅ 企业微信配置已保存")

    # 2. 创建目标用户
    step("2. 创建企业微信目标用户")
    user_body = {"msgType": 4, "previewUser": WXCP_USER_ID}
    user_result = api("POST", "/message/preview/user/add", token, json=user_body)
    print(json.dumps(user_result, ensure_ascii=False, indent=2))
    user_id = (user_result.get("data") or {}).get("id")
    if not user_id:
        # 可能已存在，查询
        users = api("GET", "/message/preview/user/queryByMsgType?msgType=4", token)
        for u in users.get("data") or []:
            if u.get("previewUser") == WXCP_USER_ID:
                user_id = u["id"]
                break
    if not user_id:
        print("❌ 创建用户失败"); sys.exit(1)
    print(f"✅ 用户 UserID={WXCP_USER_ID}, id={user_id}")

    # 3. 创建用户分组
    step("3. 创建用户分组")
    group_name = f"告警测试组_{int(time.time())}"
    group_body = {
        "msgType": 4,
        "userGroupName": group_name,
        "previewUserId": user_id,
    }
    group_result = api("POST", "/message/preview/user/group/add", token, json=group_body)
    print(json.dumps(group_result, ensure_ascii=False, indent=2))
    group_id = (group_result.get("data") or {}).get("id")
    if not group_id:
        groups = api("GET", "/message/preview/user/group/queryByMsgType?msgType=4", token)
        for g in groups.get("data") or []:
            if WXCP_USER_ID in (g.get("previewUserId") or ""):
                group_id = g["id"]
                break
    if not group_id:
        print("❌ 创建用户分组失败"); sys.exit(1)
    print(f"✅ 用户分组 id={group_id}")

    # 4. 创建企业微信工作通知模板
    step("4. 创建企业微信工作通知模板")
    template_name = f"告警工作通知测试_{int(time.time())}"
    template_body = {
        "msgType": 4,
        "t_Msg_Wx_Cp": {
            "msgName": template_name,
            "title": template_name,
            "radioType": "工作通知方式",
            "agentId": WXCP_AGENT_ID,
            "cpMsgType": "文本消息",
            "content": "【告警测试】设备：${device_name}\n事件：${event}\n对象：${object}\n时间：${time}",
            "userGroupId": group_id,
        },
        "templateDataList": [],
    }
    tpl_result = api("POST", "/message/template/add", token, json=template_body)
    print(json.dumps(tpl_result, ensure_ascii=False, indent=2))
    template_id = (tpl_result.get("data") or {}).get("t_Msg_Wx_Cp", {}).get("id")
    if not template_id:
        print("❌ 创建模板失败"); sys.exit(1)
    print(f"✅ 模板 id={template_id}")

    # 5. 测试发送（消息推送 → 测试发送）
    step("5. 测试发送企业微信工作通知")
    push_body = {
        "msgType": 4,
        "t_Msg_Wx_Cp": {
            "msgName": f"推送测试_{int(time.time())}",
            "refTemplateId": template_id,
            "userGroupId": group_id,
            "agentId": WXCP_AGENT_ID,
            "radioType": "工作通知方式",
            "cpMsgType": "文本消息",
        },
    }
    push_result = api("POST", "/message/prepare/add", token, json=push_body)
    print(json.dumps(push_result, ensure_ascii=False, indent=2))
    push_id = (push_result.get("data") or {}).get("t_Msg_Wx_Cp", {}).get("id")
    if not push_id:
        print("❌ 创建推送记录失败"); sys.exit(1)

    # 推送记录经 refTemplateId 合并模板后发送（与前端「消息推送→测试发送」一致）
    send_result = api("POST", "/message/messageSend", token, json={"msgType": 4, "msgId": push_id})
    print(json.dumps(send_result, ensure_ascii=False, indent=2))
    if not (send_result.get("success") or (send_result.get("data") or {}).get("success")):
        print("⚠️  推送记录测试发送失败，改用模板 ID 直发验证企微凭证…")
        send_result = api("POST", "/message/messageSend", token, json={"msgType": 4, "msgId": template_id})
        print(json.dumps(send_result, ensure_ascii=False, indent=2))
    if send_result.get("success") or (send_result.get("data") or {}).get("success"):
        print("✅ 企业微信测试发送成功！请检查企业微信是否收到消息")
    else:
        info = send_result.get("info") or (send_result.get("data") or {}).get("info") or send_result.get("msg")
        print(f"⚠️  测试发送结果: {info}")
        if "invaliduser" in str(info).lower() or "60020" in str(info):
            print("提示: UserID 可能不正确，请在企微管理后台确认成员 UserID")

    # 6. 端到端告警测试
    step("6. 端到端告警 Hook 测试")
    try:
        import psycopg2
        conn = psycopg2.connect("postgresql://postgres:iot45722414822@localhost:5432/iot-video20")
        cur = conn.cursor()
        cur.execute("""
            SELECT d.id, d.name, at.id as task_id, at.alert_notification_config
            FROM device d
            JOIN algorithm_task_device atd ON atd.device_id = d.id
            JOIN algorithm_task at ON at.id = atd.task_id
            WHERE at.is_enabled = true
            LIMIT 5
        """)
        rows = cur.fetchall()
        conn.close()
        print(f"找到 {len(rows)} 个已启用算法任务的设备")
        for r in rows:
            print(f"  device_id={r[0]}, name={r[1]}, task_id={r[2]}")
    except Exception as e:
        print(f"查询设备失败: {e}")
        rows = []

    device_id = rows[0][0] if rows else None
    if device_id:
        # 更新算法任务告警通知配置
        alert_config = {
            "channels": [{
                "method": "wxcp",
                "template_id": template_id,
                "template_name": template_name,
            }],
            "notify_users": [{
                "msgType": 4,
                "previewUser": WXCP_USER_ID,
                "wxcp_userid": WXCP_USER_ID,
            }],
        }
        try:
            conn = psycopg2.connect("postgresql://postgres:iot45722414822@localhost:5432/iot-video20")
            cur = conn.cursor()
            cur.execute("""
                UPDATE algorithm_task
                SET alert_event_enabled = true,
                    alert_notification_enabled = true,
                    alert_notification_config = %s,
                    last_notify_time = NULL,
                    alarm_suppress_time = 0,
                    alert_event_suppress_time = 0
                WHERE id = %s
            """, (json.dumps(alert_config), rows[0][2]))
            conn.commit()
            conn.close()
            print(f"✅ 已更新算法任务 task_id={rows[0][2]} 的告警通知配置")
        except Exception as e:
            print(f"⚠️  更新算法任务配置失败: {e}")

        hook_payload = {
            "device_id": device_id,
            "device_name": rows[0][1] or "测试摄像头",
            "object": "person",
            "event": "intrusion",
            "region": "测试区域",
            "information": {"confidence": 0.95},
            "time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "task_type": "realtime",
        }
        print(f"发送告警 Hook: device_id={device_id}")
        hook_r = requests.post(f"{VIDEO}/video/alert/hook", json=hook_payload, timeout=30)
        print(f"HTTP {hook_r.status_code}: {hook_r.text[:500]}")
        if hook_r.status_code == 200:
            print("✅ 告警 Hook 已触发，等待 Kafka → iot-sink → iot-message 处理...")
            print("   请检查企业微信是否收到告警通知（约 5-15 秒）")
        else:
            print("❌ 告警 Hook 失败")
    else:
        print("⚠️  未找到已配置算法任务的设备，跳过端到端告警测试")
        print("   请先在摄像头管理中配置算法任务并关联设备")

    step("测试完成")
    print(f"""
配置摘要:
  corpId:   {WXCP_CORP_ID}
  agentId:  {WXCP_AGENT_ID}
  UserID:   {WXCP_USER_ID}
  模板ID:   {template_id}
  用户组ID: {group_id}

前端验证路径:
  通知中心 → 消息配置 → 企业微信（确认 corpId/agentId）
  通知中心 → 用户管理 → 企业微信（确认 UserID）
  通知中心 → 消息模板 → 企业微信（确认工作通知模板）
  通知中心 → 消息推送 → 企业微信 → 测试发送
  通知中心 → 推送历史 → 企业微信（查看发送结果）
""")


if __name__ == "__main__":
    main()
