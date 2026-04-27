"""
@author 翱翔的雄库鲁
@email andywebjava@163.com
@wechat EasyAIoT2025
"""
import argparse
import os
import socket
import sys
import threading
import time
import logging

import netifaces
import pytz
from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS
from healthcheck import HealthCheck, EnvironmentDump
from sqlalchemy import text

from app.blueprints import camera, alert, snap, playback, record, algorithm_task, stream_forward

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# 解析命令行参数
def parse_args():
    parser = argparse.ArgumentParser(description='VIDEO服务启动脚本')
    parser.add_argument('--env', type=str, default='', 
                       help='指定环境配置文件，例如: --env=prod 会加载 .env.prod，默认加载 .env')
    args = parser.parse_args()
    return args

# 加载环境变量配置文件
def load_env_file(env_name=''):
    if env_name:
        env_file = f'.env.{env_name}'
        if os.path.exists(env_file):
            load_dotenv(env_file)
            print(f"✅ 已加载配置文件: {env_file}")
        else:
            print(f"⚠️  配置文件 {env_file} 不存在，尝试加载默认 .env 文件")
            if os.path.exists('.env'):
                load_dotenv('.env')
                print(f"✅ 已加载默认配置文件: .env")
            else:
                print(f"❌ 默认配置文件 .env 也不存在")
    else:
        if os.path.exists('.env'):
            load_dotenv('.env')
            print(f"✅ 已加载默认配置文件: .env")
        else:
            print(f"⚠️  默认配置文件 .env 不存在")

# 解析命令行参数并加载配置文件
args = parse_args()
load_env_file(args.env)

# 配置日志级别，减少第三方库的详细输出
logging.getLogger('apscheduler').setLevel(logging.WARNING)
logging.getLogger('werkzeug').setLevel(logging.WARNING)  # 禁用 Werkzeug 访问日志

# 配置主应用日志
logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

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
    
    # 配置 CORS - 允许跨域请求
    CORS(app, resources={
        r"/video/*": {"origins": "*"},
        r"/actuator/*": {"origins": "*"}
    })

    from app.utils.auth_session_middleware import register_auth_session_check
    register_auth_session_check(app)
    
    # 从环境变量获取数据库URL，优先使用Docker Compose传入的环境变量
    database_url = os.environ.get('DATABASE_URL')
    
    if not database_url:
        raise ValueError("DATABASE_URL环境变量未设置，请检查docker-compose.yaml配置")
    
    # 转换postgres://为postgresql://（SQLAlchemy要求）
    database_url = database_url.replace("postgres://", "postgresql://", 1)
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
        'pool_pre_ping': True,  # 连接前检测连接是否有效
        'pool_recycle': 3600,   # 1小时后回收连接
        'pool_size': 10,        # 连接池大小
        'max_overflow': 20,     # 最大溢出连接数
        'connect_args': {
            'connect_timeout': 10,  # 连接超时时间（秒）
        }
    }
    app.config['TIMEZONE'] = 'Asia/Shanghai'
    
    # 本地对象存储（兼容原 /api/v1/buckets/... URL）
    _ls_root = os.environ.get('LOCAL_STORAGE_ROOT', 'data/local_storage')
    os.makedirs(_ls_root, exist_ok=True)
    app.config['LOCAL_STORAGE_ROOT'] = os.path.abspath(_ls_root)
    app.config['RECORD_ARCHIVE_BUCKET'] = os.environ.get(
        'RECORD_ARCHIVE_BUCKET', 'record-archive'
    )
    app.config['SNAP_ARCHIVE_BUCKET'] = os.environ.get(
        'SNAP_ARCHIVE_BUCKET', 'snap-archive'
    )
    
    # Kafka配置
    # 重要：VIDEO服务使用 host 网络模式，必须使用 localhost 访问 Kafka
    # 如果环境变量中配置了容器名（如 Kafka:9092），需要强制覆盖为 localhost:9092
    kafka_bootstrap_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    if 'Kafka' in kafka_bootstrap_servers or 'kafka-server' in kafka_bootstrap_servers:
        print(f'⚠️  检测到 Kafka 配置使用容器名，强制覆盖为 localhost:9092（VIDEO服务使用 host 网络模式）')
        kafka_bootstrap_servers = 'localhost:9092'
    app.config['KAFKA_BOOTSTRAP_SERVERS'] = kafka_bootstrap_servers
    app.config['KAFKA_ALERT_TOPIC'] = os.environ.get('KAFKA_ALERT_TOPIC', 'iot-alert-notification')
    app.config['KAFKA_SNAPSHOT_ALERT_TOPIC'] = os.environ.get('KAFKA_SNAPSHOT_ALERT_TOPIC', 'iot-snapshot-alert')
    app.config['KAFKA_REQUEST_TIMEOUT_MS'] = int(os.environ.get('KAFKA_REQUEST_TIMEOUT_MS', '5000'))
    app.config['KAFKA_RETRIES'] = int(os.environ.get('KAFKA_RETRIES', '1'))
    app.config['KAFKA_RETRY_BACKOFF_MS'] = int(os.environ.get('KAFKA_RETRY_BACKOFF_MS', '100'))
    app.config['KAFKA_METADATA_MAX_AGE_MS'] = int(os.environ.get('KAFKA_METADATA_MAX_AGE_MS', '300000'))
    app.config['KAFKA_INIT_RETRY_INTERVAL'] = int(os.environ.get('KAFKA_INIT_RETRY_INTERVAL', '60'))

    # 创建数据目录
    os.makedirs('data/uploads', exist_ok=True)
    os.makedirs('data/datasets', exist_ok=True)
    os.makedirs('data/models', exist_ok=True)
    os.makedirs('data/inference_results', exist_ok=True)

    # 初始化数据库
    from models import db
    db.init_app(app)
    with app.app_context():
        try:
            from models import Device, Image, DeviceDirectory, SnapSpace, SnapTask, DetectionRegion, AlgorithmModelService, RegionModelService, DeviceStorageConfig, Playback, RecordSpace, AlgorithmTask, FrameExtractor, Sorter, Pusher, DeviceDetectionRegion
            db.create_all()
            
            # 迁移：检查并添加缺失的列和表
            try:
                # 确保所有表都存在（包括 device_directory）
                db.create_all()
                
                # 检查 device 表的 directory_id 列是否存在
                result = db.session.execute(text("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.columns 
                        WHERE table_schema = 'public' 
                        AND table_name = 'device' 
                        AND column_name = 'directory_id'
                    );
                """))
                directory_id_exists = result.scalar()
                
                if not directory_id_exists:
                    print("⚠️  device.directory_id 列不存在，正在添加...")
                    # 确保 device_directory 表存在
                    db.create_all()
                    # 添加 directory_id 列
                    db.session.execute(text("""
                        ALTER TABLE device 
                        ADD COLUMN directory_id INTEGER 
                        REFERENCES device_directory(id) ON DELETE SET NULL;
                    """))
                    db.session.commit()
                    print("✅ device.directory_id 列添加成功")
                
                # 检查 device 表的 auto_snap_enabled 列是否存在
                result = db.session.execute(text("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.columns 
                        WHERE table_schema = 'public' 
                        AND table_name = 'device' 
                        AND column_name = 'auto_snap_enabled'
                    );
                """))
                auto_snap_enabled_exists = result.scalar()
                
                if not auto_snap_enabled_exists:
                    print("⚠️  device.auto_snap_enabled 列不存在，正在添加...")
                    # 添加 auto_snap_enabled 列，默认值为 false
                    db.session.execute(text("""
                        ALTER TABLE device 
                        ADD COLUMN auto_snap_enabled BOOLEAN NOT NULL DEFAULT FALSE;
                    """))
                    db.session.commit()
                    print("✅ device.auto_snap_enabled 列添加成功")
                
                # 检查 device 表的 cover_image_path 列是否存在
                result = db.session.execute(text("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.columns 
                        WHERE table_schema = 'public' 
                        AND table_name = 'device' 
                        AND column_name = 'cover_image_path'
                    );
                """))
                cover_image_path_exists = result.scalar()
                
                if not cover_image_path_exists:
                    print("⚠️  device.cover_image_path 列不存在，正在添加...")
                    db.session.execute(text("""
                        ALTER TABLE device 
                        ADD COLUMN cover_image_path VARCHAR(500);
                    """))
                    db.session.commit()
                    print("✅ device.cover_image_path 列添加成功")
                
                # 检查 device_detection_region 表是否存在
                result = db.session.execute(text("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_schema = 'public' 
                        AND table_name = 'device_detection_region'
                    );
                """))
                device_detection_region_exists = result.scalar()
                
                if not device_detection_region_exists:
                    print("⚠️  device_detection_region 表不存在，正在创建...")
                    db.create_all()  # 这会创建所有缺失的表
                    print("✅ device_detection_region 表创建成功")
                
                # 检查 device_detection_region 表的 model_ids 列是否存在
                if device_detection_region_exists:
                    result = db.session.execute(text("""
                        SELECT EXISTS (
                            SELECT FROM information_schema.columns 
                            WHERE table_schema = 'public' 
                            AND table_name = 'device_detection_region' 
                            AND column_name = 'model_ids'
                        );
                    """))
                    model_ids_exists = result.scalar()
                    
                    if not model_ids_exists:
                        print("⚠️  device_detection_region.model_ids 列不存在，正在添加...")
                        db.session.execute(text("""
                            ALTER TABLE device_detection_region 
                            ADD COLUMN model_ids TEXT;
                        """))
                        db.session.commit()
                        print("✅ device_detection_region.model_ids 列添加成功")
                
                if directory_id_exists and auto_snap_enabled_exists and cover_image_path_exists and device_detection_region_exists:
                    print("✅ 数据库迁移检查完成，所有列和表已存在")
                
                # 检查 algorithm_task 表的新字段
                try:
                    # 检查 task_type 字段
                    result = db.session.execute(text("""
                        SELECT EXISTS (
                            SELECT FROM information_schema.columns 
                            WHERE table_schema = 'public' 
                            AND table_name = 'algorithm_task' 
                            AND column_name = 'task_type'
                        );
                    """))
                    task_type_exists = result.scalar()
                    
                    if not task_type_exists:
                        print("⚠️  algorithm_task.task_type 列不存在，正在添加...")
                        db.session.execute(text("""
                            ALTER TABLE algorithm_task 
                            ADD COLUMN task_type VARCHAR(20) NOT NULL DEFAULT 'realtime';
                        """))
                        db.session.commit()
                        print("✅ algorithm_task.task_type 列添加成功")
                    
                    # 检查其他新增字段
                    for col_name, col_def in [
                        ('space_id', 'INTEGER REFERENCES snap_space(id) ON DELETE CASCADE'),
                        ('cron_expression', 'VARCHAR(255)'),
                        ('frame_skip', 'INTEGER NOT NULL DEFAULT 1'),
                        ('total_captures', 'INTEGER NOT NULL DEFAULT 0'),
                        ('last_capture_time', 'TIMESTAMP'),
                        ('service_server_ip', 'VARCHAR(45)'),
                        ('service_port', 'INTEGER'),
                        ('service_process_id', 'INTEGER'),
                        ('service_last_heartbeat', 'TIMESTAMP'),
                        ('service_log_path', 'VARCHAR(500)')
                    ]:
                        result = db.session.execute(text(f"""
                            SELECT EXISTS (
                                SELECT FROM information_schema.columns 
                                WHERE table_schema = 'public' 
                                AND table_name = 'algorithm_task' 
                                AND column_name = '{col_name}'
                            );
                        """))
                        col_exists = result.scalar()
                        
                        if not col_exists:
                            print(f"⚠️  algorithm_task.{col_name} 列不存在，正在添加...")
                            db.session.execute(text(f"""
                                ALTER TABLE algorithm_task 
                                ADD COLUMN {col_name} {col_def};
                            """))
                            db.session.commit()
                            print(f"✅ algorithm_task.{col_name} 列添加成功")
                    
                    print("✅ algorithm_task 表迁移检查完成")
                except Exception as e:
                    print(f"⚠️  algorithm_task 表迁移检查失败: {str(e)}")
                    import traceback
                    traceback.print_exc()
                    db.session.rollback()
                
                # 检查 alert 表的 task_type 字段
                try:
                    result = db.session.execute(text("""
                        SELECT EXISTS (
                            SELECT FROM information_schema.columns 
                            WHERE table_schema = 'public' 
                            AND table_name = 'alert' 
                            AND column_name = 'task_type'
                        );
                    """))
                    alert_task_type_exists = result.scalar()
                    
                    if not alert_task_type_exists:
                        print("⚠️  alert.task_type 列不存在，正在添加...")
                        db.session.execute(text("""
                            ALTER TABLE alert 
                            ADD COLUMN task_type VARCHAR(20) NULL;
                        """))
                        db.session.commit()
                        print("✅ alert.task_type 列添加成功")
                        
                        # 尝试从 information 字段中提取 task_type 并填充（兼容旧数据）
                        try:
                            # 使用 PostgreSQL 的 JSON 函数提取 task_type
                            db.session.execute(text("""
                                UPDATE alert 
                                SET task_type = (
                                    CASE 
                                        WHEN information IS NOT NULL 
                                             AND information::text LIKE '%"task_type"%' 
                                             AND information::text LIKE '%"realtime"%' THEN 'realtime'
                                        WHEN information IS NOT NULL 
                                             AND information::text LIKE '%"task_type"%' 
                                             AND (information::text LIKE '%"snap"%' OR information::text LIKE '%"snapshot"%') THEN 'snap'
                                        ELSE 'realtime'
                                    END
                                )
                                WHERE task_type IS NULL;
                            """))
                            db.session.commit()
                            print("✅ 已从 information 字段迁移 task_type 数据")
                        except Exception as e:
                            print(f"⚠️  迁移 task_type 数据失败（不影响功能）: {str(e)}")
                            db.session.rollback()
                            
                            # 如果迁移失败，至少设置默认值
                            try:
                                db.session.execute(text("""
                                    UPDATE alert 
                                    SET task_type = 'realtime'
                                    WHERE task_type IS NULL;
                                """))
                                db.session.commit()
                                print("✅ 已设置默认 task_type 值")
                            except:
                                pass
                    
                    print("✅ alert 表迁移检查完成")
                except Exception as e:
                    print(f"⚠️  alert 表迁移检查失败: {str(e)}")
                    import traceback
                    traceback.print_exc()
                    db.session.rollback()
                
            except Exception as e:
                print(f"⚠️  数据库迁移检查失败: {str(e)}")
                import traceback
                traceback.print_exc()
                db.session.rollback()
        except Exception as e:
            print(f"❌ 建表失败: {str(e)}")

    # 注册蓝图
    try:
        app.register_blueprint(camera.camera_bp, url_prefix='/video/camera')
        print(f"✅ Camera Blueprint 注册成功")
    except Exception as e:
        print(f"❌ Camera Blueprint 注册失败: {str(e)}")
        import traceback
        traceback.print_exc()
    
    try:
        app.register_blueprint(alert.alert_bp, url_prefix='/video/alert')
        print(f"✅ Alert Blueprint 注册成功")
    except Exception as e:
        print(f"❌ Alert Blueprint 注册失败: {str(e)}")
        import traceback
        traceback.print_exc()
    
    try:
        app.register_blueprint(snap.snap_bp, url_prefix='/video/snap')
        app.register_blueprint(record.record_bp, url_prefix='/video/record')
        print(f"✅ Snap Blueprint 注册成功")
    except Exception as e:
        print(f"❌ Snap Blueprint 注册失败: {str(e)}")
        import traceback
        traceback.print_exc()
    
    try:
        app.register_blueprint(playback.playback_bp, url_prefix='/video/playback')
        print(f"✅ Playback Blueprint 注册成功")
    except Exception as e:
        print(f"❌ Playback Blueprint 注册失败: {str(e)}")
        import traceback
        traceback.print_exc()
    
    try:
        app.register_blueprint(algorithm_task.algorithm_task_bp, url_prefix='/video/algorithm')
        print(f"✅ Algorithm Task Blueprint 注册成功")
    except Exception as e:
        print(f"❌ Algorithm Task Blueprint 注册失败: {str(e)}")
    
    try:
        app.register_blueprint(stream_forward.stream_forward_bp, url_prefix='/video/stream-forward')
        print(f"✅ Stream Forward Blueprint 注册成功")
    except Exception as e:
        print(f"❌ Algorithm Task Blueprint 注册失败: {str(e)}")
        import traceback
        traceback.print_exc()
    
    try:
        from app.blueprints import device_detection_region
        app.register_blueprint(device_detection_region.device_detection_region_bp, url_prefix='/video/device-detection')
        print(f"✅ Device Detection Region Blueprint 注册成功")
    except Exception as e:
        print(f"❌ Device Detection Region Blueprint 注册失败: {str(e)}")
        import traceback
        traceback.print_exc()
    
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
            from models import db
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
    port = int(os.getenv('FLASK_RUN_PORT', 6000))
    ip = os.getenv('POD_IP') or get_local_ip()
    app.registered_ip = ip

    # 应用退出时停止自动抽帧线程
    def on_app_teardown():
        try:
            from app.services.auto_frame_extraction_service import stop_auto_frame_extraction
            stop_auto_frame_extraction()
        except Exception as e:
            print(f"❌ 停止自动抽帧线程失败: {str(e)}")

    import atexit
    atexit.register(on_app_teardown)

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

    # 启动摄像头搜索服务
    with app.app_context():
        from app.services.camera_service import _start_search, scheduler
        _start_search(app)
        import atexit
        # 安全关闭调度器：检查调度器是否正在运行
        def safe_shutdown_scheduler():
            try:
                if scheduler.running:
                    scheduler.shutdown(wait=False)
                    print('✅ 调度器已安全关闭')
            except Exception as e:
                # 忽略调度器未运行或已关闭的异常
                pass
        atexit.register(safe_shutdown_scheduler)
        
        
        # 安全关闭所有算法任务守护进程
        def safe_shutdown_daemons():
            try:
                from app.services.algorithm_task_launcher_service import stop_all_daemons
                stop_all_daemons()
                print('✅ 所有算法任务守护进程已安全关闭')
            except Exception as e:
                # 忽略守护进程未运行或已关闭的异常
                print(f'⚠️  关闭守护进程时出错: {str(e)}')
        atexit.register(safe_shutdown_daemons)

    # 应用启动后自动启动需要推流的设备
    with app.app_context():
        try:
            from app.blueprints.camera import auto_start_streaming
            auto_start_streaming()
        except Exception as e:
            print(f"❌ 自动启动推流设备失败: {str(e)}")
    
    # 启动抓拍空间自动清理任务（每天凌晨2点执行）
    with app.app_context():
        try:
            from app.services.camera_service import scheduler
            from app.services.snap_space_service import auto_cleanup_all_spaces
            
            if scheduler and not scheduler.running:
                scheduler.start()
            
            # 创建包装函数，确保在应用上下文中执行
            def cleanup_wrapper():
                """包装函数，确保传入app参数"""
                return auto_cleanup_all_spaces(app=app)
            
            # 每天凌晨2点执行自动清理
            scheduler.add_job(
                cleanup_wrapper,
                'cron',
                hour=2,
                minute=0,
                id='auto_cleanup_snap_spaces',
                replace_existing=True
            )
            print('✅ 抓拍空间自动清理任务已启动（每天凌晨2点执行）')
        except Exception as e:
            print(f"❌ 启动抓拍空间自动清理任务失败: {str(e)}")
            import traceback
            traceback.print_exc()
        
        # 初始化抓拍任务调度器
        try:
            from app.services.snap_task_service import init_all_tasks
            init_all_tasks()
            print("✅ 抓拍任务调度器初始化成功")
        except Exception as e:
            print(f"❌ 初始化抓拍任务调度器失败: {str(e)}")
            import traceback
            traceback.print_exc()
        
        # 启动自动抽帧线程（每分钟从所有在线摄像头的RTSP流中抽帧）
        # 已禁用：由算法任务来处理抽帧，不再单独启动自动抽帧
        # try:
        #     from app.services.auto_frame_extraction_service import start_auto_frame_extraction
        #     start_auto_frame_extraction(app)
        #     print("✅ 自动抽帧线程启动成功（每分钟执行一次）")
        # except Exception as e:
        #     print(f"❌ 启动自动抽帧线程失败: {str(e)}")
        #     import traceback
        #     traceback.print_exc()
        
        # 启动心跳超时检查任务（每分钟检查一次）
        try:
            from app.services.camera_service import scheduler
            from models import FrameExtractor, Sorter, Pusher
            
            if scheduler and not scheduler.running:
                scheduler.start()
            
            def check_heartbeat_timeout():
                """定时检查心跳超时，超过1分钟没上报则更新状态为stopped"""
                try:
                    with app.app_context():
                        from datetime import datetime, timedelta
                        from models import db, AlgorithmTask
                        from sqlalchemy.exc import OperationalError, DisconnectionError
                        
                        timeout_threshold = datetime.utcnow() - timedelta(minutes=1)
                        
                        try:
                            # 检查抽帧器
                            timeout_extractors = FrameExtractor.query.filter(
                                FrameExtractor.status.in_(['running']),
                                (FrameExtractor.last_heartbeat < timeout_threshold) | (FrameExtractor.last_heartbeat.is_(None))
                            ).all()
                            
                            for extractor in timeout_extractors:
                                old_status = extractor.status
                                extractor.status = 'stopped'
                                logger.info(f"抽帧器心跳超时，状态从 {old_status} 更新为 stopped: {extractor.extractor_name}")
                            
                            # 检查排序器
                            timeout_sorters = Sorter.query.filter(
                                Sorter.status.in_(['running']),
                                (Sorter.last_heartbeat < timeout_threshold) | (Sorter.last_heartbeat.is_(None))
                            ).all()
                            
                            for sorter in timeout_sorters:
                                old_status = sorter.status
                                sorter.status = 'stopped'
                                logger.info(f"排序器心跳超时，状态从 {old_status} 更新为 stopped: {sorter.sorter_name}")
                            
                            # 检查推送器
                            timeout_pushers = Pusher.query.filter(
                                Pusher.status.in_(['running']),
                                (Pusher.last_heartbeat < timeout_threshold) | (Pusher.last_heartbeat.is_(None))
                            ).all()
                            
                            for pusher in timeout_pushers:
                                old_status = pusher.status
                                pusher.status = 'stopped'
                                logger.info(f"推送器心跳超时，状态从 {old_status} 更新为 stopped: {pusher.pusher_name}")
                            
                            # 检查算法任务（实时算法任务）
                            timeout_algorithm_tasks = AlgorithmTask.query.filter(
                                AlgorithmTask.run_status.in_(['running', 'restarting']),
                                AlgorithmTask.task_type == 'realtime',
                                ((AlgorithmTask.service_last_heartbeat < timeout_threshold) | (AlgorithmTask.service_last_heartbeat.is_(None)))
                            ).all()
                            
                            for task in timeout_algorithm_tasks:
                                old_status = task.run_status
                                task.run_status = 'stopped'
                                logger.info(f"算法任务心跳超时，状态从 {old_status} 更新为 stopped: task_id={task.id}, task_name={task.task_name}")
                            
                            if timeout_extractors or timeout_sorters or timeout_pushers or timeout_algorithm_tasks:
                                db.session.commit()
                                total = len(timeout_extractors) + len(timeout_sorters) + len(timeout_pushers) + len(timeout_algorithm_tasks)
                                logger.info(f"已更新 {total} 个服务状态为stopped")
                            
                            # 清理已停止的进程
                            try:
                                from app.services.algorithm_task_launcher_service import cleanup_stopped_processes
                                cleanup_stopped_processes()
                            except Exception as e:
                                logger.warning(f"清理已停止的进程失败: {str(e)}")
                                
                        except (OperationalError, DisconnectionError) as db_error:
                            # 数据库连接异常，尝试回滚并记录错误
                            logger.warning(f"数据库连接异常，尝试重新连接: {str(db_error)}")
                            try:
                                db.session.rollback()
                                # 尝试重新连接
                                db.session.execute(text("SELECT 1"))
                            except Exception as reconnect_error:
                                logger.error(f"数据库重连失败: {str(reconnect_error)}")
                                # 不抛出异常，让定时任务继续运行
                except Exception as e:
                    # 记录详细错误信息，但不中断定时任务
                    logger.error(f"检查心跳超时失败: {str(e)}", exc_info=True)
                    try:
                        with app.app_context():
                            from models import db
                            db.session.rollback()
                    except:
                        pass
            
            # 每分钟执行一次心跳超时检查
            scheduler.add_job(
                check_heartbeat_timeout,
                'interval',
                minutes=1,
                id='check_heartbeat_timeout',
                replace_existing=True
            )
            print('✅ 心跳超时检查任务已启动（每分钟执行一次）')
        except Exception as e:
            print(f"❌ 启动心跳超时检查任务失败: {str(e)}")
            import traceback
            traceback.print_exc()
        
        # 自动启动所有启用的算法任务的服务
        try:
            from app.services.algorithm_task_launcher_service import auto_start_all_tasks
            auto_start_all_tasks(app)
            print("✅ 算法任务服务自动启动完成")
        except Exception as e:
            print(f"❌ 自动启动算法任务服务失败: {str(e)}")
            import traceback
            traceback.print_exc()
        
        # 自动启动所有启用的推流转发任务的服务
        try:
            from app.services.stream_forward_launcher_service import auto_start_all_tasks
            auto_start_all_tasks(app)
            print("✅ 推流转发任务服务自动启动完成")
        except Exception as e:
            print(f"❌ 自动启动推流转发任务服务失败: {str(e)}")
            import traceback
            traceback.print_exc()

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
    port = int(os.getenv('FLASK_RUN_PORT', 6000))
    
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