"""DVR 设备解析单元测试（无 DB）。"""
import pytest

from app.services.dvr_device_resolver import parse_infer_stream_device_id


@pytest.mark.parametrize(
    'stream,expected',
    [
        ('infer_1781506220127821717_mdefault', '1781506220127821717'),
        ('infer_1781506220124766624_mdefault', '1781506220124766624'),
        ('infer_123_my_model', '123'),
        ('1781781474119258643', None),
        ('live/1781781474119258643', None),
        ('', None),
    ],
)
def test_parse_infer_stream_device_id(stream, expected):
    assert parse_infer_stream_device_id(stream) == expected
