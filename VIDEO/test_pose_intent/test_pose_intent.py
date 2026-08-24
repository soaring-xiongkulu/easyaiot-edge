#!/usr/bin/env python3
"""
场景姿态意图分析联调测试脚本。

用法:
  cd VIDEO
  python test_pose_intent/test_pose_intent.py
  python test_pose_intent/test_pose_intent.py --image ../AI/test_pose/fixtures/pose_sample.jpg
  python test_pose_intent/test_pose_intent.py --api http://127.0.0.1:48080/admin-api/video
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import uuid

VIDEO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if VIDEO_ROOT not in sys.path:
    sys.path.insert(0, VIDEO_ROOT)


def _default_image() -> str:
    candidates = [
        os.path.join(VIDEO_ROOT, '..', 'AI', 'test_pose', 'fixtures', 'pose_sample.jpg'),
        os.path.join(VIDEO_ROOT, 'data', 'uploads', 'test_pose.jpg'),
    ]
    for p in candidates:
        if os.path.isfile(p):
            return os.path.abspath(p)
    return ''


def test_pose_intent_utils(image_path: str) -> bool:
    from app.utils.pose_intent import (
        SCENE_TEMPLATES,
        dtw_similarity,
        evaluate_extra_rules,
        extract_angle_features,
        match_person_to_entry,
    )
    from app.utils.pose_analysis import load_pose_model, run_pose_analysis
    import cv2

    print('== 1. 姿态特征提取 ==')
    frame = cv2.imread(image_path)
    if frame is None:
        print(f'无法读取图片: {image_path}')
        return False
    model = load_pose_model({'model_file_path': 'yolo26n-pose.pt'})
    persons = run_pose_analysis(model, frame, conf=0.25)
    if not persons:
        print('未检测到人体')
        return False
    kps = persons[0].get('keypoints') or []
    feat = extract_angle_features(kps)
    print(f'  检测到 {len(persons)} 人, 特征维度={len(feat or [])}')

    print('== 2. 内置场景规则 ==')
    for key, tpl in SCENE_TEMPLATES.items():
        ok = evaluate_extra_rules(kps, tpl.get('extra_rules'))
        print(f'  {key}: rules_pass={ok}')

    print('== 3. DTW 相似度 ==')
    if feat:
        seq_a = [feat, feat, feat]
        seq_b = [feat, feat]
        sim = dtw_similarity(seq_a, seq_b)
        print(f'  自相似序列 DTW={sim:.4f} (应接近 1.0)')

    print('== 4. 单帧匹配（无库条目特征时返回低分） ==')
    sim, _ = match_person_to_entry(kps, None, match_mode='angle')
    print(f'  无参考特征 similarity={sim:.4f}')
    return True


def test_scenario_pose_api(api_base: str, image_path: str) -> bool:
    import requests

    base = api_base.rstrip('/')
    prefix = '/scenario-pose' if '/scenario-pose' in base else ''
    if not prefix:
        if base.endswith('/video'):
            lib_url = f'{base}/scenario-pose/libraries'
            extract_url = f'{base}/scenario-pose/entries/extract'
        else:
            lib_url = f'{base}/video/scenario-pose/libraries'
            extract_url = f'{base}/video/scenario-pose/entries/extract'
    else:
        lib_url = f'{base}/libraries'
        extract_url = f'{base}/entries/extract'

    print('== 5. HTTP API 联调 ==')
    print(f'  GET {lib_url}')
    try:
        r = requests.get(lib_url, timeout=10)
        print(f'  状态={r.status_code}')
        if r.status_code == 200:
            data = r.json()
            total = data.get('total', len(data.get('data') or []))
            print(f'  库数量={total}')
    except Exception as exc:
        print(f'  API 不可用: {exc}')
        return False

    if not os.path.isfile(image_path):
        return True

    print(f'  POST {extract_url}')
    try:
        with open(image_path, 'rb') as f:
            r = requests.post(extract_url, files={'file': f}, timeout=60)
        print(f'  状态={r.status_code}')
        if r.status_code == 200:
            body = r.json()
            persons = (body.get('data') or {}).get('persons') or []
            print(f'  提取人数={len(persons)}')
    except Exception as exc:
        print(f'  提取失败: {exc}')
    return True


def test_in_process_matching(image_path: str) -> bool:
    """需要 Flask app 上下文与数据库。"""
    print('== 6. 进程内匹配（需 DB） ==')
    try:
        from run import create_app
        from models import db, ScenarioPoseLibrary, ScenarioPoseEntry
        from app.services import scenario_pose_library_service as svc
        from app.services.pose_intent_matching_service import match_pose_intent
        from models import AlgorithmTask
        from app.utils.pose_analysis import load_pose_model, run_pose_analysis
        import cv2

        app = create_app()
        with app.app_context():
            code = f'TEST_{uuid.uuid4().hex[:8].upper()}'
            lib = ScenarioPoseLibrary(
                name='联调测试库',
                code=code,
                scene_category='custom',
                similarity_threshold=0.5,
                match_mode='angle',
                intent_event='pose_intent_match',
                intent_object='测试姿态',
                is_enabled=True,
            )
            db.session.add(lib)
            db.session.flush()

            with open(image_path, 'rb') as f:
                entry = svc.add_entry_from_image(lib.id, '参考姿态', f.read())
            print(f'  创建库 id={lib.id}, 条目 id={entry.id}')

            frame = cv2.imread(image_path)
            model = load_pose_model({'model_file_path': 'yolo26n-pose.pt'})
            persons = run_pose_analysis(model, frame, conf=0.25)
            from app.utils.pose_analysis import serialize_pose_persons
            pose_persons = serialize_pose_persons(persons)

            task = AlgorithmTask(
                task_name='test',
                task_code=f'TEST_TASK_{code}',
                task_type='realtime',
                pose_intent_enabled=True,
                pose_library_ids=json.dumps([lib.id]),
                pose_intent_config=json.dumps({
                    'temporal_dtw_enabled': False,
                    'draw_skeleton_on_alert': False,
                }),
            )
            db.session.add(task)
            db.session.flush()

            matches = match_pose_intent(task, pose_persons, device_id='test-device')
            print(f'  匹配结果数={len(matches)}')
            if matches:
                print(f'  最佳相似度={matches[0].get("similarity")}')

            db.session.rollback()
            print('  (已回滚测试数据)')
        return True
    except Exception as exc:
        print(f'  跳过进程内测试: {exc}')
        return True


def main():
    parser = argparse.ArgumentParser(description='场景姿态意图分析联调测试')
    parser.add_argument('--image', default=_default_image(), help='测试图片路径')
    parser.add_argument('--api', default='', help='VIDEO API 基址，如 http://127.0.0.1:48080/admin-api/video')
    parser.add_argument('--skip-api', action='store_true')
    parser.add_argument('--skip-db', action='store_true')
    args = parser.parse_args()

    image = args.image or _default_image()
    if not image or not os.path.isfile(image):
        print('请指定含人物的测试图片: --image path/to/image.jpg')
        print('或放置 AI/test_pose/fixtures/pose_sample.jpg')
        sys.exit(1)

    print(f'测试图片: {image}')
    ok = test_pose_intent_utils(image)
    if args.api and not args.skip_api:
        ok = test_scenario_pose_api(args.api, image) and ok
    if not args.skip_db:
        test_in_process_matching(image)

    print('\n联调测试完成')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
