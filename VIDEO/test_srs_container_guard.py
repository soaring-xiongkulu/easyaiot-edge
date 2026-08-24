"""SRS 容器挂载自检单元测试。"""
import os
import sys
import unittest
from unittest.mock import patch

VIDEO_ROOT = os.path.dirname(os.path.abspath(__file__))
if VIDEO_ROOT not in sys.path:
    sys.path.insert(0, VIDEO_ROOT)

from app.services import srs_container_guard_service as guard  # noqa: E402


class SrsContainerGuardTest(unittest.TestCase):
    def setUp(self):
        self._saved = dict(os.environ)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._saved)

    def test_mismatch_when_mount_differs(self):
        home = os.path.expanduser('~')
        expected = os.path.join(home, 'easyaiot', 'data')
        with patch.object(guard, 'get_srs_container_data_mount_source', return_value='/root/easyaiot/data'):
            with patch.object(guard, 'get_expected_srs_host_data_dir', return_value=expected):
                self.assertTrue(guard.srs_data_mount_mismatch())

    def test_no_mismatch_when_mount_matches(self):
        home = os.path.expanduser('~')
        expected = os.path.join(home, 'easyaiot', 'data')
        with patch.object(guard, 'get_srs_container_data_mount_source', return_value=expected):
            with patch.object(guard, 'get_expected_srs_host_data_dir', return_value=expected):
                self.assertFalse(guard.srs_data_mount_mismatch())

    def test_no_container_no_mismatch(self):
        with patch.object(guard, 'get_srs_container_data_mount_source', return_value=None):
            self.assertFalse(guard.srs_data_mount_mismatch())

    def test_skipped_in_container(self):
        with patch.object(guard, '_running_inside_container', return_value=True):
            with patch.object(guard, 'run_fix_srs_script') as mock_fix:
                guard.maybe_fix_srs_on_startup()
                mock_fix.assert_not_called()

    def test_runs_fix_on_mismatch(self):
        with patch.object(guard, '_running_inside_container', return_value=False):
            with patch.object(guard, 'get_expected_srs_host_data_dir', return_value='/home/u/easyaiot/data'):
                with patch.object(guard, 'get_srs_container_data_mount_source', return_value='/root/easyaiot/data'):
                    with patch('subprocess.run') as mock_run:
                        mock_run.return_value.returncode = 0
                        with patch.object(guard, 'run_fix_srs_script', return_value=True) as mock_fix:
                            guard.maybe_fix_srs_on_startup()
                            mock_fix.assert_called_once()


if __name__ == '__main__':
    unittest.main()
