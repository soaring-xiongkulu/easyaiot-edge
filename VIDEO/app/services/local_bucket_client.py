"""
本地文件系统存储，兼容原 MinIO 客户端的常用 API（bucket/对象键布局与 URL 不变）。
"""
from __future__ import annotations

import hashlib
import mimetypes
import os
import shutil
from datetime import datetime, timezone
from io import BytesIO
from types import SimpleNamespace
from typing import BinaryIO, Iterator, Optional

from flask import current_app


class StorageObjectError(Exception):
    """兼容原 S3Error.code 判断（如 NoSuchKey）。"""

    def __init__(self, message: str = "", code: str = "NoSuchKey"):
        super().__init__(message)
        self.code = code


def get_local_storage_root() -> str:
    try:
        root = current_app.config.get("LOCAL_STORAGE_ROOT")
    except RuntimeError:
        root = None
    if not root:
        root = os.environ.get("LOCAL_STORAGE_ROOT", "data/local_storage")
    return os.path.abspath(root)


class _ObjectReader:
    def __init__(self, data: bytes):
        self._buf = BytesIO(data)

    def read(self, n: int = -1) -> bytes:
        return self._buf.read(n)

    def close(self) -> None:
        try:
            self._buf.close()
        except Exception:
            pass

    def release_conn(self) -> None:
        pass


class LocalBucketClient:
    def __init__(self, root: Optional[str] = None):
        self.root = os.path.abspath(root or get_local_storage_root())

    def _bucket_dir(self, bucket: str) -> str:
        if not bucket or ".." in bucket or "/" in bucket or "\\" in bucket:
            raise ValueError("非法 bucket 名")
        return os.path.join(self.root, bucket)

    def _validate_rel_key(self, object_name: str) -> str:
        rel = object_name.replace("\\", "/").lstrip("/")
        parts = [p for p in rel.split("/") if p and p != "."]
        if ".." in parts:
            raise ValueError("非法对象名")
        if not parts:
            raise ValueError("非法对象名")
        return "/".join(parts)

    def _object_fs_path(self, bucket: str, object_name: str) -> str:
        base = os.path.realpath(self._bucket_dir(bucket))
        rel = self._validate_rel_key(object_name)
        if not rel:
            raise ValueError("非法对象名")
        full = os.path.realpath(os.path.join(base, *rel.split("/")))
        if not full.startswith(base + os.sep) and full != base:
            raise ValueError("路径越界")
        return full

    def bucket_exists(self, bucket: str) -> bool:
        return os.path.isdir(self._bucket_dir(bucket))

    def make_bucket(self, bucket: str) -> None:
        os.makedirs(self._bucket_dir(bucket), exist_ok=True)

    def list_objects(
        self, bucket: str, prefix: str = "", recursive: bool = True
    ) -> Iterator[SimpleNamespace]:
        base = self._bucket_dir(bucket)
        if not os.path.isdir(base):
            return
            yield  # pragma: no cover

        norm_p = prefix.replace("\\", "/")

        def should_yield(rel_posix: str) -> bool:
            if norm_p and not rel_posix.startswith(norm_p):
                return False
            if not recursive and norm_p:
                suffix = rel_posix[len(norm_p) :].lstrip("/")
                if "/" in suffix:
                    return False
            elif not recursive and not norm_p:
                if "/" in rel_posix:
                    return False
            return True

        for dirpath, _dirnames, filenames in os.walk(base):
            for fn in filenames:
                if fn.endswith(".__content_type__"):
                    continue
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, base).replace("\\", "/")
                if rel.endswith("/"):
                    continue
                if should_yield(rel):
                    yield SimpleNamespace(object_name=rel)

    def stat_object(self, bucket: str, object_name: str) -> SimpleNamespace:
        path = self._object_fs_path(bucket, object_name)
        if not os.path.isfile(path):
            raise StorageObjectError(f"对象不存在: {bucket}/{object_name}", "NoSuchKey")
        st = os.stat(path)
        lm = datetime.fromtimestamp(st.st_mtime, tz=timezone.utc)
        etag = hashlib.md5(f"{path}:{st.st_mtime}:{st.st_size}".encode()).hexdigest()
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        sc = path + ".__content_type__"
        if os.path.isfile(sc):
            try:
                with open(sc, encoding="utf-8") as sf:
                    ctype = sf.read().strip() or ctype
            except OSError:
                pass
        return SimpleNamespace(
            size=st.st_size, last_modified=lm, etag=etag, content_type=ctype
        )

    def get_object(self, bucket: str, object_name: str) -> _ObjectReader:
        path = self._object_fs_path(bucket, object_name)
        if not os.path.isfile(path):
            raise StorageObjectError(f"对象不存在: {bucket}/{object_name}", "NoSuchKey")
        with open(path, "rb") as f:
            data = f.read()
        return _ObjectReader(data)

    def fget_object(self, bucket: str, object_name: str, file_path: str) -> None:
        path = self._object_fs_path(bucket, object_name)
        if not os.path.isfile(path):
            raise StorageObjectError(f"对象不存在: {bucket}/{object_name}", "NoSuchKey")
        os.makedirs(os.path.dirname(os.path.abspath(file_path)), exist_ok=True)
        shutil.copy2(path, file_path)

    def fput_object(
        self,
        bucket: str,
        object_name: str,
        file_path: str,
        content_type: Optional[str] = None,
    ) -> None:
        if not os.path.isfile(file_path):
            raise StorageObjectError(f"本地文件不存在: {file_path}", "InvalidArgument")
        self.make_bucket(bucket)
        dest = self._object_fs_path(bucket, object_name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(file_path, dest)
        if content_type:
            sidecar = dest + ".__content_type__"
            try:
                with open(sidecar, "w", encoding="utf-8") as sf:
                    sf.write(content_type)
            except OSError:
                pass

    def put_object(
        self,
        bucket: str,
        object_name: str,
        data: BinaryIO,
        length: int,
        content_type: Optional[str] = None,
    ) -> None:
        self.make_bucket(bucket)
        if object_name.endswith("/"):
            dir_path = self._object_fs_path(bucket, object_name.rstrip("/"))
            os.makedirs(dir_path, exist_ok=True)
            return
        dest = self._object_fs_path(bucket, object_name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        body = data.read(length) if length is not None else data.read()
        with open(dest, "wb") as f:
            f.write(body)
        if content_type:
            sidecar = dest + ".__content_type__"
            try:
                with open(sidecar, "w", encoding="utf-8") as sf:
                    sf.write(content_type)
            except OSError:
                pass

    def remove_object(self, bucket: str, object_name: str) -> None:
        path = self._object_fs_path(bucket, object_name)
        if os.path.isfile(path):
            os.remove(path)
            sc = path + ".__content_type__"
            if os.path.isfile(sc):
                try:
                    os.remove(sc)
                except OSError:
                    pass
        elif os.path.isdir(path):
            shutil.rmtree(path, ignore_errors=True)

    def get_file_path(self, bucket: str, object_name: str) -> Optional[str]:
        try:
            path = self._object_fs_path(bucket, object_name)
        except ValueError:
            return None
        return path if os.path.isfile(path) else None
