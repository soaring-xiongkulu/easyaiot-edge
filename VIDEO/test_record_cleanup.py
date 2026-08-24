"""录像空间清理：东八区 cutoff 与 MinIO object 时间解析。"""
import os
import sys
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

VIDEO_ROOT = os.path.dirname(os.path.abspath(__file__))
if VIDEO_ROOT not in sys.path:
    sys.path.insert(0, VIDEO_ROOT)

from app.services.media_dvr_utils import parse_record_minio_object_event_time  # noqa: E402
from app.utils.service_urls import SHANGHAI_TZ, save_time_cutoff_naive  # noqa: E402


class RecordCleanupTest(unittest.TestCase):
    def test_save_time_cutoff_uses_shanghai_wall_clock(self):
        fixed_now = datetime(2026, 7, 3, 12, 0, 0, tzinfo=SHANGHAI_TZ)
        with patch('app.utils.service_urls.datetime') as mock_dt:
            mock_dt.now.return_value = fixed_now
            cutoff = save_time_cutoff_naive(1)
        self.assertEqual(cutoff, datetime(2026, 7, 3, 11, 0, 0))

    def test_save_time_cutoff_permanent_returns_none(self):
        self.assertIsNone(save_time_cutoff_naive(0))

    def test_parse_object_time_from_flv_timestamp_in_filename(self):
        ts_ms = int(datetime(2026, 7, 2, 15, 30, 45, tzinfo=SHANGHAI_TZ).timestamp() * 1000)
        object_name = f'dev1/2026/07/02/{ts_ms}.flv'
        event_time = parse_record_minio_object_event_time(object_name, None)
        self.assertEqual(event_time, datetime(2026, 7, 2, 15, 30, 45))

    def test_parse_object_time_from_date_path_when_filename_not_timestamp(self):
        object_name = 'dev1/2026/07/02/segment.mp4'
        event_time = parse_record_minio_object_event_time(object_name, None)
        self.assertEqual(event_time, datetime(2026, 7, 2, 0, 0, 0))

    def test_parse_object_time_falls_back_to_last_modified(self):
        last_modified = datetime(2026, 7, 1, 8, 15, 0, tzinfo=timezone.utc)
        event_time = parse_record_minio_object_event_time('dev1/invalid/path/file.bin', last_modified)
        self.assertEqual(event_time, datetime(2026, 7, 1, 16, 15, 0))

    def test_event_time_before_shanghai_cutoff(self):
        fixed_now = datetime(2026, 7, 3, 12, 0, 0, tzinfo=SHANGHAI_TZ)
        with patch('app.utils.service_urls.datetime') as mock_dt:
            mock_dt.now.return_value = fixed_now
            cutoff = save_time_cutoff_naive(1)
        event_time = datetime(2026, 7, 3, 10, 30, 0)
        self.assertLess(event_time, cutoff)


if __name__ == '__main__':
    unittest.main()
