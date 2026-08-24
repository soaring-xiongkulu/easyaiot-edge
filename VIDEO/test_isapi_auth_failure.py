"""海康 ISAPI 认证失败/账号锁定提示。"""
from app.vendor.hiktools.core.isapi import describe_isapi_auth_failure


def test_describe_account_lock():
    body = """<?xml version="1.0" encoding="UTF-8" ?>
<userCheck>
<lockStatus>lock</lockStatus>
<unlockTime>493</unlockTime>
</userCheck>"""
    msg = describe_isapi_auth_failure(401, body)
    assert msg is not None
    assert '锁定' in msg
    assert '9' in msg or '8' in msg


def test_describe_wrong_password():
    body = """<?xml version="1.0" encoding="UTF-8" ?>
<userCheck>
<statusString>Unauthorized</statusString>
</userCheck>"""
    msg = describe_isapi_auth_failure(401, body)
    assert msg is not None
    assert '401' in msg


def test_describe_non_401_returns_none():
    assert describe_isapi_auth_failure(403, None) is None
