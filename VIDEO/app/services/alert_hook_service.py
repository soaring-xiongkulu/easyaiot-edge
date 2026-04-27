"""
告警Hook服务：将告警数据发送到 Kafka，由下游统一处理（无通知人/渠道等逻辑）
@author 翱翔的雄库鲁
@email andywebjava@163.com
@wechat EasyAIoT2025
"""
import json
import logging
import time
from datetime import datetime
from typing import Dict

from flask import current_app
from kafka import KafkaProducer
from kafka.errors import KafkaError

logger = logging.getLogger(__name__)

_producer = None
_producer_init_failed = False
_last_init_attempt_time = 0
_init_retry_interval = 60
_last_kafka_unavailable_warning_time = 0
_kafka_unavailable_warning_interval = 300


def get_kafka_producer():
    """获取Kafka生产者实例（单例，带错误处理和重试限制）"""
    global _producer, _producer_init_failed, _last_init_attempt_time

    try:
        bootstrap_servers = current_app.config.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
        request_timeout_ms = current_app.config.get('KAFKA_REQUEST_TIMEOUT_MS', 30000)
        retries = current_app.config.get('KAFKA_RETRIES', 3)
        retry_backoff_ms = current_app.config.get('KAFKA_RETRY_BACKOFF_MS', 1000)
        metadata_max_age_ms = current_app.config.get('KAFKA_METADATA_MAX_AGE_MS', 300000)
        init_retry_interval = current_app.config.get('KAFKA_INIT_RETRY_INTERVAL', 60)
        max_block_ms = current_app.config.get('KAFKA_MAX_BLOCK_MS', 60000)
        delivery_timeout_ms = current_app.config.get('KAFKA_DELIVERY_TIMEOUT_MS', 120000)
    except RuntimeError:
        import os
        bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
        request_timeout_ms = int(os.getenv('KAFKA_REQUEST_TIMEOUT_MS', '30000'))
        retries = int(os.getenv('KAFKA_RETRIES', '3'))
        retry_backoff_ms = int(os.getenv('KAFKA_RETRY_BACKOFF_MS', '1000'))
        metadata_max_age_ms = int(os.getenv('KAFKA_METADATA_MAX_AGE_MS', '300000'))
        init_retry_interval = int(os.getenv('KAFKA_INIT_RETRY_INTERVAL', '60'))
        max_block_ms = int(os.getenv('KAFKA_MAX_BLOCK_MS', '60000'))
        delivery_timeout_ms = int(os.getenv('KAFKA_DELIVERY_TIMEOUT_MS', '120000'))

    original_bootstrap_servers = bootstrap_servers
    if 'Kafka' in bootstrap_servers or 'kafka-server' in bootstrap_servers:
        logger.warning(
            f'⚠️  检测到 Kafka 配置使用容器名 "{bootstrap_servers}"，强制覆盖为 localhost:9092（VIDEO服务使用 host 网络模式）'
        )
        bootstrap_servers = 'localhost:9092'

    logger.debug(f'Kafka bootstrap_servers: {bootstrap_servers} (原始值: {original_bootstrap_servers})')

    if _producer is not None:
        try:
            if hasattr(_producer, 'list_topics'):
                _producer.list_topics(timeout=1)
            return _producer
        except Exception as e:
            logger.warning(f"Kafka生产者连接已断开，将重新初始化: {str(e)}")
            try:
                _producer.close(timeout=1)
            except Exception:
                pass
            _producer = None

    current_time = time.time()
    if _producer_init_failed and (current_time - _last_init_attempt_time) < init_retry_interval:
        return None

    try:
        bootstrap_servers_list = bootstrap_servers.split(',') if isinstance(bootstrap_servers, str) else bootstrap_servers
        bootstrap_servers_list = [
            s.strip() for s in bootstrap_servers_list
            if s.strip() and 'Kafka' not in s and 'kafka-server' not in s
        ]
        if not bootstrap_servers_list:
            bootstrap_servers_list = ['localhost:9092']

        logger.info(f"正在初始化 Kafka 生产者: bootstrap_servers={bootstrap_servers_list}")

        _producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers_list,
            value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            request_timeout_ms=request_timeout_ms,
            connections_max_idle_ms=300000,
            retries=retries,
            retry_backoff_ms=retry_backoff_ms,
            metadata_max_age_ms=metadata_max_age_ms,
            max_block_ms=max_block_ms,
            delivery_timeout_ms=delivery_timeout_ms,
            api_version=(2, 5),
            enable_idempotence=True,
            batch_size=16384,
            linger_ms=10,
            client_id='video-alert-producer',
        )
        logger.info(
            f"✅ Kafka生产者初始化成功: bootstrap_servers={bootstrap_servers_list}, "
            f"request_timeout_ms={request_timeout_ms}, retries={retries}"
        )
        _producer_init_failed = False
    except Exception as e:
        _producer = None
        _producer_init_failed = True
        _last_init_attempt_time = current_time
        logger.error(f"❌ Kafka生产者初始化失败: bootstrap_servers={bootstrap_servers}, error={str(e)}")
        if 'Kafka:9092' in str(e) or 'Kafka' in str(e):
            logger.error(
                "⚠️  检测到错误信息中包含容器名 'Kafka'，请检查 KAFKA_ADVERTISED_LISTENERS 是否包含 PLAINTEXT://localhost:9092"
            )
        logger.warning(f"Kafka生产者初始化失败，将在 {init_retry_interval} 秒后重试")
        return None

    return _producer


def process_alert_hook(alert_data: Dict) -> Dict:
    """
    处理告警Hook：将告警 JSON 发到 Kafka（不含通知人、渠道等字段）。
    """
    global _producer, _last_kafka_unavailable_warning_time, _kafka_unavailable_warning_interval
    try:
        device_id = alert_data.get('device_id')
        task_type = alert_data.get('task_type', 'realtime')
        if task_type == 'snapshot':
            task_type = 'snap'

        simple_message = {
            'deviceId': alert_data.get('device_id'),
            'deviceName': alert_data.get('device_name'),
            'alert': {
                'object': alert_data.get('object'),
                'event': alert_data.get('event'),
                'region': alert_data.get('region'),
                'information': alert_data.get('information'),
                'imagePath': alert_data.get('image_path'),
                'recordPath': alert_data.get('record_path'),
                'time': alert_data.get('time', datetime.now().strftime('%Y-%m-%d %H:%M:%S')),
                'taskType': task_type,
            },
            'timestamp': datetime.now().isoformat(),
        }

        producer = get_kafka_producer()
        if producer is None:
            current_time = time.time()
            if (current_time - _last_kafka_unavailable_warning_time) >= _kafka_unavailable_warning_interval:
                logger.warning(
                    f"⚠️  Kafka不可用，跳过告警消息发送: device_id={device_id}（将在 {_kafka_unavailable_warning_interval} 秒后再次提醒）"
                )
                _last_kafka_unavailable_warning_time = current_time
            else:
                logger.debug(f"Kafka不可用，跳过告警消息发送: device_id={device_id}")
            return {'status': 'failed', 'error': 'Kafka不可用'}

        try:
            if task_type == 'snap':
                kafka_topic = current_app.config.get('KAFKA_SNAPSHOT_ALERT_TOPIC', 'iot-snapshot-alert')
            else:
                kafka_topic = current_app.config.get('KAFKA_ALERT_TOPIC', 'iot-alert-notification')
        except RuntimeError:
            import os
            if task_type == 'snap':
                kafka_topic = os.getenv('KAFKA_SNAPSHOT_ALERT_TOPIC', 'iot-snapshot-alert')
            else:
                kafka_topic = os.getenv('KAFKA_ALERT_TOPIC', 'iot-alert-notification')

        logger.info(f"📤 发送告警到Kafka: device_id={device_id}, topic={kafka_topic}")

        future = producer.send(kafka_topic, key=str(device_id) if device_id else None, value=simple_message)
        try:
            record_metadata = future.get(timeout=10)
            logger.info(
                f"✅ 告警消息发送成功: topic={record_metadata.topic}, "
                f"partition={record_metadata.partition}, offset={record_metadata.offset}"
            )
            return {
                'status': 'success',
                'topic': record_metadata.topic,
                'partition': record_metadata.partition,
                'offset': record_metadata.offset,
            }
        except Exception as e:
            logger.error(f"❌ 告警消息发送到Kafka失败: device_id={device_id}, error={str(e)}")
            if isinstance(e, (KafkaError, ConnectionError, TimeoutError)) or 'socket disconnected' in str(e).lower():
                try:
                    _producer.close(timeout=1)
                except Exception:
                    pass
                _producer = None
            return {'status': 'failed', 'error': str(e)}
    except Exception as e:
        logger.error(f"处理告警Hook失败: {str(e)}", exc_info=True)
        raise RuntimeError(f"处理告警Hook失败: {str(e)}")
