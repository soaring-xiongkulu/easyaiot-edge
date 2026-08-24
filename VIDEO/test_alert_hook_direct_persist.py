"""alert_hook mini 直连落库逻辑单元测试。"""
import os
import unittest
from unittest.mock import MagicMock, patch

from app.services import alert_hook_service as hook_mod


class TestAlertHookDirectPersist(unittest.TestCase):
    def setUp(self):
        self._env = os.environ.copy()

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._env)

    def test_should_use_direct_persist_in_mini(self):
        with patch.dict(os.environ, {'EASYAIOT_DEPLOY_PROFILE': 'mini'}, clear=True):
            self.assertTrue(hook_mod._should_use_direct_alert_persist())

    def test_process_alert_hook_uses_direct_persist_in_mini(self):
        alert_data = {
            'object': 'chair',
            'event': '办公室设备',
            'device_id': 'dev-1',
            'device_name': 'CH1',
            'task_type': 'realtime',
            'time': '2026-06-20 12:00:00',
        }
        task = {
            'task_id': 1,
            'task_name': '办公室设备',
            'task_type': 'realtime',
            'face_detection_enabled': False,
            'plate_detection_enabled': False,
            'alert_event_suppress_time': 5,
        }
        with patch.dict(os.environ, {'EASYAIOT_DEPLOY_PROFILE': 'mini'}, clear=True):
            with patch.object(hook_mod, '_query_alert_event_task', return_value=task):
                with patch.object(hook_mod, '_persist_alert_directly', return_value={'status': 'success', 'alert_id': 99, 'mode': 'direct_persist'}) as persist_mock:
                    result = hook_mod.process_alert_hook(alert_data)
        self.assertEqual(result['status'], 'success')
        self.assertEqual(result['alert_id'], 99)
        persist_mock.assert_called_once()


if __name__ == '__main__':
    unittest.main()
