"""运动门控单元测试"""
import numpy as np
import pytest

from app.utils.motion_gate import MotionGate, MotionGateConfig


def _gray_frame(value: int, size=(90, 160)) -> np.ndarray:
    gray = np.full(size, value, dtype=np.uint8)
    return np.stack([gray, gray, gray], axis=-1)


def test_first_sample_frame_warmup():
    gate = MotionGate(MotionGateConfig(enabled=True, consecutive_hits_required=1))
    result = gate.on_sample_frame('dev1', _gray_frame(128), 25)
    assert result.triggered is False
    assert result.reason == 'warmup'


def test_identical_frames_no_trigger():
    cfg = MotionGateConfig(
        enabled=True,
        min_changed_area_ratio=0.01,
        min_mean_score=0.001,
        consecutive_hits_required=1,
        cooldown_frames=10,
    )
    gate = MotionGate(cfg)
    gate.on_sample_frame('dev1', _gray_frame(100), 25)
    result = gate.on_sample_frame('dev1', _gray_frame(100), 50)
    assert result.triggered is False
    assert result.changed_area_ratio < 0.001


def test_large_shift_triggers_after_consecutive_hits():
    cfg = MotionGateConfig(
        enabled=True,
        min_changed_area_ratio=0.05,
        min_mean_score=0.01,
        consecutive_hits_required=2,
        cooldown_frames=100,
        downscale_width=80,
        downscale_height=45,
    )
    gate = MotionGate(cfg)
    gate.on_sample_frame('dev1', _gray_frame(0), 25)

    frame_a = _gray_frame(0, (45, 80))
    frame_a[:, 40:, :] = 255
    r1 = gate.on_sample_frame('dev1', frame_a, 50)
    assert r1.triggered is False
    assert r1.consecutive_hits >= 1

    frame_b = _gray_frame(255, (45, 80))
    frame_b[:, :20, :] = 0
    r2 = gate.on_sample_frame('dev1', frame_b, 75)
    assert r2.triggered is True
    assert r2.reason == 'motion'


def test_cooldown_blocks_retrigger():
    cfg = MotionGateConfig(
        enabled=True,
        min_changed_area_ratio=0.01,
        min_mean_score=0.001,
        consecutive_hits_required=1,
        cooldown_frames=50,
        downscale_width=80,
        downscale_height=45,
    )
    gate = MotionGate(cfg)
    gate.on_sample_frame('dev1', _gray_frame(0), 1)
    frame = _gray_frame(0, (45, 80))
    frame[:, 20:, :] = 255
    gate.on_sample_frame('dev1', frame, 2)
    result = gate.on_sample_frame('dev1', frame, 3)
    assert result.reason == 'cooldown'


def test_reset_clears_state():
    gate = MotionGate(MotionGateConfig(enabled=True))
    gate.on_sample_frame('dev1', _gray_frame(10), 25)
    gate.reset('dev1')
    assert gate.get_stats('dev1') == {}


def test_disabled_gate():
    gate = MotionGate(MotionGateConfig(enabled=False))
    result = gate.on_sample_frame('dev1', _gray_frame(10), 25)
    assert result.reason == 'disabled'
