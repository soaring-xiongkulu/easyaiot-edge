"""media_dvr_utils 路径解析单元测试。"""
import os
import sys
import tempfile
import unittest

VIDEO_ROOT = os.path.dirname(os.path.abspath(__file__))
if VIDEO_ROOT not in sys.path:
    sys.path.insert(0, VIDEO_ROOT)

from app.services.media_dvr_utils import (  # noqa: E402
    discover_srs_host_data_root,
    parse_record_minio_object_event_time,
    resolve_playback_absolute_path,
)


class MediaDvrUtilsTest(unittest.TestCase):
    def setUp(self):
        self._saved = dict(os.environ)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._saved)

    def test_discover_uses_explicit_env(self):
        with tempfile.TemporaryDirectory() as tmp:
            os.environ['SRS_HOST_DATA_ROOT'] = tmp
            self.assertEqual(discover_srs_host_data_root(), tmp)

    def test_resolve_maps_container_data_to_host_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            rel = 'playbacks/ai/dev1/2026/07/02/123.flv'
            host_file = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(host_file), exist_ok=True)
            with open(host_file, 'wb') as fh:
                fh.write(b'x' * 9000)
            os.environ['SRS_HOST_DATA_ROOT'] = tmp
            mapped = resolve_playback_absolute_path(f'/data/{rel}')
            self.assertEqual(mapped, host_file)

    def test_resolve_existing_path_unchanged(self):
        with tempfile.NamedTemporaryFile(delete=False) as fh:
            path = fh.name
        try:
            self.assertEqual(resolve_playback_absolute_path(path), path)
        finally:
            os.remove(path)

    def test_parse_record_minio_object_time_from_path(self):
        event_time = parse_record_minio_object_event_time('1782976988203789777/2026/07/02/1782982220439.flv')
        self.assertEqual(event_time.year, 2026)
        self.assertEqual(event_time.month, 7)
        self.assertEqual(event_time.day, 2)


if __name__ == '__main__':
    unittest.main()
