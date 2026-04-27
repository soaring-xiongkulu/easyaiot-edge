"""
本地文件系统对象存储（兼容原 MinIO URL 与 ModelService 方法名，便于渐进替换）。
"""
import os
import shutil
import tempfile
import zipfile
import posixpath
from flask import current_app

from app.services.local_bucket_client import LocalBucketClient, StorageObjectError


class ModelService:
    @staticmethod
    def get_minio_client():
        return LocalBucketClient()

    @staticmethod
    def download_from_minio(bucket_name, object_name, destination_path):
        try:
            client = LocalBucketClient()
            if not client.bucket_exists(bucket_name):
                error_msg = f"存储桶不存在: {bucket_name}"
                current_app.logger.error(error_msg)
                return False, error_msg
            client.fget_object(bucket_name, object_name, destination_path)
            current_app.logger.info(
                f"成功下载对象: {bucket_name}/{object_name} -> {destination_path}"
            )
            return True, None
        except StorageObjectError as e:
            error_msg = str(e)
            current_app.logger.error(error_msg)
            return False, error_msg
        except Exception as e:
            error_msg = f"下载未知错误: {str(e)}"
            current_app.logger.error(error_msg)
            return False, error_msg

    @staticmethod
    def download_directory_from_minio(bucket_name, object_prefix, destination_zip_path):
        try:
            client = LocalBucketClient()
            if not object_prefix.endswith("/"):
                object_prefix = object_prefix + "/"
            if not client.bucket_exists(bucket_name):
                error_msg = f"存储桶不存在: {bucket_name}"
                current_app.logger.error(error_msg)
                return False, error_msg
            objs = list(
                client.list_objects(
                    bucket_name, prefix=object_prefix, recursive=True
                )
            )
            if not objs:
                error_msg = f"目录为空或不存在: {bucket_name}/{object_prefix}"
                current_app.logger.error(error_msg)
                return False, error_msg
            with zipfile.ZipFile(destination_zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
                for obj in objs:
                    if obj.object_name.endswith("/"):
                        continue
                    rel = obj.object_name[len(object_prefix) :]
                    if not rel:
                        continue
                    fd, tmp_dest = tempfile.mkstemp(prefix="dl_", suffix=".bin")
                    os.close(fd)
                    try:
                        client.fget_object(bucket_name, obj.object_name, tmp_dest)
                        zipf.write(tmp_dest, rel)
                    finally:
                        try:
                            os.remove(tmp_dest)
                        except OSError:
                            pass
            current_app.logger.info(
                f"成功打包目录: {bucket_name}/{object_prefix} -> {destination_zip_path}"
            )
            return True, None
        except Exception as e:
            error_msg = f"目录下载打包未知错误: {str(e)}"
            current_app.logger.error(error_msg)
            return False, error_msg

    @staticmethod
    def upload_to_minio(bucket_name, object_name, file_path):
        try:
            if not os.path.exists(file_path):
                error_msg = f"本地文件不存在: {file_path}"
                current_app.logger.error(error_msg)
                return False, error_msg
            client = LocalBucketClient()
            client.fput_object(bucket_name, object_name, file_path)
            current_app.logger.info(f"文件上传完成: {bucket_name}/{object_name}")
            return True, None
        except Exception as e:
            error_msg = f"上传未知错误: {str(e)}"
            current_app.logger.error(error_msg)
            return False, error_msg

    @staticmethod
    def upload_directory_to_minio(bucket_name, object_prefix, local_dir):
        try:
            if not os.path.exists(local_dir):
                error_msg = f"本地目录不存在: {local_dir}"
                current_app.logger.error(error_msg)
                return False, error_msg
            client = LocalBucketClient()
            client.make_bucket(bucket_name)
            prefix = object_prefix.rstrip("/") + "/" if object_prefix else ""
            uploaded = 0
            for root, _, files in os.walk(local_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    relative_path = os.path.relpath(file_path, local_dir)
                    object_name = (prefix + relative_path.replace("\\", "/")).lstrip(
                        "/"
                    )
                    client.fput_object(bucket_name, object_name, file_path)
                    uploaded += 1
                    current_app.logger.info(f"已上传: {object_name}")
            if uploaded == 0:
                error_msg = f"目录中没有文件可上传: {local_dir}"
                current_app.logger.error(error_msg)
                return False, error_msg
            return True, None
        except Exception as e:
            error_msg = f"目录上传未知错误: {str(e)}"
            current_app.logger.error(error_msg)
            return False, error_msg

    @staticmethod
    def extract_zip(zip_path, extract_path):
        try:
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extractall(extract_path)
            current_app.logger.info(f"成功解压ZIP文件: {zip_path} -> {extract_path}")
            return True
        except zipfile.BadZipFile:
            current_app.logger.error(f"ZIP文件损坏: {zip_path}")
            return False
        except Exception as e:
            current_app.logger.error(f"解压ZIP文件错误: {str(e)}")
            return False

    @staticmethod
    def get_model_upload_dir(model_id):
        return os.path.join(current_app.root_path, "static", "uploads", str(model_id))

    @staticmethod
    def ensure_model_upload_dir(model_id):
        model_dir = ModelService.get_model_upload_dir(model_id)
        os.makedirs(model_dir, exist_ok=True)
        return model_dir

    @staticmethod
    def get_dataset_dir(model_id):
        return os.path.join(current_app.root_path, "static", "datasets", str(model_id))

    @staticmethod
    def ensure_dataset_dir(model_id):
        model_dir = ModelService.get_dataset_dir(model_id)
        os.makedirs(model_dir, exist_ok=True)
        return model_dir

    @staticmethod
    def get_model_dir(model_id):
        return os.path.join(current_app.root_path, "static", "models", str(model_id))

    @staticmethod
    def ensure_model_dir(model_id):
        model_dir = ModelService.get_model_dir(model_id)
        os.makedirs(model_dir, exist_ok=True)
        return model_dir

    @staticmethod
    def get_relative_path(full_path):
        static_dir = os.path.join(current_app.root_path, "static")
        relative_to_static = os.path.relpath(full_path, static_dir)
        return relative_to_static

    @staticmethod
    def get_posix_path(relative_path):
        return posixpath.join(*relative_path.split(os.sep))

    @staticmethod
    def delete_from_minio(bucket_name, object_name):
        try:
            client = LocalBucketClient()
            if not client.bucket_exists(bucket_name):
                current_app.logger.warning(f"存储桶不存在: {bucket_name}")
                return False
            if object_name.endswith("/"):
                for obj in client.list_objects(
                    bucket_name, prefix=object_name, recursive=True
                ):
                    client.remove_object(bucket_name, obj.object_name)
                try:
                    p = client._object_fs_path(
                        bucket_name, object_name.rstrip("/")
                    )
                    if os.path.isdir(p):
                        shutil.rmtree(p, ignore_errors=True)
                except (ValueError, OSError):
                    pass
                current_app.logger.info(
                    f"成功删除目录前缀: {bucket_name}/{object_name}"
                )
                return True
            client.remove_object(bucket_name, object_name)
            current_app.logger.info(f"成功删除: {bucket_name}/{object_name}")
            return True
        except Exception as e:
            current_app.logger.error(f"删除未知错误: {str(e)}")
            return False
