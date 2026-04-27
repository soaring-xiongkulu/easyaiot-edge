"""
本地文件存储（保留 ModelService 名称与部分 API，供告警等模块使用）。
"""
import os
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
                current_app.logger.error(f"存储桶不存在: {bucket_name}")
                return False
            client.fget_object(bucket_name, object_name, destination_path)
            current_app.logger.info(
                f"成功下载对象: {bucket_name}/{object_name} -> {destination_path}"
            )
            return True
        except StorageObjectError as e:
            current_app.logger.error(str(e))
            return False
        except Exception as e:
            current_app.logger.error(f"下载未知错误: {str(e)}")
            return False

    @staticmethod
    def upload_to_minio(bucket_name, object_name, file_path):
        try:
            client = LocalBucketClient()
            if not os.path.exists(file_path):
                current_app.logger.error(f"本地文件不存在: {file_path}")
                return False
            client.fput_object(bucket_name, object_name, file_path)
            current_app.logger.info(f"文件上传成功: {bucket_name}/{object_name}")
            return True
        except StorageObjectError as e:
            current_app.logger.error(str(e))
            return False
        except Exception as e:
            current_app.logger.error(f"上传未知错误: {str(e)}")
            return False

    @staticmethod
    def upload_directory_to_minio(bucket_name, object_prefix, local_dir):
        try:
            client = LocalBucketClient()
            if not os.path.exists(local_dir):
                current_app.logger.error(f"本地目录不存在: {local_dir}")
                return False
            client.make_bucket(bucket_name)
            prefix = object_prefix.rstrip("/") + "/" if object_prefix else ""
            for root, _, files in os.walk(local_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    relative_path = os.path.relpath(file_path, local_dir)
                    on = (prefix + relative_path.replace("\\", "/")).lstrip("/")
                    client.fput_object(bucket_name, on, file_path)
                    current_app.logger.info(f"已上传: {on}")
            return True
        except StorageObjectError as e:
            current_app.logger.error(str(e))
            return False
        except Exception as e:
            current_app.logger.error(f"目录上传未知错误: {str(e)}")
            return False

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
        return os.path.relpath(full_path, static_dir)

    @staticmethod
    def get_posix_path(relative_path):
        return posixpath.join(*relative_path.split(os.sep))
