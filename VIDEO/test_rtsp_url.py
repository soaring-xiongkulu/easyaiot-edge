"""RTSP URL 解析与编码单元测试"""
import pytest

from app.utils.rtsp_url import (
    build_rtsp_auth_prefix,
    parse_rtsp_auth,
    quote_rtsp_userinfo,
)


@pytest.mark.parametrize(
    "password,encoded",
    [
        ("plain", "plain"),
        ("p@ss#word", "p%40ss%23word"),
        ("a:b", "a%3Ab"),
    ],
)
def test_quote_rtsp_userinfo(password, encoded):
    assert quote_rtsp_userinfo(password) == encoded


def test_build_and_parse_roundtrip_special_password():
    source = (
        f"rtsp://{build_rtsp_auth_prefix('admin', 'p@ss#:word')}"
        "192.168.1.64:554/Streaming/Channels/101"
    )
    auth = parse_rtsp_auth(source)
    assert auth["username"] == "admin"
    assert auth["password"] == "p@ss#:word"
    assert auth["hostname"] == "192.168.1.64"
    assert auth["port"] == 554
