#!/usr/bin/env python3
"""
GPU环境诊断脚本
检查PyTorch CUDA可用性、ONNX Runtime执行提供者、GPU内存等
"""

import os
import sys
import logging
import subprocess
import json
from typing import Dict, Any

def setup_logging():
    """配置日志"""
    logging.basicConfig(
        level=logging.INFO,
        format='[%(asctime)s] [%(levelname)s] %(message)s',
        datefmt='%Y-%m-d %H:%M:%S'
    )
    return logging.getLogger(__name__)

def check_environment_variables(logger):
    """检查GPU相关环境变量"""
    logger.info("=" * 60)
    logger.info("检查GPU相关环境变量")
    logger.info("=" * 60)

    env_vars = [
        'USE_GPU',
        'ORT_EXECUTION_PROVIDERS',
        'CUDA_VISIBLE_DEVICES',
        'NVIDIA_VISIBLE_DEVICES',
    ]

    for var in env_vars:
        value = os.environ.get(var, '未设置')
        logger.info(f"{var}: {value}")

def check_pytorch_cuda(logger):
    """检查PyTorch CUDA可用性"""
    logger.info("=" * 60)
    logger.info("检查PyTorch CUDA可用性")
    logger.info("=" * 60)

    try:
        import torch
        logger.info(f"PyTorch版本: {torch.__version__}")
        logger.info(f"CUDA可用: {torch.cuda.is_available()}")

        if torch.cuda.is_available():
            logger.info(f"CUDA设备数量: {torch.cuda.device_count()}")
            logger.info(f"当前设备索引: {torch.cuda.current_device()}")
            logger.info(f"当前设备名称: {torch.cuda.get_device_name(torch.cuda.current_device())}")

            # 检查GPU内存
            for i in range(torch.cuda.device_count()):
                free_memory = torch.cuda.get_device_properties(i).total_memory - torch.cuda.memory_allocated(i)
                logger.info(f"GPU {i} - 总内存: {torch.cuda.get_device_properties(i).total_memory / 1024**3:.2f} GB")
                logger.info(f"GPU {i} - 已分配内存: {torch.cuda.memory_allocated(i) / 1024**3:.2f} GB")
                logger.info(f"GPU {i} - 空闲内存: {free_memory / 1024**3:.2f} GB")
        else:
            logger.warning("PyTorch CUDA不可用")
            # 检查可能的原因
            if not torch.cuda.is_available():
                logger.warning("可能的原因:")
                logger.warning("1. PyTorch未安装GPU版本")
                logger.warning("2. CUDA驱动未安装或版本不匹配")
                logger.warning("3. 环境变量CUDA_VISIBLE_DEVICES设置不正确")

    except ImportError:
        logger.error("PyTorch未安装")
    except Exception as e:
        logger.error(f"检查PyTorch CUDA时出错: {str(e)}")

def check_onnxruntime_providers(logger):
    """检查ONNX Runtime执行提供者"""
    logger.info("=" * 60)
    logger.info("检查ONNX Runtime执行提供者")
    logger.info("=" * 60)

    try:
        import onnxruntime as ort
        providers = ort.get_available_providers()
        logger.info(f"可用执行提供者: {providers}")

        # 检查当前会话的提供者
        try:
            # 尝试创建一个临时会话来检查实际使用的提供者
            import tempfile
            import numpy as np
            from onnx import helper, TensorProto

            # 创建一个简单的ONNX模型
            with tempfile.NamedTemporaryFile(suffix='.onnx', delete=False) as f:
                # 创建简单的加法模型
                X = helper.make_tensor_value_info('X', TensorProto.FLOAT, [1])
                Y = helper.make_tensor_value_info('Y', TensorProto.FLOAT, [1])
                Z = helper.make_tensor_value_info('Z', TensorProto.FLOAT, [1])

                node = helper.make_node('Add', ['X', 'Y'], ['Z'])
                graph = helper.make_graph([node], 'test', [X, Y], [Z])
                model = helper.make_model(graph)

                f.write(model.SerializeToString())
                model_path = f.name

            # 创建会话
            session = ort.InferenceSession(model_path)
            session_providers = session.get_providers()
            logger.info(f"当前会话使用的提供者: {session_providers}")

            # 清理临时文件
            os.unlink(model_path)

        except Exception as e:
            logger.debug(f"创建测试ONNX会话时出错: {str(e)}")

    except ImportError:
        logger.error("ONNX Runtime未安装")
    except Exception as e:
        logger.error(f"检查ONNX Runtime时出错: {str(e)}")

def check_nvidia_smi(logger):
    """检查nvidia-smi输出"""
    logger.info("=" * 60)
    logger.info("检查nvidia-smi输出")
    logger.info("=" * 60)

    try:
        result = subprocess.run(['nvidia-smi'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            logger.info("nvidia-smi命令执行成功")
            # 只输出前20行避免日志过长
            lines = result.stdout.strip().split('\n')
            for line in lines[:20]:
                logger.info(line)
        else:
            logger.error(f"nvidia-smi命令失败: {result.stderr}")
    except FileNotFoundError:
        logger.warning("nvidia-smi未找到，可能未安装NVIDIA驱动或未在PATH中")
    except subprocess.TimeoutExpired:
        logger.error("nvidia-smi命令超时")
    except Exception as e:
        logger.error(f"执行nvidia-smi时出错: {str(e)}")

def check_docker_gpu_runtime(logger):
    """检查Docker GPU运行时"""
    logger.info("=" * 60)
    logger.info("检查Docker GPU运行时")
    logger.info("=" * 60)

    try:
        # 检查Docker版本
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            logger.info(f"Docker版本: {result.stdout.strip()}")

        # 检查NVIDIA Container Toolkit
        result = subprocess.run(['docker', 'info', '--format', '{{json .}}'], capture_output=True, text=True)
        if result.returncode == 0:
            try:
                docker_info = json.loads(result.stdout)
                runtimes = docker_info.get('Runtimes', {})
                if 'nvidia' in runtimes:
                    logger.info("NVIDIA Container Runtime已安装")
                    logger.info(f"NVIDIA Runtime路径: {runtimes.get('nvidia')}")
                else:
                    logger.warning("NVIDIA Container Runtime未找到")
            except json.JSONDecodeError:
                logger.warning("无法解析docker info输出")
    except FileNotFoundError:
        logger.warning("docker命令未找到")
    except Exception as e:
        logger.error(f"检查Docker GPU运行时时出错: {str(e)}")

def check_cuda_version(logger):
    """检查CUDA版本"""
    logger.info("=" * 60)
    logger.info("检查CUDA版本")
    logger.info("=" * 60)

    # 检查nvcc
    try:
        result = subprocess.run(['nvcc', '--version'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            # 提取版本信息
            for line in result.stdout.split('\n'):
                if 'release' in line.lower():
                    logger.info(f"nvcc版本: {line.strip()}")
    except FileNotFoundError:
        logger.info("nvcc未找到，可能未安装CUDA Toolkit或未在PATH中")
    except Exception:
        pass

    # 检查CUDA库文件
    cuda_libs = [
        '/usr/local/cuda/version.txt',
        '/usr/local/cuda/version.json',
    ]

    for lib_path in cuda_libs:
        if os.path.exists(lib_path):
            try:
                with open(lib_path, 'r') as f:
                    content = f.read()
                    logger.info(f"CUDA版本文件 {lib_path}: {content[:100]}...")
            except Exception:
                pass

def main():
    """主函数"""
    logger = setup_logging()

    logger.info("开始GPU环境诊断")
    logger.info(f"Python版本: {sys.version}")
    logger.info(f"工作目录: {os.getcwd()}")

    # 执行各项检查
    check_environment_variables(logger)
    check_pytorch_cuda(logger)
    check_onnxruntime_providers(logger)
    check_nvidia_smi(logger)
    check_docker_gpu_runtime(logger)
    check_cuda_version(logger)

    logger.info("=" * 60)
    logger.info("GPU环境诊断完成")
    logger.info("=" * 60)

if __name__ == '__main__':
    main()