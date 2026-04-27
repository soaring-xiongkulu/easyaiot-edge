"""
@author 翱翔的雄库鲁
@email andywebjava@163.com
@wechat EasyAIoT2025
"""
import argparse
import multiprocessing
import os
import socket
import sys
import threading
import time

import netifaces
import pytz
from dotenv import load_dotenv
from flask import Flask
from healthcheck import HealthCheck, EnvironmentDump
from sqlalchemy import text

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# 设置multiprocessing启动方法为'spawn'以支持CUDA
# 这必须在导入使用multiprocessing的模块之前设置
# 注意：set_start_method只能在主进程中调用一次
try:
    # 检查当前启动方法
    try:
        current_method = multiprocessing.get_start_method()
    except RuntimeError:
        # 如果还没有设置，尝试设置
        current_method = None
    
    if current_method != 'spawn':
        multiprocessing.set_start_method('spawn', force=True)
        print(f"✅ 已设置multiprocessing启动方法为'spawn'（原方法: {current_method or '未设置'}）")
    else:
        print(f"✅ multiprocessing启动方法已为'spawn'")
except RuntimeError as e:
    # 如果已经设置过或无法设置，记录但不中断程序
    try:
        current_method = multiprocessing.get_start_method()
        print(f"⚠️  无法设置multiprocessing启动方法: {str(e)}，当前方法: {current_method}")
    except RuntimeError:
        print(f"⚠️  无法设置multiprocessing启动方法: {str(e)}")

# 解析命令行参数
def parse_args():
    parser = argparse.ArgumentParser(description='启动模型服务器')
    parser.add_argument('--env', type=str, default='', 
                       help='指定环境配置文件，例如: --env=prod 会加载 .env.prod，默认加载 .env')
    args = parser.parse_args()
    return args

# 加载环境变量配置文件（参考VIDEO模块的实现）
def load_env_file(env_name=''):
    """
    加载环境变量配置文件
    使用 override=True 确保配置文件中的值能够覆盖系统环境变量
    """
    if env_name:
        env_file = f'.env.{env_name}'
        if os.path.exists(env_file):
            # 使用 override=True 确保配置文件中的值覆盖已存在的环境变量
            load_dotenv(env_file, override=True)
            print(f"✅ 已加载配置文件: {env_file} (覆盖模式)")
            
            # 显示关键配置信息（用于调试）
            database_url = os.getenv('DATABASE_URL', '未设置')
            flask_port = os.getenv('FLASK_RUN_PORT', '未设置')
            print(f"   📊 DATABASE_URL: {database_url[:50]}..." if len(database_url) > 50 else f"   📊 DATABASE_URL: {database_url}")
            print(f"   📊 FLASK_RUN_PORT: {flask_port}")
        else:
            print(f"⚠️  配置文件 {env_file} 不存在，尝试加载默认 .env 文件")
            if os.path.exists('.env'):
                load_dotenv('.env', override=True)
                print(f"✅ 已加载默认配置文件: .env (覆盖模式)")
            else:
                print(f"❌ 默认配置文件 .env 也不存在")
    else:
        if os.path.exists('.env'):
            load_dotenv('.env', override=True)
            print(f"✅ 已加载默认配置文件: .env (覆盖模式)")
        else:
            print(f"⚠️  默认配置文件 .env 不存在")

# 解析命令行参数并加载配置文件
args = parse_args()
load_env_file(args.env)

# 强制 ONNX Runtime 使用 CPU（在导入任何使用 ONNX Runtime 的模块之前设置）
# 这样可以避免 CUDA 相关的错误，特别是在 CUDA 库不完整的情况下
os.environ['ORT_EXECUTION_PROVIDERS'] = 'CPUExecutionProvider'
print("✅ 已设置 ONNX Runtime 使用 CPU 执行提供者")

# 如果未设置 CUDA_VISIBLE_DEVICES，临时隐藏 GPU 以避免 onnxruntime-gpu 在导入时加载 CUDA 库
# 注意：这不会影响已经设置的 CUDA_VISIBLE_DEVICES（例如在 docker-compose.yaml 中设置的）
# 如果需要在其他地方使用 GPU（如 PyTorch），可以在环境变量中明确设置 CUDA_VISIBLE_DEVICES
if 'CUDA_VISIBLE_DEVICES' not in os.environ:
    # 临时设置空值，避免 onnxruntime-gpu 在导入时尝试加载 CUDA 库
    # 如果后续需要使用 GPU，可以在导入 onnxruntime 相关模块后重新设置
    os.environ['CUDA_VISIBLE_DEVICES'] = ''
    print("⚠️  临时隐藏 GPU 设备以避免 onnxruntime-gpu 导入时的 CUDA 库加载错误")
    print("   如需使用 GPU，请在环境变量中设置 CUDA_VISIBLE_DEVICES（例如：CUDA_VISIBLE_DEVICES=0）")


def get_local_ip():
    # 方案1: 环境变量优先
    if ip := os.getenv('POD_IP'):
        return ip

    # 方案2: 多网卡探测
    for iface in netifaces.interfaces():
        addrs = netifaces.ifaddresses(iface).get(netifaces.AF_INET, [])
        for addr in addrs:
            ip = addr['addr']
            if ip != '127.0.0.1' and not ip.startswith('169.254.'):
                return ip

    # 方案3: 原始方式（仅在无代理时启用）
    if not (os.getenv('HTTP_PROXY') or os.getenv('HTTPS_PROXY')):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(('8.8.8.8', 80))
            ip = s.getsockname()[0]
        finally:
            s.close()
        return ip

    raise RuntimeError("无法确定本地IP，请配置POD_IP环境变量")


def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY')
    
    # 从环境变量获取数据库URL
    database_url = os.environ.get('DATABASE_URL')
    
    if not database_url:
        raise ValueError("DATABASE_URL环境变量未设置，请检查docker-compose.yaml配置或.env文件")
    
    # 转换postgres://为postgresql://（SQLAlchemy要求）
    database_url = database_url.replace("postgres://", "postgresql://", 1)
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['TIMEZONE'] = 'Asia/Shanghai'

    from app.utils.auth_session_middleware import register_auth_session_check
    register_auth_session_check(app)
    
    # 配置 Flask URL 生成（用于在异步任务中使用 url_for）
    # 从环境变量获取配置，如果没有则从运行参数推断
    host = os.getenv('FLASK_RUN_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_RUN_PORT', 5000))
    
    # 检测是否在容器环境中运行
    def is_containerized():
        """检测是否在容器环境中运行"""
        # 检查常见的容器环境标识
        if os.path.exists('/.dockerenv'):
            return True
        # 检查 cgroup 是否包含容器标识
        try:
            with open('/proc/self/cgroup', 'r') as f:
                content = f.read()
                if 'docker' in content or 'kubepods' in content or 'containerd' in content:
                    return True
        except:
            pass
        # 检查环境变量
        if os.getenv('KUBERNETES_SERVICE_HOST') or os.getenv('DOCKER_CONTAINER'):
            return True
        return False
    
    # 如果配置了 SERVER_NAME，使用它；否则根据 host 和 port 构建
    # 如果设置为空字符串、"none" 或 "disable"，则不设置 SERVER_NAME（避免警告）
    server_name = os.getenv('FLASK_SERVER_NAME')
    if server_name and server_name.lower() in ('none', 'disable', ''):
        server_name = None
    elif not server_name:
        # 如果设置了 FLASK_AUTO_SERVER_NAME=false，则不自动设置 SERVER_NAME
        auto_server_name = os.getenv('FLASK_AUTO_SERVER_NAME', 'true').lower()
        if auto_server_name == 'false':
            server_name = None
        else:
            # 在容器环境中，默认不自动设置 SERVER_NAME，避免 Host 不匹配问题
            # 只有在非容器环境或明确配置时才设置
            if is_containerized():
                # 容器环境中，不自动设置 SERVER_NAME，允许通过 localhost、127.0.0.1 或任何 IP 访问
                server_name = None
                print("ℹ️  检测到容器环境，不自动设置 SERVER_NAME（允许灵活访问）")
            else:
                # 非容器环境，按原逻辑设置
                if host == '0.0.0.0':
                    try:
                        actual_ip = os.getenv('POD_IP') or get_local_ip()
                        server_name = f"{actual_ip}:{port}"
                    except Exception as e:
                        # 如果无法获取 IP，不设置 SERVER_NAME（避免 localhost 警告）
                        print(f"⚠️  无法获取本地IP，不设置SERVER_NAME以避免警告: {str(e)}")
                        server_name = None
                else:
                    server_name = f"{host}:{port}"
    
    # 只在设置了 server_name 时才配置，避免 localhost 访问时的警告
    # 注意：在容器环境中，建议不设置 SERVER_NAME 以避免 Host 不匹配的警告
    if server_name:
        app.config['SERVER_NAME'] = server_name
    app.config['APPLICATION_ROOT'] = os.getenv('FLASK_APPLICATION_ROOT', '/')
    app.config['PREFERRED_URL_SCHEME'] = os.getenv('FLASK_PREFERRED_URL_SCHEME', 'http')
    print(f"✅ Flask URL配置: SERVER_NAME={server_name or '(未设置，从请求推断)'}, APPLICATION_ROOT={app.config['APPLICATION_ROOT']}, PREFERRED_URL_SCHEME={app.config['PREFERRED_URL_SCHEME']}")

    # 创建数据目录
    os.makedirs('data/uploads', exist_ok=True)
    os.makedirs('data/datasets', exist_ok=True)
    os.makedirs('data/models', exist_ok=True)
    os.makedirs('data/inference_results', exist_ok=True)
    _ls_root = os.environ.get('LOCAL_STORAGE_ROOT', 'data/local_storage')
    os.makedirs(_ls_root, exist_ok=True)
    app.config['LOCAL_STORAGE_ROOT'] = os.path.abspath(_ls_root)

    # 初始化数据库
    from db_models import db
    db.init_app(app)
    with app.app_context():
        database_uri = app.config['SQLALCHEMY_DATABASE_URI']
        try:
            # 隐藏密码显示（安全考虑）
            safe_uri = database_uri
            if '@' in database_uri:
                parts = database_uri.split('@')
                if len(parts) == 2:
                    user_pass = parts[0].split('://')[-1]
                    if ':' in user_pass:
                        user = user_pass.split(':')[0]
                        safe_uri = database_uri.replace(user_pass, f"{user}:***")
            print(f"数据库连接: {safe_uri}")
            from db_models import Model, ExportRecord, InferenceTask, OCRResult, AIService, AutoLabelTask, AutoLabelResult
            db.create_all()
            print(f"✅ 数据库连接成功，表结构已创建/验证")
        except Exception as e:
            error_msg = str(e)
            print(f"❌ 数据库连接失败: {error_msg}")
            if "Connection refused" in error_msg:
                print(f"💡 提示: 请检查数据库服务是否运行，以及 DATABASE_URL 配置是否正确")
                db_host = database_uri.split('@')[1].split('/')[0] if '@' in database_uri else '未知'
                print(f"   当前 DATABASE_URL 主机: {db_host}")
            elif "No module named" in error_msg:
                print(f"💡 提示: 缺少数据库驱动，请运行: pip install psycopg2-binary")

    # 注册蓝图（延迟导入，避免在环境变量加载前就导入）
    try:
        from app.blueprints import export, inference, model, ocr, speech, deploy, auto_label
        
        app.register_blueprint(export.export_bp, url_prefix='/model/export')
        app.register_blueprint(inference.inference_task_bp, url_prefix='/model/inference_task')
        app.register_blueprint(model.model_bp, url_prefix='/model')
        app.register_blueprint(ocr.ocr_bp, url_prefix='/model/ocr')
        app.register_blueprint(speech.speech_bp, url_prefix='/model/speech')
        app.register_blueprint(deploy.deploy_service_bp, url_prefix='/model/deploy_service')
        app.register_blueprint(auto_label.auto_label_bp, url_prefix='/model/dataset')  # 与其他模块保持一致，使用 /model/ 前缀
        
        # 注册集群推理接口（使用不同的路由，不影响原有推理接口）
        from app.blueprints import cluster
        app.register_blueprint(cluster.cluster_inference_bp, url_prefix='/model/cluster')
        print(f"✅ 所有蓝图注册成功")
        
        # 启动心跳超时检查任务
        try:
            from app.blueprints.deploy import start_heartbeat_checker
            start_heartbeat_checker(app)
        except Exception as e:
            print(f"⚠️  启动心跳检查任务失败: {str(e)}")
    except Exception as e:
        print(f"❌ 蓝图注册失败: {str(e)}")
        import traceback
        traceback.print_exc()
        raise

    import mimetypes
    from urllib.parse import unquote
    from flask import send_file, request, abort
    from app.services.local_bucket_client import LocalBucketClient

    @app.route('/api/v1/buckets/<bucket_name>/objects/download')
    def _local_bucket_object_download(bucket_name):
        prefix = request.args.get('prefix')
        if not prefix:
            abort(400)
        object_name = unquote(prefix)
        client = LocalBucketClient()
        fpath = client.get_file_path(bucket_name, object_name)
        if not fpath:
            abort(404)
        mt, _ = mimetypes.guess_type(fpath)
        return send_file(
            fpath,
            mimetype=mt or 'application/octet-stream',
            as_attachment=False,
            download_name=os.path.basename(fpath),
        )

    # 健康检查路由初始化
    def init_health_check(app):
        health = HealthCheck()
        envdump = EnvironmentDump()

        # 添加数据库检查 - 使用text()包装SQL语句
        def database_available():
            from db_models import db
            try:
                db.session.execute(text('SELECT 1'))
                return True, "Database OK"
            except Exception as e:
                return False, str(e)

        health.add_check(database_available)

        # 显式绑定路由
        app.add_url_rule('/actuator/health', 'healthcheck', view_func=health.run)
        app.add_url_rule('/actuator/info', 'envdump', view_func=envdump.run)

        # 处理所有OPTIONS请求
        @app.route('/actuator/<path:subpath>', methods=['OPTIONS'])
        def handle_options(subpath):
            return '', 204

    init_health_check(app)

    # 直接暴露端口，无服务注册与发现
    port = int(os.getenv('FLASK_RUN_PORT', 5000))
    ip = os.getenv('POD_IP') or get_local_ip()
    if not os.getenv('POD_IP'):
        print(f"⚠️ 未配置POD_IP，自动获取局域网IP: {ip}")
    app.registered_ip = ip

    # 时间格式化过滤器
    @app.template_filter('beijing_time')
    def beijing_time_filter(dt):
        if dt:
            utc = pytz.timezone('UTC')
            beijing = pytz.timezone('Asia/Shanghai')
            utc_time = utc.localize(dt)
            beijing_time = utc_time.astimezone(beijing)
            return beijing_time.strftime('%Y-%m-%d %H:%M:%S')
        return '未知'

    return app


def check_port_available(host, port):
    """检查端口是否可用"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind((host, port))
        sock.close()
        return True
    except OSError:
        return False
    finally:
        try:
            sock.close()
        except:
            pass


if __name__ == '__main__':
    app = create_app()
    # 从环境变量读取主机和端口配置
    host = os.getenv('FLASK_RUN_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_RUN_PORT', 5000))
    
    # 检查端口是否可用
    if not check_port_available(host, port):
        print(f"❌ 错误: 端口 {port} 已被占用")
        print(f"💡 解决方案:")
        print(f"   1. 检查是否有其他进程在使用端口 {port}: lsof -i :{port} 或 netstat -tulpn | grep {port}")
        print(f"   2. 停止占用端口的进程")
        print(f"   3. 或者修改环境变量 FLASK_RUN_PORT 使用其他端口")
        sys.exit(1)
    
    # 获取实际IP地址
    ip = getattr(app, 'registered_ip', None) or get_local_ip()
    print(f"🚀 服务启动: http://{ip}:{port}")
    
    try:
        app.run(host=host, port=port)
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"❌ 错误: 端口 {port} 已被占用")
            print(f"💡 请检查是否有其他进程在使用该端口")
        else:
            print(f"❌ 启动失败: {str(e)}")
        sys.exit(1)
