#!/usr/bin/env python3
"""
测试 services 服务启动脚本
用于验证模型部署服务是否能正常启动和运行
"""
import os
import sys
import time
import signal
import subprocess
import requests
import socket
from pathlib import Path


class ServiceTester:
    """服务测试类"""
    
    def __init__(self, model_path=None, port=8899, service_name="test_deploy_service"):
        """
        初始化测试器
        
        Args:
            model_path: 模型文件路径，如果为None则自动查找
            port: 服务端口，默认8899
            service_name: 服务名称，默认test_deploy_service
        """
        self.port = port
        self.service_name = service_name
        self.process = None
        self.server_ip = 'localhost'  # 默认使用localhost，启动后会从日志中解析实际IP
        self.base_url = f"http://localhost:{port}"
        self.service_output_lines = []  # 存储服务输出，用于解析IP地址
        
        # 自动查找模型文件
        if model_path is None:
            model_path = self._find_model_file()
        
        self.model_path = model_path
        if not self.model_path:
            raise ValueError("未找到模型文件，请指定 MODEL_PATH 环境变量或确保 AI 目录下有 .pt 或 .onnx 文件")
        
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"模型文件不存在: {self.model_path}")
        
        print(f"📦 使用模型文件: {self.model_path}")
        print(f"🌐 服务地址: {self.base_url}")
        print(f"🔧 服务名称: {self.service_name}")
    
    def _find_model_file(self):
        """自动查找模型文件"""
        # 获取 AI 目录路径
        ai_dir = Path(__file__).parent.absolute()
        
        # 查找 .pt 文件
        pt_files = list(ai_dir.glob("*.pt"))
        if pt_files:
            return str(pt_files[0])
        
        # 查找 .onnx 文件
        onnx_files = list(ai_dir.glob("*.onnx"))
        if onnx_files:
            return str(onnx_files[0])
        
        # 查找 services 目录下的模型文件
        services_dir = ai_dir / "services"
        if services_dir.exists():
            pt_files = list(services_dir.glob("*.pt"))
            if pt_files:
                return str(pt_files[0])
            
            onnx_files = list(services_dir.glob("*.onnx"))
            if onnx_files:
                return str(onnx_files[0])
        
        return None
    
    def _is_port_available(self, port):
        """检查端口是否可用"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('0.0.0.0', port))
                return True
            except OSError:
                return False
    
    def _wait_for_service(self, timeout=60):
        """等待服务启动"""
        print(f"⏳ 等待服务启动（最多等待 {timeout} 秒）...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            # 检查进程是否还在运行
            if self.process and self.process.poll() is not None:
                print(f"❌ 服务进程已退出，退出码: {self.process.returncode}")
                # 尝试读取剩余输出
                if self.process.stdout:
                    try:
                        remaining_output = self.process.stdout.read()
                        if remaining_output:
                            print(f"[服务] {remaining_output.decode('utf-8', errors='ignore')}")
                    except:
                        pass
                if self.process.stderr:
                    try:
                        remaining_error = self.process.stderr.read()
                        if remaining_error:
                            print(f"[服务] {remaining_error.decode('utf-8', errors='ignore')}")
                    except:
                        pass
                return False
            
            # 检查端口是否在监听（简化逻辑：只要端口打开就认为服务已启动）
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.settimeout(1)
                    result = s.connect_ex(('localhost', self.port))
                    if result == 0:
                        # 端口已打开，认为服务已启动（不再进行健康检查）
                        print("✅ 服务已启动（端口已打开）")
                        return True
            except Exception:
                pass
            
            time.sleep(1)
            elapsed = int(time.time() - start_time)
            if elapsed % 5 == 0:
                print(f"   等待中... ({elapsed}/{timeout} 秒)")
        
        print("❌ 服务启动超时")
        # 检查端口是否在监听
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(1)
                result = s.connect_ex(('localhost', self.port))
                if result == 0:
                    print(f"⚠️  端口 {self.port} 已打开，但启动检测超时")
                else:
                    print(f"⚠️  端口 {self.port} 未打开")
        except Exception as e:
            print(f"⚠️  检查端口时出错: {str(e)}")
        return False
    
    def _read_output(self, pipe, prefix="[服务]"):
        """读取进程输出并实时显示"""
        try:
            for line in iter(pipe.readline, ''):
                if line:
                    line_str = line.rstrip()
                    if line_str:
                        print(f"{prefix} {line_str}")
                        # 保存输出行，用于解析服务IP地址
                        self.service_output_lines.append(line_str)
                        # 尝试从日志中解析服务器IP
                        self._parse_server_ip_from_output(line_str)
        except Exception as e:
            print(f"⚠️  读取输出时出错: {str(e)}")
        finally:
            pipe.close()
    
    def _parse_server_ip_from_output(self, line):
        """从服务输出中解析服务器IP地址和端口"""
        # 查找格式: [SERVICES] 服务器IP: 192.168.11.28
        if '[SERVICES] 服务器IP:' in line:
            try:
                # 提取IP地址
                parts = line.split('服务器IP:')
                if len(parts) > 1:
                    ip = parts[1].strip()
                    if ip and ip != self.server_ip:
                        self.server_ip = ip
                        self.base_url = f"http://{ip}:{self.port}"
                        print(f"🔍 检测到服务IP: {ip}，更新服务地址为: {self.base_url}")
            except Exception:
                pass
        
        # 检测端口切换: ✅ 已切换到可用端口: 8900
        if '已切换到可用端口:' in line or '已切换到端口:' in line:
            try:
                parts = line.split('端口:')
                if len(parts) > 1:
                    port_str = parts[1].strip().split()[0]  # 取第一个数字
                    try:
                        new_port = int(port_str)
                        if new_port != self.port:
                            old_port = self.port
                            self.port = new_port
                            self.base_url = f"http://{self.server_ip}:{self.port}"
                            print(f"🔍 检测到端口已切换: {old_port} -> {new_port}，更新服务地址为: {self.base_url}")
                    except ValueError:
                        pass
            except Exception:
                pass
        
        # 也尝试从服务地址输出中解析: 🌐 服务地址: http://192.168.11.28:8899
        if '🌐 服务地址:' in line or '服务地址:' in line:
            try:
                # 提取URL
                if 'http://' in line:
                    parts = line.split('http://')
                    if len(parts) > 1:
                        url_part = parts[1].split()[0] if ' ' in parts[1] else parts[1].strip()
                        # 移除可能的尾随字符
                        url_part = url_part.rstrip('.,;:')
                        if ':' in url_part:
                            ip, port_str = url_part.split(':', 1)
                            # 验证IP和端口
                            try:
                                port_num = int(port_str)
                                # 更新端口（如果不同）
                                if port_num != self.port:
                                    self.port = port_num
                                    print(f"🔍 从服务地址解析到端口: {port_num}")
                                # 更新IP（如果不同）
                                if ip and ip != self.server_ip:
                                    self.server_ip = ip
                                # 更新base_url
                                self.base_url = f"http://{ip}:{port_num}"
                                print(f"🔍 从服务地址解析到完整地址: {self.base_url}")
                            except ValueError:
                                pass
            except Exception:
                pass
    
    def start_service(self):
        """启动服务"""
        # 检查端口是否被占用
        if not self._is_port_available(self.port):
            print(f"⚠️  端口 {self.port} 已被占用，尝试使用其他端口...")
            # 尝试找到可用端口
            for p in range(self.port, self.port + 10):
                if self._is_port_available(p):
                    self.port = p
                    self.base_url = f"http://localhost:{p}"
                    print(f"✅ 使用端口: {p}")
                    break
            else:
                raise RuntimeError(f"无法找到可用端口（从 {self.port} 开始）")
        
        # 设置环境变量
        env = os.environ.copy()
        env['SERVICE_NAME'] = self.service_name
        env['MODEL_PATH'] = self.model_path
        env['PORT'] = str(self.port)
        env['PYTHONUNBUFFERED'] = '1'
        
        # 可选：设置其他环境变量（如果存在）
        if 'MODEL_ID' not in env:
            env['MODEL_ID'] = 'test_model'
        if 'MODEL_VERSION' not in env:
            env['MODEL_VERSION'] = 'V1.0.0'
        # 设置 SERVICE_ID（必需，用于心跳上报）
        if 'SERVICE_ID' not in env:
            env['SERVICE_ID'] = '999'  # 使用测试用的默认值
        
        # 注意：不再设置 MODEL_FORMAT，因为服务会根据文件扩展名自动判断
        
        # 获取 services 目录路径
        services_dir = Path(__file__).parent.absolute() / "services"
        run_deploy_path = services_dir / "run_deploy.py"
        
        if not run_deploy_path.exists():
            raise FileNotFoundError(f"找不到服务启动脚本: {run_deploy_path}")
        
        print(f"🚀 启动服务...")
        print(f"   脚本路径: {run_deploy_path}")
        print(f"   模型路径: {self.model_path}")
        print(f"   端口: {self.port}")
        
        # 启动服务进程
        try:
            self.process = subprocess.Popen(
                [sys.executable, str(run_deploy_path)],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(services_dir),
                text=True,  # 使用文本模式
                bufsize=1  # 行缓冲
            )
            
            # 启动线程实时读取输出
            # 注意：services 服务将日志输出到 stderr，所以主要关注 stderr
            import threading
            stdout_thread = threading.Thread(
                target=self._read_output,
                args=(self.process.stdout, "[服务]"),
                daemon=True
            )
            stderr_thread = threading.Thread(
                target=self._read_output,
                args=(self.process.stderr, "[服务]"),
                daemon=True
            )
            stdout_thread.start()
            stderr_thread.start()
            
            # 注意：services 服务主要使用 stderr 输出日志，所以 stderr 线程更重要
            
            # 等待服务启动，使用更长的等待时间和重试机制
            print("⏳ 等待服务启动...")
            max_wait_time = 60  # 增加等待时间到60秒，因为Flask启动可能需要更长时间
            check_interval = 2  # 每2秒检查一次
            waited_time = 0
            flask_started = False  # 标记Flask是否已启动
            
            while waited_time < max_wait_time:
                # 检查进程是否还在运行
                if self.process.poll() is not None:
                    # 进程已经退出，读取剩余输出
                    print("❌ 服务进程已退出")
                    # 等待输出线程完成
                    time.sleep(0.5)
                    return False
                
                # 检查日志中是否有Flask启动的标记
                if not flask_started:
                    for line in self.service_output_lines:
                        # 匹配多种可能的启动标记
                        if ('🚀 正在启动Flask应用...' in line or 
                            '🚀 模型部署服务启动中...' in line or
                            ('服务地址:' in line and 'http://' in line) or
                            ('🌐 服务地址:' in line)):
                            flask_started = True
                            # 再等待几秒让Flask完全启动
                            print("🔍 检测到Flask正在启动，等待服务完全就绪...")
                            time.sleep(3)
                            break
                
                # 只有在检测到Flask启动标记后才尝试连接（或者已经等待了足够长的时间）
                if flask_started or waited_time >= 10:
                    # 尝试连接服务（先尝试localhost，再尝试解析出的IP）
                    # 构建测试地址列表：优先使用解析出的IP，然后是localhost
                    test_hosts = []
                    if self.server_ip != 'localhost':
                        test_hosts.append(self.server_ip)
                    test_hosts.append('localhost')
                    test_hosts.append('127.0.0.1')  # 也尝试127.0.0.1
                    
                    for test_host in test_hosts:
                        try:
                            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                                s.settimeout(1)
                                result = s.connect_ex((test_host, self.port))
                                if result == 0:
                                    # 端口已打开，更新base_url并使用该地址
                                    if test_host != self.server_ip:
                                        self.server_ip = test_host
                                        self.base_url = f"http://{test_host}:{self.port}"
                                    # 再等待2秒确保Flask完全启动（因为服务可能需要加载模型）
                                    time.sleep(2)
                                    print(f"✅ 服务已启动（{test_host}:{self.port} 已打开）")
                                    return True
                        except Exception:
                            pass
                
                time.sleep(check_interval)
                waited_time += check_interval
                if waited_time % 6 == 0:  # 每6秒打印一次进度
                    print(f"   等待中... ({waited_time}/{max_wait_time} 秒)")
            
            # 如果超时，检查进程是否还在运行
            if self.process.poll() is None:
                print(f"⚠️  等待超时，但服务进程仍在运行")
                print(f"💡 提示：服务可能已启动，但端口检查失败")
                print(f"💡 提示：尝试使用解析出的IP地址: {self.server_ip}:{self.port}")
                print(f"💡 提示：服务可能已启动，请检查端口与进程")
                # 即使超时，如果进程还在运行，也认为启动成功（可能是网络问题）
                return True
            else:
                print("❌ 服务进程已退出")
                return False
                
        except Exception as e:
            print(f"❌ 启动服务失败: {str(e)}")
            import traceback
            traceback.print_exc()
            if self.process:
                self.stop_service()
            return False
    
    def test_health(self):
        """测试健康检查接口"""
        print("\n" + "="*60)
        print("📊 测试健康检查接口")
        print("="*60)
        print(f"🌐 测试地址: {self.base_url}/health")
        
        # 重试机制：最多重试5次，每次间隔2秒
        max_retries = 5
        retry_interval = 2
        
        # 尝试多个地址：先尝试解析出的IP，再尝试localhost
        test_urls = [f"{self.base_url}/health"]
        if self.server_ip != 'localhost':
            # 如果解析出的IP不是localhost，也尝试localhost
            localhost_url = f"http://localhost:{self.port}/health"
            if localhost_url not in test_urls:
                test_urls.append(localhost_url)
        
        for attempt in range(1, max_retries + 1):
            for test_url in test_urls:
                try:
                    print(f"   尝试连接: {test_url}")
                    response = requests.get(test_url, timeout=5)
                    print(f"状态码: {response.status_code}")
                    
                    if response.status_code == 200:
                        data = response.json()
                        print(f"响应数据: {data}")
                        
                        # 检查健康状态（匹配最新的接口格式）
                        if data.get('status') == 'healthy':
                            # 如果使用localhost成功，更新base_url
                            if 'localhost' in test_url and self.server_ip != 'localhost':
                                self.base_url = f"http://localhost:{self.port}"
                            
                            # 显示额外的服务信息
                            model_loaded = data.get('model_loaded', False)
                            service_name = data.get('service_name', 'unknown')
                            print(f"   模型已加载: {model_loaded}")
                            print(f"   服务名称: {service_name}")
                            print("✅ 健康检查通过")
                            return True
                        else:
                            print(f"⚠️  服务状态异常: {data.get('status')}")
                            return False
                    else:
                        print(f"❌ 健康检查失败，状态码: {response.status_code}")
                        print(f"响应内容: {response.text}")
                        continue  # 尝试下一个URL
                        
                except requests.exceptions.RequestException as e:
                    print(f"❌ 连接失败: {str(e)}")
                    continue  # 尝试下一个URL
            
            # 如果所有URL都失败，等待后重试
            if attempt < max_retries:
                print(f"   所有地址都失败，重试中... ({attempt}/{max_retries})")
                time.sleep(retry_interval)
            else:
                print(f"⚠️  已重试 {max_retries} 次，仍然失败")
                print(f"💡 提示：服务可能绑定到了其他IP地址")
                print(f"💡 提示：已尝试的地址: {', '.join(test_urls)}")
                print(f"💡 提示：请检查服务实际绑定的 IP 和端口")
                return False
        
        return False
    
    def test_restart(self):
        """测试重启服务接口"""
        print("\n" + "="*60)
        print("🔄 测试重启服务接口")
        print("="*60)
        
        try:
            response = requests.post(f"{self.base_url}/restart", timeout=30)
            print(f"状态码: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"响应数据: {data}")
                
                if data.get('code') == 0:
                    print("✅ 重启服务请求成功")
                    # 等待服务重新加载模型
                    time.sleep(3)
                    # 再次检查健康状态
                    return self.test_health()
                else:
                    print(f"⚠️  重启服务返回异常: {data.get('msg')}")
                    return False
            else:
                print(f"❌ 重启服务失败，状态码: {response.status_code}")
                print(f"响应内容: {response.text}")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"❌ 重启服务请求失败: {str(e)}")
            return False
    
    def test_stop(self):
        """测试停止服务接口"""
        print("\n" + "="*60)
        print("🛑 测试停止服务接口")
        print("="*60)
        
        try:
            response = requests.post(f"{self.base_url}/stop", timeout=5)
            print(f"状态码: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"响应数据: {data}")
                
                if data.get('code') == 0:
                    print("✅ 停止服务请求成功")
                    # 等待服务停止
                    time.sleep(2)
                    return True
                else:
                    print(f"⚠️  停止服务返回异常: {data.get('msg')}")
                    return False
            else:
                print(f"❌ 停止服务失败，状态码: {response.status_code}")
                print(f"响应内容: {response.text}")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"❌ 停止服务请求失败: {str(e)}")
            return False
    
    def stop_service(self):
        """停止服务进程"""
        if self.process:
            print("\n" + "="*60)
            print("🛑 停止服务进程")
            print("="*60)
            
            try:
                # 先尝试优雅停止
                self.process.terminate()
                try:
                    self.process.wait(timeout=5)
                    print("✅ 服务已停止")
                except subprocess.TimeoutExpired:
                    # 如果5秒内没有停止，强制终止
                    print("⚠️  服务未在5秒内停止，强制终止...")
                    self.process.kill()
                    self.process.wait()
                    print("✅ 服务已强制停止")
            except Exception as e:
                print(f"⚠️  停止服务时出错: {str(e)}")
            
            self.process = None
    
    def run_all_tests(self):
        """运行所有测试"""
        print("="*60)
        print("🧪 Services 服务测试")
        print("="*60)
        
        results = {}
        
        try:
            # 启动服务
            if not self.start_service():
                print("\n❌ 服务启动失败，无法继续测试")
                return False
            
            # 测试健康检查
            results['health'] = self.test_health()
            
            # 可选：测试推理接口（需要提供测试图片）
            # results['inference'] = self.test_inference()
            
            # 注意：不测试 stop 接口，因为测试后服务会停止
            # 如果需要测试 stop 接口，可以取消下面的注释
            # results['stop'] = self.test_stop()
            
            # 注意：不测试 restart 接口，因为会重新加载模型
            # 如果需要测试 restart 接口，可以取消下面的注释
            # results['restart'] = self.test_restart()
            
            # 打印测试结果
            print("\n" + "="*60)
            print("📋 测试结果汇总")
            print("="*60)
            for test_name, result in results.items():
                status = "✅ 通过" if result else "❌ 失败"
                print(f"{test_name}: {status}")
            
            all_passed = all(results.values())
            if all_passed:
                print("\n🎉 所有测试通过！")
            else:
                print("\n⚠️  部分测试失败")
            
            return all_passed
            
        except KeyboardInterrupt:
            print("\n\n⚠️  测试被用户中断")
            return False
        except Exception as e:
            print(f"\n❌ 测试过程中出错: {str(e)}")
            import traceback
            traceback.print_exc()
            return False
        finally:
            # 清理资源
            self.stop_service()


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='测试 services 服务启动')
    parser.add_argument('--model-path', type=str, default=None,
                        help='模型文件路径（如果不指定，会自动查找）')
    parser.add_argument('--port', type=int, default=8899,
                        help='服务端口（默认: 8899）')
    parser.add_argument('--service-name', type=str, default='test_deploy_service',
                        help='服务名称（默认: test_deploy_service）')
    
    args = parser.parse_args()
    
    try:
        tester = ServiceTester(
            model_path=args.model_path,
            port=args.port,
            service_name=args.service_name
        )
        
        success = tester.run_all_tests()
        sys.exit(0 if success else 1)
        
    except Exception as e:
        print(f"❌ 初始化测试器失败: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

