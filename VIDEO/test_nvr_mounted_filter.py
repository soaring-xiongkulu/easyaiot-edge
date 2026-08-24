"""NVR 已挂载通道过滤逻辑单元测试。"""
from app.vendor.hiktools.core.nvr import (
    filter_mounted_channel_rows,
    filter_registerable_channel_rows,
    is_mounted_channel_row,
    is_registerable_channel_row,
)


def test_mounted_by_ip_when_status_unknown():
    assert is_mounted_channel_row({'channel_id': 1, 'ip': '192.168.1.100'}) is True


def test_mounted_by_online():
    assert is_mounted_channel_row({'channel_id': 2, 'online': True}) is True


def test_mounted_by_device_id_when_status_unknown():
    assert is_mounted_channel_row({'channel_id': 3, 'device_id': 'abc123'}) is True


def test_offline_slot_filtered():
    assert is_mounted_channel_row({'channel_id': 4, 'name': 'Camera 04', 'online': False}) is False


def test_offline_with_ip_filtered():
    assert is_mounted_channel_row({
        'channel_id': 2,
        'ip': '10.0.0.2',
        'online': False,
        'connection_status': 'netUnreachable',
    }) is False


def test_offline_conn_status_filtered():
    assert is_mounted_channel_row({
        'channel_id': 2,
        'connection_status': 'netUnreachable',
    }) is False


def test_empty_slot_filtered():
    assert is_mounted_channel_row({'channel_id': 5, 'enabled': True}) is False
    assert is_mounted_channel_row({'channel_id': 3, 'name': 'Camera 03'}) is False


def test_hikvision_status_scenario():
    """CH1 在线、CH2 离线 netUnreachable、CH3 在线。"""
    rows = [
        {'channel_id': 1, 'online': True, 'ip': '10.0.0.1'},
        {'channel_id': 2, 'online': False, 'connection_status': 'netUnreachable', 'ip': '10.0.0.2'},
        {'channel_id': 3, 'online': True, 'ip': '10.0.0.3'},
    ]
    filtered = filter_mounted_channel_rows(rows)
    assert [r['channel_id'] for r in filtered] == [1, 3]


def test_filter_keeps_only_mounted():
    rows = [
        {'channel_id': 1, 'ip': '10.0.0.1'},
        {'channel_id': 2, 'online': True},
        {'channel_id': 3, 'name': 'Camera 03'},
        {'channel_id': 4, 'device_id': 'dev-4'},
    ]
    filtered = filter_mounted_channel_rows(rows)
    assert [r['channel_id'] for r in filtered] == [1, 2, 4]


def test_registerable_includes_offline_with_ip():
    row = {
        'channel_id': 2,
        'ip': '10.0.0.2',
        'online': False,
        'connection_status': 'netUnreachable',
    }
    assert is_mounted_channel_row(row) is False
    assert is_registerable_channel_row(row) is True


def test_registerable_includes_custom_name_slot():
    row = {'channel_id': 3, 'name': '大门入口'}
    assert is_registerable_channel_row(row) is True


def test_registerable_excludes_empty_generic_slot():
    assert is_registerable_channel_row({'channel_id': 5, 'enabled': True}) is False
    assert is_registerable_channel_row({'channel_id': 3, 'name': 'Camera 03'}) is False


def test_registerable_filter_keeps_offline_ipc():
    rows = [
        {'channel_id': 1, 'online': True, 'ip': '10.0.0.1'},
        {'channel_id': 2, 'online': False, 'connection_status': 'netUnreachable', 'ip': '10.0.0.2'},
        {'channel_id': 3, 'name': 'Camera 03'},
    ]
    filtered = filter_registerable_channel_rows(rows)
    assert [r['channel_id'] for r in filtered] == [1, 2]
