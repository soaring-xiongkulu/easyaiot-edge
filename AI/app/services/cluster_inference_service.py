"""
集群推理服务
从 AI 模块 AIService 表获取已部署模型服务地址，实现集群推理（直接暴露端口，无服务发现）
"""
import os
import logging
import requests
import tempfile
from typing import Dict, Any, Optional
from flask import request

logger = logging.getLogger(__name__)


def _get_model_service_base_url(model_id: int, model_format: str, model_version: str) -> Optional[str]:
    """
    从 AIService 表根据 service_name 获取运行中实例的推理地址（base URL）。
    service_name 格式：model_{model_id}_{model_format}_{model_version}
    """
    from db_models import AIService
    service_name = f"model_{model_id}_{model_format}_{model_version}"
    svc = (
        AIService.query.filter_by(service_name=service_name)
        .filter(AIService.status.in_(['running', 'online']))
        .order_by(AIService.last_heartbeat.desc())
        .first()
    )
    if not svc or not svc.inference_endpoint:
        return None
    # inference_endpoint 形如 http://ip:port/inference，返回 base URL
    ep = svc.inference_endpoint.rstrip('/')
    if ep.endswith('/inference'):
        return ep[:-len('/inference')].rstrip('/')
    return ep


class ClusterInferenceService:
    """集群推理服务类"""
    
    @staticmethod
    def get_model_format(model_path: str) -> str:
        """推断模型格式"""
        if not model_path:
            return 'pytorch'
        
        model_path_lower = model_path.lower()
        if model_path_lower.endswith('.onnx') or 'onnx' in model_path_lower:
            return 'onnx'
        elif model_path_lower.endswith(('.pt', '.pth')):
            return 'pytorch'
        elif 'openvino' in model_path_lower:
            return 'openvino'
        elif 'tensorrt' in model_path_lower:
            return 'tensorrt'
        else:
            return 'pytorch'  # 默认
    
    @staticmethod
    def inference_via_cluster(
        model_id: int,
        model_format: str,
        model_version: str,
        file_path: Optional[str] = None,
        file_obj=None,
        parameters: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        通过集群services实例进行推理
        
        Args:
            model_id: 模型ID
            model_format: 模型格式 (onnx, pytorch等)
            model_version: 模型版本
            file_path: 文件路径（可选）
            file_obj: 文件对象（可选）
            parameters: 推理参数
        
        Returns:
            推理结果
        """
        # 从 AIService 表获取已部署且运行中的模型服务地址（心跳上报的 inference_endpoint）
        service_name = f"model_{model_id}_{model_format}_{model_version}"
        logger.info(f"查找模型服务实例: {service_name}")
        service_url = _get_model_service_base_url(model_id, model_format, model_version)
        if not service_url:
            error_msg = f"未找到模型服务实例: {service_name}。请确保模型服务已部署并正在运行（心跳已上报至 AI 模块）"
            logger.error(error_msg)
            raise Exception(error_msg)
        logger.info(f"使用模型服务实例: {service_url}，进行集群推理")
        
        # 准备文件上传
        files = {}
        file_handle = None
        
        if file_path and os.path.exists(file_path):
            # 打开文件并保持打开状态直到请求完成
            file_handle = open(file_path, 'rb')
            files['file'] = (os.path.basename(file_path), file_handle, 'application/octet-stream')
            logger.info(f"准备上传文件: {file_path}")
        elif file_obj:
            # 重置文件指针
            file_obj.seek(0)
            files['file'] = (file_obj.filename, file_obj.stream, file_obj.content_type)
            logger.info(f"准备上传文件对象: {file_obj.filename}")
        
        if not files:
            raise Exception("未提供文件")
        
        # 准备参数
        params = parameters or {}
        
        try:
            # 调用services实例的推理接口
            inference_url = f"{service_url}/inference"
            logger.info(f"调用模型服务推理接口: {inference_url}")
            
            response = requests.post(
                inference_url,
                files=files,
                data=params,
                timeout=60
            )
            
            logger.info(f"模型服务响应状态码: {response.status_code}")
            
            if response.status_code == 200:
                try:
                    result = response.json()
                    logger.info(f"推理成功，返回结果: {type(result)}")
                    return result
                except ValueError as e:
                    error_msg = f"解析响应JSON失败: {str(e)}, 响应内容: {response.text[:500]}"
                    logger.error(error_msg)
                    raise Exception(error_msg)
            else:
                error_msg = f"调用services实例失败: HTTP {response.status_code}, 响应: {response.text[:500]}"
                logger.error(error_msg)
                raise Exception(error_msg)
        except requests.exceptions.Timeout as e:
            error_msg = f"调用services实例超时: {str(e)}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except requests.exceptions.ConnectionError as e:
            error_msg = f"连接services实例失败: {str(e)}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except requests.exceptions.RequestException as e:
            error_msg = f"调用services实例异常: {type(e).__name__}: {str(e)}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except Exception as e:
            error_msg = f"推理过程发生未知错误: {type(e).__name__}: {str(e)}"
            logger.error(error_msg, exc_info=True)
            raise Exception(error_msg)
        finally:
            # 关闭文件（仅当使用file_path时，file_obj由Flask管理）
            if file_handle and hasattr(file_handle, 'close'):
                try:
                    file_handle.close()
                    logger.debug("已关闭文件句柄")
                except Exception as e:
                    logger.warning(f"关闭文件失败: {str(e)}")

