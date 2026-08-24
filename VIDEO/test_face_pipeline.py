#!/usr/bin/env python3
"""
人脸功能全链路测试脚本

覆盖接口：
1. /video/face/health
2. /video/face/library (GET/POST/PUT/DELETE)
3. /video/face/recognize/image
4. /video/face/recognize/device/<device_id>/snapshot
"""
import argparse
import json
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import requests


@dataclass
class CaseResult:
    name: str
    success: bool
    detail: str
    response: Optional[dict] = None


class FaceApiTester:
    def __init__(self, base_url: str, timeout: int = 20):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.session = requests.Session()

    def _url(self, path: str) -> str:
        return f"{self.base_url}{path}"

    def _request(self, method: str, path: str, **kwargs) -> dict:
        resp = self.session.request(method, self._url(path), timeout=self.timeout, **kwargs)
        try:
            payload = resp.json()
        except Exception:
            payload = {"code": resp.status_code, "msg": f"非JSON响应: {resp.text[:500]}"}
        payload["_http_status"] = resp.status_code
        return payload

    def health(self) -> dict:
        return self._request("GET", "/video/face/health")

    def list_library(self, label: Optional[str] = None, limit: int = 1000) -> dict:
        params = {"limit": limit}
        if label:
            params["label"] = label
        return self._request("GET", "/video/face/library", params=params)

    def add_face(self, label: str, image_path: Path) -> dict:
        with image_path.open("rb") as f:
            files = {"file": (image_path.name, f, "application/octet-stream")}
            data = {"label": label}
            return self._request("POST", "/video/face/library", files=files, data=data)

    def update_face(self, label: str, image_path: Path) -> dict:
        with image_path.open("rb") as f:
            files = {"file": (image_path.name, f, "application/octet-stream")}
            return self._request("PUT", f"/video/face/library/{label}", files=files)

    def delete_face(self, label: str) -> dict:
        return self._request("DELETE", f"/video/face/library/{label}")

    def recognize_image(self, image_path: Path, top_k: int = 3) -> dict:
        with image_path.open("rb") as f:
            files = {"file": (image_path.name, f, "application/octet-stream")}
            data = {"top_k": str(top_k)}
            return self._request("POST", "/video/face/recognize/image", files=files, data=data)

    def recognize_device_snapshot(self, device_id: str, top_k: int = 3) -> dict:
        return self._request(
            "POST",
            f"/video/face/recognize/device/{device_id}/snapshot",
            json={"top_k": top_k},
        )


def parse_label_image_pairs(items: List[str], arg_name: str) -> List[Tuple[str, Path]]:
    pairs: List[Tuple[str, Path]] = []
    for item in items:
        if "=" not in item:
            raise ValueError(f"{arg_name} 参数格式错误: {item}，应为 label=图片路径")
        label, img = item.split("=", 1)
        label = label.strip()
        image_path = Path(img.strip())
        if not label:
            raise ValueError(f"{arg_name} 参数标签为空: {item}")
        if not image_path.exists() or not image_path.is_file():
            raise ValueError(f"{arg_name} 图片不存在: {image_path}")
        pairs.append((label, image_path))
    return pairs


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="EasyAIoT VIDEO 人脸功能全链路测试脚本",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "--base-url",
        default="http://localhost:6000",
        help="VIDEO服务地址，默认: http://localhost:6000",
    )
    parser.add_argument(
        "--register",
        action="append",
        default=[],
        help="入库数据，格式 label=图片路径；可重复传入",
    )
    parser.add_argument(
        "--recognize",
        action="append",
        default=[],
        help="识别图片，格式 label=图片路径；label用于测试输出标记，可重复传入",
    )
    parser.add_argument(
        "--update",
        action="append",
        default=[],
        help="更新人脸，格式 label=图片路径；可重复传入",
    )
    parser.add_argument(
        "--device-id",
        default="",
        help="可选：设备ID，传入后会测试设备抓拍识别接口",
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=3,
        help="识别返回TopK，默认3",
    )
    parser.add_argument(
        "--cleanup",
        action="store_true",
        help="测试结束后删除本次 --register 的标签",
    )
    parser.add_argument(
        "--output",
        default="",
        help="测试报告输出JSON路径（可选）",
    )
    parser.add_argument(
        "--sleep",
        type=float,
        default=0.2,
        help="接口间隔秒数，默认0.2",
    )
    return parser.parse_args()


def is_ok(resp: dict) -> bool:
    return int(resp.get("code", -1)) == 0 and int(resp.get("_http_status", 500)) < 400


def main() -> int:
    args = parse_args()

    try:
        register_pairs = parse_label_image_pairs(args.register, "--register")
        recognize_pairs = parse_label_image_pairs(args.recognize, "--recognize")
        update_pairs = parse_label_image_pairs(args.update, "--update")
    except ValueError as e:
        print(f"[参数错误] {e}")
        return 2

    tester = FaceApiTester(base_url=args.base_url)
    results: List[CaseResult] = []

    def add_result(name: str, resp: dict, ok_detail: str, fail_detail_prefix: str):
        ok = is_ok(resp)
        detail = ok_detail if ok else f"{fail_detail_prefix}: {resp.get('msg', '未知错误')}"
        results.append(CaseResult(name=name, success=ok, detail=detail, response=resp))
        flag = "PASS" if ok else "FAIL"
        print(f"[{flag}] {name} -> {detail}")

    print("====================================================")
    print(" 人脸功能全链路测试开始 ")
    print(f" BASE_URL: {args.base_url}")
    print("====================================================")

    # 1) 健康检查
    health_resp = tester.health()
    add_result("健康检查", health_resp, "人脸服务可用", "人脸服务不可用")
    if not results[-1].success:
        return 1
    time.sleep(args.sleep)

    # 2) 入库
    for label, image_path in register_pairs:
        resp = tester.add_face(label=label, image_path=image_path)
        add_result(f"人脸入库[{label}]", resp, f"已录入: {image_path}", "入库失败")
        time.sleep(args.sleep)

    # 3) 列表查询
    list_resp = tester.list_library(limit=2000)
    add_result("人脸库查询", list_resp, "查询成功", "查询失败")
    time.sleep(args.sleep)

    # 4) 单图识别
    for mark, image_path in recognize_pairs:
        resp = tester.recognize_image(image_path=image_path, top_k=args.top_k)
        if is_ok(resp):
            face_count = resp.get("data", {}).get("face_count", 0)
            msg = f"识别完成，face_count={face_count}"
            add_result(f"图片识别[{mark}]", resp, msg, "识别失败")
        else:
            add_result(f"图片识别[{mark}]", resp, "", "识别失败")
        time.sleep(args.sleep)

    # 5) 更新
    for label, image_path in update_pairs:
        resp = tester.update_face(label=label, image_path=image_path)
        add_result(f"人脸更新[{label}]", resp, f"已更新: {image_path}", "更新失败")
        time.sleep(args.sleep)

    # 6) 设备抓拍识别（可选）
    if args.device_id:
        resp = tester.recognize_device_snapshot(device_id=args.device_id, top_k=args.top_k)
        if is_ok(resp):
            face_count = resp.get("data", {}).get("face_count", 0)
            add_result(
                f"设备抓拍识别[{args.device_id}]",
                resp,
                f"识别完成，face_count={face_count}",
                "设备抓拍识别失败",
            )
        else:
            add_result(
                f"设备抓拍识别[{args.device_id}]",
                resp,
                "",
                "设备抓拍识别失败",
            )
        time.sleep(args.sleep)

    # 7) 清理（可选）
    if args.cleanup and register_pairs:
        unique_labels = sorted({label for label, _ in register_pairs})
        for label in unique_labels:
            resp = tester.delete_face(label)
            add_result(f"人脸删除[{label}]", resp, "删除成功", "删除失败")
            time.sleep(args.sleep)

    # 汇总
    passed = sum(1 for r in results if r.success)
    failed = len(results) - passed
    print("====================================================")
    print(f" 测试完成: 总计 {len(results)}，通过 {passed}，失败 {failed}")
    print("====================================================")

    report = {
        "base_url": args.base_url,
        "total": len(results),
        "passed": passed,
        "failed": failed,
        "results": [
            {
                "name": r.name,
                "success": r.success,
                "detail": r.detail,
                "response": r.response,
            }
            for r in results
        ],
    }

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[报告] 已输出: {out_path}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
