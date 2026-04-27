--
-- PostgreSQL database dump
--

\restrict af7pCVwnp32bnyp4mwsppWdgPKo21zmcpy14bm8rfpenX2tHQTNYeDQecfK6NtJ

-- Dumped from database version 18.1 (Debian 18.1-1.pgdg13+2)
-- Dumped by pg_dump version 18.1 (Debian 18.1-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS "iot-edge-video20";
--
-- Name: iot-edge-video20; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE "iot-edge-video20" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.utf8';


\unrestrict af7pCVwnp32bnyp4mwsppWdgPKo21zmcpy14bm8rfpenX2tHQTNYeDQecfK6NtJ
\encoding SQL_ASCII
\connect -reuse-previous=on "dbname='iot-edge-video20'"
\restrict af7pCVwnp32bnyp4mwsppWdgPKo21zmcpy14bm8rfpenX2tHQTNYeDQecfK6NtJ

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alert; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alert (
    id integer NOT NULL,
    object character varying(30) NOT NULL,
    event character varying(30) NOT NULL,
    region character varying(30),
    information text,
    "time" timestamp with time zone DEFAULT now() NOT NULL,
    device_id character varying(30) NOT NULL,
    device_name character varying(30) NOT NULL,
    image_path character varying(200),
    record_path character varying(200),
    task_type character varying(20),
    notify_users text,
    channels text,
    notification_sent boolean NOT NULL,
    notification_sent_time timestamp without time zone
);


--
-- Name: COLUMN alert.task_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.alert.task_type IS '告警事件类型[realtime:实时算法任务,snap:抓拍算法任务]';


--
-- Name: COLUMN alert.notify_users; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.alert.notify_users IS '通知人列表（JSON格式，格式：[{"phone": "xxx", "email": "xxx", "name": "xxx"}, ...]）';


--
-- Name: COLUMN alert.channels; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.alert.channels IS '通知渠道配置（JSON格式，格式：[{"method": "sms", "template_id": "xxx"}, ...]）';


--
-- Name: COLUMN alert.notification_sent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.alert.notification_sent IS '是否已发送通知';


--
-- Name: COLUMN alert.notification_sent_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.alert.notification_sent_time IS '通知发送时间';


--
-- Name: alert_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.alert_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: alert_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.alert_id_seq OWNED BY public.alert.id;


--
-- Name: algorithm_model_service; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.algorithm_model_service (
    id integer NOT NULL,
    task_id integer NOT NULL,
    service_name character varying(255) NOT NULL,
    service_url character varying(500) NOT NULL,
    service_type character varying(100),
    model_id integer,
    threshold double precision,
    request_method character varying(10) NOT NULL,
    request_headers text,
    request_body_template text,
    timeout integer NOT NULL,
    is_enabled boolean NOT NULL,
    sort_order integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN algorithm_model_service.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.task_id IS '所属算法任务ID';


--
-- Name: COLUMN algorithm_model_service.service_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.service_name IS '服务名称';


--
-- Name: COLUMN algorithm_model_service.service_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.service_url IS 'AI模型服务请求接口URL';


--
-- Name: COLUMN algorithm_model_service.service_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.service_type IS '服务类型[FIRE:火焰烟雾检测,CROWD:人群聚集计数,SMOKE:吸烟检测等]';


--
-- Name: COLUMN algorithm_model_service.model_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.model_id IS '关联的模型ID';


--
-- Name: COLUMN algorithm_model_service.threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.threshold IS '检测阈值';


--
-- Name: COLUMN algorithm_model_service.request_method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.request_method IS '请求方法[GET,POST]';


--
-- Name: COLUMN algorithm_model_service.request_headers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.request_headers IS '请求头（JSON格式）';


--
-- Name: COLUMN algorithm_model_service.request_body_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.request_body_template IS '请求体模板（JSON格式，支持变量替换）';


--
-- Name: COLUMN algorithm_model_service.timeout; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.timeout IS '请求超时时间（秒）';


--
-- Name: COLUMN algorithm_model_service.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.is_enabled IS '是否启用';


--
-- Name: COLUMN algorithm_model_service.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_model_service.sort_order IS '排序顺序';


--
-- Name: algorithm_model_service_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.algorithm_model_service_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: algorithm_model_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.algorithm_model_service_id_seq OWNED BY public.algorithm_model_service.id;


--
-- Name: algorithm_task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.algorithm_task (
    id integer NOT NULL,
    task_name character varying(255) NOT NULL,
    task_code character varying(255) NOT NULL,
    task_type character varying(20) NOT NULL,
    model_ids text,
    model_names text,
    extract_interval integer NOT NULL,
    rtmp_input_url character varying(500),
    rtmp_output_url character varying(500),
    tracking_enabled boolean NOT NULL,
    tracking_similarity_threshold double precision NOT NULL,
    tracking_max_age integer NOT NULL,
    tracking_smooth_alpha double precision NOT NULL,
    alert_event_enabled boolean NOT NULL,
    alert_notification_enabled boolean NOT NULL,
    alert_notification_config text,
    alarm_suppress_time integer NOT NULL,
    last_notify_time timestamp without time zone,
    space_id integer,
    cron_expression character varying(255),
    frame_skip integer NOT NULL,
    status smallint NOT NULL,
    is_enabled boolean NOT NULL,
    run_status character varying(20) NOT NULL,
    exception_reason character varying(500),
    service_server_ip character varying(45),
    service_port integer,
    service_process_id integer,
    service_last_heartbeat timestamp without time zone,
    service_log_path character varying(500),
    total_frames integer NOT NULL,
    total_detections integer NOT NULL,
    total_captures integer NOT NULL,
    last_process_time timestamp without time zone,
    last_success_time timestamp without time zone,
    last_capture_time timestamp without time zone,
    description character varying(500),
    defense_mode character varying(20) NOT NULL,
    defense_schedule text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN algorithm_task.task_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.task_name IS '任务名称';


--
-- Name: COLUMN algorithm_task.task_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.task_code IS '任务编号（唯一标识）';


--
-- Name: COLUMN algorithm_task.task_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.task_type IS '任务类型[realtime:实时算法任务,snap:抓拍算法任务]';


--
-- Name: COLUMN algorithm_task.model_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.model_ids IS '关联的模型ID列表（JSON格式，如[1,2,3]）';


--
-- Name: COLUMN algorithm_task.model_names; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.model_names IS '关联的模型名称列表（逗号分隔，冗余字段，用于快速显示）';


--
-- Name: COLUMN algorithm_task.extract_interval; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.extract_interval IS '抽帧间隔（每N帧抽一次，仅实时算法任务）';


--
-- Name: COLUMN algorithm_task.rtmp_input_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.rtmp_input_url IS 'RTMP输入流地址（仅实时算法任务）';


--
-- Name: COLUMN algorithm_task.rtmp_output_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.rtmp_output_url IS 'RTMP输出流地址（仅实时算法任务）';


--
-- Name: COLUMN algorithm_task.tracking_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.tracking_enabled IS '是否启用目标追踪';


--
-- Name: COLUMN algorithm_task.tracking_similarity_threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.tracking_similarity_threshold IS '追踪相似度阈值';


--
-- Name: COLUMN algorithm_task.tracking_max_age; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.tracking_max_age IS '追踪目标最大存活帧数';


--
-- Name: COLUMN algorithm_task.tracking_smooth_alpha; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.tracking_smooth_alpha IS '追踪平滑系数';


--
-- Name: COLUMN algorithm_task.alert_event_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.alert_event_enabled IS '是否启用告警事件';


--
-- Name: COLUMN algorithm_task.alert_notification_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.alert_notification_enabled IS '是否启用告警通知';


--
-- Name: COLUMN algorithm_task.alert_notification_config; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.alert_notification_config IS '告警通知配置（JSON格式，包含通知渠道和模板配置，格式：{"channels": [{"method": "sms", "template_id": "xxx", "template_name": "xxx"}, ...]}）';


--
-- Name: COLUMN algorithm_task.alarm_suppress_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.alarm_suppress_time IS '告警通知抑制时间（秒），防止频繁通知，默认5分钟';


--
-- Name: COLUMN algorithm_task.last_notify_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.last_notify_time IS '最后通知时间';


--
-- Name: COLUMN algorithm_task.space_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.space_id IS '所属抓拍空间ID（仅抓拍算法任务）';


--
-- Name: COLUMN algorithm_task.cron_expression; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.cron_expression IS 'Cron表达式（仅抓拍算法任务）';


--
-- Name: COLUMN algorithm_task.frame_skip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.frame_skip IS '抽帧间隔（每N帧抓一次，仅抓拍算法任务）';


--
-- Name: COLUMN algorithm_task.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.status IS '状态[0:正常,1:异常]';


--
-- Name: COLUMN algorithm_task.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.is_enabled IS '是否启用[0:停用,1:启用]';


--
-- Name: COLUMN algorithm_task.run_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.run_status IS '运行状态[running:运行中,stopped:已停止,restarting:重启中]';


--
-- Name: COLUMN algorithm_task.exception_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.exception_reason IS '异常原因';


--
-- Name: COLUMN algorithm_task.service_server_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.service_server_ip IS '服务运行服务器IP';


--
-- Name: COLUMN algorithm_task.service_port; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.service_port IS '服务端口';


--
-- Name: COLUMN algorithm_task.service_process_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.service_process_id IS '服务进程ID';


--
-- Name: COLUMN algorithm_task.service_last_heartbeat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.service_last_heartbeat IS '服务最后心跳时间';


--
-- Name: COLUMN algorithm_task.service_log_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.service_log_path IS '服务日志路径';


--
-- Name: COLUMN algorithm_task.total_frames; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.total_frames IS '总处理帧数';


--
-- Name: COLUMN algorithm_task.total_detections; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.total_detections IS '总检测次数';


--
-- Name: COLUMN algorithm_task.total_captures; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.total_captures IS '总抓拍次数（仅抓拍算法任务）';


--
-- Name: COLUMN algorithm_task.last_process_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.last_process_time IS '最后处理时间';


--
-- Name: COLUMN algorithm_task.last_success_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.last_success_time IS '最后成功时间';


--
-- Name: COLUMN algorithm_task.last_capture_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.last_capture_time IS '最后抓拍时间（仅抓拍算法任务）';


--
-- Name: COLUMN algorithm_task.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.description IS '任务描述';


--
-- Name: COLUMN algorithm_task.defense_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.defense_mode IS '布防模式[full:全防模式,half:半防模式,day:白天模式,night:夜间模式]';


--
-- Name: COLUMN algorithm_task.defense_schedule; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task.defense_schedule IS '布防时段配置（JSON格式，7天×24小时的二维数组）';


--
-- Name: algorithm_task_device; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.algorithm_task_device (
    task_id integer NOT NULL,
    device_id character varying(100) NOT NULL,
    created_at timestamp without time zone
);


--
-- Name: COLUMN algorithm_task_device.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task_device.task_id IS '算法任务ID';


--
-- Name: COLUMN algorithm_task_device.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task_device.device_id IS '摄像头ID';


--
-- Name: COLUMN algorithm_task_device.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.algorithm_task_device.created_at IS '创建时间';


--
-- Name: algorithm_task_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.algorithm_task_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: algorithm_task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.algorithm_task_id_seq OWNED BY public.algorithm_task.id;


--
-- Name: detection_region; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detection_region (
    id integer NOT NULL,
    task_id integer NOT NULL,
    region_name character varying(255) NOT NULL,
    region_type character varying(50) NOT NULL,
    points text NOT NULL,
    image_id integer,
    algorithm_type character varying(255),
    algorithm_model_id integer,
    algorithm_threshold double precision,
    algorithm_enabled boolean NOT NULL,
    color character varying(20) NOT NULL,
    opacity double precision NOT NULL,
    is_enabled boolean NOT NULL,
    sort_order integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN detection_region.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.task_id IS '所属任务ID（关联到algorithm_task或snap_task）';


--
-- Name: COLUMN detection_region.region_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.region_name IS '区域名称';


--
-- Name: COLUMN detection_region.region_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.region_type IS '区域类型[polygon:多边形,rectangle:矩形]';


--
-- Name: COLUMN detection_region.points; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.points IS '区域坐标点(JSON格式，归一化坐标0-1)';


--
-- Name: COLUMN detection_region.image_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.image_id IS '参考图片ID（用于绘制区域的基准图片）';


--
-- Name: COLUMN detection_region.algorithm_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.algorithm_type IS '绑定的算法类型[FIRE:火焰烟雾检测,CROWD:人群聚集计数,SMOKE:吸烟检测等]';


--
-- Name: COLUMN detection_region.algorithm_model_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.algorithm_model_id IS '绑定的算法模型ID';


--
-- Name: COLUMN detection_region.algorithm_threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.algorithm_threshold IS '算法阈值';


--
-- Name: COLUMN detection_region.algorithm_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.algorithm_enabled IS '是否启用该区域的算法';


--
-- Name: COLUMN detection_region.color; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.color IS '区域显示颜色';


--
-- Name: COLUMN detection_region.opacity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.opacity IS '区域透明度(0-1)';


--
-- Name: COLUMN detection_region.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.is_enabled IS '是否启用该区域';


--
-- Name: COLUMN detection_region.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.detection_region.sort_order IS '排序顺序';


--
-- Name: detection_region_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.detection_region_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: detection_region_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.detection_region_id_seq OWNED BY public.detection_region.id;


--
-- Name: device; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device (
    id character varying(100) NOT NULL,
    name character varying(100),
    source text NOT NULL,
    rtmp_stream text NOT NULL,
    http_stream text NOT NULL,
    ai_rtmp_stream text,
    ai_http_stream text,
    stream smallint,
    ip character varying(45),
    port smallint,
    username character varying(100),
    password character varying(100),
    mac character varying(17),
    manufacturer character varying(100) NOT NULL,
    model character varying(100) NOT NULL,
    firmware_version character varying(100),
    serial_number character varying(300),
    hardware_id character varying(100),
    support_move boolean,
    support_zoom boolean,
    nvr_id integer,
    nvr_channel smallint NOT NULL,
    enable_forward boolean,
    auto_snap_enabled boolean NOT NULL,
    directory_id integer,
    cover_image_path character varying(500),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN device.ai_rtmp_stream; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device.ai_rtmp_stream IS 'AI推流地址（用于算法任务）';


--
-- Name: COLUMN device.ai_http_stream; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device.ai_http_stream IS 'AI HTTP地址（用于算法任务）';


--
-- Name: COLUMN device.auto_snap_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device.auto_snap_enabled IS '是否开启自动抓拍[默认不开启]';


--
-- Name: COLUMN device.directory_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device.directory_id IS '所属目录ID';


--
-- Name: COLUMN device.cover_image_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device.cover_image_path IS '摄像头封面展示图路径';


--
-- Name: device_detection_region; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device_detection_region (
    id integer NOT NULL,
    device_id character varying(100) NOT NULL,
    region_name character varying(255) NOT NULL,
    region_type character varying(50) NOT NULL,
    points text NOT NULL,
    image_id integer,
    color character varying(20) NOT NULL,
    opacity double precision NOT NULL,
    is_enabled boolean NOT NULL,
    sort_order integer NOT NULL,
    model_ids text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN device_detection_region.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.device_id IS '设备ID';


--
-- Name: COLUMN device_detection_region.region_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.region_name IS '区域名称';


--
-- Name: COLUMN device_detection_region.region_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.region_type IS '区域类型[polygon:多边形,line:线条]';


--
-- Name: COLUMN device_detection_region.points; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.points IS '区域坐标点(JSON格式，归一化坐标0-1)';


--
-- Name: COLUMN device_detection_region.image_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.image_id IS '参考图片ID（用于绘制区域的基准图片）';


--
-- Name: COLUMN device_detection_region.color; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.color IS '区域显示颜色';


--
-- Name: COLUMN device_detection_region.opacity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.opacity IS '区域透明度(0-1)';


--
-- Name: COLUMN device_detection_region.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.is_enabled IS '是否启用该区域';


--
-- Name: COLUMN device_detection_region.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.sort_order IS '排序顺序';


--
-- Name: COLUMN device_detection_region.model_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_detection_region.model_ids IS '关联的算法模型ID列表（JSON格式，如[1,2,3]）';


--
-- Name: device_detection_region_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.device_detection_region_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_detection_region_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.device_detection_region_id_seq OWNED BY public.device_detection_region.id;


--
-- Name: device_directory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device_directory (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    parent_id integer,
    description character varying(500),
    sort_order integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN device_directory.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_directory.name IS '目录名称';


--
-- Name: COLUMN device_directory.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_directory.parent_id IS '父目录ID，NULL表示根目录';


--
-- Name: COLUMN device_directory.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_directory.description IS '目录描述';


--
-- Name: COLUMN device_directory.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_directory.sort_order IS '排序顺序';


--
-- Name: device_directory_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.device_directory_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_directory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.device_directory_id_seq OWNED BY public.device_directory.id;


--
-- Name: device_storage_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device_storage_config (
    id integer NOT NULL,
    device_id character varying(100) NOT NULL,
    snap_storage_bucket character varying(255),
    snap_storage_max_size bigint,
    snap_storage_cleanup_enabled boolean NOT NULL,
    snap_storage_cleanup_threshold double precision NOT NULL,
    snap_storage_cleanup_ratio double precision NOT NULL,
    video_storage_bucket character varying(255),
    video_storage_max_size bigint,
    video_storage_cleanup_enabled boolean NOT NULL,
    video_storage_cleanup_threshold double precision NOT NULL,
    video_storage_cleanup_ratio double precision NOT NULL,
    last_snap_cleanup_time timestamp without time zone,
    last_video_cleanup_time timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN device_storage_config.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.device_id IS '设备ID';


--
-- Name: COLUMN device_storage_config.snap_storage_bucket; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.snap_storage_bucket IS '抓拍图片存储bucket名称';


--
-- Name: COLUMN device_storage_config.snap_storage_max_size; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.snap_storage_max_size IS '抓拍图片存储最大空间（字节），0表示不限制';


--
-- Name: COLUMN device_storage_config.snap_storage_cleanup_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.snap_storage_cleanup_enabled IS '是否启用抓拍图片自动清理';


--
-- Name: COLUMN device_storage_config.snap_storage_cleanup_threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.snap_storage_cleanup_threshold IS '抓拍图片清理阈值（使用率超过此值触发清理）';


--
-- Name: COLUMN device_storage_config.snap_storage_cleanup_ratio; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.snap_storage_cleanup_ratio IS '抓拍图片清理比例（清理最老的30%）';


--
-- Name: COLUMN device_storage_config.video_storage_bucket; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.video_storage_bucket IS '录像存储bucket名称';


--
-- Name: COLUMN device_storage_config.video_storage_max_size; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.video_storage_max_size IS '录像存储最大空间（字节），0表示不限制';


--
-- Name: COLUMN device_storage_config.video_storage_cleanup_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.video_storage_cleanup_enabled IS '是否启用录像自动清理';


--
-- Name: COLUMN device_storage_config.video_storage_cleanup_threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.video_storage_cleanup_threshold IS '录像清理阈值（使用率超过此值触发清理）';


--
-- Name: COLUMN device_storage_config.video_storage_cleanup_ratio; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.video_storage_cleanup_ratio IS '录像清理比例（清理最老的30%）';


--
-- Name: COLUMN device_storage_config.last_snap_cleanup_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.last_snap_cleanup_time IS '最后抓拍图片清理时间';


--
-- Name: COLUMN device_storage_config.last_video_cleanup_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.device_storage_config.last_video_cleanup_time IS '最后录像清理时间';


--
-- Name: device_storage_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.device_storage_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_storage_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.device_storage_config_id_seq OWNED BY public.device_storage_config.id;


--
-- Name: frame_extractor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frame_extractor (
    id integer NOT NULL,
    extractor_name character varying(255) NOT NULL,
    extractor_code character varying(255) NOT NULL,
    extractor_type character varying(50) NOT NULL,
    "interval" integer NOT NULL,
    description character varying(500),
    is_enabled boolean NOT NULL,
    status character varying(20) NOT NULL,
    server_ip character varying(50),
    port integer,
    process_id integer,
    last_heartbeat timestamp without time zone,
    log_path character varying(500),
    task_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN frame_extractor.extractor_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.extractor_name IS '抽帧器名称';


--
-- Name: COLUMN frame_extractor.extractor_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.extractor_code IS '抽帧器编号（唯一标识）';


--
-- Name: COLUMN frame_extractor.extractor_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.extractor_type IS '抽帧类型[interval:按间隔,time:按时间]';


--
-- Name: COLUMN frame_extractor."interval"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor."interval" IS '抽帧间隔（每N帧抽一次，或每N秒抽一次）';


--
-- Name: COLUMN frame_extractor.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.description IS '描述';


--
-- Name: COLUMN frame_extractor.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.is_enabled IS '是否启用';


--
-- Name: COLUMN frame_extractor.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.status IS '运行状态[running:运行中,stopped:已停止,error:错误]';


--
-- Name: COLUMN frame_extractor.server_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.server_ip IS '部署的服务器IP';


--
-- Name: COLUMN frame_extractor.port; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.port IS '服务端口';


--
-- Name: COLUMN frame_extractor.process_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.process_id IS '进程ID';


--
-- Name: COLUMN frame_extractor.last_heartbeat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.last_heartbeat IS '最后上报时间';


--
-- Name: COLUMN frame_extractor.log_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.log_path IS '日志文件路径';


--
-- Name: COLUMN frame_extractor.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.frame_extractor.task_id IS '关联的算法任务ID';


--
-- Name: frame_extractor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.frame_extractor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: frame_extractor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.frame_extractor_id_seq OWNED BY public.frame_extractor.id;


--
-- Name: image; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image (
    id integer NOT NULL,
    filename character varying(255) NOT NULL,
    original_filename character varying(255) NOT NULL,
    path character varying(500) NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    created_at timestamp without time zone,
    device_id character varying(100)
);


--
-- Name: image_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.image_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: image_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.image_id_seq OWNED BY public.image.id;


--
-- Name: llm_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_config (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    service_type character varying(20) NOT NULL,
    vendor character varying(50) NOT NULL,
    model_type character varying(50) NOT NULL,
    model_name character varying(100) NOT NULL,
    base_url character varying(500) NOT NULL,
    api_key character varying(200),
    api_version character varying(50),
    temperature double precision NOT NULL,
    max_tokens integer NOT NULL,
    timeout integer NOT NULL,
    is_active boolean NOT NULL,
    status character varying(20) NOT NULL,
    last_test_time timestamp without time zone,
    last_test_result text,
    description text,
    icon_url character varying(500),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN llm_config.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.name IS '模型名称';


--
-- Name: COLUMN llm_config.service_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.service_type IS '服务类型[online:线上服务,local:本地服务]';


--
-- Name: COLUMN llm_config.vendor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.vendor IS '供应商[aliyun:阿里云,openai:OpenAI,anthropic:Anthropic,local:本地服务]';


--
-- Name: COLUMN llm_config.model_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.model_type IS '模型类型[text:文本,vision:视觉,multimodal:多模态]';


--
-- Name: COLUMN llm_config.model_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.model_name IS '模型标识（如qwen-vl-max）';


--
-- Name: COLUMN llm_config.base_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.base_url IS 'API基础URL';


--
-- Name: COLUMN llm_config.api_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.api_key IS 'API密钥（线上服务必填，本地服务可选）';


--
-- Name: COLUMN llm_config.api_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.api_version IS 'API版本';


--
-- Name: COLUMN llm_config.temperature; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.temperature IS '温度参数';


--
-- Name: COLUMN llm_config.max_tokens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.max_tokens IS '最大输出token数';


--
-- Name: COLUMN llm_config.timeout; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.timeout IS '请求超时时间（秒）';


--
-- Name: COLUMN llm_config.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.is_active IS '是否激活';


--
-- Name: COLUMN llm_config.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.status IS '状态[active:激活,inactive:未激活,error:错误]';


--
-- Name: COLUMN llm_config.last_test_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.last_test_time IS '最后测试时间';


--
-- Name: COLUMN llm_config.last_test_result; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.last_test_result IS '最后测试结果';


--
-- Name: COLUMN llm_config.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.description IS '模型描述';


--
-- Name: COLUMN llm_config.icon_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_config.icon_url IS '图标URL';


--
-- Name: llm_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_config_id_seq OWNED BY public.llm_config.id;


--
-- Name: llm_inference_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_inference_record (
    id integer NOT NULL,
    record_name character varying(255),
    llm_model_id integer,
    input_type character varying(20) NOT NULL,
    input_intent text,
    input_image_path character varying(500),
    input_video_path character varying(500),
    output_text text,
    output_json text,
    output_image_path character varying(500),
    output_video_path character varying(500),
    status character varying(20) NOT NULL,
    error_message text,
    inference_time double precision,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN llm_inference_record.record_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.record_name IS '记录名称（可选，用于标识推理任务）';


--
-- Name: COLUMN llm_inference_record.llm_model_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.llm_model_id IS '使用的大模型ID';


--
-- Name: COLUMN llm_inference_record.input_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.input_type IS '输入类型[image:图片,video:视频]';


--
-- Name: COLUMN llm_inference_record.input_intent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.input_intent IS '监管意图（自然语言描述）';


--
-- Name: COLUMN llm_inference_record.input_image_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.input_image_path IS '输入图片路径（存储在MinIO）';


--
-- Name: COLUMN llm_inference_record.input_video_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.input_video_path IS '输入视频路径（存储在MinIO）';


--
-- Name: COLUMN llm_inference_record.output_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.output_text IS '推理结果文本';


--
-- Name: COLUMN llm_inference_record.output_json; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.output_json IS '推理结果JSON（规则描述等）';


--
-- Name: COLUMN llm_inference_record.output_image_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.output_image_path IS '输出图片路径（如果有）';


--
-- Name: COLUMN llm_inference_record.output_video_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.output_video_path IS '输出视频路径（如果有）';


--
-- Name: COLUMN llm_inference_record.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.status IS '状态[completed:已完成,failed:失败,processing:处理中]';


--
-- Name: COLUMN llm_inference_record.error_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.error_message IS '错误信息（如果失败）';


--
-- Name: COLUMN llm_inference_record.inference_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.llm_inference_record.inference_time IS '推理耗时（秒）';


--
-- Name: llm_inference_record_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_inference_record_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_inference_record_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_inference_record_id_seq OWNED BY public.llm_inference_record.id;


--
-- Name: nvr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nvr (
    id integer NOT NULL,
    ip character varying(45) NOT NULL,
    username character varying(100),
    password character varying(100),
    name character varying(100),
    model character varying(100)
);


--
-- Name: nvr_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nvr_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nvr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nvr_id_seq OWNED BY public.nvr.id;


--
-- Name: playback; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playback (
    id integer NOT NULL,
    file_path character varying(200) NOT NULL,
    event_time timestamp with time zone NOT NULL,
    device_id character varying(30) NOT NULL,
    device_name character varying(30) NOT NULL,
    duration smallint NOT NULL,
    thumbnail_path character varying(200),
    file_size bigint,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: playback_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.playback_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: playback_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.playback_id_seq OWNED BY public.playback.id;


--
-- Name: pusher; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pusher (
    id integer NOT NULL,
    pusher_name character varying(255) NOT NULL,
    pusher_code character varying(255) NOT NULL,
    video_stream_enabled boolean NOT NULL,
    video_stream_url character varying(500),
    device_rtmp_mapping text,
    video_stream_format character varying(50) NOT NULL,
    video_stream_quality character varying(50) NOT NULL,
    event_alert_enabled boolean NOT NULL,
    event_alert_url character varying(500),
    event_alert_method character varying(20) NOT NULL,
    event_alert_format character varying(50) NOT NULL,
    event_alert_headers text,
    event_alert_template text,
    description character varying(500),
    is_enabled boolean NOT NULL,
    status character varying(20) NOT NULL,
    server_ip character varying(50),
    port integer,
    process_id integer,
    last_heartbeat timestamp without time zone,
    log_path character varying(500),
    task_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN pusher.pusher_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.pusher_name IS '推送器名称';


--
-- Name: COLUMN pusher.pusher_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.pusher_code IS '推送器编号（唯一标识）';


--
-- Name: COLUMN pusher.video_stream_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.video_stream_enabled IS '是否启用推送视频流';


--
-- Name: COLUMN pusher.video_stream_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.video_stream_url IS '视频流推送地址（RTMP/RTSP等，单摄像头时使用）';


--
-- Name: COLUMN pusher.device_rtmp_mapping; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.device_rtmp_mapping IS '多摄像头RTMP推送映射（JSON格式，device_id -> rtmp_url）';


--
-- Name: COLUMN pusher.video_stream_format; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.video_stream_format IS '视频流格式[rtmp:RTMP,rtsp:RTSP,webrtc:WebRTC]';


--
-- Name: COLUMN pusher.video_stream_quality; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.video_stream_quality IS '视频流质量[low:低,medium:中,high:高]';


--
-- Name: COLUMN pusher.event_alert_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.event_alert_enabled IS '是否启用推送事件告警';


--
-- Name: COLUMN pusher.event_alert_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.event_alert_url IS '事件告警推送地址（HTTP/WebSocket/Kafka等）';


--
-- Name: COLUMN pusher.event_alert_method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.event_alert_method IS '事件告警推送方式[http:HTTP,websocket:WebSocket,kafka:Kafka]';


--
-- Name: COLUMN pusher.event_alert_format; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.event_alert_format IS '事件告警数据格式[json:JSON,xml:XML]';


--
-- Name: COLUMN pusher.event_alert_headers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.event_alert_headers IS '事件告警请求头（JSON格式）';


--
-- Name: COLUMN pusher.event_alert_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.event_alert_template IS '事件告警数据模板（JSON格式，支持变量替换）';


--
-- Name: COLUMN pusher.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.description IS '描述';


--
-- Name: COLUMN pusher.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.is_enabled IS '是否启用';


--
-- Name: COLUMN pusher.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.status IS '运行状态[running:运行中,stopped:已停止,error:错误]';


--
-- Name: COLUMN pusher.server_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.server_ip IS '部署的服务器IP';


--
-- Name: COLUMN pusher.port; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.port IS '服务端口';


--
-- Name: COLUMN pusher.process_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.process_id IS '进程ID';


--
-- Name: COLUMN pusher.last_heartbeat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.last_heartbeat IS '最后上报时间';


--
-- Name: COLUMN pusher.log_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.log_path IS '日志文件路径';


--
-- Name: COLUMN pusher.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pusher.task_id IS '关联的算法任务ID';


--
-- Name: pusher_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pusher_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pusher_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pusher_id_seq OWNED BY public.pusher.id;


--
-- Name: record_space; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.record_space (
    id integer NOT NULL,
    space_name character varying(255) NOT NULL,
    space_code character varying(255) NOT NULL,
    bucket_name character varying(255) NOT NULL,
    save_mode smallint NOT NULL,
    save_time integer NOT NULL,
    description character varying(500),
    device_id character varying(100),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN record_space.space_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.record_space.space_name IS '空间名称';


--
-- Name: COLUMN record_space.space_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.record_space.space_code IS '空间编号（唯一标识）';


--
-- Name: COLUMN record_space.bucket_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.record_space.bucket_name IS 'MinIO bucket名称';


--
-- Name: COLUMN record_space.save_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.record_space.save_mode IS '文件保存模式[0:标准存储,1:归档存储]';


--
-- Name: COLUMN record_space.save_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.record_space.save_time IS '文件保存时间[0:永久保存,>=7(单位:天)]';


--
-- Name: COLUMN record_space.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.record_space.description IS '空间描述';


--
-- Name: COLUMN record_space.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.record_space.device_id IS '关联的设备ID（一对一关系）';


--
-- Name: record_space_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.record_space_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: record_space_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.record_space_id_seq OWNED BY public.record_space.id;


--
-- Name: region_model_service; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.region_model_service (
    id integer NOT NULL,
    region_id integer NOT NULL,
    service_name character varying(255) NOT NULL,
    service_url character varying(500) NOT NULL,
    service_type character varying(100),
    model_id integer,
    threshold double precision,
    request_method character varying(10) NOT NULL,
    request_headers text,
    request_body_template text,
    timeout integer NOT NULL,
    is_enabled boolean NOT NULL,
    sort_order integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN region_model_service.region_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.region_id IS '所属检测区域ID';


--
-- Name: COLUMN region_model_service.service_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.service_name IS '服务名称';


--
-- Name: COLUMN region_model_service.service_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.service_url IS 'AI模型服务请求接口URL';


--
-- Name: COLUMN region_model_service.service_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.service_type IS '服务类型[FIRE:火焰烟雾检测,CROWD:人群聚集计数,SMOKE:吸烟检测等]';


--
-- Name: COLUMN region_model_service.model_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.model_id IS '关联的模型ID';


--
-- Name: COLUMN region_model_service.threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.threshold IS '检测阈值';


--
-- Name: COLUMN region_model_service.request_method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.request_method IS '请求方法[GET,POST]';


--
-- Name: COLUMN region_model_service.request_headers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.request_headers IS '请求头（JSON格式）';


--
-- Name: COLUMN region_model_service.request_body_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.request_body_template IS '请求体模板（JSON格式，支持变量替换）';


--
-- Name: COLUMN region_model_service.timeout; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.timeout IS '请求超时时间（秒）';


--
-- Name: COLUMN region_model_service.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.is_enabled IS '是否启用';


--
-- Name: COLUMN region_model_service.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region_model_service.sort_order IS '排序顺序';


--
-- Name: region_model_service_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.region_model_service_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: region_model_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.region_model_service_id_seq OWNED BY public.region_model_service.id;


--
-- Name: regulation_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.regulation_rule (
    id integer NOT NULL,
    rule_name character varying(255) NOT NULL,
    rule_code character varying(255) NOT NULL,
    scene_type character varying(100) NOT NULL,
    rule_type character varying(50) NOT NULL,
    rule_description text,
    severity character varying(20) NOT NULL,
    is_enabled boolean NOT NULL,
    sort_order integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN regulation_rule.rule_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.rule_name IS '规则名称';


--
-- Name: COLUMN regulation_rule.rule_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.rule_code IS '规则编号（唯一标识）';


--
-- Name: COLUMN regulation_rule.scene_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.scene_type IS '场景类型[detention_center:看守所,prison:监狱,detention_house:拘留所,interrogation_room:审讯室,security_center:安防监控中心等]';


--
-- Name: COLUMN regulation_rule.rule_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.rule_type IS '规则类型[safety:安全规则,compliance:合规规则,quality:质量规则,behavior:行为规则]';


--
-- Name: COLUMN regulation_rule.rule_description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.rule_description IS '规则描述';


--
-- Name: COLUMN regulation_rule.severity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.severity IS '严重程度[low:低,medium:中,high:高,critical:严重]';


--
-- Name: COLUMN regulation_rule.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.is_enabled IS '是否启用';


--
-- Name: COLUMN regulation_rule.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule.sort_order IS '排序顺序';


--
-- Name: regulation_rule_detail; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.regulation_rule_detail (
    id integer NOT NULL,
    regulation_rule_id integer NOT NULL,
    rule_name character varying(255) NOT NULL,
    rule_description text,
    priority integer NOT NULL,
    trigger_conditions text,
    is_enabled boolean NOT NULL,
    sort_order integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN regulation_rule_detail.regulation_rule_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule_detail.regulation_rule_id IS '所属监管规则ID';


--
-- Name: COLUMN regulation_rule_detail.rule_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule_detail.rule_name IS '规则名称';


--
-- Name: COLUMN regulation_rule_detail.rule_description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule_detail.rule_description IS '规则描述';


--
-- Name: COLUMN regulation_rule_detail.priority; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule_detail.priority IS '优先级（数字越大优先级越高）';


--
-- Name: COLUMN regulation_rule_detail.trigger_conditions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule_detail.trigger_conditions IS '触发条件（JSON格式，描述何时应用此规则）';


--
-- Name: COLUMN regulation_rule_detail.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule_detail.is_enabled IS '是否启用';


--
-- Name: COLUMN regulation_rule_detail.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulation_rule_detail.sort_order IS '排序顺序';


--
-- Name: regulation_rule_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.regulation_rule_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: regulation_rule_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.regulation_rule_detail_id_seq OWNED BY public.regulation_rule_detail.id;


--
-- Name: regulation_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.regulation_rule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: regulation_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.regulation_rule_id_seq OWNED BY public.regulation_rule.id;


--
-- Name: snap_space; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snap_space (
    id integer NOT NULL,
    space_name character varying(255) NOT NULL,
    space_code character varying(255) NOT NULL,
    bucket_name character varying(255) NOT NULL,
    save_mode smallint NOT NULL,
    save_time integer NOT NULL,
    description character varying(500),
    device_id character varying(100),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN snap_space.space_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_space.space_name IS '空间名称';


--
-- Name: COLUMN snap_space.space_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_space.space_code IS '空间编号（唯一标识）';


--
-- Name: COLUMN snap_space.bucket_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_space.bucket_name IS 'MinIO bucket名称';


--
-- Name: COLUMN snap_space.save_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_space.save_mode IS '文件保存模式[0:标准存储,1:归档存储]';


--
-- Name: COLUMN snap_space.save_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_space.save_time IS '文件保存时间[0:永久保存,>=7(单位:天)]';


--
-- Name: COLUMN snap_space.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_space.description IS '空间描述';


--
-- Name: COLUMN snap_space.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_space.device_id IS '关联的设备ID（一对一关系）';


--
-- Name: snap_space_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.snap_space_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: snap_space_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.snap_space_id_seq OWNED BY public.snap_space.id;


--
-- Name: snap_task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snap_task (
    id integer NOT NULL,
    task_name character varying(255) NOT NULL,
    task_code character varying(255) NOT NULL,
    space_id integer NOT NULL,
    device_id character varying(100) NOT NULL,
    pusher_id integer,
    capture_type smallint NOT NULL,
    cron_expression character varying(255) NOT NULL,
    frame_skip integer NOT NULL,
    algorithm_enabled boolean NOT NULL,
    algorithm_type character varying(255),
    algorithm_model_id integer,
    algorithm_threshold double precision,
    algorithm_night_mode boolean NOT NULL,
    alarm_enabled boolean NOT NULL,
    alarm_type smallint NOT NULL,
    phone_number character varying(500),
    email character varying(500),
    notify_users text,
    notify_methods character varying(100),
    alarm_suppress_time integer NOT NULL,
    last_notify_time timestamp without time zone,
    auto_filename boolean NOT NULL,
    custom_filename_prefix character varying(255),
    status smallint NOT NULL,
    is_enabled boolean NOT NULL,
    exception_reason character varying(500),
    run_status character varying(20) NOT NULL,
    total_captures integer NOT NULL,
    last_capture_time timestamp without time zone,
    last_success_time timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN snap_task.task_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.task_name IS '任务名称';


--
-- Name: COLUMN snap_task.task_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.task_code IS '任务编号（唯一标识）';


--
-- Name: COLUMN snap_task.space_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.space_id IS '所属抓拍空间ID';


--
-- Name: COLUMN snap_task.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.device_id IS '设备ID';


--
-- Name: COLUMN snap_task.pusher_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.pusher_id IS '关联的推送器ID';


--
-- Name: COLUMN snap_task.capture_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.capture_type IS '抓拍类型[0:抽帧,1:抓拍]';


--
-- Name: COLUMN snap_task.cron_expression; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.cron_expression IS 'Cron表达式';


--
-- Name: COLUMN snap_task.frame_skip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.frame_skip IS '抽帧间隔（每N帧抓一次）';


--
-- Name: COLUMN snap_task.algorithm_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.algorithm_enabled IS '是否启用算法推理';


--
-- Name: COLUMN snap_task.algorithm_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.algorithm_type IS '算法类型[FIRE:火焰烟雾检测,CROWD:人群聚集计数,SMOKE:吸烟检测等]';


--
-- Name: COLUMN snap_task.algorithm_model_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.algorithm_model_id IS '算法模型ID（关联AI模块的Model表）';


--
-- Name: COLUMN snap_task.algorithm_threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.algorithm_threshold IS '算法阈值';


--
-- Name: COLUMN snap_task.algorithm_night_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.algorithm_night_mode IS '是否仅夜间(23点~8点)启用算法';


--
-- Name: COLUMN snap_task.alarm_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.alarm_enabled IS '是否启用告警';


--
-- Name: COLUMN snap_task.alarm_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.alarm_type IS '告警类型[0:短信告警,1:邮箱告警,2:短信+邮箱]';


--
-- Name: COLUMN snap_task.phone_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.phone_number IS '告警手机号[多个用英文逗号分割]';


--
-- Name: COLUMN snap_task.email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.email IS '告警邮箱[多个用英文逗号分割]';


--
-- Name: COLUMN snap_task.notify_users; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.notify_users IS '通知人列表（JSON格式，包含用户ID、姓名、手机号、邮箱等）';


--
-- Name: COLUMN snap_task.notify_methods; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.notify_methods IS '通知方式[sms:短信,email:邮箱,app:应用内通知，多个用逗号分割]';


--
-- Name: COLUMN snap_task.alarm_suppress_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.alarm_suppress_time IS '告警通知抑制时间（秒），防止频繁通知，默认5分钟';


--
-- Name: COLUMN snap_task.last_notify_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.last_notify_time IS '最后通知时间';


--
-- Name: COLUMN snap_task.auto_filename; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.auto_filename IS '是否自动命名[0:否,1:是]';


--
-- Name: COLUMN snap_task.custom_filename_prefix; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.custom_filename_prefix IS '自定义文件前缀';


--
-- Name: COLUMN snap_task.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.status IS '状态[0:正常,1:异常]';


--
-- Name: COLUMN snap_task.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.is_enabled IS '是否启用[0:停用,1:启用]';


--
-- Name: COLUMN snap_task.exception_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.exception_reason IS '异常原因';


--
-- Name: COLUMN snap_task.run_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.run_status IS '运行状态[running:运行中,stopped:已停止,restarting:重启中]';


--
-- Name: COLUMN snap_task.total_captures; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.total_captures IS '总抓拍次数';


--
-- Name: COLUMN snap_task.last_capture_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.last_capture_time IS '最后抓拍时间';


--
-- Name: COLUMN snap_task.last_success_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.snap_task.last_success_time IS '最后成功时间';


--
-- Name: snap_task_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.snap_task_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: snap_task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.snap_task_id_seq OWNED BY public.snap_task.id;


--
-- Name: sorter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sorter (
    id integer NOT NULL,
    sorter_name character varying(255) NOT NULL,
    sorter_code character varying(255) NOT NULL,
    sorter_type character varying(50) NOT NULL,
    sort_order character varying(10) NOT NULL,
    description character varying(500),
    is_enabled boolean NOT NULL,
    status character varying(20) NOT NULL,
    server_ip character varying(50),
    port integer,
    process_id integer,
    last_heartbeat timestamp without time zone,
    log_path character varying(500),
    task_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN sorter.sorter_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.sorter_name IS '排序器名称';


--
-- Name: COLUMN sorter.sorter_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.sorter_code IS '排序器编号（唯一标识）';


--
-- Name: COLUMN sorter.sorter_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.sorter_type IS '排序类型[confidence:置信度,time:时间,score:分数]';


--
-- Name: COLUMN sorter.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.sort_order IS '排序顺序[asc:升序,desc:降序]';


--
-- Name: COLUMN sorter.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.description IS '描述';


--
-- Name: COLUMN sorter.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.is_enabled IS '是否启用';


--
-- Name: COLUMN sorter.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.status IS '运行状态[running:运行中,stopped:已停止,error:错误]';


--
-- Name: COLUMN sorter.server_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.server_ip IS '部署的服务器IP';


--
-- Name: COLUMN sorter.port; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.port IS '服务端口';


--
-- Name: COLUMN sorter.process_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.process_id IS '进程ID';


--
-- Name: COLUMN sorter.last_heartbeat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.last_heartbeat IS '最后上报时间';


--
-- Name: COLUMN sorter.log_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.log_path IS '日志文件路径';


--
-- Name: COLUMN sorter.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sorter.task_id IS '关联的算法任务ID';


--
-- Name: sorter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sorter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sorter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sorter_id_seq OWNED BY public.sorter.id;


--
-- Name: stream_forward_task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stream_forward_task (
    id integer NOT NULL,
    task_name character varying(255) NOT NULL,
    task_code character varying(255) NOT NULL,
    output_format character varying(50) NOT NULL,
    output_quality character varying(50) NOT NULL,
    output_bitrate character varying(50),
    status smallint NOT NULL,
    is_enabled boolean NOT NULL,
    exception_reason character varying(500),
    service_server_ip character varying(45),
    service_port integer,
    service_process_id integer,
    service_last_heartbeat timestamp without time zone,
    service_log_path character varying(500),
    total_streams integer NOT NULL,
    last_process_time timestamp without time zone,
    last_success_time timestamp without time zone,
    description character varying(500),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN stream_forward_task.task_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.task_name IS '任务名称';


--
-- Name: COLUMN stream_forward_task.task_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.task_code IS '任务编号（唯一标识）';


--
-- Name: COLUMN stream_forward_task.output_format; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.output_format IS '输出格式[rtmp:RTMP,rtsp:RTSP]';


--
-- Name: COLUMN stream_forward_task.output_quality; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.output_quality IS '输出质量[low:低,medium:中,high:高]';


--
-- Name: COLUMN stream_forward_task.output_bitrate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.output_bitrate IS '输出码率（如512k,1M等，为空则使用默认值）';


--
-- Name: COLUMN stream_forward_task.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.status IS '状态[0:正常,1:异常]';


--
-- Name: COLUMN stream_forward_task.is_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.is_enabled IS '是否启用[0:停用,1:启用]';


--
-- Name: COLUMN stream_forward_task.exception_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.exception_reason IS '异常原因';


--
-- Name: COLUMN stream_forward_task.service_server_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.service_server_ip IS '服务运行服务器IP';


--
-- Name: COLUMN stream_forward_task.service_port; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.service_port IS '服务端口';


--
-- Name: COLUMN stream_forward_task.service_process_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.service_process_id IS '服务进程ID';


--
-- Name: COLUMN stream_forward_task.service_last_heartbeat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.service_last_heartbeat IS '服务最后心跳时间';


--
-- Name: COLUMN stream_forward_task.service_log_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.service_log_path IS '服务日志路径';


--
-- Name: COLUMN stream_forward_task.total_streams; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.total_streams IS '总推流数';


--
-- Name: COLUMN stream_forward_task.last_process_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.last_process_time IS '最后处理时间';


--
-- Name: COLUMN stream_forward_task.last_success_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.last_success_time IS '最后成功时间';


--
-- Name: COLUMN stream_forward_task.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task.description IS '任务描述';


--
-- Name: stream_forward_task_device; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stream_forward_task_device (
    stream_forward_task_id integer NOT NULL,
    device_id character varying(100) NOT NULL,
    created_at timestamp without time zone
);


--
-- Name: COLUMN stream_forward_task_device.stream_forward_task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task_device.stream_forward_task_id IS '推流转发任务ID';


--
-- Name: COLUMN stream_forward_task_device.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task_device.device_id IS '摄像头ID';


--
-- Name: COLUMN stream_forward_task_device.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.stream_forward_task_device.created_at IS '创建时间';


--
-- Name: stream_forward_task_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stream_forward_task_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stream_forward_task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stream_forward_task_id_seq OWNED BY public.stream_forward_task.id;


--
-- Name: streaming_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.streaming_session (
    id character varying(100) NOT NULL,
    llm_model_id integer,
    llm_model_name character varying(100),
    prompt text,
    video_config text,
    status character varying(20) NOT NULL,
    websocket_status character varying(20) NOT NULL,
    processed_frames integer NOT NULL,
    duration_seconds double precision NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    started_at timestamp without time zone,
    stopped_at timestamp without time zone
);


--
-- Name: COLUMN streaming_session.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.id IS '会话ID（UUID）';


--
-- Name: COLUMN streaming_session.llm_model_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.llm_model_id IS '使用的大模型ID';


--
-- Name: COLUMN streaming_session.llm_model_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.llm_model_name IS '大模型名称';


--
-- Name: COLUMN streaming_session.prompt; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.prompt IS '提示词';


--
-- Name: COLUMN streaming_session.video_config; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.video_config IS '视频配置（JSON格式）';


--
-- Name: COLUMN streaming_session.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.status IS '状态[active:活跃,stopped:已停止,error:错误]';


--
-- Name: COLUMN streaming_session.websocket_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.websocket_status IS 'WebSocket连接状态[connected:已连接,disconnected:未连接]';


--
-- Name: COLUMN streaming_session.processed_frames; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.processed_frames IS '已处理帧数';


--
-- Name: COLUMN streaming_session.duration_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.duration_seconds IS '持续时间（秒）';


--
-- Name: COLUMN streaming_session.started_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.started_at IS '开始时间';


--
-- Name: COLUMN streaming_session.stopped_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.streaming_session.stopped_at IS '停止时间';


--
-- Name: tracking_target; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tracking_target (
    id integer NOT NULL,
    task_id integer NOT NULL,
    device_id character varying(100) NOT NULL,
    device_name character varying(255),
    track_id integer NOT NULL,
    class_id integer,
    class_name character varying(100),
    first_seen_time timestamp without time zone NOT NULL,
    last_seen_time timestamp without time zone,
    leave_time timestamp without time zone,
    duration double precision,
    first_seen_frame integer,
    last_seen_frame integer,
    total_detections integer NOT NULL,
    information text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN tracking_target.task_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.task_id IS '所属算法任务ID';


--
-- Name: COLUMN tracking_target.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.device_id IS '设备ID';


--
-- Name: COLUMN tracking_target.device_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.device_name IS '设备名称';


--
-- Name: COLUMN tracking_target.track_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.track_id IS '追踪ID（同一任务内唯一）';


--
-- Name: COLUMN tracking_target.class_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.class_id IS '类别ID';


--
-- Name: COLUMN tracking_target.class_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.class_name IS '类别名称';


--
-- Name: COLUMN tracking_target.first_seen_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.first_seen_time IS '首次出现时间';


--
-- Name: COLUMN tracking_target.last_seen_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.last_seen_time IS '最后出现时间';


--
-- Name: COLUMN tracking_target.leave_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.leave_time IS '离开时间';


--
-- Name: COLUMN tracking_target.duration; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.duration IS '停留时长（秒）';


--
-- Name: COLUMN tracking_target.first_seen_frame; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.first_seen_frame IS '首次出现帧号';


--
-- Name: COLUMN tracking_target.last_seen_frame; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.last_seen_frame IS '最后出现帧号';


--
-- Name: COLUMN tracking_target.total_detections; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.total_detections IS '总检测次数';


--
-- Name: COLUMN tracking_target.information; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tracking_target.information IS '详细信息（JSON格式）';


--
-- Name: tracking_target_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tracking_target_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tracking_target_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tracking_target_id_seq OWNED BY public.tracking_target.id;


--
-- Name: alert id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert ALTER COLUMN id SET DEFAULT nextval('public.alert_id_seq'::regclass);


--
-- Name: algorithm_model_service id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.algorithm_model_service ALTER COLUMN id SET DEFAULT nextval('public.algorithm_model_service_id_seq'::regclass);


--
-- Name: algorithm_task id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.algorithm_task ALTER COLUMN id SET DEFAULT nextval('public.algorithm_task_id_seq'::regclass);


--
-- Name: detection_region id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_region ALTER COLUMN id SET DEFAULT nextval('public.detection_region_id_seq'::regclass);


--
-- Name: device_detection_region id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_detection_region ALTER COLUMN id SET DEFAULT nextval('public.device_detection_region_id_seq'::regclass);


--
-- Name: device_directory id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_directory ALTER COLUMN id SET DEFAULT nextval('public.device_directory_id_seq'::regclass);


--
-- Name: device_storage_config id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_storage_config ALTER COLUMN id SET DEFAULT nextval('public.device_storage_config_id_seq'::regclass);


--
-- Name: frame_extractor id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frame_extractor ALTER COLUMN id SET DEFAULT nextval('public.frame_extractor_id_seq'::regclass);


--
-- Name: image id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image ALTER COLUMN id SET DEFAULT nextval('public.image_id_seq'::regclass);


--
-- Name: llm_config id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_config ALTER COLUMN id SET DEFAULT nextval('public.llm_config_id_seq'::regclass);


--
-- Name: llm_inference_record id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_inference_record ALTER COLUMN id SET DEFAULT nextval('public.llm_inference_record_id_seq'::regclass);


--
-- Name: nvr id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nvr ALTER COLUMN id SET DEFAULT nextval('public.nvr_id_seq'::regclass);


--
-- Name: playback id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playback ALTER COLUMN id SET DEFAULT nextval('public.playback_id_seq'::regclass);


--
-- Name: pusher id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pusher ALTER COLUMN id SET DEFAULT nextval('public.pusher_id_seq'::regclass);


--
-- Name: record_space id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.record_space ALTER COLUMN id SET DEFAULT nextval('public.record_space_id_seq'::regclass);


--
-- Name: region_model_service id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_model_service ALTER COLUMN id SET DEFAULT nextval('public.region_model_service_id_seq'::regclass);


--
-- Name: regulation_rule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulation_rule ALTER COLUMN id SET DEFAULT nextval('public.regulation_rule_id_seq'::regclass);


--
-- Name: regulation_rule_detail id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulation_rule_detail ALTER COLUMN id SET DEFAULT nextval('public.regulation_rule_detail_id_seq'::regclass);


--
-- Name: snap_space id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_space ALTER COLUMN id SET DEFAULT nextval('public.snap_space_id_seq'::regclass);


--
-- Name: snap_task id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_task ALTER COLUMN id SET DEFAULT nextval('public.snap_task_id_seq'::regclass);


--
-- Name: sorter id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sorter ALTER COLUMN id SET DEFAULT nextval('public.sorter_id_seq'::regclass);


--
-- Name: stream_forward_task id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stream_forward_task ALTER COLUMN id SET DEFAULT nextval('public.stream_forward_task_id_seq'::regclass);


--
-- Name: tracking_target id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_target ALTER COLUMN id SET DEFAULT nextval('public.tracking_target_id_seq'::regclass);


--
-- Data for Name: alert; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.alert (id, object, event, region, information, "time", device_id, device_name, image_path, record_path, task_type, notify_users, channels, notification_sent, notification_sent_time) FROM stdin;
1	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.683577299118042,"bbox":[411,118,458,159],"first_seen_time":"2026-02-05T23:33:00.318502","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5846864581108093,"bbox":[315,125,360,173],"first_seen_time":"2026-02-05T23:33:00.318502","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4389825165271759,"bbox":[257,85,293,119],"first_seen_time":"2026-02-05T23:33:00.318502","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43820565938949585,"bbox":[378,28,397,43],"first_seen_time":"2026-02-05T23:33:00.318502","duration":0.0}],"frame_number":2160,"task_type":"realtime"}	2026-02-05 23:33:00+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233300_frame2160_track0_car.jpg	\N	realtime	\N	\N	f	\N
2	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.5270816683769226,"bbox":[319,75,346,97],"first_seen_time":"2026-02-05T23:33:05.719653","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48440343141555786,"bbox":[228,169,286,229],"first_seen_time":"2026-02-05T23:33:05.719653","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3704964816570282,"bbox":[402,105,480,167],"first_seen_time":"2026-02-05T23:33:05.719653","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33554133772850037,"bbox":[324,25,344,44],"first_seen_time":"2026-02-05T23:33:05.719653","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2683171331882477,"bbox":[407,80,438,108],"first_seen_time":"2026-02-05T23:33:05.719653","duration":0.0}],"frame_number":2210,"task_type":"realtime"}	2026-02-05 23:33:05+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233305_frame2210_track0_car.jpg	\N	realtime	\N	\N	f	\N
3	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7973070740699768,"bbox":[295,257,372,355],"first_seen_time":"2026-02-05T23:33:11.033492","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5926856994628906,"bbox":[322,67,350,96],"first_seen_time":"2026-02-05T23:33:11.033492","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.286639541387558,"bbox":[393,70,424,99],"first_seen_time":"2026-02-05T23:33:11.033492","duration":0.0}],"frame_number":2260,"task_type":"realtime"}	2026-02-05 23:33:11+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233311_frame2260_track0_car.jpg	\N	realtime	\N	\N	f	\N
4	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.43740737438201904,"bbox":[321,29,343,49],"first_seen_time":"2026-02-05T23:33:16.550098","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.35841313004493713,"bbox":[373,50,404,79],"first_seen_time":"2026-02-05T23:33:16.550098","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35328370332717896,"bbox":[373,50,404,79],"first_seen_time":"2026-02-05T23:33:16.550098","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.30807578563690186,"bbox":[148,1,173,18],"first_seen_time":"2026-02-05T23:33:16.550098","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2581252455711365,"bbox":[136,36,167,62],"first_seen_time":"2026-02-05T23:33:16.550098","duration":0.0}],"frame_number":2310,"task_type":"realtime"}	2026-02-05 23:33:16+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233316_frame2310_track0_car.jpg	\N	realtime	\N	\N	f	\N
5	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.8550215363502502,"bbox":[486,143,559,197],"first_seen_time":"2026-02-05T23:33:22.074944","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7130457758903503,"bbox":[380,89,426,128],"first_seen_time":"2026-02-05T23:33:22.074944","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6936148405075073,"bbox":[311,185,366,246],"first_seen_time":"2026-02-05T23:33:22.074944","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5217536687850952,"bbox":[78,33,109,51],"first_seen_time":"2026-02-05T23:33:22.074944","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5144363045692444,"bbox":[141,6,158,17],"first_seen_time":"2026-02-05T23:33:22.074944","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4351561963558197,"bbox":[123,26,152,48],"first_seen_time":"2026-02-05T23:33:22.074944","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25428158044815063,"bbox":[355,4,370,24],"first_seen_time":"2026-02-05T23:33:22.074944","duration":0.0}],"frame_number":2360,"task_type":"realtime"}	2026-02-05 23:33:22+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233322_frame2360_track0_car.jpg	\N	realtime	\N	\N	f	\N
6	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8235951066017151,"bbox":[374,63,403,90],"first_seen_time":"2026-02-05T23:33:27.398428","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7530712485313416,"bbox":[462,119,516,157],"first_seen_time":"2026-02-05T23:33:27.398428","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6517500281333923,"bbox":[63,23,105,57],"first_seen_time":"2026-02-05T23:33:27.398428","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5465684533119202,"bbox":[392,30,413,48],"first_seen_time":"2026-02-05T23:33:27.398428","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3736271560192108,"bbox":[137,3,181,25],"first_seen_time":"2026-02-05T23:33:27.398428","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25926002860069275,"bbox":[324,25,343,39],"first_seen_time":"2026-02-05T23:33:27.398428","duration":0.0}],"frame_number":2410,"task_type":"realtime"}	2026-02-05 23:33:27+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233327_frame2410_track0_car.jpg	\N	realtime	\N	\N	f	\N
7	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.738518238067627,"bbox":[444,265,563,355],"first_seen_time":"2026-02-05T23:33:32.932339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6198684573173523,"bbox":[291,38,312,54],"first_seen_time":"2026-02-05T23:33:32.932339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5667575001716614,"bbox":[328,88,361,117],"first_seen_time":"2026-02-05T23:33:32.932339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36956968903541565,"bbox":[385,29,403,44],"first_seen_time":"2026-02-05T23:33:32.932339","duration":0.0}],"frame_number":2460,"task_type":"realtime"}	2026-02-05 23:33:32+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233333_frame2460_track0_car.jpg	\N	realtime	\N	\N	f	\N
134	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.6077995896339417,"bbox":[378,77,411,107],"first_seen_time":"2026-02-05T23:44:58.781122","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42675501108169556,"bbox":[0,55,37,84],"first_seen_time":"2026-02-05T23:44:58.781122","duration":0.0}],"frame_number":8765,"task_type":"realtime"}	2026-02-05 23:44:58+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234458_frame8765_track0_car.jpg	\N	realtime	\N	\N	f	\N
8	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6462066769599915,"bbox":[363,40,387,62],"first_seen_time":"2026-02-05T23:33:38.373909","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5013751983642578,"bbox":[420,182,501,256],"first_seen_time":"2026-02-05T23:33:38.373909","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.417273610830307,"bbox":[314,154,378,230],"first_seen_time":"2026-02-05T23:33:38.373909","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2854427397251129,"bbox":[190,14,209,29],"first_seen_time":"2026-02-05T23:33:38.373909","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26533523201942444,"bbox":[314,155,378,230],"first_seen_time":"2026-02-05T23:33:38.373909","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2579202950000763,"bbox":[150,10,172,29],"first_seen_time":"2026-02-05T23:33:38.373909","duration":0.0}],"frame_number":2510,"task_type":"realtime"}	2026-02-05 23:33:38+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233338_frame2510_track0_car.jpg	\N	realtime	\N	\N	f	\N
9	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.8064674139022827,"bbox":[419,182,500,254],"first_seen_time":"2026-02-05T23:33:43.717905","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5169517397880554,"bbox":[362,33,382,49],"first_seen_time":"2026-02-05T23:33:43.717905","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3671426475048065,"bbox":[90,30,119,46],"first_seen_time":"2026-02-05T23:33:43.717905","duration":0.0}],"frame_number":2560,"task_type":"realtime"}	2026-02-05 23:33:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233343_frame2560_track0_car.jpg	\N	realtime	\N	\N	f	\N
10	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.6990257501602173,"bbox":[165,25,189,42],"first_seen_time":"2026-02-05T23:33:49.012404","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6287100315093994,"bbox":[360,30,382,50],"first_seen_time":"2026-02-05T23:33:49.012404","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5281999707221985,"bbox":[394,117,443,160],"first_seen_time":"2026-02-05T23:33:49.012404","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.526929497718811,"bbox":[119,16,145,38],"first_seen_time":"2026-02-05T23:33:49.012404","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4834228754043579,"bbox":[320,98,365,143],"first_seen_time":"2026-02-05T23:33:49.012404","duration":0.0}],"frame_number":2605,"task_type":"realtime"}	2026-02-05 23:33:49+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233349_frame2605_track0_car.jpg	\N	realtime	\N	\N	f	\N
11	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.5928703546524048,"bbox":[395,121,444,165],"first_seen_time":"2026-02-05T23:33:54.455498","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31188657879829407,"bbox":[43,40,82,62],"first_seen_time":"2026-02-05T23:33:54.455498","duration":0.0}],"frame_number":2655,"task_type":"realtime"}	2026-02-05 23:33:54+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233354_frame2655_track0_car.jpg	\N	realtime	\N	\N	f	\N
12	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.743447482585907,"bbox":[462,274,579,355],"first_seen_time":"2026-02-05T23:33:59.777656","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6406437754631042,"bbox":[3,57,56,96],"first_seen_time":"2026-02-05T23:33:59.777656","duration":0.0}],"frame_number":2705,"task_type":"realtime"}	2026-02-05 23:33:59+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233359_frame2705_track0_car.jpg	\N	realtime	\N	\N	f	\N
13	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.8535988926887512,"bbox":[436,199,530,295],"first_seen_time":"2026-02-05T23:34:05.197677","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6450486779212952,"bbox":[377,40,397,58],"first_seen_time":"2026-02-05T23:34:05.197677","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45833924412727356,"bbox":[196,6,220,24],"first_seen_time":"2026-02-05T23:34:05.197677","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3107086718082428,"bbox":[279,55,304,73],"first_seen_time":"2026-02-05T23:34:05.197677","duration":0.0}],"frame_number":2755,"task_type":"realtime"}	2026-02-05 23:34:05+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233405_frame2755_track0_car.jpg	\N	realtime	\N	\N	f	\N
14	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7616347670555115,"bbox":[364,31,386,51],"first_seen_time":"2026-02-05T23:34:10.494569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6582570672035217,"bbox":[177,16,202,37],"first_seen_time":"2026-02-05T23:34:10.494569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6244185566902161,"bbox":[276,62,304,87],"first_seen_time":"2026-02-05T23:34:10.494569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4224373996257782,"bbox":[113,13,138,30],"first_seen_time":"2026-02-05T23:34:10.494569","duration":0.0}],"frame_number":2805,"task_type":"realtime"}	2026-02-05 23:34:10+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233410_frame2805_track0_car.jpg	\N	realtime	\N	\N	f	\N
15	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7385068535804749,"bbox":[173,115,224,157],"first_seen_time":"2026-02-05T23:34:15.835493","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6870825886726379,"bbox":[142,21,169,38],"first_seen_time":"2026-02-05T23:34:15.835493","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6700810194015503,"bbox":[393,130,443,177],"first_seen_time":"2026-02-05T23:34:15.835493","duration":0.0}],"frame_number":2855,"task_type":"realtime"}	2026-02-05 23:34:15+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233415_frame2855_track0_car.jpg	\N	realtime	\N	\N	f	\N
16	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.8788648843765259,"bbox":[127,259,234,355],"first_seen_time":"2026-02-05T23:34:21.305316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6125808358192444,"bbox":[383,87,419,117],"first_seen_time":"2026-02-05T23:34:21.305316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5793294906616211,"bbox":[88,18,116,37],"first_seen_time":"2026-02-05T23:34:21.305316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4874696731567383,"bbox":[269,84,301,112],"first_seen_time":"2026-02-05T23:34:21.305316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44113829731941223,"bbox":[320,108,366,164],"first_seen_time":"2026-02-05T23:34:21.305316","duration":0.0}],"frame_number":2905,"task_type":"realtime"}	2026-02-05 23:34:21+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233421_frame2905_track0_car.jpg	\N	realtime	\N	\N	f	\N
17	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7650682330131531,"bbox":[84,42,119,63],"first_seen_time":"2026-02-05T23:34:26.763352","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7104394435882568,"bbox":[375,73,404,103],"first_seen_time":"2026-02-05T23:34:26.763352","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.699303150177002,"bbox":[231,63,262,88],"first_seen_time":"2026-02-05T23:34:26.763352","duration":0.0}],"frame_number":2955,"task_type":"realtime"}	2026-02-05 23:34:26+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233426_frame2955_track0_car.jpg	\N	realtime	\N	\N	f	\N
18	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.6682484149932861,"bbox":[234,118,280,162],"first_seen_time":"2026-02-05T23:34:32.183288","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6584815979003906,"bbox":[24,31,62,56],"first_seen_time":"2026-02-05T23:34:32.183288","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6121930480003357,"bbox":[370,54,399,75],"first_seen_time":"2026-02-05T23:34:32.183288","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5718635320663452,"bbox":[123,30,150,48],"first_seen_time":"2026-02-05T23:34:32.183288","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5003604888916016,"bbox":[287,51,309,71],"first_seen_time":"2026-02-05T23:34:32.183288","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38017359375953674,"bbox":[147,284,245,356],"first_seen_time":"2026-02-05T23:34:32.183288","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3026925325393677,"bbox":[145,1,184,29],"first_seen_time":"2026-02-05T23:34:32.183288","duration":0.0}],"frame_number":3005,"task_type":"realtime"}	2026-02-05 23:34:32+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233432_frame3005_track0_car.jpg	\N	realtime	\N	\N	f	\N
19	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7034851908683777,"bbox":[317,48,343,69],"first_seen_time":"2026-02-05T23:34:37.648503","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6916067600250244,"bbox":[422,175,495,245],"first_seen_time":"2026-02-05T23:34:37.648503","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6133184432983398,"bbox":[45,28,78,50],"first_seen_time":"2026-02-05T23:34:37.648503","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5635417103767395,"bbox":[287,24,312,55],"first_seen_time":"2026-02-05T23:34:37.648503","duration":0.0}],"frame_number":3055,"task_type":"realtime"}	2026-02-05 23:34:37+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233437_frame3055_track0_car.jpg	\N	realtime	\N	\N	f	\N
20	car	江北初中监控安防任务	\N	{"total_count":10,"object_counts":{"car":9,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.764154851436615,"bbox":[467,278,579,354],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6617202758789062,"bbox":[53,72,102,102],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6544316411018372,"bbox":[165,26,189,44],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6239866018295288,"bbox":[207,182,271,246],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.618369996547699,"bbox":[325,97,361,131],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5011208057403564,"bbox":[134,13,156,31],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37769800424575806,"bbox":[286,57,307,73],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3520471155643463,"bbox":[387,106,428,145],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32009878754615784,"bbox":[29,34,63,56],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.29696395993232727,"bbox":[386,106,428,145],"first_seen_time":"2026-02-05T23:34:43.134373","duration":0.0}],"frame_number":3105,"task_type":"realtime"}	2026-02-05 23:34:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233443_frame3105_track0_car.jpg	\N	realtime	\N	\N	f	\N
21	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":7,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6196405291557312,"bbox":[39,40,77,64],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4748530685901642,"bbox":[178,8,200,25],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.369708776473999,"bbox":[96,20,123,35],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3621605336666107,"bbox":[155,3,172,16],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32512158155441284,"bbox":[280,45,304,67],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31394392251968384,"bbox":[398,42,421,60],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2780143916606903,"bbox":[374,15,394,44],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.25095993280410767,"bbox":[321,7,355,71],"first_seen_time":"2026-02-05T23:34:48.563885","duration":0.0}],"frame_number":3155,"task_type":"realtime"}	2026-02-05 23:34:48+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233448_frame3155_track0_car.jpg	\N	realtime	\N	\N	f	\N
22	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7971256375312805,"bbox":[242,125,292,172],"first_seen_time":"2026-02-05T23:34:53.966907","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7891362905502319,"bbox":[35,30,76,52],"first_seen_time":"2026-02-05T23:34:53.966907","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7743144631385803,"bbox":[318,206,380,279],"first_seen_time":"2026-02-05T23:34:53.966907","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5486928224563599,"bbox":[374,49,398,71],"first_seen_time":"2026-02-05T23:34:53.966907","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3899557590484619,"bbox":[322,57,351,79],"first_seen_time":"2026-02-05T23:34:53.966907","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28058865666389465,"bbox":[168,14,188,30],"first_seen_time":"2026-02-05T23:34:53.966907","duration":0.0}],"frame_number":3205,"task_type":"realtime"}	2026-02-05 23:34:53+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233454_frame3205_track0_car.jpg	\N	realtime	\N	\N	f	\N
23	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":7,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6852601766586304,"bbox":[180,104,232,146],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5913262367248535,"bbox":[263,27,285,47],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5748330354690552,"bbox":[317,148,371,205],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48638466000556946,"bbox":[398,81,434,114],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4563116133213043,"bbox":[370,40,391,57],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36737093329429626,"bbox":[302,20,318,32],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2987406551837921,"bbox":[400,82,434,114],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27392497658729553,"bbox":[177,21,202,39],"first_seen_time":"2026-02-05T23:34:59.383450","duration":0.0}],"frame_number":3255,"task_type":"realtime"}	2026-02-05 23:34:59+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233459_frame3255_track0_car.jpg	\N	realtime	\N	\N	f	\N
24	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6840445399284363,"bbox":[376,64,403,90],"first_seen_time":"2026-02-05T23:35:04.757514","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6028356552124023,"bbox":[250,93,293,121],"first_seen_time":"2026-02-05T23:35:04.757514","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4242917597293854,"bbox":[324,59,348,80],"first_seen_time":"2026-02-05T23:35:04.757514","duration":0.0}],"frame_number":3305,"task_type":"realtime"}	2026-02-05 23:35:04+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233504_frame3305_track0_car.jpg	\N	realtime	\N	\N	f	\N
25	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7423878312110901,"bbox":[161,301,256,356],"first_seen_time":"2026-02-05T23:35:10.047742","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7175582051277161,"bbox":[260,99,299,140],"first_seen_time":"2026-02-05T23:35:10.047742","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6062703728675842,"bbox":[40,77,88,111],"first_seen_time":"2026-02-05T23:35:10.047742","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5773536562919617,"bbox":[424,109,465,146],"first_seen_time":"2026-02-05T23:35:10.047742","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4124612808227539,"bbox":[77,29,110,51],"first_seen_time":"2026-02-05T23:35:10.047742","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3557337820529938,"bbox":[161,18,180,31],"first_seen_time":"2026-02-05T23:35:10.047742","duration":0.0}],"frame_number":3355,"task_type":"realtime"}	2026-02-05 23:35:10+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233510_frame3355_track0_car.jpg	\N	realtime	\N	\N	f	\N
26	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6072936654090881,"bbox":[153,295,252,357],"first_seen_time":"2026-02-05T23:35:17.028439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2579924762248993,"bbox":[507,272,618,353],"first_seen_time":"2026-02-05T23:35:17.028439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25533586740493774,"bbox":[154,35,178,51],"first_seen_time":"2026-02-05T23:35:17.028439","duration":0.0}],"frame_number":3420,"task_type":"realtime"}	2026-02-05 23:35:17+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233517_frame3420_track0_car.jpg	\N	realtime	\N	\N	f	\N
27	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.8062516450881958,"bbox":[447,206,534,284],"first_seen_time":"2026-02-05T23:35:22.498187","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.8015455007553101,"bbox":[301,254,386,356],"first_seen_time":"2026-02-05T23:35:22.498187","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7344064712524414,"bbox":[219,151,276,207],"first_seen_time":"2026-02-05T23:35:22.498187","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.544894814491272,"bbox":[47,52,88,79],"first_seen_time":"2026-02-05T23:35:22.498187","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5142917037010193,"bbox":[384,41,407,58],"first_seen_time":"2026-02-05T23:35:22.498187","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4315893054008484,"bbox":[282,64,308,90],"first_seen_time":"2026-02-05T23:35:22.498187","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3804747760295868,"bbox":[296,32,316,49],"first_seen_time":"2026-02-05T23:35:22.498187","duration":0.0}],"frame_number":3470,"task_type":"realtime"}	2026-02-05 23:35:22+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233522_frame3470_track0_car.jpg	\N	realtime	\N	\N	f	\N
28	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.5795521140098572,"bbox":[407,127,472,187],"first_seen_time":"2026-02-05T23:35:27.992945","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.579378068447113,"bbox":[317,88,348,117],"first_seen_time":"2026-02-05T23:35:27.992945","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3914395868778229,"bbox":[325,31,346,49],"first_seen_time":"2026-02-05T23:35:27.992945","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26718515157699585,"bbox":[381,39,403,56],"first_seen_time":"2026-02-05T23:35:27.992945","duration":0.0}],"frame_number":3520,"task_type":"realtime"}	2026-02-05 23:35:27+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233528_frame3520_track0_car.jpg	\N	realtime	\N	\N	f	\N
29	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6145681738853455,"bbox":[106,12,136,31],"first_seen_time":"2026-02-05T23:35:33.415598","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3406342566013336,"bbox":[0,86,46,137],"first_seen_time":"2026-02-05T23:35:33.415598","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26748552918434143,"bbox":[157,11,179,24],"first_seen_time":"2026-02-05T23:35:33.415598","duration":0.0}],"frame_number":3570,"task_type":"realtime"}	2026-02-05 23:35:33+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233533_frame3570_track0_car.jpg	\N	realtime	\N	\N	f	\N
30	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7497137188911438,"bbox":[422,68,455,97],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.729609489440918,"bbox":[422,195,504,269],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7044181823730469,"bbox":[363,43,388,65],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6631205677986145,"bbox":[320,68,349,90],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6360692381858826,"bbox":[115,48,150,68],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6208247542381287,"bbox":[61,74,106,100],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49908044934272766,"bbox":[91,18,115,36],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4305602014064789,"bbox":[144,5,178,25],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3192523717880249,"bbox":[0,74,29,103],"first_seen_time":"2026-02-05T23:35:38.810185","duration":0.0}],"frame_number":3620,"task_type":"realtime"}	2026-02-05 23:35:38+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233538_frame3620_track0_car.jpg	\N	realtime	\N	\N	f	\N
31	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7041664719581604,"bbox":[362,32,381,50],"first_seen_time":"2026-02-05T23:35:44.280766","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6869306564331055,"bbox":[253,108,291,144],"first_seen_time":"2026-02-05T23:35:44.280766","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5647873282432556,"bbox":[86,28,125,46],"first_seen_time":"2026-02-05T23:35:44.280766","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5545684695243835,"bbox":[413,62,441,82],"first_seen_time":"2026-02-05T23:35:44.280766","duration":0.0}],"frame_number":3670,"task_type":"realtime"}	2026-02-05 23:35:44+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233544_frame3670_track0_car.jpg	\N	realtime	\N	\N	f	\N
32	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7895582318305969,"bbox":[384,98,428,137],"first_seen_time":"2026-02-05T23:35:49.841081","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5298271775245667,"bbox":[44,43,81,65],"first_seen_time":"2026-02-05T23:35:49.841081","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2572353780269623,"bbox":[328,43,349,57],"first_seen_time":"2026-02-05T23:35:49.841081","duration":0.0}],"frame_number":3720,"task_type":"realtime"}	2026-02-05 23:35:49+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233549_frame3720_track0_car.jpg	\N	realtime	\N	\N	f	\N
33	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.627204954624176,"bbox":[323,61,355,91],"first_seen_time":"2026-02-05T23:35:55.343217","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5685858726501465,"bbox":[96,20,122,36],"first_seen_time":"2026-02-05T23:35:55.343217","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5342316627502441,"bbox":[59,35,96,59],"first_seen_time":"2026-02-05T23:35:55.343217","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5276324152946472,"bbox":[378,79,411,103],"first_seen_time":"2026-02-05T23:35:55.343217","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5176899433135986,"bbox":[120,38,154,65],"first_seen_time":"2026-02-05T23:35:55.343217","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31265130639076233,"bbox":[355,22,375,38],"first_seen_time":"2026-02-05T23:35:55.343217","duration":0.0}],"frame_number":3770,"task_type":"realtime"}	2026-02-05 23:35:55+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233555_frame3770_track0_car.jpg	\N	realtime	\N	\N	f	\N
34	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6024330258369446,"bbox":[382,79,415,109],"first_seen_time":"2026-02-05T23:36:00.709540","duration":0.0}],"frame_number":3820,"task_type":"realtime"}	2026-02-05 23:36:00+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233600_frame3820_track0_car.jpg	\N	realtime	\N	\N	f	\N
35	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.42983880639076233,"bbox":[4,76,67,121],"first_seen_time":"2026-02-05T23:36:06.091472","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40573522448539734,"bbox":[38,36,66,54],"first_seen_time":"2026-02-05T23:36:06.091472","duration":0.0}],"frame_number":3870,"task_type":"realtime"}	2026-02-05 23:36:06+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233606_frame3870_track0_car.jpg	\N	realtime	\N	\N	f	\N
36	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.5307011008262634,"bbox":[65,29,95,43],"first_seen_time":"2026-02-05T23:36:11.438716","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5023670196533203,"bbox":[124,27,151,46],"first_seen_time":"2026-02-05T23:36:11.438716","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3887086510658264,"bbox":[370,51,395,71],"first_seen_time":"2026-02-05T23:36:11.438716","duration":0.0}],"frame_number":3920,"task_type":"realtime"}	2026-02-05 23:36:11+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233611_frame3920_track0_car.jpg	\N	realtime	\N	\N	f	\N
37	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.7144010066986084,"bbox":[232,133,280,176],"first_seen_time":"2026-02-05T23:36:16.760762","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.636915922164917,"bbox":[390,80,424,111],"first_seen_time":"2026-02-05T23:36:16.760762","duration":0.0}],"frame_number":3970,"task_type":"realtime"}	2026-02-05 23:36:16+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233616_frame3970_track0_car.jpg	\N	realtime	\N	\N	f	\N
56	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6466093063354492,"bbox":[277,64,304,87],"first_seen_time":"2026-02-05T23:38:00.066519","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6433433294296265,"bbox":[31,38,73,69],"first_seen_time":"2026-02-05T23:38:00.066519","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6260514259338379,"bbox":[398,43,419,59],"first_seen_time":"2026-02-05T23:38:00.066519","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47892123460769653,"bbox":[323,166,377,227],"first_seen_time":"2026-02-05T23:38:00.066519","duration":0.0}],"frame_number":4920,"task_type":"realtime"}	2026-02-05 23:38:00+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233800_frame4920_track0_car.jpg	\N	realtime	\N	\N	f	\N
38	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7486678957939148,"bbox":[379,64,411,94],"first_seen_time":"2026-02-05T23:36:22.188228","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6719128489494324,"bbox":[214,156,276,215],"first_seen_time":"2026-02-05T23:36:22.188228","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5655443072319031,"bbox":[126,28,161,63],"first_seen_time":"2026-02-05T23:36:22.188228","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5370039343833923,"bbox":[368,16,385,30],"first_seen_time":"2026-02-05T23:36:22.188228","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3614904284477234,"bbox":[216,3,233,17],"first_seen_time":"2026-02-05T23:36:22.188228","duration":0.0}],"frame_number":4020,"task_type":"realtime"}	2026-02-05 23:36:22+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233622_frame4020_track0_car.jpg	\N	realtime	\N	\N	f	\N
39	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.713567852973938,"bbox":[64,62,109,95],"first_seen_time":"2026-02-05T23:36:27.659490","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5456635355949402,"bbox":[0,39,27,65],"first_seen_time":"2026-02-05T23:36:27.659490","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3590835928916931,"bbox":[297,24,315,38],"first_seen_time":"2026-02-05T23:36:27.659490","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.30615681409835815,"bbox":[90,36,124,61],"first_seen_time":"2026-02-05T23:36:27.659490","duration":0.0}],"frame_number":4070,"task_type":"realtime"}	2026-02-05 23:36:27+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233627_frame4070_track0_car.jpg	\N	realtime	\N	\N	f	\N
40	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":8,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6918703317642212,"bbox":[195,209,271,289],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6034876108169556,"bbox":[433,222,525,311],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5292443633079529,"bbox":[254,40,280,57],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5047298669815063,"bbox":[314,145,364,200],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.42331695556640625,"bbox":[313,145,364,200],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3930639922618866,"bbox":[366,50,392,71],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33075886964797974,"bbox":[54,32,86,49],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3230392336845398,"bbox":[146,7,168,19],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2776336073875427,"bbox":[0,73,33,102],"first_seen_time":"2026-02-05T23:36:33.075109","duration":0.0}],"frame_number":4120,"task_type":"realtime"}	2026-02-05 23:36:33+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233633_frame4120_track0_car.jpg	\N	realtime	\N	\N	f	\N
41	car	江北初中监控安防任务	\N	{"total_count":10,"object_counts":{"car":10},"detections":[{"track_id":0,"class_name":"car","confidence":0.850907027721405,"bbox":[244,258,335,357],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7095190286636353,"bbox":[0,304,88,358],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.706855833530426,"bbox":[266,70,295,101],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6523407101631165,"bbox":[231,143,282,191],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6460370421409607,"bbox":[63,51,99,71],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5625496506690979,"bbox":[292,35,313,51],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5423030257225037,"bbox":[131,8,166,24],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4860963821411133,"bbox":[105,28,129,41],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4449477195739746,"bbox":[363,36,384,53],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34456169605255127,"bbox":[325,30,350,62],"first_seen_time":"2026-02-05T23:36:38.537518","duration":0.0}],"frame_number":4170,"task_type":"realtime"}	2026-02-05 23:36:38+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233638_frame4170_track0_car.jpg	\N	realtime	\N	\N	f	\N
42	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6802580952644348,"bbox":[317,142,374,217],"first_seen_time":"2026-02-05T23:36:43.946230","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5235635638237,"bbox":[322,40,343,59],"first_seen_time":"2026-02-05T23:36:43.946230","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4626525044441223,"bbox":[391,104,434,139],"first_seen_time":"2026-02-05T23:36:43.946230","duration":0.0}],"frame_number":4220,"task_type":"realtime"}	2026-02-05 23:36:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233644_frame4220_track0_car.jpg	\N	realtime	\N	\N	f	\N
43	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7715378999710083,"bbox":[79,20,108,41],"first_seen_time":"2026-02-05T23:36:49.435595","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6894665360450745,"bbox":[167,115,222,160],"first_seen_time":"2026-02-05T23:36:49.435595","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.665217936038971,"bbox":[301,110,341,150],"first_seen_time":"2026-02-05T23:36:49.435595","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5571180582046509,"bbox":[283,42,304,62],"first_seen_time":"2026-02-05T23:36:49.435595","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5015783309936523,"bbox":[269,75,298,101],"first_seen_time":"2026-02-05T23:36:49.435595","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4383932650089264,"bbox":[117,11,141,28],"first_seen_time":"2026-02-05T23:36:49.435595","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37949830293655396,"bbox":[30,45,65,69],"first_seen_time":"2026-02-05T23:36:49.435595","duration":0.0}],"frame_number":4270,"task_type":"realtime"}	2026-02-05 23:36:49+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233649_frame4270_track0_car.jpg	\N	realtime	\N	\N	f	\N
44	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6570963859558105,"bbox":[447,280,555,352],"first_seen_time":"2026-02-05T23:36:54.854147","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5029274821281433,"bbox":[309,272,395,355],"first_seen_time":"2026-02-05T23:36:54.854147","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4674335718154907,"bbox":[112,14,136,31],"first_seen_time":"2026-02-05T23:36:54.854147","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.4663753807544708,"bbox":[246,130,289,171],"first_seen_time":"2026-02-05T23:36:54.854147","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45045047998428345,"bbox":[380,57,408,84],"first_seen_time":"2026-02-05T23:36:54.854147","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.446005254983902,"bbox":[163,31,185,47],"first_seen_time":"2026-02-05T23:36:54.854147","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4127349257469177,"bbox":[245,130,287,170],"first_seen_time":"2026-02-05T23:36:54.854147","duration":0.0}],"frame_number":4320,"task_type":"realtime"}	2026-02-05 23:36:54+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233654_frame4320_track0_car.jpg	\N	realtime	\N	\N	f	\N
45	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.6948270201683044,"bbox":[164,29,185,45],"first_seen_time":"2026-02-05T23:37:00.266274","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6227441430091858,"bbox":[393,85,427,115],"first_seen_time":"2026-02-05T23:37:00.266274","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5971275568008423,"bbox":[362,44,385,61],"first_seen_time":"2026-02-05T23:37:00.266274","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5829135179519653,"bbox":[244,123,287,164],"first_seen_time":"2026-02-05T23:37:00.266274","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3999173939228058,"bbox":[327,38,351,52],"first_seen_time":"2026-02-05T23:37:00.266274","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35956770181655884,"bbox":[0,84,60,127],"first_seen_time":"2026-02-05T23:37:00.266274","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2796803414821625,"bbox":[32,35,69,55],"first_seen_time":"2026-02-05T23:37:00.266274","duration":0.0}],"frame_number":4370,"task_type":"realtime"}	2026-02-05 23:37:00+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233700_frame4370_track0_car.jpg	\N	realtime	\N	\N	f	\N
46	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7071889042854309,"bbox":[87,38,120,63],"first_seen_time":"2026-02-05T23:37:05.675605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.631125271320343,"bbox":[0,42,27,69],"first_seen_time":"2026-02-05T23:37:05.675605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5537449717521667,"bbox":[321,118,362,158],"first_seen_time":"2026-02-05T23:37:05.675605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5058026313781738,"bbox":[392,96,429,129],"first_seen_time":"2026-02-05T23:37:05.675605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43409836292266846,"bbox":[103,14,132,32],"first_seen_time":"2026-02-05T23:37:05.675605","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.385389119386673,"bbox":[321,118,362,159],"first_seen_time":"2026-02-05T23:37:05.675605","duration":0.0}],"frame_number":4420,"task_type":"realtime"}	2026-02-05 23:37:05+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233705_frame4420_track0_car.jpg	\N	realtime	\N	\N	f	\N
47	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":8,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6420371532440186,"bbox":[453,213,539,292],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6354197263717651,"bbox":[289,40,313,59],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5896388292312622,"bbox":[326,67,352,92],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.57390296459198,"bbox":[219,66,257,97],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5599937438964844,"bbox":[44,51,89,81],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5431837439537048,"bbox":[386,81,422,112],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4062492251396179,"bbox":[365,23,380,35],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.378643274307251,"bbox":[219,65,258,97],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2946662902832031,"bbox":[325,22,345,37],"first_seen_time":"2026-02-05T23:37:10.996179","duration":0.0}],"frame_number":4470,"task_type":"realtime"}	2026-02-05 23:37:10+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233711_frame4470_track0_car.jpg	\N	realtime	\N	\N	f	\N
48	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6745041608810425,"bbox":[408,149,465,199],"first_seen_time":"2026-02-05T23:37:16.413695","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5821806788444519,"bbox":[261,31,284,50],"first_seen_time":"2026-02-05T23:37:16.413695","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5174046158790588,"bbox":[131,297,233,357],"first_seen_time":"2026-02-05T23:37:16.413695","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5114692449569702,"bbox":[325,53,350,73],"first_seen_time":"2026-02-05T23:37:16.413695","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47973406314849854,"bbox":[319,131,361,172],"first_seen_time":"2026-02-05T23:37:16.413695","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.45597654581069946,"bbox":[15,76,84,119],"first_seen_time":"2026-02-05T23:37:16.413695","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3925069272518158,"bbox":[378,32,397,48],"first_seen_time":"2026-02-05T23:37:16.413695","duration":0.0}],"frame_number":4520,"task_type":"realtime"}	2026-02-05 23:37:16+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233716_frame4520_track0_car.jpg	\N	realtime	\N	\N	f	\N
57	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6583613157272339,"bbox":[372,64,402,92],"first_seen_time":"2026-02-05T23:38:05.438484","duration":0.0}],"frame_number":4970,"task_type":"realtime"}	2026-02-05 23:38:05+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233805_frame4970_track0_car.jpg	\N	realtime	\N	\N	f	\N
49	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.6951632499694824,"bbox":[133,142,206,203],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6836130023002625,"bbox":[373,47,397,69],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5735918879508972,"bbox":[313,198,381,278],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5497456789016724,"bbox":[191,16,214,31],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48617908358573914,"bbox":[253,35,280,57],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4010865390300751,"bbox":[409,103,449,142],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3518080413341522,"bbox":[327,44,347,61],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3478652238845825,"bbox":[298,24,319,39],"first_seen_time":"2026-02-05T23:37:21.795666","duration":0.0}],"frame_number":4570,"task_type":"realtime"}	2026-02-05 23:37:21+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233721_frame4570_track0_car.jpg	\N	realtime	\N	\N	f	\N
50	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.5215487480163574,"bbox":[240,122,284,161],"first_seen_time":"2026-02-05T23:37:27.275799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42384740710258484,"bbox":[323,74,350,97],"first_seen_time":"2026-02-05T23:37:27.275799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4082408547401428,"bbox":[383,80,415,109],"first_seen_time":"2026-02-05T23:37:27.275799","duration":0.0}],"frame_number":4620,"task_type":"realtime"}	2026-02-05 23:37:27+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233727_frame4620_track0_car.jpg	\N	realtime	\N	\N	f	\N
51	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7215592861175537,"bbox":[242,132,292,184],"first_seen_time":"2026-02-05T23:37:32.806281","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7070168852806091,"bbox":[85,60,125,86],"first_seen_time":"2026-02-05T23:37:32.806281","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6876762509346008,"bbox":[440,140,491,184],"first_seen_time":"2026-02-05T23:37:32.806281","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3179562985897064,"bbox":[102,19,132,42],"first_seen_time":"2026-02-05T23:37:32.806281","duration":0.0}],"frame_number":4670,"task_type":"realtime"}	2026-02-05 23:37:32+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233732_frame4670_track0_car.jpg	\N	realtime	\N	\N	f	\N
52	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.5895135402679443,"bbox":[315,125,360,174],"first_seen_time":"2026-02-05T23:37:38.187016","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5438098311424255,"bbox":[412,116,458,159],"first_seen_time":"2026-02-05T23:37:38.187016","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4983324706554413,"bbox":[378,28,397,44],"first_seen_time":"2026-02-05T23:37:38.187016","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48667389154434204,"bbox":[258,87,293,118],"first_seen_time":"2026-02-05T23:37:38.187016","duration":0.0}],"frame_number":4720,"task_type":"realtime"}	2026-02-05 23:37:38+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233738_frame4720_track0_car.jpg	\N	realtime	\N	\N	f	\N
53	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6744471788406372,"bbox":[318,53,345,74],"first_seen_time":"2026-02-05T23:37:43.663011","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4670385718345642,"bbox":[388,81,428,119],"first_seen_time":"2026-02-05T23:37:43.663011","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27058127522468567,"bbox":[376,25,393,43],"first_seen_time":"2026-02-05T23:37:43.663011","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25541582703590393,"bbox":[326,19,343,34],"first_seen_time":"2026-02-05T23:37:43.663011","duration":0.0}],"frame_number":4770,"task_type":"realtime"}	2026-02-05 23:37:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233743_frame4770_track0_car.jpg	\N	realtime	\N	\N	f	\N
54	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6007722616195679,"bbox":[409,169,482,240],"first_seen_time":"2026-02-05T23:37:49.188572","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5565471649169922,"bbox":[129,20,151,34],"first_seen_time":"2026-02-05T23:37:49.188572","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.488964706659317,"bbox":[65,17,105,43],"first_seen_time":"2026-02-05T23:37:49.188572","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3455241918563843,"bbox":[621,293,639,348],"first_seen_time":"2026-02-05T23:37:49.188572","duration":0.0}],"frame_number":4820,"task_type":"realtime"}	2026-02-05 23:37:49+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233749_frame4820_track0_car.jpg	\N	realtime	\N	\N	f	\N
55	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7416378855705261,"bbox":[40,29,74,53],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7248852849006653,"bbox":[358,28,380,47],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7178997993469238,"bbox":[551,224,639,302],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6841781139373779,"bbox":[390,108,432,149],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.67255038022995,"bbox":[112,10,151,36],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6237413287162781,"bbox":[322,41,344,59],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5315796136856079,"bbox":[407,46,430,68],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4394860863685608,"bbox":[16,81,74,118],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37895408272743225,"bbox":[163,1,203,16],"first_seen_time":"2026-02-05T23:37:54.638780","duration":0.0}],"frame_number":4870,"task_type":"realtime"}	2026-02-05 23:37:54+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233754_frame4870_track0_car.jpg	\N	realtime	\N	\N	f	\N
58	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6759306788444519,"bbox":[50,31,83,49],"first_seen_time":"2026-02-05T23:38:10.740352","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6210517287254333,"bbox":[369,52,397,72],"first_seen_time":"2026-02-05T23:38:10.740352","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5556128025054932,"bbox":[36,68,88,103],"first_seen_time":"2026-02-05T23:38:10.740352","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3112107515335083,"bbox":[325,38,350,59],"first_seen_time":"2026-02-05T23:38:10.740352","duration":0.0}],"frame_number":5020,"task_type":"realtime"}	2026-02-05 23:38:10+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233810_frame5020_track0_car.jpg	\N	realtime	\N	\N	f	\N
59	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6526903510093689,"bbox":[420,183,501,256],"first_seen_time":"2026-02-05T23:38:16.216856","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5219466090202332,"bbox":[364,41,387,62],"first_seen_time":"2026-02-05T23:38:16.216856","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5047004818916321,"bbox":[314,156,378,230],"first_seen_time":"2026-02-05T23:38:16.216856","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35197725892066956,"bbox":[190,14,209,30],"first_seen_time":"2026-02-05T23:38:16.216856","duration":0.0}],"frame_number":5070,"task_type":"realtime"}	2026-02-05 23:38:16+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233816_frame5070_track0_car.jpg	\N	realtime	\N	\N	f	\N
60	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7930365800857544,"bbox":[419,182,500,253],"first_seen_time":"2026-02-05T23:38:21.751368","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5698912143707275,"bbox":[362,33,382,49],"first_seen_time":"2026-02-05T23:38:21.751368","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2673397958278656,"bbox":[89,29,120,47],"first_seen_time":"2026-02-05T23:38:21.751368","duration":0.0}],"frame_number":5120,"task_type":"realtime"}	2026-02-05 23:38:21+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233821_frame5120_track0_car.jpg	\N	realtime	\N	\N	f	\N
61	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6823679208755493,"bbox":[73,44,109,67],"first_seen_time":"2026-02-05T23:38:27.065560","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5504431128501892,"bbox":[363,34,383,52],"first_seen_time":"2026-02-05T23:38:27.065560","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4580501616001129,"bbox":[0,42,33,60],"first_seen_time":"2026-02-05T23:38:27.065560","duration":0.0}],"frame_number":5170,"task_type":"realtime"}	2026-02-05 23:38:27+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233827_frame5170_track0_car.jpg	\N	realtime	\N	\N	f	\N
62	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6953461170196533,"bbox":[382,53,406,77],"first_seen_time":"2026-02-05T23:38:32.440007","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5660011768341064,"bbox":[267,76,296,103],"first_seen_time":"2026-02-05T23:38:32.440007","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4862591326236725,"bbox":[210,3,233,18],"first_seen_time":"2026-02-05T23:38:32.440007","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3132845461368561,"bbox":[138,8,159,23],"first_seen_time":"2026-02-05T23:38:32.440007","duration":0.0}],"frame_number":5220,"task_type":"realtime"}	2026-02-05 23:38:32+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233832_frame5220_track0_car.jpg	\N	realtime	\N	\N	f	\N
63	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7802714705467224,"bbox":[370,43,394,64],"first_seen_time":"2026-02-05T23:38:37.915331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6232203245162964,"bbox":[253,91,294,122],"first_seen_time":"2026-02-05T23:38:37.915331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5786606669425964,"bbox":[193,6,219,26],"first_seen_time":"2026-02-05T23:38:37.915331","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.4872235655784607,"bbox":[60,44,116,92],"first_seen_time":"2026-02-05T23:38:37.915331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46735477447509766,"bbox":[136,8,158,22],"first_seen_time":"2026-02-05T23:38:37.915331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.432603120803833,"bbox":[59,43,116,92],"first_seen_time":"2026-02-05T23:38:37.915331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42572811245918274,"bbox":[365,6,382,24],"first_seen_time":"2026-02-05T23:38:37.915331","duration":0.0}],"frame_number":5270,"task_type":"realtime"}	2026-02-05 23:38:37+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233838_frame5270_track0_car.jpg	\N	realtime	\N	\N	f	\N
64	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.8224722146987915,"bbox":[421,210,505,293],"first_seen_time":"2026-02-05T23:38:43.350117","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.8071422576904297,"bbox":[76,198,170,271],"first_seen_time":"2026-02-05T23:38:43.350117","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4016658067703247,"bbox":[168,12,192,29],"first_seen_time":"2026-02-05T23:38:43.350117","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2541577219963074,"bbox":[11,56,65,92],"first_seen_time":"2026-02-05T23:38:43.350117","duration":0.0}],"frame_number":5320,"task_type":"realtime"}	2026-02-05 23:38:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233843_frame5320_track0_car.jpg	\N	realtime	\N	\N	f	\N
71	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7275626063346863,"bbox":[185,211,271,306],"first_seen_time":"2026-02-05T23:39:21.445069","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6641775369644165,"bbox":[380,67,410,92],"first_seen_time":"2026-02-05T23:39:21.445069","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5954137444496155,"bbox":[71,20,103,41],"first_seen_time":"2026-02-05T23:39:21.445069","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5230644345283508,"bbox":[30,59,63,90],"first_seen_time":"2026-02-05T23:39:21.445069","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4865623712539673,"bbox":[322,78,353,105],"first_seen_time":"2026-02-05T23:39:21.445069","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3209780156612396,"bbox":[15,67,53,92],"first_seen_time":"2026-02-05T23:39:21.445069","duration":0.0}],"frame_number":5670,"task_type":"realtime"}	2026-02-05 23:39:21+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233921_frame5670_track0_car.jpg	\N	realtime	\N	\N	f	\N
65	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":7,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6939758658409119,"bbox":[398,129,446,172],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5727260112762451,"bbox":[249,121,292,160],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5558432936668396,"bbox":[360,33,382,52],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5097879767417908,"bbox":[320,89,353,120],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.41902005672454834,"bbox":[119,11,144,29],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4115634858608246,"bbox":[311,176,387,275],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3475431799888611,"bbox":[312,177,387,276],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3123290240764618,"bbox":[0,41,28,69],"first_seen_time":"2026-02-05T23:38:48.840041","duration":0.0}],"frame_number":5370,"task_type":"realtime"}	2026-02-05 23:38:48+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233848_frame5370_track0_car.jpg	\N	realtime	\N	\N	f	\N
66	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7124320864677429,"bbox":[128,28,156,44],"first_seen_time":"2026-02-05T23:38:54.260430","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6032884120941162,"bbox":[198,92,240,127],"first_seen_time":"2026-02-05T23:38:54.260430","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5819145441055298,"bbox":[386,102,428,145],"first_seen_time":"2026-02-05T23:38:54.260430","duration":0.0}],"frame_number":5420,"task_type":"realtime"}	2026-02-05 23:38:54+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233854_frame5420_track0_car.jpg	\N	realtime	\N	\N	f	\N
67	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.6961814761161804,"bbox":[181,181,256,265],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6680039763450623,"bbox":[378,65,408,100],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6587910652160645,"bbox":[276,71,304,95],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6332736015319824,"bbox":[69,21,102,42],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5814855098724365,"bbox":[322,89,365,133],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28100156784057617,"bbox":[154,18,178,35],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27142083644866943,"bbox":[155,10,193,36],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26715660095214844,"bbox":[321,54,349,74],"first_seen_time":"2026-02-05T23:38:59.786086","duration":0.0}],"frame_number":5470,"task_type":"realtime"}	2026-02-05 23:38:59+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233859_frame5470_track0_car.jpg	\N	realtime	\N	\N	f	\N
68	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7515295743942261,"bbox":[314,69,343,97],"first_seen_time":"2026-02-05T23:39:05.162368","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6375585198402405,"bbox":[85,18,111,36],"first_seen_time":"2026-02-05T23:39:05.162368","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6233934760093689,"bbox":[28,29,65,57],"first_seen_time":"2026-02-05T23:39:05.162368","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6050061583518982,"bbox":[289,30,309,48],"first_seen_time":"2026-02-05T23:39:05.162368","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5675883293151855,"bbox":[278,54,305,74],"first_seen_time":"2026-02-05T23:39:05.162368","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5576655864715576,"bbox":[217,71,254,102],"first_seen_time":"2026-02-05T23:39:05.162368","duration":0.0}],"frame_number":5520,"task_type":"realtime"}	2026-02-05 23:39:05+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233905_frame5520_track0_car.jpg	\N	realtime	\N	\N	f	\N
69	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7510245442390442,"bbox":[403,162,463,217],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6455560326576233,"bbox":[319,149,369,203],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5039617419242859,"bbox":[188,15,209,32],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48153504729270935,"bbox":[117,49,151,70],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3832009732723236,"bbox":[156,9,175,23],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37421298027038574,"bbox":[74,24,104,41],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36680787801742554,"bbox":[104,26,137,54],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32308241724967957,"bbox":[272,79,301,104],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3184102177619934,"bbox":[374,40,397,61],"first_seen_time":"2026-02-05T23:39:10.532789","duration":0.0}],"frame_number":5570,"task_type":"realtime"}	2026-02-05 23:39:10+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233910_frame5570_track0_car.jpg	\N	realtime	\N	\N	f	\N
70	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.661604642868042,"bbox":[384,60,411,83],"first_seen_time":"2026-02-05T23:39:15.956231","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6307446956634521,"bbox":[123,45,154,66],"first_seen_time":"2026-02-05T23:39:15.956231","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5238444805145264,"bbox":[271,74,299,101],"first_seen_time":"2026-02-05T23:39:15.956231","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35382863879203796,"bbox":[291,33,311,48],"first_seen_time":"2026-02-05T23:39:15.956231","duration":0.0}],"frame_number":5620,"task_type":"realtime"}	2026-02-05 23:39:15+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233916_frame5620_track0_car.jpg	\N	realtime	\N	\N	f	\N
72	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7996886968612671,"bbox":[81,182,179,263],"first_seen_time":"2026-02-05T23:39:26.888233","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7067212462425232,"bbox":[375,56,403,78],"first_seen_time":"2026-02-05T23:39:26.888233","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.678712785243988,"bbox":[296,27,317,43],"first_seen_time":"2026-02-05T23:39:26.888233","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6437718272209167,"bbox":[419,124,464,167],"first_seen_time":"2026-02-05T23:39:26.888233","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5867751240730286,"bbox":[310,249,395,354],"first_seen_time":"2026-02-05T23:39:26.888233","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4942414462566376,"bbox":[327,49,349,68],"first_seen_time":"2026-02-05T23:39:26.888233","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45853739976882935,"bbox":[246,41,275,65],"first_seen_time":"2026-02-05T23:39:26.888233","duration":0.0}],"frame_number":5720,"task_type":"realtime"}	2026-02-05 23:39:26+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233926_frame5720_track0_car.jpg	\N	realtime	\N	\N	f	\N
73	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6800687313079834,"bbox":[320,161,370,218],"first_seen_time":"2026-02-05T23:39:32.284278","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6646212935447693,"bbox":[450,240,558,351],"first_seen_time":"2026-02-05T23:39:32.284278","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6041670441627502,"bbox":[257,100,296,137],"first_seen_time":"2026-02-05T23:39:32.284278","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.5419531464576721,"bbox":[0,247,126,356],"first_seen_time":"2026-02-05T23:39:32.284278","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5052633881568909,"bbox":[14,35,57,58],"first_seen_time":"2026-02-05T23:39:32.284278","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.498500794172287,"bbox":[155,18,177,35],"first_seen_time":"2026-02-05T23:39:32.284278","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48314306139945984,"bbox":[372,43,393,60],"first_seen_time":"2026-02-05T23:39:32.284278","duration":0.0}],"frame_number":5770,"task_type":"realtime"}	2026-02-05 23:39:32+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233932_frame5770_track0_car.jpg	\N	realtime	\N	\N	f	\N
74	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.6605145931243896,"bbox":[321,119,363,163],"first_seen_time":"2026-02-05T23:39:37.667122","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5622705817222595,"bbox":[162,25,190,48],"first_seen_time":"2026-02-05T23:39:37.667122","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.510601818561554,"bbox":[206,81,247,117],"first_seen_time":"2026-02-05T23:39:37.667122","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4600507616996765,"bbox":[302,15,321,28],"first_seen_time":"2026-02-05T23:39:37.667122","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40575820207595825,"bbox":[394,68,423,96],"first_seen_time":"2026-02-05T23:39:37.667122","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3863618075847626,"bbox":[268,22,289,40],"first_seen_time":"2026-02-05T23:39:37.667122","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3142494261264801,"bbox":[367,33,387,50],"first_seen_time":"2026-02-05T23:39:37.667122","duration":0.0}],"frame_number":5820,"task_type":"realtime"}	2026-02-05 23:39:37+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233937_frame5820_track0_car.jpg	\N	realtime	\N	\N	f	\N
75	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6898912787437439,"bbox":[372,57,399,77],"first_seen_time":"2026-02-05T23:39:43.082540","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5555357933044434,"bbox":[269,75,297,101],"first_seen_time":"2026-02-05T23:39:43.082540","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28813913464546204,"bbox":[325,53,346,68],"first_seen_time":"2026-02-05T23:39:43.082540","duration":0.0}],"frame_number":5870,"task_type":"realtime"}	2026-02-05 23:39:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233943_frame5870_track0_car.jpg	\N	realtime	\N	\N	f	\N
76	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6426225900650024,"bbox":[271,82,306,115],"first_seen_time":"2026-02-05T23:39:48.520616","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.6268857717514038,"bbox":[200,214,277,293],"first_seen_time":"2026-02-05T23:39:48.520616","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5616374611854553,"bbox":[415,91,451,124],"first_seen_time":"2026-02-05T23:39:48.520616","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48367178440093994,"bbox":[53,38,90,59],"first_seen_time":"2026-02-05T23:39:48.520616","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33776286244392395,"bbox":[149,21,172,36],"first_seen_time":"2026-02-05T23:39:48.520616","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33579355478286743,"bbox":[0,101,38,143],"first_seen_time":"2026-02-05T23:39:48.520616","duration":0.0}],"frame_number":5920,"task_type":"realtime"}	2026-02-05 23:39:48+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233948_frame5920_track0_car.jpg	\N	realtime	\N	\N	f	\N
77	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6147585511207581,"bbox":[320,78,352,111],"first_seen_time":"2026-02-05T23:39:53.887885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5659288167953491,"bbox":[399,80,431,112],"first_seen_time":"2026-02-05T23:39:53.887885","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5543585419654846,"bbox":[275,57,302,81],"first_seen_time":"2026-02-05T23:39:53.887885","duration":0.0}],"frame_number":5970,"task_type":"realtime"}	2026-02-05 23:39:53+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233954_frame5970_track0_car.jpg	\N	realtime	\N	\N	f	\N
78	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6687439680099487,"bbox":[378,58,408,88],"first_seen_time":"2026-02-05T23:39:59.388868","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5150646567344666,"bbox":[320,38,343,53],"first_seen_time":"2026-02-05T23:39:59.388868","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46347764134407043,"bbox":[152,31,177,51],"first_seen_time":"2026-02-05T23:39:59.388868","duration":0.0}],"frame_number":6020,"task_type":"realtime"}	2026-02-05 23:39:59+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_233959_frame6020_track0_car.jpg	\N	realtime	\N	\N	f	\N
79	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8538680672645569,"bbox":[508,169,600,234],"first_seen_time":"2026-02-05T23:40:04.866378","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7670023441314697,"bbox":[93,30,122,46],"first_seen_time":"2026-02-05T23:40:04.866378","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7348156571388245,"bbox":[305,234,376,328],"first_seen_time":"2026-02-05T23:40:04.866378","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.665202260017395,"bbox":[386,103,431,147],"first_seen_time":"2026-02-05T23:40:04.866378","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5368434190750122,"bbox":[29,28,69,55],"first_seen_time":"2026-02-05T23:40:04.866378","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5230630040168762,"bbox":[138,25,163,42],"first_seen_time":"2026-02-05T23:40:04.866378","duration":0.0}],"frame_number":6070,"task_type":"realtime"}	2026-02-05 23:40:04+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234005_frame6070_track0_car.jpg	\N	realtime	\N	\N	f	\N
80	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.8310718536376953,"bbox":[480,141,541,182],"first_seen_time":"2026-02-05T23:40:10.246688","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7746224999427795,"bbox":[377,73,407,101],"first_seen_time":"2026-02-05T23:40:10.246688","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6597678661346436,"bbox":[396,33,417,53],"first_seen_time":"2026-02-05T23:40:10.246688","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6428865194320679,"bbox":[82,19,120,50],"first_seen_time":"2026-02-05T23:40:10.246688","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5914875268936157,"bbox":[324,29,344,44],"first_seen_time":"2026-02-05T23:40:10.246688","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5851407051086426,"bbox":[0,42,27,70],"first_seen_time":"2026-02-05T23:40:10.246688","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3814952075481415,"bbox":[145,3,190,22],"first_seen_time":"2026-02-05T23:40:10.246688","duration":0.0}],"frame_number":6120,"task_type":"realtime"}	2026-02-05 23:40:10+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234010_frame6120_track0_car.jpg	\N	realtime	\N	\N	f	\N
81	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.632421612739563,"bbox":[289,43,309,60],"first_seen_time":"2026-02-05T23:40:15.569311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5913593769073486,"bbox":[327,100,367,135],"first_seen_time":"2026-02-05T23:40:15.569311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5376457571983337,"bbox":[386,33,407,47],"first_seen_time":"2026-02-05T23:40:15.569311","duration":0.0}],"frame_number":6170,"task_type":"realtime"}	2026-02-05 23:40:15+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234015_frame6170_track0_car.jpg	\N	realtime	\N	\N	f	\N
82	truck	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"truck":2,"car":1},"detections":[{"track_id":0,"class_name":"truck","confidence":0.547812283039093,"bbox":[311,193,389,298],"first_seen_time":"2026-02-05T23:40:20.997748","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.5300480723381042,"bbox":[438,225,538,329],"first_seen_time":"2026-02-05T23:40:20.997748","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4396970868110657,"bbox":[365,45,396,70],"first_seen_time":"2026-02-05T23:40:20.997748","duration":0.0}],"frame_number":6220,"task_type":"realtime"}	2026-02-05 23:40:20+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234021_frame6220_track0_truck.jpg	\N	realtime	\N	\N	f	\N
83	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7329147458076477,"bbox":[403,153,466,211],"first_seen_time":"2026-02-05T23:40:26.439737","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49689728021621704,"bbox":[327,59,355,80],"first_seen_time":"2026-02-05T23:40:26.439737","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44952502846717834,"bbox":[35,36,72,54],"first_seen_time":"2026-02-05T23:40:26.439737","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2892724871635437,"bbox":[296,25,317,40],"first_seen_time":"2026-02-05T23:40:26.439737","duration":0.0}],"frame_number":6270,"task_type":"realtime"}	2026-02-05 23:40:26+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234026_frame6270_track0_car.jpg	\N	realtime	\N	\N	f	\N
84	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7154672741889954,"bbox":[162,26,186,43],"first_seen_time":"2026-02-05T23:40:31.764172","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5441376566886902,"bbox":[393,115,438,156],"first_seen_time":"2026-02-05T23:40:31.764172","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48898327350616455,"bbox":[360,30,382,48],"first_seen_time":"2026-02-05T23:40:31.764172","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.4632938504219055,"bbox":[320,94,367,136],"first_seen_time":"2026-02-05T23:40:31.764172","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43554648756980896,"bbox":[115,12,146,38],"first_seen_time":"2026-02-05T23:40:31.764172","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4053215980529785,"bbox":[320,94,366,136],"first_seen_time":"2026-02-05T23:40:31.764172","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2959829270839691,"bbox":[114,24,139,39],"first_seen_time":"2026-02-05T23:40:31.764172","duration":0.0}],"frame_number":6320,"task_type":"realtime"}	2026-02-05 23:40:31+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234031_frame6320_track0_car.jpg	\N	realtime	\N	\N	f	\N
85	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.48568737506866455,"bbox":[395,115,441,157],"first_seen_time":"2026-02-05T23:40:37.220097","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46570757031440735,"bbox":[37,42,77,65],"first_seen_time":"2026-02-05T23:40:37.220097","duration":0.0}],"frame_number":6370,"task_type":"realtime"}	2026-02-05 23:40:37+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234037_frame6370_track0_car.jpg	\N	realtime	\N	\N	f	\N
86	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.7775968909263611,"bbox":[455,257,564,354],"first_seen_time":"2026-02-05T23:40:42.667769","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.513890266418457,"bbox":[0,62,50,100],"first_seen_time":"2026-02-05T23:40:42.667769","duration":0.0}],"frame_number":6420,"task_type":"realtime"}	2026-02-05 23:40:42+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234042_frame6420_track0_car.jpg	\N	realtime	\N	\N	f	\N
87	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.8829171061515808,"bbox":[431,191,521,279],"first_seen_time":"2026-02-05T23:40:48.099455","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5064026117324829,"bbox":[195,4,219,24],"first_seen_time":"2026-02-05T23:40:48.099455","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.440424382686615,"bbox":[376,39,397,56],"first_seen_time":"2026-02-05T23:40:48.099455","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3707038164138794,"bbox":[108,16,134,33],"first_seen_time":"2026-02-05T23:40:48.099455","duration":0.0}],"frame_number":6470,"task_type":"realtime"}	2026-02-05 23:40:48+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234048_frame6470_track0_car.jpg	\N	realtime	\N	\N	f	\N
88	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7746641635894775,"bbox":[364,30,385,50],"first_seen_time":"2026-02-05T23:40:53.431170","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6324156522750854,"bbox":[276,59,304,84],"first_seen_time":"2026-02-05T23:40:53.431170","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5535566806793213,"bbox":[174,11,198,38],"first_seen_time":"2026-02-05T23:40:53.431170","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.39411965012550354,"bbox":[109,13,134,31],"first_seen_time":"2026-02-05T23:40:53.431170","duration":0.0}],"frame_number":6520,"task_type":"realtime"}	2026-02-05 23:40:53+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234053_frame6520_track0_car.jpg	\N	realtime	\N	\N	f	\N
89	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7291859984397888,"bbox":[393,98,437,141],"first_seen_time":"2026-02-05T23:40:58.811767","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6822633147239685,"bbox":[166,17,194,41],"first_seen_time":"2026-02-05T23:40:58.811767","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6070718765258789,"bbox":[42,30,79,52],"first_seen_time":"2026-02-05T23:40:58.811767","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5806130766868591,"bbox":[372,25,390,42],"first_seen_time":"2026-02-05T23:40:58.811767","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36244016885757446,"bbox":[293,27,310,44],"first_seen_time":"2026-02-05T23:40:58.811767","duration":0.0}],"frame_number":6570,"task_type":"realtime"}	2026-02-05 23:40:58+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234058_frame6570_track0_car.jpg	\N	realtime	\N	\N	f	\N
90	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7456321716308594,"bbox":[56,24,90,46],"first_seen_time":"2026-02-05T23:41:04.199331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7047384977340698,"bbox":[289,36,312,52],"first_seen_time":"2026-02-05T23:41:04.199331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5018773078918457,"bbox":[130,38,160,65],"first_seen_time":"2026-02-05T23:41:04.199331","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27143704891204834,"bbox":[135,23,160,39],"first_seen_time":"2026-02-05T23:41:04.199331","duration":0.0}],"frame_number":6620,"task_type":"realtime"}	2026-02-05 23:41:04+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234104_frame6620_track0_car.jpg	\N	realtime	\N	\N	f	\N
91	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7372342348098755,"bbox":[233,61,263,85],"first_seen_time":"2026-02-05T23:41:09.617717","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6671855449676514,"bbox":[78,44,113,64],"first_seen_time":"2026-02-05T23:41:09.617717","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5721768140792847,"bbox":[374,69,404,100],"first_seen_time":"2026-02-05T23:41:09.617717","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4317975640296936,"bbox":[300,283,391,354],"first_seen_time":"2026-02-05T23:41:09.617717","duration":0.0}],"frame_number":6670,"task_type":"realtime"}	2026-02-05 23:41:09+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234109_frame6670_track0_car.jpg	\N	realtime	\N	\N	f	\N
92	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7257254719734192,"bbox":[145,266,250,357],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6368317008018494,"bbox":[237,104,282,155],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5960564017295837,"bbox":[370,52,397,73],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4947654604911804,"bbox":[120,31,147,50],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4457269608974457,"bbox":[287,51,309,69],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38249367475509644,"bbox":[29,32,57,59],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3743894100189209,"bbox":[324,58,354,91],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.30184033513069153,"bbox":[13,41,30,60],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2776550352573395,"bbox":[149,0,183,20],"first_seen_time":"2026-02-05T23:41:15.011997","duration":0.0}],"frame_number":6720,"task_type":"realtime"}	2026-02-05 23:41:15+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234115_frame6720_track0_car.jpg	\N	realtime	\N	\N	f	\N
93	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7290912866592407,"bbox":[417,167,488,231],"first_seen_time":"2026-02-05T23:41:20.379408","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6877284646034241,"bbox":[288,28,310,54],"first_seen_time":"2026-02-05T23:41:20.379408","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6822248697280884,"bbox":[319,46,344,66],"first_seen_time":"2026-02-05T23:41:20.379408","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.522287130355835,"bbox":[39,28,76,52],"first_seen_time":"2026-02-05T23:41:20.379408","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3916890323162079,"bbox":[245,45,269,69],"first_seen_time":"2026-02-05T23:41:20.379408","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2641879618167877,"bbox":[194,1,214,16],"first_seen_time":"2026-02-05T23:41:20.379408","duration":0.0}],"frame_number":6770,"task_type":"realtime"}	2026-02-05 23:41:20+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234120_frame6770_track0_car.jpg	\N	realtime	\N	\N	f	\N
94	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7892690300941467,"bbox":[322,116,362,155],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7496417164802551,"bbox":[170,235,257,332],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6714699268341064,"bbox":[278,63,305,85],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5744017362594604,"bbox":[84,61,125,88],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5267859697341919,"bbox":[48,29,83,51],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4911231994628906,"bbox":[393,126,438,168],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40004441142082214,"bbox":[173,20,197,39],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36367249488830566,"bbox":[144,11,166,28],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26355254650115967,"bbox":[373,33,393,55],"first_seen_time":"2026-02-05T23:41:25.386533","duration":0.0}],"frame_number":6815,"task_type":"realtime"}	2026-02-05 23:41:25+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234125_frame6815_track0_car.jpg	\N	realtime	\N	\N	f	\N
95	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7358433604240417,"bbox":[276,60,304,82],"first_seen_time":"2026-02-05T23:41:30.916252","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7040977478027344,"bbox":[91,56,131,82],"first_seen_time":"2026-02-05T23:41:30.916252","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6126962304115295,"bbox":[382,51,405,72],"first_seen_time":"2026-02-05T23:41:30.916252","duration":0.0}],"frame_number":6865,"task_type":"realtime"}	2026-02-05 23:41:30+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234131_frame6865_track0_car.jpg	\N	realtime	\N	\N	f	\N
96	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7718517184257507,"bbox":[314,256,393,353],"first_seen_time":"2026-02-05T23:41:36.408266","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7362945079803467,"bbox":[227,152,285,210],"first_seen_time":"2026-02-05T23:41:36.408266","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.733310878276825,"bbox":[51,25,86,45],"first_seen_time":"2026-02-05T23:41:36.408266","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7076420783996582,"bbox":[376,58,403,79],"first_seen_time":"2026-02-05T23:41:36.408266","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5963780283927917,"bbox":[0,76,16,106],"first_seen_time":"2026-02-05T23:41:36.408266","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48788905143737793,"bbox":[324,65,351,87],"first_seen_time":"2026-02-05T23:41:36.408266","duration":0.0}],"frame_number":6915,"task_type":"realtime"}	2026-02-05 23:41:36+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234136_frame6915_track0_car.jpg	\N	realtime	\N	\N	f	\N
97	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7918506264686584,"bbox":[152,128,217,182],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7190983891487122,"bbox":[372,46,396,65],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7051547169685364,"bbox":[314,178,377,247],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5136844515800476,"bbox":[404,96,443,131],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48959070444107056,"bbox":[186,18,210,35],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4408370852470398,"bbox":[298,24,320,37],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3815338611602783,"bbox":[327,42,346,57],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3370741903781891,"bbox":[257,32,280,52],"first_seen_time":"2026-02-05T23:41:41.950553","duration":0.0}],"frame_number":6965,"task_type":"realtime"}	2026-02-05 23:41:41+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234142_frame6965_track0_car.jpg	\N	realtime	\N	\N	f	\N
98	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":7,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6785736680030823,"bbox":[421,173,495,240],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6229007244110107,"bbox":[322,126,363,168],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5958641767501831,"bbox":[0,42,27,65],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5347878336906433,"bbox":[323,41,344,57],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5111454129219055,"bbox":[271,77,307,108],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47586342692375183,"bbox":[370,38,390,53],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.47466424107551575,"bbox":[92,166,189,239],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4640893340110779,"bbox":[92,167,188,239],"first_seen_time":"2026-02-05T23:41:47.392982","duration":0.0}],"frame_number":7015,"task_type":"realtime"}	2026-02-05 23:41:47+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234147_frame7015_track0_car.jpg	\N	realtime	\N	\N	f	\N
113	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.764208197593689,"bbox":[276,57,305,79],"first_seen_time":"2026-02-05T23:43:07.194741","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7551021575927734,"bbox":[364,29,382,47],"first_seen_time":"2026-02-05T23:43:07.194741","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6317443251609802,"bbox":[105,15,130,32],"first_seen_time":"2026-02-05T23:43:07.194741","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5441256165504456,"bbox":[170,14,195,40],"first_seen_time":"2026-02-05T23:43:07.194741","duration":0.0}],"frame_number":7760,"task_type":"realtime"}	2026-02-05 23:43:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234307_frame7760_track0_car.jpg	\N	realtime	\N	\N	f	\N
99	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.6648162007331848,"bbox":[321,112,362,158],"first_seen_time":"2026-02-05T23:41:52.411843","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6508793234825134,"bbox":[210,78,250,111],"first_seen_time":"2026-02-05T23:41:52.411843","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6053888201713562,"bbox":[394,68,422,92],"first_seen_time":"2026-02-05T23:41:52.411843","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5011806488037109,"bbox":[268,21,289,38],"first_seen_time":"2026-02-05T23:41:52.411843","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43213945627212524,"bbox":[303,14,322,27],"first_seen_time":"2026-02-05T23:41:52.411843","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42323431372642517,"bbox":[158,28,187,49],"first_seen_time":"2026-02-05T23:41:52.411843","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31071174144744873,"bbox":[367,33,387,49],"first_seen_time":"2026-02-05T23:41:52.411843","duration":0.0}],"frame_number":7060,"task_type":"realtime"}	2026-02-05 23:41:52+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234152_frame7060_track0_car.jpg	\N	realtime	\N	\N	f	\N
100	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.70001220703125,"bbox":[372,55,398,75],"first_seen_time":"2026-02-05T23:41:57.919751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6606582999229431,"bbox":[271,73,299,96],"first_seen_time":"2026-02-05T23:41:57.919751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2587287127971649,"bbox":[325,51,345,67],"first_seen_time":"2026-02-05T23:41:57.919751","duration":0.0}],"frame_number":7110,"task_type":"realtime"}	2026-02-05 23:41:57+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234158_frame7110_track0_car.jpg	\N	realtime	\N	\N	f	\N
101	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6523117423057556,"bbox":[274,77,305,111],"first_seen_time":"2026-02-05T23:42:03.332289","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6282424330711365,"bbox":[413,88,447,118],"first_seen_time":"2026-02-05T23:42:03.332289","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5278330445289612,"bbox":[46,37,86,61],"first_seen_time":"2026-02-05T23:42:03.332289","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.48405614495277405,"bbox":[208,201,279,274],"first_seen_time":"2026-02-05T23:42:03.332289","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43449246883392334,"bbox":[208,201,279,273],"first_seen_time":"2026-02-05T23:42:03.332289","duration":0.0}],"frame_number":7160,"task_type":"realtime"}	2026-02-05 23:42:03+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234203_frame7160_track0_car.jpg	\N	realtime	\N	\N	f	\N
102	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.5216960310935974,"bbox":[397,78,430,108],"first_seen_time":"2026-02-05T23:42:08.767299","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4422318637371063,"bbox":[321,76,352,106],"first_seen_time":"2026-02-05T23:42:08.767299","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.409938246011734,"bbox":[293,318,375,356],"first_seen_time":"2026-02-05T23:42:08.767299","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.39770880341529846,"bbox":[276,56,303,80],"first_seen_time":"2026-02-05T23:42:08.767299","duration":0.0}],"frame_number":7210,"task_type":"realtime"}	2026-02-05 23:42:08+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234208_frame7210_track0_car.jpg	\N	realtime	\N	\N	f	\N
103	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7296612858772278,"bbox":[377,55,407,86],"first_seen_time":"2026-02-05T23:42:14.028943","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5508966445922852,"bbox":[321,36,343,53],"first_seen_time":"2026-02-05T23:42:14.028943","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33854594826698303,"bbox":[148,31,175,52],"first_seen_time":"2026-02-05T23:42:14.028943","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2599615752696991,"bbox":[372,17,389,31],"first_seen_time":"2026-02-05T23:42:14.028943","duration":0.0}],"frame_number":7260,"task_type":"realtime"}	2026-02-05 23:42:14+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234214_frame7260_track0_car.jpg	\N	realtime	\N	\N	f	\N
104	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8391969799995422,"bbox":[501,162,587,224],"first_seen_time":"2026-02-05T23:42:19.344632","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.8353655338287354,"bbox":[308,221,372,301],"first_seen_time":"2026-02-05T23:42:19.344632","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.732836902141571,"bbox":[90,31,117,47],"first_seen_time":"2026-02-05T23:42:19.344632","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5830540657043457,"bbox":[385,100,428,142],"first_seen_time":"2026-02-05T23:42:19.344632","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4864504337310791,"bbox":[27,27,69,55],"first_seen_time":"2026-02-05T23:42:19.344632","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38296547532081604,"bbox":[133,24,160,43],"first_seen_time":"2026-02-05T23:42:19.344632","duration":0.0}],"frame_number":7310,"task_type":"realtime"}	2026-02-05 23:42:19+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234219_frame7310_track0_car.jpg	\N	realtime	\N	\N	f	\N
105	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7806102633476257,"bbox":[376,69,405,98],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7757113575935364,"bbox":[473,135,535,177],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6040880680084229,"bbox":[77,19,115,52],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5341042280197144,"bbox":[395,33,416,52],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5195610523223877,"bbox":[323,28,342,42],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4106433689594269,"bbox":[144,8,179,22],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4009522795677185,"bbox":[0,49,16,70],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29891568422317505,"bbox":[357,19,374,35],"first_seen_time":"2026-02-05T23:42:24.745795","duration":0.0}],"frame_number":7360,"task_type":"realtime"}	2026-02-05 23:42:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234224_frame7360_track0_car.jpg	\N	realtime	\N	\N	f	\N
106	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.635866105556488,"bbox":[60,47,102,73],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6124776005744934,"bbox":[439,89,484,125],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.606357753276825,"bbox":[123,50,152,69],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5869656801223755,"bbox":[5,54,49,77],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5086396932601929,"bbox":[369,57,399,84],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46617838740348816,"bbox":[319,97,352,128],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46294838190078735,"bbox":[152,32,178,50],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3277779817581177,"bbox":[114,13,135,28],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31028562784194946,"bbox":[169,0,193,18],"first_seen_time":"2026-02-05T23:42:30.177037","duration":0.0}],"frame_number":7410,"task_type":"realtime"}	2026-02-05 23:42:30+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234230_frame7410_track0_car.jpg	\N	realtime	\N	\N	f	\N
107	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":8,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6988217830657959,"bbox":[364,41,387,61],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6984090209007263,"bbox":[217,171,275,228],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6793322563171387,"bbox":[428,78,464,106],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4227171242237091,"bbox":[112,15,152,35],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38047322630882263,"bbox":[110,16,131,34],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3616020679473877,"bbox":[0,38,44,86],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32568076252937317,"bbox":[324,16,343,28],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3191690444946289,"bbox":[0,38,44,86],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.30412906408309937,"bbox":[353,9,368,23],"first_seen_time":"2026-02-05T23:42:35.434150","duration":0.0}],"frame_number":7460,"task_type":"realtime"}	2026-02-05 23:42:35+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234235_frame7460_track0_car.jpg	\N	realtime	\N	\N	f	\N
108	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.8256346583366394,"bbox":[397,139,455,194],"first_seen_time":"2026-02-05T23:42:40.694901","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5184109210968018,"bbox":[327,56,355,76],"first_seen_time":"2026-02-05T23:42:40.694901","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4374338686466217,"bbox":[88,33,117,50],"first_seen_time":"2026-02-05T23:42:40.694901","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34179678559303284,"bbox":[30,39,66,56],"first_seen_time":"2026-02-05T23:42:40.694901","duration":0.0}],"frame_number":7510,"task_type":"realtime"}	2026-02-05 23:42:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234240_frame7510_track0_car.jpg	\N	realtime	\N	\N	f	\N
109	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7435711622238159,"bbox":[155,26,182,45],"first_seen_time":"2026-02-05T23:42:45.987432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5601497292518616,"bbox":[359,29,382,47],"first_seen_time":"2026-02-05T23:42:45.987432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5009622573852539,"bbox":[322,87,361,126],"first_seen_time":"2026-02-05T23:42:45.987432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43842121958732605,"bbox":[106,26,133,41],"first_seen_time":"2026-02-05T23:42:45.987432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42257747054100037,"bbox":[389,103,433,143],"first_seen_time":"2026-02-05T23:42:45.987432","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.326700896024704,"bbox":[389,103,433,143],"first_seen_time":"2026-02-05T23:42:45.987432","duration":0.0}],"frame_number":7560,"task_type":"realtime"}	2026-02-05 23:42:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234246_frame7560_track0_car.jpg	\N	realtime	\N	\N	f	\N
110	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.49738624691963196,"bbox":[393,102,435,146],"first_seen_time":"2026-02-05T23:42:51.222584","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3955844044685364,"bbox":[30,45,67,68],"first_seen_time":"2026-02-05T23:42:51.222584","duration":0.0}],"frame_number":7610,"task_type":"realtime"}	2026-02-05 23:42:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234251_frame7610_track0_car.jpg	\N	realtime	\N	\N	f	\N
111	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.8585284948348999,"bbox":[444,228,537,319],"first_seen_time":"2026-02-05T23:42:56.542330","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32529234886169434,"bbox":[0,72,33,108],"first_seen_time":"2026-02-05T23:42:56.542330","duration":0.0}],"frame_number":7660,"task_type":"realtime"}	2026-02-05 23:42:56+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234256_frame7660_track0_car.jpg	\N	realtime	\N	\N	f	\N
112	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7937852144241333,"bbox":[423,175,503,249],"first_seen_time":"2026-02-05T23:43:01.822567","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.582140326499939,"bbox":[191,10,218,28],"first_seen_time":"2026-02-05T23:43:01.822567","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4732027053833008,"bbox":[376,37,395,53],"first_seen_time":"2026-02-05T23:43:01.822567","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38927239179611206,"bbox":[284,44,305,65],"first_seen_time":"2026-02-05T23:43:01.822567","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3599652945995331,"bbox":[101,16,127,35],"first_seen_time":"2026-02-05T23:43:01.822567","duration":0.0}],"frame_number":7710,"task_type":"realtime"}	2026-02-05 23:43:01+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234301_frame7710_track0_car.jpg	\N	realtime	\N	\N	f	\N
114	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8039345145225525,"bbox":[131,260,244,358],"first_seen_time":"2026-02-05T23:43:12.467989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7694342136383057,"bbox":[388,87,428,126],"first_seen_time":"2026-02-05T23:43:12.467989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7570556402206421,"bbox":[0,296,100,358],"first_seen_time":"2026-02-05T23:43:12.467989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5261708498001099,"bbox":[11,76,68,119],"first_seen_time":"2026-02-05T23:43:12.467989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48366275429725647,"bbox":[51,54,96,73],"first_seen_time":"2026-02-05T23:43:12.467989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3977672755718231,"bbox":[157,20,186,45],"first_seen_time":"2026-02-05T23:43:12.467989","duration":0.0}],"frame_number":7810,"task_type":"realtime"}	2026-02-05 23:43:12+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234312_frame7810_track0_car.jpg	\N	realtime	\N	\N	f	\N
115	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7622051239013672,"bbox":[42,28,78,51],"first_seen_time":"2026-02-05T23:43:17.736869","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7576590180397034,"bbox":[290,32,313,49],"first_seen_time":"2026-02-05T23:43:17.736869","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38501647114753723,"bbox":[117,49,150,69],"first_seen_time":"2026-02-05T23:43:17.736869","duration":0.0}],"frame_number":7860,"task_type":"realtime"}	2026-02-05 23:43:17+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234317_frame7860_track0_car.jpg	\N	realtime	\N	\N	f	\N
116	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6901664137840271,"bbox":[58,50,99,72],"first_seen_time":"2026-02-05T23:43:23.003475","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6423636674880981,"bbox":[241,55,267,76],"first_seen_time":"2026-02-05T23:43:23.003475","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5133839845657349,"bbox":[371,64,400,91],"first_seen_time":"2026-02-05T23:43:23.003475","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5126392245292664,"bbox":[305,232,383,342],"first_seen_time":"2026-02-05T23:43:23.003475","duration":0.0}],"frame_number":7910,"task_type":"realtime"}	2026-02-05 23:43:23+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234323_frame7910_track0_car.jpg	\N	realtime	\N	\N	f	\N
117	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.6977394223213196,"bbox":[230,124,279,170],"first_seen_time":"2026-02-05T23:43:28.191364","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6047518849372864,"bbox":[30,30,65,55],"first_seen_time":"2026-02-05T23:43:28.191364","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5758272409439087,"bbox":[372,56,399,77],"first_seen_time":"2026-02-05T23:43:28.191364","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5462779402732849,"bbox":[137,306,239,356],"first_seen_time":"2026-02-05T23:43:28.191364","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5417947769165039,"bbox":[285,54,308,72],"first_seen_time":"2026-02-05T23:43:28.191364","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4889439642429352,"bbox":[129,30,153,45],"first_seen_time":"2026-02-05T23:43:28.191364","duration":0.0}],"frame_number":7955,"task_type":"realtime"}	2026-02-05 23:43:28+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234328_frame7955_track0_car.jpg	\N	realtime	\N	\N	f	\N
118	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6893670558929443,"bbox":[318,49,343,72],"first_seen_time":"2026-02-05T23:43:33.522801","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6884177327156067,"bbox":[49,28,83,49],"first_seen_time":"2026-02-05T23:43:33.522801","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6356329321861267,"bbox":[423,183,502,257],"first_seen_time":"2026-02-05T23:43:33.522801","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.539121150970459,"bbox":[287,31,310,57],"first_seen_time":"2026-02-05T23:43:33.522801","duration":0.0}],"frame_number":8005,"task_type":"realtime"}	2026-02-05 23:43:33+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234333_frame8005_track0_car.jpg	\N	realtime	\N	\N	f	\N
119	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7062033414840698,"bbox":[474,295,580,355],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6518359184265137,"bbox":[199,194,268,265],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6149444580078125,"bbox":[325,102,361,135],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6058012843132019,"bbox":[61,68,109,100],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5280022025108337,"bbox":[167,25,191,43],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4996938705444336,"bbox":[31,33,69,55],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4676710367202759,"bbox":[389,112,429,150],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3758001923561096,"bbox":[283,58,307,77],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.30701500177383423,"bbox":[136,13,160,30],"first_seen_time":"2026-02-05T23:43:38.801751","duration":0.0}],"frame_number":8055,"task_type":"realtime"}	2026-02-05 23:43:38+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234338_frame8055_track0_car.jpg	\N	realtime	\N	\N	f	\N
120	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7692668437957764,"bbox":[69,64,113,92],"first_seen_time":"2026-02-05T23:43:44.172440","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6585159301757812,"bbox":[280,56,305,73],"first_seen_time":"2026-02-05T23:43:44.172440","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5878028273582458,"bbox":[379,46,403,66],"first_seen_time":"2026-02-05T23:43:44.172440","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44881173968315125,"bbox":[297,24,315,36],"first_seen_time":"2026-02-05T23:43:44.172440","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3183762729167938,"bbox":[210,1,236,18],"first_seen_time":"2026-02-05T23:43:44.172440","duration":0.0}],"frame_number":8105,"task_type":"realtime"}	2026-02-05 23:43:44+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234344_frame8105_track0_car.jpg	\N	realtime	\N	\N	f	\N
121	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7350287437438965,"bbox":[232,146,287,201],"first_seen_time":"2026-02-05T23:43:49.436502","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7231464385986328,"bbox":[46,27,86,49],"first_seen_time":"2026-02-05T23:43:49.436502","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6350487470626831,"bbox":[314,242,390,342],"first_seen_time":"2026-02-05T23:43:49.436502","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6025801301002502,"bbox":[135,307,245,358],"first_seen_time":"2026-02-05T23:43:49.436502","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42023566365242004,"bbox":[325,58,351,80],"first_seen_time":"2026-02-05T23:43:49.436502","duration":0.0}],"frame_number":8155,"task_type":"realtime"}	2026-02-05 23:43:49+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234349_frame8155_track0_car.jpg	\N	realtime	\N	\N	f	\N
122	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.722131073474884,"bbox":[54,28,86,49],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6571416854858398,"bbox":[423,174,491,236],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6071059703826904,"bbox":[314,233,394,344],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5157866477966309,"bbox":[144,18,169,38],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3869527578353882,"bbox":[132,9,157,23],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33468541502952576,"bbox":[132,10,168,32],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3223765790462494,"bbox":[291,27,308,43],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31176993250846863,"bbox":[389,28,407,43],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2661484181880951,"bbox":[371,12,389,30],"first_seen_time":"2026-02-05T23:43:54.773351","duration":0.0}],"frame_number":8205,"task_type":"realtime"}	2026-02-05 23:43:54+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234354_frame8205_track0_car.jpg	\N	realtime	\N	\N	f	\N
123	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7471505403518677,"bbox":[413,149,472,206],"first_seen_time":"2026-02-05T23:44:00.105361","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7061544060707092,"bbox":[324,113,360,150],"first_seen_time":"2026-02-05T23:44:00.105361","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7005025744438171,"bbox":[275,69,305,98],"first_seen_time":"2026-02-05T23:44:00.105361","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5403814911842346,"bbox":[129,139,206,199],"first_seen_time":"2026-02-05T23:44:00.105361","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.4608428478240967,"bbox":[129,138,207,198],"first_seen_time":"2026-02-05T23:44:00.105361","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32948949933052063,"bbox":[323,38,345,54],"first_seen_time":"2026-02-05T23:44:00.105361","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27732330560684204,"bbox":[125,28,152,49],"first_seen_time":"2026-02-05T23:44:00.105361","duration":0.0}],"frame_number":8255,"task_type":"realtime"}	2026-02-05 23:44:00+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234400_frame8255_track0_car.jpg	\N	realtime	\N	\N	f	\N
124	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6919608116149902,"bbox":[387,53,411,74],"first_seen_time":"2026-02-05T23:44:05.522318","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6771553158760071,"bbox":[235,56,265,83],"first_seen_time":"2026-02-05T23:44:05.522318","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5342171788215637,"bbox":[323,85,362,117],"first_seen_time":"2026-02-05T23:44:05.522318","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.35511767864227295,"bbox":[127,40,161,66],"first_seen_time":"2026-02-05T23:44:05.522318","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34230437874794006,"bbox":[276,16,292,29],"first_seen_time":"2026-02-05T23:44:05.522318","duration":0.0}],"frame_number":8305,"task_type":"realtime"}	2026-02-05 23:44:05+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234405_frame8305_track0_car.jpg	\N	realtime	\N	\N	f	\N
125	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.2699158489704132,"bbox":[366,41,386,59],"first_seen_time":"2026-02-05T23:44:10.830845","duration":0.0}],"frame_number":8355,"task_type":"realtime"}	2026-02-05 23:44:10+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234410_frame8355_track0_car.jpg	\N	realtime	\N	\N	f	\N
126	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6516835689544678,"bbox":[282,58,310,84],"first_seen_time":"2026-02-05T23:44:16.101561","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6145492196083069,"bbox":[248,129,294,177],"first_seen_time":"2026-02-05T23:44:16.101561","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4356754720211029,"bbox":[124,30,150,47],"first_seen_time":"2026-02-05T23:44:16.101561","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42153114080429077,"bbox":[402,69,430,92],"first_seen_time":"2026-02-05T23:44:16.101561","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.320195734500885,"bbox":[249,129,295,176],"first_seen_time":"2026-02-05T23:44:16.101561","duration":0.0}],"frame_number":8405,"task_type":"realtime"}	2026-02-05 23:44:16+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234416_frame8405_track0_car.jpg	\N	realtime	\N	\N	f	\N
127	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7533259987831116,"bbox":[478,282,619,353],"first_seen_time":"2026-02-05T23:44:21.565791","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7261199951171875,"bbox":[305,190,363,264],"first_seen_time":"2026-02-05T23:44:21.565791","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5759721398353577,"bbox":[322,57,348,81],"first_seen_time":"2026-02-05T23:44:21.565791","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5008940696716309,"bbox":[391,62,419,87],"first_seen_time":"2026-02-05T23:44:21.565791","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4796436131000519,"bbox":[285,43,305,62],"first_seen_time":"2026-02-05T23:44:21.565791","duration":0.0}],"frame_number":8455,"task_type":"realtime"}	2026-02-05 23:44:21+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234421_frame8455_track0_car.jpg	\N	realtime	\N	\N	f	\N
128	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.5410680770874023,"bbox":[141,4,166,21],"first_seen_time":"2026-02-05T23:44:27.060445","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44358181953430176,"bbox":[114,45,152,71],"first_seen_time":"2026-02-05T23:44:27.060445","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3570607304573059,"bbox":[323,23,342,42],"first_seen_time":"2026-02-05T23:44:27.060445","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31735724210739136,"bbox":[371,43,398,72],"first_seen_time":"2026-02-05T23:44:27.060445","duration":0.0}],"frame_number":8505,"task_type":"realtime"}	2026-02-05 23:44:27+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234427_frame8505_track0_car.jpg	\N	realtime	\N	\N	f	\N
129	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.8070075511932373,"bbox":[463,117,524,163],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7054690718650818,"bbox":[54,40,88,60],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6112249493598938,"bbox":[376,75,409,109],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5560612678527832,"bbox":[103,30,137,56],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5146904587745667,"bbox":[314,141,358,186],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43076103925704956,"bbox":[131,8,150,23],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4244401454925537,"bbox":[158,35,179,51],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.403473436832428,"bbox":[0,39,26,66],"first_seen_time":"2026-02-05T23:44:32.459043","duration":0.0}],"frame_number":8555,"task_type":"realtime"}	2026-02-05 23:44:32+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234432_frame8555_track0_car.jpg	\N	realtime	\N	\N	f	\N
130	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7220993041992188,"bbox":[359,28,381,47],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7123961448669434,"bbox":[41,29,74,52],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7065901756286621,"bbox":[552,223,639,305],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6634807586669922,"bbox":[391,108,432,148],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6244916915893555,"bbox":[113,11,150,36],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5604025721549988,"bbox":[323,41,344,58],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5352811217308044,"bbox":[406,46,430,68],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32969537377357483,"bbox":[14,79,75,118],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28292176127433777,"bbox":[159,2,195,17],"first_seen_time":"2026-02-05T23:44:37.511547","duration":0.0}],"frame_number":8585,"task_type":"realtime"}	2026-02-05 23:44:37+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234437_frame8585_track0_car.jpg	\N	realtime	\N	\N	f	\N
131	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7872720956802368,"bbox":[305,251,380,353],"first_seen_time":"2026-02-05T23:44:43.001770","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6779564619064331,"bbox":[265,91,296,121],"first_seen_time":"2026-02-05T23:44:43.001770","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6045461893081665,"bbox":[54,26,103,52],"first_seen_time":"2026-02-05T23:44:43.001770","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5221310257911682,"bbox":[408,55,434,76],"first_seen_time":"2026-02-05T23:44:43.001770","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3545452356338501,"bbox":[358,24,377,44],"first_seen_time":"2026-02-05T23:44:43.001770","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.267848938703537,"bbox":[325,7,342,18],"first_seen_time":"2026-02-05T23:44:43.001770","duration":0.0}],"frame_number":8630,"task_type":"realtime"}	2026-02-05 23:44:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234443_frame8630_track0_car.jpg	\N	realtime	\N	\N	f	\N
132	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.857252836227417,"bbox":[484,145,550,191],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6913644671440125,"bbox":[377,74,410,105],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6766101121902466,"bbox":[0,42,27,69],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6276666522026062,"bbox":[85,17,123,49],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5527110695838928,"bbox":[396,35,417,55],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4708002507686615,"bbox":[323,32,342,45],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3030414879322052,"bbox":[165,5,188,21],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2748471796512604,"bbox":[147,9,164,21],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2551295757293701,"bbox":[356,19,375,36],"first_seen_time":"2026-02-05T23:44:48.406129","duration":0.0}],"frame_number":8680,"task_type":"realtime"}	2026-02-05 23:44:48+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234448_frame8680_track0_car.jpg	\N	realtime	\N	\N	f	\N
133	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6892435550689697,"bbox":[324,130,370,177],"first_seen_time":"2026-02-05T23:44:53.493328","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6411165595054626,"bbox":[0,41,46,82],"first_seen_time":"2026-02-05T23:44:53.493328","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5487416982650757,"bbox":[283,52,306,74],"first_seen_time":"2026-02-05T23:44:53.493328","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33106669783592224,"bbox":[393,39,416,54],"first_seen_time":"2026-02-05T23:44:53.493328","duration":0.0}],"frame_number":8725,"task_type":"realtime"}	2026-02-05 23:44:53+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234453_frame8725_track0_car.jpg	\N	realtime	\N	\N	f	\N
135	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":6,"truck":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.7255244255065918,"bbox":[148,29,175,50],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4841728210449219,"bbox":[358,26,379,44],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4596523642539978,"bbox":[322,80,358,117],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4010148346424103,"bbox":[387,98,427,134],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35326388478279114,"bbox":[98,32,125,46],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2868484556674957,"bbox":[387,97,427,134],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2678925096988678,"bbox":[322,80,359,117],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2664601802825928,"bbox":[115,14,138,29],"first_seen_time":"2026-02-05T23:45:03.922028","duration":0.0}],"frame_number":8800,"task_type":"realtime"}	2026-02-05 23:45:03+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234504_frame8800_track0_car.jpg	\N	realtime	\N	\N	f	\N
136	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.5928703546524048,"bbox":[395,121,444,165],"first_seen_time":"2026-02-05T23:45:09.885638","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31188657879829407,"bbox":[43,40,82,62],"first_seen_time":"2026-02-05T23:45:09.885638","duration":0.0}],"frame_number":8845,"task_type":"realtime"}	2026-02-05 23:45:09+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234510_frame8845_track0_car.jpg	\N	realtime	\N	\N	f	\N
137	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6498603820800781,"bbox":[73,44,109,67],"first_seen_time":"2026-02-05T23:45:15.325610","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5661213994026184,"bbox":[363,35,384,51],"first_seen_time":"2026-02-05T23:45:15.325610","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29746493697166443,"bbox":[0,42,37,60],"first_seen_time":"2026-02-05T23:45:15.325610","duration":0.0}],"frame_number":8885,"task_type":"realtime"}	2026-02-05 23:45:15+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234515_frame8885_track0_car.jpg	\N	realtime	\N	\N	f	\N
138	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.6307258009910583,"bbox":[389,76,420,102],"first_seen_time":"2026-02-05T23:45:20.379522","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6235920190811157,"bbox":[241,120,284,159],"first_seen_time":"2026-02-05T23:45:20.379522","duration":0.0}],"frame_number":8925,"task_type":"realtime"}	2026-02-05 23:45:20+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234520_frame8925_track0_car.jpg	\N	realtime	\N	\N	f	\N
139	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7757078409194946,"bbox":[193,178,269,253],"first_seen_time":"2026-02-05T23:45:25.545697","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7673662304878235,"bbox":[382,64,415,103],"first_seen_time":"2026-02-05T23:45:25.545697","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5342884063720703,"bbox":[139,27,171,55],"first_seen_time":"2026-02-05T23:45:25.545697","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4756583571434021,"bbox":[0,39,27,70],"first_seen_time":"2026-02-05T23:45:25.545697","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38915470242500305,"bbox":[369,17,385,31],"first_seen_time":"2026-02-05T23:45:25.545697","duration":0.0}],"frame_number":8970,"task_type":"realtime"}	2026-02-05 23:45:25+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234525_frame8970_track0_car.jpg	\N	realtime	\N	\N	f	\N
140	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6832675933837891,"bbox":[386,63,413,89],"first_seen_time":"2026-02-05T23:45:31.011984","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6540255546569824,"bbox":[251,95,292,127],"first_seen_time":"2026-02-05T23:45:31.011984","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3319806158542633,"bbox":[216,1,239,15],"first_seen_time":"2026-02-05T23:45:31.011984","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2615859806537628,"bbox":[149,6,170,19],"first_seen_time":"2026-02-05T23:45:31.011984","duration":0.0}],"frame_number":9015,"task_type":"realtime"}	2026-02-05 23:45:31+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234531_frame9015_track0_car.jpg	\N	realtime	\N	\N	f	\N
141	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7769333124160767,"bbox":[373,51,401,77],"first_seen_time":"2026-02-05T23:45:36.433747","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6624026894569397,"bbox":[244,110,288,154],"first_seen_time":"2026-02-05T23:45:36.433747","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5479068160057068,"bbox":[146,5,168,19],"first_seen_time":"2026-02-05T23:45:36.433747","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4500558078289032,"bbox":[200,4,225,23],"first_seen_time":"2026-02-05T23:45:36.433747","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4177107810974121,"bbox":[92,38,136,78],"first_seen_time":"2026-02-05T23:45:36.433747","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.369286447763443,"bbox":[366,13,385,28],"first_seen_time":"2026-02-05T23:45:36.433747","duration":0.0}],"frame_number":9065,"task_type":"realtime"}	2026-02-05 23:45:36+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234536_frame9065_track0_car.jpg	\N	realtime	\N	\N	f	\N
142	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7733243703842163,"bbox":[0,275,114,357],"first_seen_time":"2026-02-05T23:45:41.881102","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7503507733345032,"bbox":[1,84,60,128],"first_seen_time":"2026-02-05T23:45:41.881102","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7310304641723633,"bbox":[448,282,559,352],"first_seen_time":"2026-02-05T23:45:41.881102","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5326010584831238,"bbox":[49,47,92,76],"first_seen_time":"2026-02-05T23:45:41.881102","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34464696049690247,"bbox":[165,2,190,19],"first_seen_time":"2026-02-05T23:45:41.881102","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2750623822212219,"bbox":[179,8,202,23],"first_seen_time":"2026-02-05T23:45:41.881102","duration":0.0}],"frame_number":9115,"task_type":"realtime"}	2026-02-05 23:45:41+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234541_frame9115_track0_car.jpg	\N	realtime	\N	\N	f	\N
143	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7309796214103699,"bbox":[411,157,468,214],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6320124864578247,"bbox":[233,148,287,199],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47298967838287354,"bbox":[319,108,357,146],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4439730644226074,"bbox":[265,31,286,47],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42463916540145874,"bbox":[362,39,383,58],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4132084250450134,"bbox":[307,237,399,304],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3760492205619812,"bbox":[33,42,56,59],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28860002756118774,"bbox":[131,10,153,25],"first_seen_time":"2026-02-05T23:45:47.292145","duration":0.0}],"frame_number":9165,"task_type":"realtime"}	2026-02-05 23:45:47+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234547_frame9165_track0_car.jpg	\N	realtime	\N	\N	f	\N
144	car	江北初中监控安防任务	\N	{"total_count":12,"object_counts":{"car":12},"detections":[{"track_id":0,"class_name":"car","confidence":0.7592103481292725,"bbox":[274,54,301,81],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7195772528648376,"bbox":[72,184,173,267],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7102920413017273,"bbox":[251,104,290,142],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6583351492881775,"bbox":[281,169,341,237],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5431171655654907,"bbox":[110,14,137,31],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5182849764823914,"bbox":[12,66,60,91],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.393403023481369,"bbox":[361,32,379,45],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3857594132423401,"bbox":[325,25,349,52],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34851497411727905,"bbox":[77,35,108,52],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33406180143356323,"bbox":[296,29,316,42],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2937076687812805,"bbox":[12,75,45,94],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25979483127593994,"bbox":[137,8,158,20],"first_seen_time":"2026-02-05T23:45:52.737647","duration":0.0}],"frame_number":9215,"task_type":"realtime"}	2026-02-05 23:45:52+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234552_frame9215_track0_car.jpg	\N	realtime	\N	\N	f	\N
145	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.885228157043457,"bbox":[127,259,234,355],"first_seen_time":"2026-02-05T23:45:58.226339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4731691777706146,"bbox":[324,31,343,49],"first_seen_time":"2026-02-05T23:45:58.226339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44382238388061523,"bbox":[261,24,287,49],"first_seen_time":"2026-02-05T23:45:58.226339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37577134370803833,"bbox":[384,87,418,113],"first_seen_time":"2026-02-05T23:45:58.226339","duration":0.0}],"frame_number":9265,"task_type":"realtime"}	2026-02-05 23:45:58+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234558_frame9265_track0_car.jpg	\N	realtime	\N	\N	f	\N
146	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7133415341377258,"bbox":[309,85,342,116],"first_seen_time":"2026-02-05T23:46:03.628850","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6872535347938538,"bbox":[275,62,302,84],"first_seen_time":"2026-02-05T23:46:03.628850","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6793925166130066,"bbox":[52,25,86,49],"first_seen_time":"2026-02-05T23:46:03.628850","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.672209620475769,"bbox":[287,33,307,52],"first_seen_time":"2026-02-05T23:46:03.628850","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5494111180305481,"bbox":[101,15,126,32],"first_seen_time":"2026-02-05T23:46:03.628850","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49012380838394165,"bbox":[199,87,241,123],"first_seen_time":"2026-02-05T23:46:03.628850","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2933989465236664,"bbox":[0,55,28,84],"first_seen_time":"2026-02-05T23:46:03.628850","duration":0.0}],"frame_number":9315,"task_type":"realtime"}	2026-02-05 23:46:03+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234603_frame9315_track0_car.jpg	\N	realtime	\N	\N	f	\N
147	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.693752646446228,"bbox":[418,202,498,277],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.634247362613678,"bbox":[317,190,378,266],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45351216197013855,"bbox":[262,97,295,129],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4418124556541443,"bbox":[165,3,186,20],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42305898666381836,"bbox":[376,46,402,72],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42293399572372437,"bbox":[122,24,150,47],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4046507775783539,"bbox":[93,19,121,36],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31905633211135864,"bbox":[199,11,217,28],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25205713510513306,"bbox":[325,10,344,26],"first_seen_time":"2026-02-05T23:46:09.070083","duration":0.0}],"frame_number":9365,"task_type":"realtime"}	2026-02-05 23:46:09+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234609_frame9365_track0_car.jpg	\N	realtime	\N	\N	f	\N
148	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7309205532073975,"bbox":[389,68,418,95],"first_seen_time":"2026-02-05T23:46:14.338526","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6025806069374084,"bbox":[256,94,294,123],"first_seen_time":"2026-02-05T23:46:14.338526","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45918911695480347,"bbox":[329,30,349,46],"first_seen_time":"2026-02-05T23:46:14.338526","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4072320759296417,"bbox":[143,37,171,55],"first_seen_time":"2026-02-05T23:46:14.338526","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36751165986061096,"bbox":[360,34,382,53],"first_seen_time":"2026-02-05T23:46:14.338526","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3410792648792267,"bbox":[289,39,309,55],"first_seen_time":"2026-02-05T23:46:14.338526","duration":0.0}],"frame_number":9415,"task_type":"realtime"}	2026-02-05 23:46:14+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234614_frame9415_track0_car.jpg	\N	realtime	\N	\N	f	\N
149	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7604379057884216,"bbox":[82,39,117,64],"first_seen_time":"2026-02-05T23:46:19.355067","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6976773142814636,"bbox":[390,94,428,124],"first_seen_time":"2026-02-05T23:46:19.355067","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6547604203224182,"bbox":[322,113,361,153],"first_seen_time":"2026-02-05T23:46:19.355067","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5842169523239136,"bbox":[98,15,128,32],"first_seen_time":"2026-02-05T23:46:19.355067","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48394232988357544,"bbox":[0,46,24,68],"first_seen_time":"2026-02-05T23:46:19.355067","duration":0.0}],"frame_number":9460,"task_type":"realtime"}	2026-02-05 23:46:19+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234619_frame9460_track0_car.jpg	\N	realtime	\N	\N	f	\N
150	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.8081353902816772,"bbox":[447,194,528,274],"first_seen_time":"2026-02-05T23:46:24.771302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6670907139778137,"bbox":[290,39,313,57],"first_seen_time":"2026-02-05T23:46:24.771302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6287781000137329,"bbox":[384,78,419,107],"first_seen_time":"2026-02-05T23:46:24.771302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6202932596206665,"bbox":[223,64,258,93],"first_seen_time":"2026-02-05T23:46:24.771302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5994784832000732,"bbox":[37,53,82,85],"first_seen_time":"2026-02-05T23:46:24.771302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5862306952476501,"bbox":[326,66,351,90],"first_seen_time":"2026-02-05T23:46:24.771302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2703165113925934,"bbox":[365,22,380,33],"first_seen_time":"2026-02-05T23:46:24.771302","duration":0.0}],"frame_number":9510,"task_type":"realtime"}	2026-02-05 23:46:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234624_frame9510_track0_car.jpg	\N	realtime	\N	\N	f	\N
151	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7437518835067749,"bbox":[404,143,460,191],"first_seen_time":"2026-02-05T23:46:30.195206","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6693675518035889,"bbox":[264,30,284,47],"first_seen_time":"2026-02-05T23:46:30.195206","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5589359998703003,"bbox":[133,276,239,358],"first_seen_time":"2026-02-05T23:46:30.195206","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48826366662979126,"bbox":[319,126,361,166],"first_seen_time":"2026-02-05T23:46:30.195206","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4278341829776764,"bbox":[377,31,397,46],"first_seen_time":"2026-02-05T23:46:30.195206","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38244569301605225,"bbox":[325,50,350,72],"first_seen_time":"2026-02-05T23:46:30.195206","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.33040937781333923,"bbox":[3,79,76,125],"first_seen_time":"2026-02-05T23:46:30.195206","duration":0.0}],"frame_number":9560,"task_type":"realtime"}	2026-02-05 23:46:30+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234630_frame9560_track0_car.jpg	\N	realtime	\N	\N	f	\N
152	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.8273643851280212,"bbox":[478,217,560,287],"first_seen_time":"2026-02-05T23:46:36.183488","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6485222578048706,"bbox":[185,222,271,313],"first_seen_time":"2026-02-05T23:46:36.183488","duration":0.0}],"frame_number":9615,"task_type":"realtime"}	2026-02-05 23:46:36+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234636_frame9615_track0_car.jpg	\N	realtime	\N	\N	f	\N
153	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.8020157814025879,"bbox":[433,171,499,232],"first_seen_time":"2026-02-05T23:46:41.595773","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7180731892585754,"bbox":[307,198,373,279],"first_seen_time":"2026-02-05T23:46:41.595773","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6640622019767761,"bbox":[235,125,283,173],"first_seen_time":"2026-02-05T23:46:41.595773","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5247693061828613,"bbox":[287,58,311,78],"first_seen_time":"2026-02-05T23:46:41.595773","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5226150155067444,"bbox":[297,26,319,44],"first_seen_time":"2026-02-05T23:46:41.595773","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40842142701148987,"bbox":[20,61,66,90],"first_seen_time":"2026-02-05T23:46:41.595773","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36640217900276184,"bbox":[382,36,404,54],"first_seen_time":"2026-02-05T23:46:41.595773","duration":0.0}],"frame_number":9665,"task_type":"realtime"}	2026-02-05 23:46:41+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234641_frame9665_track0_car.jpg	\N	realtime	\N	\N	f	\N
154	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7999675273895264,"bbox":[161,279,262,357],"first_seen_time":"2026-02-05T23:46:46.878998","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6445019841194153,"bbox":[264,96,300,134],"first_seen_time":"2026-02-05T23:46:46.878998","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5137206315994263,"bbox":[423,105,462,141],"first_seen_time":"2026-02-05T23:46:46.878998","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4453005790710449,"bbox":[158,19,180,32],"first_seen_time":"2026-02-05T23:46:46.878998","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4443436861038208,"bbox":[31,81,81,117],"first_seen_time":"2026-02-05T23:46:46.878998","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3051009476184845,"bbox":[71,32,106,53],"first_seen_time":"2026-02-05T23:46:46.878998","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.25669676065444946,"bbox":[26,81,81,118],"first_seen_time":"2026-02-05T23:46:46.878998","duration":0.0}],"frame_number":9715,"task_type":"realtime"}	2026-02-05 23:46:46+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234647_frame9715_track0_car.jpg	\N	realtime	\N	\N	f	\N
155	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.570274293422699,"bbox":[402,92,440,127],"first_seen_time":"2026-02-05T23:46:52.377589","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5375309586524963,"bbox":[271,64,300,92],"first_seen_time":"2026-02-05T23:46:52.377589","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48862868547439575,"bbox":[319,92,354,129],"first_seen_time":"2026-02-05T23:46:52.377589","duration":0.0}],"frame_number":9765,"task_type":"realtime"}	2026-02-05 23:46:52+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234652_frame9765_track0_car.jpg	\N	realtime	\N	\N	f	\N
156	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7096502780914307,"bbox":[379,65,416,97],"first_seen_time":"2026-02-05T23:46:57.816539","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46156516671180725,"bbox":[320,41,343,60],"first_seen_time":"2026-02-05T23:46:57.816539","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2820936143398285,"bbox":[164,25,187,45],"first_seen_time":"2026-02-05T23:46:57.816539","duration":0.0}],"frame_number":9815,"task_type":"realtime"}	2026-02-05 23:46:57+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234657_frame9815_track0_car.jpg	\N	realtime	\N	\N	f	\N
157	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7784610986709595,"bbox":[538,202,639,283],"first_seen_time":"2026-02-05T23:47:03.160261","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6575594544410706,"bbox":[108,25,134,40],"first_seen_time":"2026-02-05T23:47:03.160261","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5668916702270508,"bbox":[392,122,444,172],"first_seen_time":"2026-02-05T23:47:03.160261","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5424253940582275,"bbox":[36,31,73,50],"first_seen_time":"2026-02-05T23:47:03.160261","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42441830039024353,"bbox":[148,17,173,37],"first_seen_time":"2026-02-05T23:47:03.160261","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35011211037635803,"bbox":[300,314,384,357],"first_seen_time":"2026-02-05T23:47:03.160261","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34261491894721985,"bbox":[62,23,86,45],"first_seen_time":"2026-02-05T23:47:03.160261","duration":0.0}],"frame_number":9865,"task_type":"realtime"}	2026-02-05 23:47:03+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234703_frame9865_track0_car.jpg	\N	realtime	\N	\N	f	\N
158	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.8437207937240601,"bbox":[499,164,576,217],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7532347440719604,"bbox":[382,83,415,116],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6352897882461548,"bbox":[94,14,132,45],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6213347315788269,"bbox":[323,33,342,48],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5955801010131836,"bbox":[399,38,421,57],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4363492429256439,"bbox":[358,22,377,39],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4326440989971161,"bbox":[3,43,35,64],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.428047776222229,"bbox":[152,2,196,19],"first_seen_time":"2026-02-05T23:47:08.528480","duration":0.0}],"frame_number":9915,"task_type":"realtime"}	2026-02-05 23:47:08+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234708_frame9915_track0_car.jpg	\N	realtime	\N	\N	f	\N
159	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6411619782447815,"bbox":[325,120,367,160],"first_seen_time":"2026-02-05T23:47:13.800893","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3534983694553375,"bbox":[287,49,307,68],"first_seen_time":"2026-02-05T23:47:13.800893","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27736055850982666,"bbox":[0,42,35,86],"first_seen_time":"2026-02-05T23:47:13.800893","duration":0.0}],"frame_number":9965,"task_type":"realtime"}	2026-02-05 23:47:13+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234713_frame9965_track0_car.jpg	\N	realtime	\N	\N	f	\N
160	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6364232897758484,"bbox":[462,288,575,352],"first_seen_time":"2026-02-05T23:47:19.192297","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3553168773651123,"bbox":[305,248,401,322],"first_seen_time":"2026-02-05T23:47:19.192297","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31493934988975525,"bbox":[368,50,398,77],"first_seen_time":"2026-02-05T23:47:19.192297","duration":0.0}],"frame_number":10015,"task_type":"realtime"}	2026-02-05 23:47:19+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234719_frame10015_track0_car.jpg	\N	realtime	\N	\N	f	\N
161	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.5474212765693665,"bbox":[27,39,56,59],"first_seen_time":"2026-02-05T23:47:24.480586","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4813978672027588,"bbox":[457,273,576,353],"first_seen_time":"2026-02-05T23:47:24.480586","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3549787700176239,"bbox":[0,96,26,134],"first_seen_time":"2026-02-05T23:47:24.480586","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34339848160743713,"bbox":[118,22,141,37],"first_seen_time":"2026-02-05T23:47:24.480586","duration":0.0}],"frame_number":10065,"task_type":"realtime"}	2026-02-05 23:47:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234724_frame10065_track0_car.jpg	\N	realtime	\N	\N	f	\N
162	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.477491557598114,"bbox":[367,45,389,62],"first_seen_time":"2026-02-05T23:47:29.915323","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4537125527858734,"bbox":[46,32,79,49],"first_seen_time":"2026-02-05T23:47:29.915323","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4051136076450348,"bbox":[110,31,139,52],"first_seen_time":"2026-02-05T23:47:29.915323","duration":0.0}],"frame_number":10115,"task_type":"realtime"}	2026-02-05 23:47:29+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234730_frame10115_track0_car.jpg	\N	realtime	\N	\N	f	\N
163	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7214128971099854,"bbox":[399,130,453,177],"first_seen_time":"2026-02-05T23:47:35.315583","duration":0.0}],"frame_number":10165,"task_type":"realtime"}	2026-02-05 23:47:35+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234735_frame10165_track0_car.jpg	\N	realtime	\N	\N	f	\N
164	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.6041973233222961,"bbox":[20,57,69,90],"first_seen_time":"2026-02-05T23:47:40.722204","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40394219756126404,"bbox":[477,313,582,356],"first_seen_time":"2026-02-05T23:47:40.722204","duration":0.0}],"frame_number":10215,"task_type":"realtime"}	2026-02-05 23:47:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234740_frame10215_track0_car.jpg	\N	realtime	\N	\N	f	\N
165	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.8840954303741455,"bbox":[445,228,558,338],"first_seen_time":"2026-02-05T23:47:46.178898","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6444034576416016,"bbox":[377,42,399,62],"first_seen_time":"2026-02-05T23:47:46.178898","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5120146870613098,"bbox":[276,58,304,78],"first_seen_time":"2026-02-05T23:47:46.178898","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47449517250061035,"bbox":[199,4,222,23],"first_seen_time":"2026-02-05T23:47:46.178898","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37075474858283997,"bbox":[118,12,141,31],"first_seen_time":"2026-02-05T23:47:46.178898","duration":0.0}],"frame_number":10265,"task_type":"realtime"}	2026-02-05 23:47:46+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234746_frame10265_track0_car.jpg	\N	realtime	\N	\N	f	\N
166	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7089602947235107,"bbox":[364,33,387,54],"first_seen_time":"2026-02-05T23:47:51.664237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6168733835220337,"bbox":[273,65,302,92],"first_seen_time":"2026-02-05T23:47:51.664237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5682770609855652,"bbox":[181,15,205,35],"first_seen_time":"2026-02-05T23:47:51.664237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47606176137924194,"bbox":[118,12,143,28],"first_seen_time":"2026-02-05T23:47:51.664237","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.28906428813934326,"bbox":[0,63,71,127],"first_seen_time":"2026-02-05T23:47:51.664237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26208993792533875,"bbox":[0,81,61,126],"first_seen_time":"2026-02-05T23:47:51.664237","duration":0.0}],"frame_number":10315,"task_type":"realtime"}	2026-02-05 23:47:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234751_frame10315_track0_car.jpg	\N	realtime	\N	\N	f	\N
167	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6989395022392273,"bbox":[149,19,174,36],"first_seen_time":"2026-02-05T23:47:57.098839","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6763153672218323,"bbox":[159,126,218,174],"first_seen_time":"2026-02-05T23:47:57.098839","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6580845713615417,"bbox":[397,142,451,194],"first_seen_time":"2026-02-05T23:47:57.098839","duration":0.0}],"frame_number":10365,"task_type":"realtime"}	2026-02-05 23:47:57+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234757_frame10365_track0_car.jpg	\N	realtime	\N	\N	f	\N
168	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":8,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7700707912445068,"bbox":[111,298,220,357],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7133715152740479,"bbox":[386,94,426,126],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5988633036613464,"bbox":[265,88,299,120],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45175471901893616,"bbox":[322,65,350,91],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4359162747859955,"bbox":[95,16,123,35],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.4167669713497162,"bbox":[319,119,369,179],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3747578561306,"bbox":[319,119,369,179],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.283961683511734,"bbox":[356,26,375,42],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2595573961734772,"bbox":[173,4,199,28],"first_seen_time":"2026-02-05T23:48:02.562902","duration":0.0}],"frame_number":10415,"task_type":"realtime"}	2026-02-05 23:48:02+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234802_frame10415_track0_car.jpg	\N	realtime	\N	\N	f	\N
169	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.770258903503418,"bbox":[66,24,98,44],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5978312492370605,"bbox":[305,96,342,132],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5056390762329102,"bbox":[2,44,48,77],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5001542568206787,"bbox":[284,38,306,56],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4828101396560669,"bbox":[107,14,132,31],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4411577880382538,"bbox":[186,102,232,140],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.39455124735832214,"bbox":[31,49,47,74],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25161123275756836,"bbox":[272,66,300,91],"first_seen_time":"2026-02-05T23:48:07.968146","duration":0.0}],"frame_number":10465,"task_type":"realtime"}	2026-02-05 23:48:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234808_frame10465_track0_car.jpg	\N	realtime	\N	\N	f	\N
170	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.6541645526885986,"bbox":[230,124,278,170],"first_seen_time":"2026-02-05T23:48:13.297537","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.642342209815979,"bbox":[371,56,399,77],"first_seen_time":"2026-02-05T23:48:13.297537","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5918934941291809,"bbox":[28,29,67,55],"first_seen_time":"2026-02-05T23:48:13.297537","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5767796039581299,"bbox":[136,306,240,356],"first_seen_time":"2026-02-05T23:48:13.297537","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49461600184440613,"bbox":[284,54,308,72],"first_seen_time":"2026-02-05T23:48:13.297537","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4351039230823517,"bbox":[128,31,153,45],"first_seen_time":"2026-02-05T23:48:13.297537","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3384084105491638,"bbox":[149,0,184,25],"first_seen_time":"2026-02-05T23:48:13.297537","duration":0.0}],"frame_number":10515,"task_type":"realtime"}	2026-02-05 23:48:13+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234813_frame10515_track0_car.jpg	\N	realtime	\N	\N	f	\N
171	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7465822100639343,"bbox":[48,27,82,48],"first_seen_time":"2026-02-05T23:48:18.809300","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7152398824691772,"bbox":[318,49,344,72],"first_seen_time":"2026-02-05T23:48:18.809300","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7084700465202332,"bbox":[424,183,502,256],"first_seen_time":"2026-02-05T23:48:18.809300","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5833544731140137,"bbox":[287,32,311,56],"first_seen_time":"2026-02-05T23:48:18.809300","duration":0.0}],"frame_number":10565,"task_type":"realtime"}	2026-02-05 23:48:18+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234818_frame10565_track0_car.jpg	\N	realtime	\N	\N	f	\N
172	car	江北初中监控安防任务	\N	{"total_count":11,"object_counts":{"car":10,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6944471597671509,"bbox":[474,296,581,356],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6519200801849365,"bbox":[199,194,269,265],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6516320705413818,"bbox":[167,25,191,43],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6475030779838562,"bbox":[325,101,362,136],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6010103225708008,"bbox":[61,68,109,99],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.586176335811615,"bbox":[31,33,70,55],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45176103711128235,"bbox":[136,12,160,31],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44019946455955505,"bbox":[386,112,429,150],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4272422194480896,"bbox":[283,59,306,77],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.269771933555603,"bbox":[58,51,99,75],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.26720941066741943,"bbox":[388,109,429,148],"first_seen_time":"2026-02-05T23:48:24.301745","duration":0.0}],"frame_number":10615,"task_type":"realtime"}	2026-02-05 23:48:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234824_frame10615_track0_car.jpg	\N	realtime	\N	\N	f	\N
173	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.8072689771652222,"bbox":[69,64,113,92],"first_seen_time":"2026-02-05T23:48:29.641483","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6609092354774475,"bbox":[280,56,305,73],"first_seen_time":"2026-02-05T23:48:29.641483","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4877491891384125,"bbox":[380,46,402,67],"first_seen_time":"2026-02-05T23:48:29.641483","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3527672588825226,"bbox":[296,24,316,36],"first_seen_time":"2026-02-05T23:48:29.641483","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3300025165081024,"bbox":[210,0,236,18],"first_seen_time":"2026-02-05T23:48:29.641483","duration":0.0}],"frame_number":10665,"task_type":"realtime"}	2026-02-05 23:48:29+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234829_frame10665_track0_car.jpg	\N	realtime	\N	\N	f	\N
174	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.8159119486808777,"bbox":[239,131,290,180],"first_seen_time":"2026-02-05T23:48:35.073066","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.760085940361023,"bbox":[316,216,383,296],"first_seen_time":"2026-02-05T23:48:35.073066","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7354633212089539,"bbox":[38,29,78,51],"first_seen_time":"2026-02-05T23:48:35.073066","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49507036805152893,"bbox":[374,51,398,71],"first_seen_time":"2026-02-05T23:48:35.073066","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.329531192779541,"bbox":[322,59,350,80],"first_seen_time":"2026-02-05T23:48:35.073066","duration":0.0}],"frame_number":10715,"task_type":"realtime"}	2026-02-05 23:48:35+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234835_frame10715_track0_car.jpg	\N	realtime	\N	\N	f	\N
175	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.700446367263794,"bbox":[175,108,229,155],"first_seen_time":"2026-02-05T23:48:40.487782","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5885945558547974,"bbox":[316,155,372,215],"first_seen_time":"2026-02-05T23:48:40.487782","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5794879794120789,"bbox":[261,28,284,49],"first_seen_time":"2026-02-05T23:48:40.487782","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5224313735961914,"bbox":[370,42,392,59],"first_seen_time":"2026-02-05T23:48:40.487782","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4842940866947174,"bbox":[400,85,436,118],"first_seen_time":"2026-02-05T23:48:40.487782","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4760622978210449,"bbox":[179,20,204,38],"first_seen_time":"2026-02-05T23:48:40.487782","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4281981289386749,"bbox":[301,22,318,32],"first_seen_time":"2026-02-05T23:48:40.487782","duration":0.0}],"frame_number":10765,"task_type":"realtime"}	2026-02-05 23:48:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234840_frame10765_track0_car.jpg	\N	realtime	\N	\N	f	\N
176	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.5706490874290466,"bbox":[251,95,291,129],"first_seen_time":"2026-02-05T23:48:45.912282","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5028738975524902,"bbox":[377,65,405,92],"first_seen_time":"2026-02-05T23:48:45.912282","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45805060863494873,"bbox":[324,63,348,82],"first_seen_time":"2026-02-05T23:48:45.912282","duration":0.0}],"frame_number":10815,"task_type":"realtime"}	2026-02-05 23:48:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234846_frame10815_track0_car.jpg	\N	realtime	\N	\N	f	\N
213	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.5565887689590454,"bbox":[65,29,95,43],"first_seen_time":"2026-02-05T23:52:07.987273","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5212210416793823,"bbox":[123,28,151,46],"first_seen_time":"2026-02-05T23:52:07.987273","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43845972418785095,"bbox":[370,51,395,70],"first_seen_time":"2026-02-05T23:52:07.987273","duration":0.0}],"frame_number":12670,"task_type":"realtime"}	2026-02-05 23:52:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235208_frame12670_track0_car.jpg	\N	realtime	\N	\N	f	\N
177	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7250427007675171,"bbox":[45,75,96,105],"first_seen_time":"2026-02-05T23:48:51.386076","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6953144073486328,"bbox":[258,104,297,145],"first_seen_time":"2026-02-05T23:48:51.386076","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6489153504371643,"bbox":[424,111,470,151],"first_seen_time":"2026-02-05T23:48:51.386076","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3811635673046112,"bbox":[165,327,249,357],"first_seen_time":"2026-02-05T23:48:51.386076","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2956370413303375,"bbox":[163,18,183,31],"first_seen_time":"2026-02-05T23:48:51.386076","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2529675364494324,"bbox":[82,30,113,49],"first_seen_time":"2026-02-05T23:48:51.386076","duration":0.0}],"frame_number":10865,"task_type":"realtime"}	2026-02-05 23:48:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234851_frame10865_track0_car.jpg	\N	realtime	\N	\N	f	\N
178	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.3149130046367645,"bbox":[161,33,184,49],"first_seen_time":"2026-02-05T23:48:58.403527","duration":0.0}],"frame_number":10930,"task_type":"realtime"}	2026-02-05 23:48:58+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234858_frame10930_track0_car.jpg	\N	realtime	\N	\N	f	\N
179	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7958192825317383,"bbox":[456,227,553,318],"first_seen_time":"2026-02-05T23:49:03.802302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5555962920188904,"bbox":[295,32,317,51],"first_seen_time":"2026-02-05T23:49:03.802302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5503472685813904,"bbox":[59,49,96,74],"first_seen_time":"2026-02-05T23:49:03.802302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5340097546577454,"bbox":[279,71,307,97],"first_seen_time":"2026-02-05T23:49:03.802302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5171701312065125,"bbox":[206,166,272,232],"first_seen_time":"2026-02-05T23:49:03.802302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5012166500091553,"bbox":[296,295,390,356],"first_seen_time":"2026-02-05T23:49:03.802302","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4650386869907379,"bbox":[388,44,409,61],"first_seen_time":"2026-02-05T23:49:03.802302","duration":0.0}],"frame_number":10980,"task_type":"realtime"}	2026-02-05 23:49:03+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234903_frame10980_track0_car.jpg	\N	realtime	\N	\N	f	\N
180	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6716524958610535,"bbox":[409,136,484,204],"first_seen_time":"2026-02-05T23:49:09.260648","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5993216633796692,"bbox":[316,94,349,126],"first_seen_time":"2026-02-05T23:49:09.260648","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44852015376091003,"bbox":[325,34,346,52],"first_seen_time":"2026-02-05T23:49:09.260648","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26163238286972046,"bbox":[382,41,404,57],"first_seen_time":"2026-02-05T23:49:09.260648","duration":0.0}],"frame_number":11030,"task_type":"realtime"}	2026-02-05 23:49:09+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234909_frame11030_track0_car.jpg	\N	realtime	\N	\N	f	\N
181	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.5674214363098145,"bbox":[1,75,63,125],"first_seen_time":"2026-02-05T23:49:14.568557","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5564296841621399,"bbox":[110,10,141,31],"first_seen_time":"2026-02-05T23:49:14.568557","duration":0.0}],"frame_number":11080,"task_type":"realtime"}	2026-02-05 23:49:14+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234914_frame11080_track0_car.jpg	\N	realtime	\N	\N	f	\N
182	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.6714186072349548,"bbox":[425,71,462,103],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6413049697875977,"bbox":[363,46,392,70],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.620093822479248,"bbox":[432,221,522,303],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6094766855239868,"bbox":[320,74,348,97],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5999066233634949,"bbox":[76,68,118,92],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5522803068161011,"bbox":[95,17,120,34],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4142824411392212,"bbox":[145,3,181,24],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3332171142101288,"bbox":[3,56,62,96],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32438817620277405,"bbox":[125,43,155,65],"first_seen_time":"2026-02-05T23:49:20.024439","duration":0.0}],"frame_number":11130,"task_type":"realtime"}	2026-02-05 23:49:20+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234920_frame11130_track0_car.jpg	\N	realtime	\N	\N	f	\N
183	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7159425020217896,"bbox":[250,119,289,157],"first_seen_time":"2026-02-05T23:49:25.545376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6071701645851135,"bbox":[415,65,445,88],"first_seen_time":"2026-02-05T23:49:25.545376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5441346168518066,"bbox":[362,33,382,51],"first_seen_time":"2026-02-05T23:49:25.545376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5243542790412903,"bbox":[95,23,131,42],"first_seen_time":"2026-02-05T23:49:25.545376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3539043068885803,"bbox":[351,6,368,18],"first_seen_time":"2026-02-05T23:49:25.545376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25636300444602966,"bbox":[151,8,169,19],"first_seen_time":"2026-02-05T23:49:25.545376","duration":0.0}],"frame_number":11180,"task_type":"realtime"}	2026-02-05 23:49:25+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234925_frame11180_track0_car.jpg	\N	realtime	\N	\N	f	\N
184	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.5748360753059387,"bbox":[387,101,431,148],"first_seen_time":"2026-02-05T23:49:30.962479","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5596652030944824,"bbox":[54,43,87,61],"first_seen_time":"2026-02-05T23:49:30.962479","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42202258110046387,"bbox":[0,42,27,69],"first_seen_time":"2026-02-05T23:49:30.962479","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33482009172439575,"bbox":[300,18,317,30],"first_seen_time":"2026-02-05T23:49:30.962479","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2921501696109772,"bbox":[327,44,350,61],"first_seen_time":"2026-02-05T23:49:30.962479","duration":0.0}],"frame_number":11230,"task_type":"realtime"}	2026-02-05 23:49:30+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234931_frame11230_track0_car.jpg	\N	realtime	\N	\N	f	\N
185	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.6671671271324158,"bbox":[321,64,356,97],"first_seen_time":"2026-02-05T23:49:36.440949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6200520396232605,"bbox":[130,37,159,58],"first_seen_time":"2026-02-05T23:49:36.440949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4650033414363861,"bbox":[382,83,415,111],"first_seen_time":"2026-02-05T23:49:36.440949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40986770391464233,"bbox":[71,34,105,54],"first_seen_time":"2026-02-05T23:49:36.440949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34118518233299255,"bbox":[102,17,127,34],"first_seen_time":"2026-02-05T23:49:36.440949","duration":0.0}],"frame_number":11280,"task_type":"realtime"}	2026-02-05 23:49:36+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234936_frame11280_track0_car.jpg	\N	realtime	\N	\N	f	\N
186	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6696203351020813,"bbox":[371,64,403,92],"first_seen_time":"2026-02-05T23:49:41.847504","duration":0.0}],"frame_number":11330,"task_type":"realtime"}	2026-02-05 23:49:41+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234941_frame11330_track0_car.jpg	\N	realtime	\N	\N	f	\N
187	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6528334617614746,"bbox":[37,69,89,103],"first_seen_time":"2026-02-05T23:49:47.364691","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6342245936393738,"bbox":[369,52,395,72],"first_seen_time":"2026-02-05T23:49:47.364691","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6026002168655396,"bbox":[50,30,83,49],"first_seen_time":"2026-02-05T23:49:47.364691","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4434008300304413,"bbox":[325,38,350,59],"first_seen_time":"2026-02-05T23:49:47.364691","duration":0.0}],"frame_number":11380,"task_type":"realtime"}	2026-02-05 23:49:47+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234947_frame11380_track0_car.jpg	\N	realtime	\N	\N	f	\N
188	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.37024208903312683,"bbox":[135,24,159,42],"first_seen_time":"2026-02-05T23:49:52.795307","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3191675841808319,"bbox":[371,56,398,75],"first_seen_time":"2026-02-05T23:49:52.795307","duration":0.0}],"frame_number":11430,"task_type":"realtime"}	2026-02-05 23:49:52+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234952_frame11430_track0_car.jpg	\N	realtime	\N	\N	f	\N
189	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.7333319783210754,"bbox":[217,154,274,207],"first_seen_time":"2026-02-05T23:49:58.204834","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5434815883636475,"bbox":[392,87,429,122],"first_seen_time":"2026-02-05T23:49:58.204834","duration":0.0}],"frame_number":11480,"task_type":"realtime"}	2026-02-05 23:49:58+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_234958_frame11480_track0_car.jpg	\N	realtime	\N	\N	f	\N
190	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7783156037330627,"bbox":[193,178,269,253],"first_seen_time":"2026-02-05T23:50:03.671311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7771175503730774,"bbox":[382,64,415,103],"first_seen_time":"2026-02-05T23:50:03.671311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5307248830795288,"bbox":[138,27,171,56],"first_seen_time":"2026-02-05T23:50:03.671311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5049268007278442,"bbox":[0,39,27,69],"first_seen_time":"2026-02-05T23:50:03.671311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4145907163619995,"bbox":[369,17,386,31],"first_seen_time":"2026-02-05T23:50:03.671311","duration":0.0}],"frame_number":11530,"task_type":"realtime"}	2026-02-05 23:50:03+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235003_frame11530_track0_car.jpg	\N	realtime	\N	\N	f	\N
191	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6719695925712585,"bbox":[293,25,315,42],"first_seen_time":"2026-02-05T23:50:09.070128","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6574084162712097,"bbox":[6,34,50,59],"first_seen_time":"2026-02-05T23:50:09.070128","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.623327374458313,"bbox":[85,56,123,86],"first_seen_time":"2026-02-05T23:50:09.070128","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.39516448974609375,"bbox":[101,31,135,55],"first_seen_time":"2026-02-05T23:50:09.070128","duration":0.0}],"frame_number":11580,"task_type":"realtime"}	2026-02-05 23:50:09+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235009_frame11580_track0_car.jpg	\N	realtime	\N	\N	f	\N
198	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6666902899742126,"bbox":[30,35,65,56],"first_seen_time":"2026-02-05T23:50:46.884615","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6233078837394714,"bbox":[123,17,153,46],"first_seen_time":"2026-02-05T23:50:46.884615","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.605766236782074,"bbox":[406,135,459,180],"first_seen_time":"2026-02-05T23:50:46.884615","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.38088375329971313,"bbox":[317,171,376,240],"first_seen_time":"2026-02-05T23:50:46.884615","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3769153356552124,"bbox":[317,172,375,240],"first_seen_time":"2026-02-05T23:50:46.884615","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3121092915534973,"bbox":[121,11,151,27],"first_seen_time":"2026-02-05T23:50:46.884615","duration":0.0}],"frame_number":11925,"task_type":"realtime"}	2026-02-05 23:50:46+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235047_frame11925_track0_car.jpg	\N	realtime	\N	\N	f	\N
192	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.823514461517334,"bbox":[168,247,263,355],"first_seen_time":"2026-02-05T23:50:14.349339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7373371720314026,"bbox":[311,169,368,233],"first_seen_time":"2026-02-05T23:50:14.349339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.691365659236908,"bbox":[451,263,560,355],"first_seen_time":"2026-02-05T23:50:14.349339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5927603244781494,"bbox":[13,64,65,90],"first_seen_time":"2026-02-05T23:50:14.349339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49253302812576294,"bbox":[252,44,277,64],"first_seen_time":"2026-02-05T23:50:14.349339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4626655578613281,"bbox":[367,55,396,77],"first_seen_time":"2026-02-05T23:50:14.349339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3435606360435486,"bbox":[66,31,99,44],"first_seen_time":"2026-02-05T23:50:14.349339","duration":0.0}],"frame_number":11630,"task_type":"realtime"}	2026-02-05 23:50:14+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235014_frame11630_track0_car.jpg	\N	realtime	\N	\N	f	\N
193	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.6934622526168823,"bbox":[248,96,286,133],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6875796318054199,"bbox":[184,209,265,295],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6171102523803711,"bbox":[103,36,135,56],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5384580492973328,"bbox":[289,45,311,61],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48610472679138184,"bbox":[369,44,391,65],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.452440470457077,"bbox":[0,41,26,67],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31861621141433716,"bbox":[148,1,179,17],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31840112805366516,"bbox":[324,49,352,80],"first_seen_time":"2026-02-05T23:50:19.354575","duration":0.0}],"frame_number":11675,"task_type":"realtime"}	2026-02-05 23:50:19+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235019_frame11675_track0_car.jpg	\N	realtime	\N	\N	f	\N
194	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.6761372685432434,"bbox":[233,150,286,200],"first_seen_time":"2026-02-05T23:50:24.855640","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6094174385070801,"bbox":[410,156,469,215],"first_seen_time":"2026-02-05T23:50:24.855640","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48457658290863037,"bbox":[319,109,357,146],"first_seen_time":"2026-02-05T23:50:24.855640","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4718886613845825,"bbox":[362,39,383,58],"first_seen_time":"2026-02-05T23:50:24.855640","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46337994933128357,"bbox":[309,236,397,304],"first_seen_time":"2026-02-05T23:50:24.855640","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26101258397102356,"bbox":[265,32,285,46],"first_seen_time":"2026-02-05T23:50:24.855640","duration":0.0}],"frame_number":11725,"task_type":"realtime"}	2026-02-05 23:50:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235024_frame11725_track0_car.jpg	\N	realtime	\N	\N	f	\N
195	car	江北初中监控安防任务	\N	{"total_count":12,"object_counts":{"car":12},"detections":[{"track_id":0,"class_name":"car","confidence":0.775873064994812,"bbox":[273,55,300,81],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7572769522666931,"bbox":[72,184,172,267],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7506768107414246,"bbox":[252,104,291,142],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6803018450737,"bbox":[281,169,340,236],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6208582520484924,"bbox":[110,13,137,31],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43009334802627563,"bbox":[76,35,107,52],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4142991304397583,"bbox":[325,23,348,51],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.39537328481674194,"bbox":[11,65,61,92],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3819755017757416,"bbox":[361,31,380,45],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32159915566444397,"bbox":[297,29,316,43],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.30205079913139343,"bbox":[137,9,158,20],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29287075996398926,"bbox":[11,78,33,94],"first_seen_time":"2026-02-05T23:50:30.376652","duration":0.0}],"frame_number":11775,"task_type":"realtime"}	2026-02-05 23:50:30+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235030_frame11775_track0_car.jpg	\N	realtime	\N	\N	f	\N
196	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6129030585289001,"bbox":[195,214,268,289],"first_seen_time":"2026-02-05T23:50:35.868269","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6100980043411255,"bbox":[387,77,422,111],"first_seen_time":"2026-02-05T23:50:35.868269","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2963240444660187,"bbox":[300,14,317,32],"first_seen_time":"2026-02-05T23:50:35.868269","duration":0.0}],"frame_number":11825,"task_type":"realtime"}	2026-02-05 23:50:35+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235035_frame11825_track0_car.jpg	\N	realtime	\N	\N	f	\N
197	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7298747301101685,"bbox":[403,116,449,155],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.695499062538147,"bbox":[75,55,120,88],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6806837916374207,"bbox":[192,200,264,276],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5811524391174316,"bbox":[185,18,207,33],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5482247471809387,"bbox":[327,47,351,68],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47813332080841064,"bbox":[368,57,395,78],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46065446734428406,"bbox":[58,34,95,56],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33716389536857605,"bbox":[273,67,301,94],"first_seen_time":"2026-02-05T23:50:41.396025","duration":0.0}],"frame_number":11875,"task_type":"realtime"}	2026-02-05 23:50:41+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235041_frame11875_track0_car.jpg	\N	realtime	\N	\N	f	\N
214	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.741053581237793,"bbox":[233,133,281,177],"first_seen_time":"2026-02-05T23:52:13.360262","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6603071689605713,"bbox":[390,80,423,110],"first_seen_time":"2026-02-05T23:52:13.360262","duration":0.0}],"frame_number":12720,"task_type":"realtime"}	2026-02-05 23:52:13+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235213_frame12720_track0_car.jpg	\N	realtime	\N	\N	f	\N
199	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":7,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7385961413383484,"bbox":[399,117,446,156],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7019681334495544,"bbox":[281,56,310,79],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5510929822921753,"bbox":[325,91,355,121],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5290141701698303,"bbox":[99,35,132,59],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.44873932003974915,"bbox":[179,98,233,144],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4208141267299652,"bbox":[179,99,233,144],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4035276174545288,"bbox":[325,33,344,46],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38893190026283264,"bbox":[367,30,384,43],"first_seen_time":"2026-02-05T23:50:52.364605","duration":0.0}],"frame_number":11975,"task_type":"realtime"}	2026-02-05 23:50:52+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235052_frame11975_track0_car.jpg	\N	realtime	\N	\N	f	\N
200	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7524164319038391,"bbox":[312,204,373,278],"first_seen_time":"2026-02-05T23:50:57.729422","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6733198761940002,"bbox":[444,235,543,328],"first_seen_time":"2026-02-05T23:50:57.729422","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6125428080558777,"bbox":[247,43,276,65],"first_seen_time":"2026-02-05T23:50:57.729422","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4981178939342499,"bbox":[93,50,138,81],"first_seen_time":"2026-02-05T23:50:57.729422","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3673381209373474,"bbox":[92,50,137,81],"first_seen_time":"2026-02-05T23:50:57.729422","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33173868060112,"bbox":[385,43,405,61],"first_seen_time":"2026-02-05T23:50:57.729422","duration":0.0}],"frame_number":12025,"task_type":"realtime"}	2026-02-05 23:50:57+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235057_frame12025_track0_car.jpg	\N	realtime	\N	\N	f	\N
201	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7637189626693726,"bbox":[427,148,483,200],"first_seen_time":"2026-02-05T23:51:03.222949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7114167809486389,"bbox":[0,243,137,358],"first_seen_time":"2026-02-05T23:51:03.222949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6277253031730652,"bbox":[305,325,401,354],"first_seen_time":"2026-02-05T23:51:03.222949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40696048736572266,"bbox":[76,238,138,286],"first_seen_time":"2026-02-05T23:51:03.222949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3526727557182312,"bbox":[0,71,36,108],"first_seen_time":"2026-02-05T23:51:03.222949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3234303891658783,"bbox":[378,63,407,84],"first_seen_time":"2026-02-05T23:51:03.222949","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25084665417671204,"bbox":[240,50,264,72],"first_seen_time":"2026-02-05T23:51:03.222949","duration":0.0}],"frame_number":12075,"task_type":"realtime"}	2026-02-05 23:51:03+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235103_frame12075_track0_car.jpg	\N	realtime	\N	\N	f	\N
202	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.5363759994506836,"bbox":[395,105,435,147],"first_seen_time":"2026-02-05T23:51:08.661422","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4664136469364166,"bbox":[193,177,267,255],"first_seen_time":"2026-02-05T23:51:08.661422","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.4123843312263489,"bbox":[193,178,267,255],"first_seen_time":"2026-02-05T23:51:08.661422","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31223973631858826,"bbox":[376,25,393,43],"first_seen_time":"2026-02-05T23:51:08.661422","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29236894845962524,"bbox":[324,98,355,128],"first_seen_time":"2026-02-05T23:51:08.661422","duration":0.0}],"frame_number":12125,"task_type":"realtime"}	2026-02-05 23:51:08+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235108_frame12125_track0_car.jpg	\N	realtime	\N	\N	f	\N
203	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.834465742111206,"bbox":[472,204,549,271],"first_seen_time":"2026-02-05T23:51:13.925496","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5561792254447937,"bbox":[195,208,274,292],"first_seen_time":"2026-02-05T23:51:13.925496","duration":0.0}],"frame_number":12175,"task_type":"realtime"}	2026-02-05 23:51:13+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235114_frame12175_track0_car.jpg	\N	realtime	\N	\N	f	\N
204	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":7,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7945336699485779,"bbox":[430,163,493,222],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6616905927658081,"bbox":[308,186,371,265],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.406758189201355,"bbox":[288,55,312,76],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40477144718170166,"bbox":[383,36,403,52],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34510675072669983,"bbox":[299,26,318,43],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34035757184028625,"bbox":[239,121,283,166],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.31805142760276794,"bbox":[239,120,285,165],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28493979573249817,"bbox":[13,63,61,92],"first_seen_time":"2026-02-05T23:51:19.377799","duration":0.0}],"frame_number":12225,"task_type":"realtime"}	2026-02-05 23:51:19+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235119_frame12225_track0_car.jpg	\N	realtime	\N	\N	f	\N
205	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6730034351348877,"bbox":[319,71,347,96],"first_seen_time":"2026-02-05T23:51:24.853819","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6072747707366943,"bbox":[399,103,452,155],"first_seen_time":"2026-02-05T23:51:24.853819","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5263596773147583,"bbox":[379,32,399,50],"first_seen_time":"2026-02-05T23:51:24.853819","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2856840193271637,"bbox":[324,26,344,42],"first_seen_time":"2026-02-05T23:51:24.853819","duration":0.0}],"frame_number":12275,"task_type":"realtime"}	2026-02-05 23:51:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235124_frame12275_track0_car.jpg	\N	realtime	\N	\N	f	\N
206	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6615198254585266,"bbox":[90,14,124,35],"first_seen_time":"2026-02-05T23:51:30.340125","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5571728944778442,"bbox":[444,263,568,354],"first_seen_time":"2026-02-05T23:51:30.340125","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3265880346298218,"bbox":[148,14,170,29],"first_seen_time":"2026-02-05T23:51:30.340125","duration":0.0}],"frame_number":12325,"task_type":"realtime"}	2026-02-05 23:51:30+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235130_frame12325_track0_car.jpg	\N	realtime	\N	\N	f	\N
207	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.739666759967804,"bbox":[407,152,465,209],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6959215998649597,"bbox":[361,36,384,57],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6345127820968628,"bbox":[86,55,126,82],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6106489300727844,"bbox":[320,56,346,77],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6102536916732788,"bbox":[415,56,444,83],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5489691495895386,"bbox":[73,24,100,41],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33755746483802795,"bbox":[140,6,168,28],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2565978765487671,"bbox":[131,9,157,28],"first_seen_time":"2026-02-05T23:51:35.821259","duration":0.0}],"frame_number":12375,"task_type":"realtime"}	2026-02-05 23:51:35+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235135_frame12375_track0_car.jpg	\N	realtime	\N	\N	f	\N
208	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.744365394115448,"bbox":[253,108,292,144],"first_seen_time":"2026-02-05T23:51:40.816321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6554348468780518,"bbox":[361,32,382,50],"first_seen_time":"2026-02-05T23:51:40.816321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.645713746547699,"bbox":[412,61,441,82],"first_seen_time":"2026-02-05T23:51:40.816321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4568406641483307,"bbox":[85,27,125,47],"first_seen_time":"2026-02-05T23:51:40.816321","duration":0.0}],"frame_number":12420,"task_type":"realtime"}	2026-02-05 23:51:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235140_frame12420_track0_car.jpg	\N	realtime	\N	\N	f	\N
209	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6733974814414978,"bbox":[384,99,428,137],"first_seen_time":"2026-02-05T23:51:46.302986","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5460160374641418,"bbox":[44,42,81,64],"first_seen_time":"2026-02-05T23:51:46.302986","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3032665252685547,"bbox":[328,42,352,57],"first_seen_time":"2026-02-05T23:51:46.302986","duration":0.0}],"frame_number":12470,"task_type":"realtime"}	2026-02-05 23:51:46+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235146_frame12470_track0_car.jpg	\N	realtime	\N	\N	f	\N
210	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.5537480115890503,"bbox":[325,60,357,92],"first_seen_time":"2026-02-05T23:51:51.728195","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5475068688392639,"bbox":[378,78,411,104],"first_seen_time":"2026-02-05T23:51:51.728195","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5264326333999634,"bbox":[96,20,122,35],"first_seen_time":"2026-02-05T23:51:51.728195","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.504463791847229,"bbox":[121,38,154,65],"first_seen_time":"2026-02-05T23:51:51.728195","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.498119592666626,"bbox":[59,38,95,58],"first_seen_time":"2026-02-05T23:51:51.728195","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29197487235069275,"bbox":[356,22,374,37],"first_seen_time":"2026-02-05T23:51:51.728195","duration":0.0}],"frame_number":12520,"task_type":"realtime"}	2026-02-05 23:51:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235151_frame12520_track0_car.jpg	\N	realtime	\N	\N	f	\N
211	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.5717827081680298,"bbox":[371,59,400,85],"first_seen_time":"2026-02-05T23:51:57.197374","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28121548891067505,"bbox":[172,3,197,18],"first_seen_time":"2026-02-05T23:51:57.197374","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2636934518814087,"bbox":[211,6,229,19],"first_seen_time":"2026-02-05T23:51:57.197374","duration":0.0}],"frame_number":12570,"task_type":"realtime"}	2026-02-05 23:51:57+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235157_frame12570_track0_car.jpg	\N	realtime	\N	\N	f	\N
212	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7340480089187622,"bbox":[35,33,73,53],"first_seen_time":"2026-02-05T23:52:02.653686","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6577353477478027,"bbox":[5,77,65,118],"first_seen_time":"2026-02-05T23:52:02.653686","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4861290454864502,"bbox":[368,45,392,66],"first_seen_time":"2026-02-05T23:52:02.653686","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27315932512283325,"bbox":[128,19,149,32],"first_seen_time":"2026-02-05T23:52:02.653686","duration":0.0}],"frame_number":12620,"task_type":"realtime"}	2026-02-05 23:52:02+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235202_frame12620_track0_car.jpg	\N	realtime	\N	\N	f	\N
215	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7824683785438538,"bbox":[379,63,410,94],"first_seen_time":"2026-02-05T23:52:18.745902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7104282379150391,"bbox":[215,156,276,216],"first_seen_time":"2026-02-05T23:52:18.745902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5499042868614197,"bbox":[126,28,162,62],"first_seen_time":"2026-02-05T23:52:18.745902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4645846486091614,"bbox":[368,16,385,30],"first_seen_time":"2026-02-05T23:52:18.745902","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3104095458984375,"bbox":[213,5,233,17],"first_seen_time":"2026-02-05T23:52:18.745902","duration":0.0}],"frame_number":12770,"task_type":"realtime"}	2026-02-05 23:52:18+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235218_frame12770_track0_car.jpg	\N	realtime	\N	\N	f	\N
216	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.732062816619873,"bbox":[64,62,109,95],"first_seen_time":"2026-02-05T23:52:24.240227","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5611363649368286,"bbox":[0,39,26,64],"first_seen_time":"2026-02-05T23:52:24.240227","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4073237180709839,"bbox":[88,36,124,62],"first_seen_time":"2026-02-05T23:52:24.240227","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3204496502876282,"bbox":[297,24,315,38],"first_seen_time":"2026-02-05T23:52:24.240227","duration":0.0}],"frame_number":12820,"task_type":"realtime"}	2026-02-05 23:52:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235224_frame12820_track0_car.jpg	\N	realtime	\N	\N	f	\N
217	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":8,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.735366702079773,"bbox":[195,209,271,290],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7098119854927063,"bbox":[435,222,527,312],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5570131540298462,"bbox":[366,49,391,71],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5157654285430908,"bbox":[314,145,364,200],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5015602111816406,"bbox":[255,39,279,58],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3962620794773102,"bbox":[145,6,167,19],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3777000606060028,"bbox":[314,145,364,201],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35267144441604614,"bbox":[0,73,34,102],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.30279943346977234,"bbox":[54,31,87,49],"first_seen_time":"2026-02-05T23:52:29.707611","duration":0.0}],"frame_number":12870,"task_type":"realtime"}	2026-02-05 23:52:29+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235229_frame12870_track0_car.jpg	\N	realtime	\N	\N	f	\N
218	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.8380070328712463,"bbox":[411,181,479,245],"first_seen_time":"2026-02-05T23:52:35.246087","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.8290005922317505,"bbox":[116,165,191,226],"first_seen_time":"2026-02-05T23:52:35.246087","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5486248731613159,"bbox":[165,18,185,31],"first_seen_time":"2026-02-05T23:52:35.246087","duration":0.0}],"frame_number":12920,"task_type":"realtime"}	2026-02-05 23:52:35+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235235_frame12920_track0_car.jpg	\N	realtime	\N	\N	f	\N
219	car	江北初中监控安防任务	\N	{"total_count":10,"object_counts":{"car":8,"truck":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.5350518822669983,"bbox":[392,114,435,153],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4651418924331665,"bbox":[321,77,353,108],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4205937683582306,"bbox":[358,31,381,48],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3894980251789093,"bbox":[315,150,378,230],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3508131206035614,"bbox":[254,106,295,143],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32187220454216003,"bbox":[110,13,135,31],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2909340560436249,"bbox":[315,150,379,230],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2603420615196228,"bbox":[271,22,293,38],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2573224902153015,"bbox":[252,100,295,143],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2537085711956024,"bbox":[183,1,203,22],"first_seen_time":"2026-02-05T23:52:40.757432","duration":0.0}],"frame_number":12970,"task_type":"realtime"}	2026-02-05 23:52:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235240_frame12970_track0_car.jpg	\N	realtime	\N	\N	f	\N
220	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7681599855422974,"bbox":[300,115,341,157],"first_seen_time":"2026-02-05T23:52:46.168120","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6694047451019287,"bbox":[160,119,218,170],"first_seen_time":"2026-02-05T23:52:46.168120","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6441682577133179,"bbox":[282,43,305,64],"first_seen_time":"2026-02-05T23:52:46.168120","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6271402835845947,"bbox":[83,20,110,39],"first_seen_time":"2026-02-05T23:52:46.168120","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5150689482688904,"bbox":[31,43,72,66],"first_seen_time":"2026-02-05T23:52:46.168120","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4607919156551361,"bbox":[267,78,298,105],"first_seen_time":"2026-02-05T23:52:46.168120","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3417549729347229,"bbox":[118,11,143,27],"first_seen_time":"2026-02-05T23:52:46.168120","duration":0.0}],"frame_number":13020,"task_type":"realtime"}	2026-02-05 23:52:46+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235246_frame13020_track0_car.jpg	\N	realtime	\N	\N	f	\N
221	car	江北初中监控安防任务	\N	{"total_count":10,"object_counts":{"car":8,"truck":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.619070827960968,"bbox":[454,298,556,353],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.517514705657959,"bbox":[165,31,186,45],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38746941089630127,"bbox":[116,14,136,30],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3751087486743927,"bbox":[242,135,286,179],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35992202162742615,"bbox":[325,17,344,30],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.351374089717865,"bbox":[242,135,287,179],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2984570264816284,"bbox":[209,9,227,22],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2767258286476135,"bbox":[380,58,408,87],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27358442544937134,"bbox":[381,58,409,87],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2713991403579712,"bbox":[144,16,166,38],"first_seen_time":"2026-02-05T23:52:51.608283","duration":0.0}],"frame_number":13070,"task_type":"realtime"}	2026-02-05 23:52:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235251_frame13070_track0_car.jpg	\N	realtime	\N	\N	f	\N
222	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.6883010864257812,"bbox":[167,27,190,44],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6867843270301819,"bbox":[395,87,429,118],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6061433553695679,"bbox":[328,38,351,54],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5551052689552307,"bbox":[240,130,284,171],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49647098779678345,"bbox":[364,46,386,63],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.319031685590744,"bbox":[281,49,307,70],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28603309392929077,"bbox":[6,53,52,75],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27780404686927795,"bbox":[5,79,67,122],"first_seen_time":"2026-02-05T23:52:57.138550","duration":0.0}],"frame_number":13120,"task_type":"realtime"}	2026-02-05 23:52:57+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235257_frame13120_track0_car.jpg	\N	realtime	\N	\N	f	\N
223	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6370739936828613,"bbox":[93,37,124,60],"first_seen_time":"2026-02-05T23:53:02.586460","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6061303615570068,"bbox":[0,41,27,67],"first_seen_time":"2026-02-05T23:53:02.586460","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5736103057861328,"bbox":[394,100,431,133],"first_seen_time":"2026-02-05T23:53:02.586460","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.4242140054702759,"bbox":[321,123,363,166],"first_seen_time":"2026-02-05T23:53:02.586460","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4029845893383026,"bbox":[319,121,364,166],"first_seen_time":"2026-02-05T23:53:02.586460","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3570178151130676,"bbox":[104,15,133,30],"first_seen_time":"2026-02-05T23:53:02.586460","duration":0.0}],"frame_number":13170,"task_type":"realtime"}	2026-02-05 23:53:02+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235302_frame13170_track0_car.jpg	\N	realtime	\N	\N	f	\N
224	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.6423544883728027,"bbox":[460,225,551,312],"first_seen_time":"2026-02-05T23:53:08.035529","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6012385487556458,"bbox":[51,48,94,78],"first_seen_time":"2026-02-05T23:53:08.035529","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5984240174293518,"bbox":[289,41,313,61],"first_seen_time":"2026-02-05T23:53:08.035529","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4976511001586914,"bbox":[386,85,424,115],"first_seen_time":"2026-02-05T23:53:08.035529","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4789329171180725,"bbox":[216,69,255,102],"first_seen_time":"2026-02-05T23:53:08.035529","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3318748474121094,"bbox":[326,71,353,94],"first_seen_time":"2026-02-05T23:53:08.035529","duration":0.0}],"frame_number":13220,"task_type":"realtime"}	2026-02-05 23:53:08+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235308_frame13220_track0_car.jpg	\N	realtime	\N	\N	f	\N
225	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":6,"truck":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.7154150605201721,"bbox":[62,23,95,45],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6808009147644043,"bbox":[378,62,406,84],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6073607802391052,"bbox":[207,178,278,253],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5650500655174255,"bbox":[309,309,401,355],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5402564406394958,"bbox":[322,71,353,96],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3565884232521057,"bbox":[0,66,41,103],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3385491371154785,"bbox":[208,179,278,251],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.31946420669555664,"bbox":[0,66,42,104],"first_seen_time":"2026-02-05T23:53:13.363522","duration":0.0}],"frame_number":13270,"task_type":"realtime"}	2026-02-05 23:53:13+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235313_frame13270_track0_car.jpg	\N	realtime	\N	\N	f	\N
226	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":7,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.8188771605491638,"bbox":[123,151,200,215],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6688105463981628,"bbox":[374,49,398,72],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5414445996284485,"bbox":[251,38,278,59],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.5229274034500122,"bbox":[313,209,385,295],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44537216424942017,"bbox":[299,25,319,39],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4036148190498352,"bbox":[412,108,452,146],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38344916701316833,"bbox":[194,14,215,31],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33300161361694336,"bbox":[327,45,348,62],"first_seen_time":"2026-02-05T23:53:18.784397","duration":0.0}],"frame_number":13320,"task_type":"realtime"}	2026-02-05 23:53:18+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235318_frame13320_track0_car.jpg	\N	realtime	\N	\N	f	\N
227	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6566524505615234,"bbox":[238,129,283,171],"first_seen_time":"2026-02-05T23:53:24.211385","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6264460682868958,"bbox":[385,86,420,113],"first_seen_time":"2026-02-05T23:53:24.211385","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.539141058921814,"bbox":[323,76,351,100],"first_seen_time":"2026-02-05T23:53:24.211385","duration":0.0}],"frame_number":13370,"task_type":"realtime"}	2026-02-05 23:53:24+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235324_frame13370_track0_car.jpg	\N	realtime	\N	\N	f	\N
228	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7542281150817871,"bbox":[93,58,131,82],"first_seen_time":"2026-02-05T23:53:29.559365","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.718377411365509,"bbox":[239,140,290,193],"first_seen_time":"2026-02-05T23:53:29.559365","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.675984799861908,"bbox":[443,146,496,192],"first_seen_time":"2026-02-05T23:53:29.559365","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40210798382759094,"bbox":[105,20,133,41],"first_seen_time":"2026-02-05T23:53:29.559365","duration":0.0}],"frame_number":13420,"task_type":"realtime"}	2026-02-05 23:53:29+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235329_frame13420_track0_car.jpg	\N	realtime	\N	\N	f	\N
229	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":4,"truck":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6390955448150635,"bbox":[314,131,361,181],"first_seen_time":"2026-02-05T23:53:35.018989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5352547764778137,"bbox":[414,122,461,167],"first_seen_time":"2026-02-05T23:53:35.018989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4370805025100708,"bbox":[379,29,397,44],"first_seen_time":"2026-02-05T23:53:35.018989","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.41779565811157227,"bbox":[252,90,293,122],"first_seen_time":"2026-02-05T23:53:35.018989","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.32449978590011597,"bbox":[414,122,461,167],"first_seen_time":"2026-02-05T23:53:35.018989","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2870880663394928,"bbox":[251,89,293,122],"first_seen_time":"2026-02-05T23:53:35.018989","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.27659207582473755,"bbox":[314,131,361,181],"first_seen_time":"2026-02-05T23:53:35.018989","duration":0.0}],"frame_number":13470,"task_type":"realtime"}	2026-02-05 23:53:35+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235335_frame13470_track0_car.jpg	\N	realtime	\N	\N	f	\N
230	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6938616037368774,"bbox":[318,56,344,77],"first_seen_time":"2026-02-05T23:53:40.455109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5143147706985474,"bbox":[376,27,395,44],"first_seen_time":"2026-02-05T23:53:40.455109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4192259907722473,"bbox":[389,82,432,124],"first_seen_time":"2026-02-05T23:53:40.455109","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3695714771747589,"bbox":[388,83,432,123],"first_seen_time":"2026-02-05T23:53:40.455109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3574301600456238,"bbox":[183,17,205,35],"first_seen_time":"2026-02-05T23:53:40.455109","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.26449155807495117,"bbox":[326,20,343,35],"first_seen_time":"2026-02-05T23:53:40.455109","duration":0.0}],"frame_number":13520,"task_type":"realtime"}	2026-02-05 23:53:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235340_frame13520_track0_car.jpg	\N	realtime	\N	\N	f	\N
231	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.8043377995491028,"bbox":[412,177,490,252],"first_seen_time":"2026-02-05T23:53:45.873052","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6243087649345398,"bbox":[69,17,110,40],"first_seen_time":"2026-02-05T23:53:45.873052","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.556756854057312,"bbox":[131,19,154,32],"first_seen_time":"2026-02-05T23:53:45.873052","duration":0.0}],"frame_number":13570,"task_type":"realtime"}	2026-02-05 23:53:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235345_frame13570_track0_car.jpg	\N	realtime	\N	\N	f	\N
239	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7148716449737549,"bbox":[382,55,406,79],"first_seen_time":"2026-02-05T23:54:29.422563","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49606359004974365,"bbox":[265,80,295,108],"first_seen_time":"2026-02-05T23:54:29.422563","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.465013325214386,"bbox":[211,2,234,16],"first_seen_time":"2026-02-05T23:54:29.422563","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2828594446182251,"bbox":[140,7,162,22],"first_seen_time":"2026-02-05T23:54:29.422563","duration":0.0}],"frame_number":13970,"task_type":"realtime"}	2026-02-05 23:54:29+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235429_frame13970_track0_car.jpg	\N	realtime	\N	\N	f	\N
232	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7541103959083557,"bbox":[359,29,383,50],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7328131198883057,"bbox":[391,114,436,155],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6827005743980408,"bbox":[46,30,76,51],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6500712037086487,"bbox":[114,10,153,36],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6061522364616394,"bbox":[324,44,344,60],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5997145771980286,"bbox":[407,47,432,70],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5986385345458984,"bbox":[38,78,83,112],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.435413122177124,"bbox":[561,234,639,311],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36523157358169556,"bbox":[165,1,191,16],"first_seen_time":"2026-02-05T23:53:51.371310","duration":0.0}],"frame_number":13620,"task_type":"realtime"}	2026-02-05 23:53:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235351_frame13620_track0_car.jpg	\N	realtime	\N	\N	f	\N
233	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8071947693824768,"bbox":[491,149,568,206],"first_seen_time":"2026-02-05T23:53:56.825853","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7292630076408386,"bbox":[241,131,286,174],"first_seen_time":"2026-02-05T23:53:56.825853","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6805863380432129,"bbox":[418,67,449,91],"first_seen_time":"2026-02-05T23:53:56.825853","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6700204610824585,"bbox":[382,93,427,131],"first_seen_time":"2026-02-05T23:53:56.825853","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6516662240028381,"bbox":[310,194,369,262],"first_seen_time":"2026-02-05T23:53:56.825853","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5686724781990051,"bbox":[363,33,383,54],"first_seen_time":"2026-02-05T23:53:56.825853","duration":0.0}],"frame_number":13670,"task_type":"realtime"}	2026-02-05 23:53:56+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235356_frame13670_track0_car.jpg	\N	realtime	\N	\N	f	\N
234	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8133662343025208,"bbox":[374,66,403,92],"first_seen_time":"2026-02-05T23:54:02.289753","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7785722017288208,"bbox":[467,125,522,165],"first_seen_time":"2026-02-05T23:54:02.289753","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6344320774078369,"bbox":[69,21,108,54],"first_seen_time":"2026-02-05T23:54:02.289753","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6214796304702759,"bbox":[392,31,415,49],"first_seen_time":"2026-02-05T23:54:02.289753","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5013933181762695,"bbox":[139,1,185,24],"first_seen_time":"2026-02-05T23:54:02.289753","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32250601053237915,"bbox":[323,25,344,40],"first_seen_time":"2026-02-05T23:54:02.289753","duration":0.0}],"frame_number":13720,"task_type":"realtime"}	2026-02-05 23:54:02+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235402_frame13720_track0_car.jpg	\N	realtime	\N	\N	f	\N
235	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.6446628570556641,"bbox":[451,278,570,355],"first_seen_time":"2026-02-05T23:54:07.715362","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.589840292930603,"bbox":[291,38,311,55],"first_seen_time":"2026-02-05T23:54:07.715362","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5379311442375183,"bbox":[327,90,365,121],"first_seen_time":"2026-02-05T23:54:07.715362","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4122479557991028,"bbox":[385,29,404,44],"first_seen_time":"2026-02-05T23:54:07.715362","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.301847368478775,"bbox":[135,22,156,33],"first_seen_time":"2026-02-05T23:54:07.715362","duration":0.0}],"frame_number":13770,"task_type":"realtime"}	2026-02-05 23:54:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235407_frame13770_track0_car.jpg	\N	realtime	\N	\N	f	\N
236	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":5,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7214914560317993,"bbox":[421,191,506,270],"first_seen_time":"2026-02-05T23:54:13.046289","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6068316102027893,"bbox":[364,42,388,63],"first_seen_time":"2026-02-05T23:54:13.046289","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4058366119861603,"bbox":[313,163,381,245],"first_seen_time":"2026-02-05T23:54:13.046289","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34763678908348083,"bbox":[151,10,173,26],"first_seen_time":"2026-02-05T23:54:13.046289","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.34737882018089294,"bbox":[314,163,380,246],"first_seen_time":"2026-02-05T23:54:13.046289","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34547439217567444,"bbox":[191,14,212,28],"first_seen_time":"2026-02-05T23:54:13.046289","duration":0.0}],"frame_number":13820,"task_type":"realtime"}	2026-02-05 23:54:13+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235413_frame13820_track0_car.jpg	\N	realtime	\N	\N	f	\N
237	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7942983508110046,"bbox":[422,190,505,267],"first_seen_time":"2026-02-05T23:54:18.472404","duration":0.0}],"frame_number":13870,"task_type":"realtime"}	2026-02-05 23:54:18+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235418_frame13870_track0_car.jpg	\N	realtime	\N	\N	f	\N
238	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6629188060760498,"bbox":[78,41,113,65],"first_seen_time":"2026-02-05T23:54:23.939717","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5499609112739563,"bbox":[363,35,384,52],"first_seen_time":"2026-02-05T23:54:23.939717","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4041456878185272,"bbox":[3,40,47,58],"first_seen_time":"2026-02-05T23:54:23.939717","duration":0.0}],"frame_number":13920,"task_type":"realtime"}	2026-02-05 23:54:23+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235424_frame13920_track0_car.jpg	\N	realtime	\N	\N	f	\N
240	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7734600901603699,"bbox":[252,94,294,129],"first_seen_time":"2026-02-05T23:54:34.825376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7494310140609741,"bbox":[371,44,396,67],"first_seen_time":"2026-02-05T23:54:34.825376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45976442098617554,"bbox":[195,6,220,23],"first_seen_time":"2026-02-05T23:54:34.825376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.414247989654541,"bbox":[138,7,160,20],"first_seen_time":"2026-02-05T23:54:34.825376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3968803286552429,"bbox":[66,44,119,90],"first_seen_time":"2026-02-05T23:54:34.825376","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.370536744594574,"bbox":[65,43,119,90],"first_seen_time":"2026-02-05T23:54:34.825376","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35947439074516296,"bbox":[365,8,383,25],"first_seen_time":"2026-02-05T23:54:34.825376","duration":0.0}],"frame_number":14020,"task_type":"realtime"}	2026-02-05 23:54:34+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235434_frame14020_track0_car.jpg	\N	realtime	\N	\N	f	\N
241	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8301230072975159,"bbox":[425,222,515,310],"first_seen_time":"2026-02-05T23:54:40.291075","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7377711534500122,"bbox":[58,210,161,291],"first_seen_time":"2026-02-05T23:54:40.291075","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5143998265266418,"bbox":[0,102,24,144],"first_seen_time":"2026-02-05T23:54:40.291075","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4940183758735657,"bbox":[21,54,71,89],"first_seen_time":"2026-02-05T23:54:40.291075","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4198223948478699,"bbox":[167,11,196,29],"first_seen_time":"2026-02-05T23:54:40.291075","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2778274118900299,"bbox":[301,16,319,28],"first_seen_time":"2026-02-05T23:54:40.291075","duration":0.0}],"frame_number":14070,"task_type":"realtime"}	2026-02-05 23:54:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235440_frame14070_track0_car.jpg	\N	realtime	\N	\N	f	\N
242	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7801404595375061,"bbox":[362,27,381,45],"first_seen_time":"2026-02-05T23:54:45.736237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7218456268310547,"bbox":[279,51,305,74],"first_seen_time":"2026-02-05T23:54:45.736237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7157161235809326,"bbox":[167,22,191,43],"first_seen_time":"2026-02-05T23:54:45.736237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5452092885971069,"bbox":[98,16,125,34],"first_seen_time":"2026-02-05T23:54:45.736237","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.41087329387664795,"bbox":[0,80,25,108],"first_seen_time":"2026-02-05T23:54:45.736237","duration":0.0}],"frame_number":14120,"task_type":"realtime"}	2026-02-05 23:54:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235445_frame14120_track0_car.jpg	\N	realtime	\N	\N	f	\N
243	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7175291776657104,"bbox":[128,28,155,44],"first_seen_time":"2026-02-05T23:54:51.199858","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5516572594642639,"bbox":[386,103,428,145],"first_seen_time":"2026-02-05T23:54:51.199858","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5208909511566162,"bbox":[198,90,242,127],"first_seen_time":"2026-02-05T23:54:51.199858","duration":0.0}],"frame_number":14170,"task_type":"realtime"}	2026-02-05 23:54:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235451_frame14170_track0_car.jpg	\N	realtime	\N	\N	f	\N
244	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7212491631507874,"bbox":[275,70,304,96],"first_seen_time":"2026-02-05T23:54:56.675205","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6994413137435913,"bbox":[180,178,256,265],"first_seen_time":"2026-02-05T23:54:56.675205","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6707491874694824,"bbox":[378,65,407,101],"first_seen_time":"2026-02-05T23:54:56.675205","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6512634754180908,"bbox":[322,90,365,132],"first_seen_time":"2026-02-05T23:54:56.675205","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6306195855140686,"bbox":[69,22,101,42],"first_seen_time":"2026-02-05T23:54:56.675205","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3682040274143219,"bbox":[320,53,352,74],"first_seen_time":"2026-02-05T23:54:56.675205","duration":0.0}],"frame_number":14220,"task_type":"realtime"}	2026-02-05 23:54:56+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235456_frame14220_track0_car.jpg	\N	realtime	\N	\N	f	\N
245	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7247397899627686,"bbox":[313,68,344,97],"first_seen_time":"2026-02-05T23:55:02.177569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6783737540245056,"bbox":[29,29,64,58],"first_seen_time":"2026-02-05T23:55:02.177569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6775258779525757,"bbox":[85,19,112,36],"first_seen_time":"2026-02-05T23:55:02.177569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6054332256317139,"bbox":[217,71,254,102],"first_seen_time":"2026-02-05T23:55:02.177569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5656413435935974,"bbox":[278,54,304,74],"first_seen_time":"2026-02-05T23:55:02.177569","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5175451636314392,"bbox":[290,30,309,48],"first_seen_time":"2026-02-05T23:55:02.177569","duration":0.0}],"frame_number":14270,"task_type":"realtime"}	2026-02-05 23:55:02+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235502_frame14270_track0_car.jpg	\N	realtime	\N	\N	f	\N
252	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.70001220703125,"bbox":[372,55,398,75],"first_seen_time":"2026-02-05T23:55:40.260561","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6606582999229431,"bbox":[271,73,299,96],"first_seen_time":"2026-02-05T23:55:40.260561","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2587287127971649,"bbox":[325,51,345,67],"first_seen_time":"2026-02-05T23:55:40.260561","duration":0.0}],"frame_number":14620,"task_type":"realtime"}	2026-02-05 23:55:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235540_frame14620_track0_car.jpg	\N	realtime	\N	\N	f	\N
246	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.6890445351600647,"bbox":[403,162,464,217],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6867300271987915,"bbox":[319,150,369,203],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.52397221326828,"bbox":[117,48,151,71],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4923015534877777,"bbox":[188,15,209,31],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3661319315433502,"bbox":[73,24,104,41],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32079261541366577,"bbox":[374,40,397,61],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3189050853252411,"bbox":[157,8,175,22],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2512330710887909,"bbox":[273,79,301,105],"first_seen_time":"2026-02-05T23:55:07.653992","duration":0.0}],"frame_number":14320,"task_type":"realtime"}	2026-02-05 23:55:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235507_frame14320_track0_car.jpg	\N	realtime	\N	\N	f	\N
247	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7074131965637207,"bbox":[384,60,412,83],"first_seen_time":"2026-02-05T23:55:12.938559","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.596697986125946,"bbox":[123,46,154,67],"first_seen_time":"2026-02-05T23:55:12.938559","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5565370321273804,"bbox":[271,74,298,101],"first_seen_time":"2026-02-05T23:55:12.938559","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4823607802391052,"bbox":[291,33,312,48],"first_seen_time":"2026-02-05T23:55:12.938559","duration":0.0}],"frame_number":14370,"task_type":"realtime"}	2026-02-05 23:55:12+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235513_frame14370_track0_car.jpg	\N	realtime	\N	\N	f	\N
248	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7946538925170898,"bbox":[185,211,271,305],"first_seen_time":"2026-02-05T23:55:18.318787","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6411505341529846,"bbox":[380,66,410,91],"first_seen_time":"2026-02-05T23:55:18.318787","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5453504920005798,"bbox":[70,21,103,41],"first_seen_time":"2026-02-05T23:55:18.318787","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5390118956565857,"bbox":[17,59,63,89],"first_seen_time":"2026-02-05T23:55:18.318787","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42201703786849976,"bbox":[322,78,353,105],"first_seen_time":"2026-02-05T23:55:18.318787","duration":0.0}],"frame_number":14420,"task_type":"realtime"}	2026-02-05 23:55:18+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235518_frame14420_track0_car.jpg	\N	realtime	\N	\N	f	\N
249	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":8,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7085850834846497,"bbox":[460,263,579,353],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4933604598045349,"bbox":[166,13,185,30],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4407654404640198,"bbox":[145,5,165,18],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4398566484451294,"bbox":[80,23,107,39],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3652656078338623,"bbox":[374,14,392,37],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36487698554992676,"bbox":[286,38,306,55],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3541780114173889,"bbox":[0,50,41,78],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.31103232502937317,"bbox":[321,3,353,59],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2839938998222351,"bbox":[148,6,180,29],"first_seen_time":"2026-02-05T23:55:23.846703","duration":0.0}],"frame_number":14470,"task_type":"realtime"}	2026-02-05 23:55:23+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235523_frame14470_track0_car.jpg	\N	realtime	\N	\N	f	\N
250	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"truck":2,"car":5},"detections":[{"track_id":0,"class_name":"truck","confidence":0.6746695637702942,"bbox":[0,226,140,353],"first_seen_time":"2026-02-05T23:55:29.351506","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6548837423324585,"bbox":[260,96,297,131],"first_seen_time":"2026-02-05T23:55:29.351506","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6190292239189148,"bbox":[322,156,368,207],"first_seen_time":"2026-02-05T23:55:29.351506","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.5395052433013916,"bbox":[443,225,544,329],"first_seen_time":"2026-02-05T23:55:29.351506","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4354035258293152,"bbox":[6,35,53,60],"first_seen_time":"2026-02-05T23:55:29.351506","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4345166087150574,"bbox":[372,44,393,59],"first_seen_time":"2026-02-05T23:55:29.351506","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3995899260044098,"bbox":[153,19,176,36],"first_seen_time":"2026-02-05T23:55:29.351506","duration":0.0}],"frame_number":14520,"task_type":"realtime"}	2026-02-05 23:55:29+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235529_frame14520_track0_truck.jpg	\N	realtime	\N	\N	f	\N
251	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.6648162007331848,"bbox":[321,112,362,158],"first_seen_time":"2026-02-05T23:55:34.765732","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6508793234825134,"bbox":[210,78,250,111],"first_seen_time":"2026-02-05T23:55:34.765732","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6053888201713562,"bbox":[394,68,422,92],"first_seen_time":"2026-02-05T23:55:34.765732","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5011806488037109,"bbox":[268,21,289,38],"first_seen_time":"2026-02-05T23:55:34.765732","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43213945627212524,"bbox":[303,14,322,27],"first_seen_time":"2026-02-05T23:55:34.765732","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42323431372642517,"bbox":[158,28,187,49],"first_seen_time":"2026-02-05T23:55:34.765732","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31071174144744873,"bbox":[367,33,387,49],"first_seen_time":"2026-02-05T23:55:34.765732","duration":0.0}],"frame_number":14570,"task_type":"realtime"}	2026-02-05 23:55:34+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235534_frame14570_track0_car.jpg	\N	realtime	\N	\N	f	\N
253	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6523117423057556,"bbox":[274,77,305,111],"first_seen_time":"2026-02-05T23:55:45.716831","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6282424330711365,"bbox":[413,88,447,118],"first_seen_time":"2026-02-05T23:55:45.716831","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5278330445289612,"bbox":[46,37,86,61],"first_seen_time":"2026-02-05T23:55:45.716831","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.48405614495277405,"bbox":[208,201,279,274],"first_seen_time":"2026-02-05T23:55:45.716831","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43449246883392334,"bbox":[208,201,279,273],"first_seen_time":"2026-02-05T23:55:45.716831","duration":0.0}],"frame_number":14670,"task_type":"realtime"}	2026-02-05 23:55:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235545_frame14670_track0_car.jpg	\N	realtime	\N	\N	f	\N
254	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.5216960310935974,"bbox":[397,78,430,108],"first_seen_time":"2026-02-05T23:55:51.223828","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4422318637371063,"bbox":[321,76,352,106],"first_seen_time":"2026-02-05T23:55:51.223828","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.409938246011734,"bbox":[293,318,375,356],"first_seen_time":"2026-02-05T23:55:51.223828","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.39770880341529846,"bbox":[276,56,303,80],"first_seen_time":"2026-02-05T23:55:51.223828","duration":0.0}],"frame_number":14720,"task_type":"realtime"}	2026-02-05 23:55:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235551_frame14720_track0_car.jpg	\N	realtime	\N	\N	f	\N
255	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7296612858772278,"bbox":[377,55,407,86],"first_seen_time":"2026-02-05T23:55:56.758056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5508966445922852,"bbox":[321,36,343,53],"first_seen_time":"2026-02-05T23:55:56.758056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33854594826698303,"bbox":[148,31,175,52],"first_seen_time":"2026-02-05T23:55:56.758056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2599615752696991,"bbox":[372,17,389,31],"first_seen_time":"2026-02-05T23:55:56.758056","duration":0.0}],"frame_number":14770,"task_type":"realtime"}	2026-02-05 23:55:56+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235556_frame14770_track0_car.jpg	\N	realtime	\N	\N	f	\N
256	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8391969799995422,"bbox":[501,162,587,224],"first_seen_time":"2026-02-05T23:56:02.282830","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.8353655338287354,"bbox":[308,221,372,301],"first_seen_time":"2026-02-05T23:56:02.282830","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.732836902141571,"bbox":[90,31,117,47],"first_seen_time":"2026-02-05T23:56:02.282830","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5830540657043457,"bbox":[385,100,428,142],"first_seen_time":"2026-02-05T23:56:02.282830","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4864504337310791,"bbox":[27,27,69,55],"first_seen_time":"2026-02-05T23:56:02.282830","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38296547532081604,"bbox":[133,24,160,43],"first_seen_time":"2026-02-05T23:56:02.282830","duration":0.0}],"frame_number":14820,"task_type":"realtime"}	2026-02-05 23:56:02+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235602_frame14820_track0_car.jpg	\N	realtime	\N	\N	f	\N
257	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7806102633476257,"bbox":[376,69,405,98],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7757113575935364,"bbox":[473,135,535,177],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6040880680084229,"bbox":[77,19,115,52],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5341042280197144,"bbox":[395,33,416,52],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5195610523223877,"bbox":[323,28,342,42],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4106433689594269,"bbox":[144,8,179,22],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4009522795677185,"bbox":[0,49,16,70],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29891568422317505,"bbox":[357,19,374,35],"first_seen_time":"2026-02-05T23:56:07.655359","duration":0.0}],"frame_number":14870,"task_type":"realtime"}	2026-02-05 23:56:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235607_frame14870_track0_car.jpg	\N	realtime	\N	\N	f	\N
258	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.6439194679260254,"bbox":[326,97,368,131],"first_seen_time":"2026-02-05T23:56:12.920465","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6212093234062195,"bbox":[290,41,310,59],"first_seen_time":"2026-02-05T23:56:12.920465","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.568080484867096,"bbox":[466,317,564,355],"first_seen_time":"2026-02-05T23:56:12.920465","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47023484110832214,"bbox":[386,30,406,46],"first_seen_time":"2026-02-05T23:56:12.920465","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27694520354270935,"bbox":[139,19,160,32],"first_seen_time":"2026-02-05T23:56:12.920465","duration":0.0}],"frame_number":14920,"task_type":"realtime"}	2026-02-05 23:56:12+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235613_frame14920_track0_car.jpg	\N	realtime	\N	\N	f	\N
267	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7587229609489441,"bbox":[53,25,86,47],"first_seen_time":"2026-02-05T23:57:01.828286","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7139086723327637,"bbox":[289,35,313,51],"first_seen_time":"2026-02-05T23:57:01.828286","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49124830961227417,"bbox":[127,41,158,65],"first_seen_time":"2026-02-05T23:57:01.828286","duration":0.0}],"frame_number":15370,"task_type":"realtime"}	2026-02-05 23:57:01+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235701_frame15370_track0_car.jpg	\N	realtime	\N	\N	f	\N
259	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.6606537699699402,"bbox":[210,180,274,242],"first_seen_time":"2026-02-05T23:56:18.315683","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5997356176376343,"bbox":[366,44,387,63],"first_seen_time":"2026-02-05T23:56:18.315683","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5197389125823975,"bbox":[429,80,467,110],"first_seen_time":"2026-02-05T23:56:18.315683","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36786240339279175,"bbox":[119,16,153,34],"first_seen_time":"2026-02-05T23:56:18.315683","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3422865569591522,"bbox":[112,15,134,33],"first_seen_time":"2026-02-05T23:56:18.315683","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.31165122985839844,"bbox":[0,37,50,82],"first_seen_time":"2026-02-05T23:56:18.315683","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2994737923145294,"bbox":[325,16,343,28],"first_seen_time":"2026-02-05T23:56:18.315683","duration":0.0}],"frame_number":14970,"task_type":"realtime"}	2026-02-05 23:56:18+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235618_frame14970_track0_car.jpg	\N	realtime	\N	\N	f	\N
260	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7182822823524475,"bbox":[400,146,460,204],"first_seen_time":"2026-02-05T23:56:23.736269","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4486890435218811,"bbox":[327,57,355,79],"first_seen_time":"2026-02-05T23:56:23.736269","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3655117452144623,"bbox":[31,39,67,56],"first_seen_time":"2026-02-05T23:56:23.736269","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33396315574645996,"bbox":[92,34,121,48],"first_seen_time":"2026-02-05T23:56:23.736269","duration":0.0}],"frame_number":15020,"task_type":"realtime"}	2026-02-05 23:56:23+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235623_frame15020_track0_car.jpg	\N	realtime	\N	\N	f	\N
261	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7029615640640259,"bbox":[159,25,184,44],"first_seen_time":"2026-02-05T23:56:29.202982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5227030515670776,"bbox":[321,91,365,131],"first_seen_time":"2026-02-05T23:56:29.202982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.44827860593795776,"bbox":[392,106,435,148],"first_seen_time":"2026-02-05T23:56:29.202982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4417993128299713,"bbox":[110,25,137,40],"first_seen_time":"2026-02-05T23:56:29.202982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4369882345199585,"bbox":[360,29,381,48],"first_seen_time":"2026-02-05T23:56:29.202982","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3495333790779114,"bbox":[112,12,145,40],"first_seen_time":"2026-02-05T23:56:29.202982","duration":0.0}],"frame_number":15070,"task_type":"realtime"}	2026-02-05 23:56:29+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235629_frame15070_track0_car.jpg	\N	realtime	\N	\N	f	\N
262	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.5139014720916748,"bbox":[33,44,74,66],"first_seen_time":"2026-02-05T23:56:34.657166","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5004393458366394,"bbox":[393,112,438,153],"first_seen_time":"2026-02-05T23:56:34.657166","duration":0.0}],"frame_number":15120,"task_type":"realtime"}	2026-02-05 23:56:34+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235634_frame15120_track0_car.jpg	\N	realtime	\N	\N	f	\N
263	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.8487952947616577,"bbox":[448,242,550,342],"first_seen_time":"2026-02-05T23:56:40.137062","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31594452261924744,"bbox":[0,69,40,104],"first_seen_time":"2026-02-05T23:56:40.137062","duration":0.0}],"frame_number":15170,"task_type":"realtime"}	2026-02-05 23:56:40+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235640_frame15170_track0_car.jpg	\N	realtime	\N	\N	f	\N
264	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.8032705187797546,"bbox":[427,185,512,264],"first_seen_time":"2026-02-05T23:56:45.630419","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6217586994171143,"bbox":[193,8,218,27],"first_seen_time":"2026-02-05T23:56:45.630419","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49722009897232056,"bbox":[376,38,396,55],"first_seen_time":"2026-02-05T23:56:45.630419","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28700047731399536,"bbox":[105,16,130,33],"first_seen_time":"2026-02-05T23:56:45.630419","duration":0.0}],"frame_number":15220,"task_type":"realtime"}	2026-02-05 23:56:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235645_frame15220_track0_car.jpg	\N	realtime	\N	\N	f	\N
265	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.8433838486671448,"bbox":[145,252,244,356],"first_seen_time":"2026-02-05T23:56:51.072556","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6877365112304688,"bbox":[404,119,449,160],"first_seen_time":"2026-02-05T23:56:51.072556","duration":0.0}],"frame_number":15270,"task_type":"realtime"}	2026-02-05 23:56:51+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235651_frame15270_track0_car.jpg	\N	realtime	\N	\N	f	\N
266	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.730363667011261,"bbox":[162,19,191,43],"first_seen_time":"2026-02-05T23:56:56.450311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7117002606391907,"bbox":[37,29,76,54],"first_seen_time":"2026-02-05T23:56:56.450311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.693428099155426,"bbox":[390,94,435,135],"first_seen_time":"2026-02-05T23:56:56.450311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.522119402885437,"bbox":[372,24,390,41],"first_seen_time":"2026-02-05T23:56:56.450311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4850681722164154,"bbox":[127,300,230,357],"first_seen_time":"2026-02-05T23:56:56.450311","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3622654378414154,"bbox":[294,26,311,43],"first_seen_time":"2026-02-05T23:56:56.450311","duration":0.0}],"frame_number":15320,"task_type":"realtime"}	2026-02-05 23:56:56+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235656_frame15320_track0_car.jpg	\N	realtime	\N	\N	f	\N
268	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.679376482963562,"bbox":[72,46,110,67],"first_seen_time":"2026-02-05T23:57:07.172429","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6244163513183594,"bbox":[302,264,391,355],"first_seen_time":"2026-02-05T23:57:07.172429","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5527601838111877,"bbox":[373,68,402,96],"first_seen_time":"2026-02-05T23:57:07.172429","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5408393144607544,"bbox":[235,58,266,82],"first_seen_time":"2026-02-05T23:57:07.172429","duration":0.0}],"frame_number":15420,"task_type":"realtime"}	2026-02-05 23:57:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235707_frame15420_track0_car.jpg	\N	realtime	\N	\N	f	\N
269	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7567417025566101,"bbox":[155,249,254,355],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6966502666473389,"bbox":[240,106,283,149],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5096311569213867,"bbox":[370,48,396,71],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47569286823272705,"bbox":[117,34,144,51],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46800512075424194,"bbox":[287,49,310,67],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40968430042266846,"bbox":[6,36,43,61],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28623080253601074,"bbox":[325,57,353,87],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25689515471458435,"bbox":[22,34,52,59],"first_seen_time":"2026-02-05T23:57:12.407001","duration":0.0}],"frame_number":15470,"task_type":"realtime"}	2026-02-05 23:57:12+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235712_frame15470_track0_car.jpg	\N	realtime	\N	\N	f	\N
270	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7007270455360413,"bbox":[417,156,480,222],"first_seen_time":"2026-02-05T23:57:17.790394","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6774473190307617,"bbox":[320,44,342,65],"first_seen_time":"2026-02-05T23:57:17.790394","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6398782730102539,"bbox":[35,30,70,53],"first_seen_time":"2026-02-05T23:57:17.790394","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5748348832130432,"bbox":[289,24,312,53],"first_seen_time":"2026-02-05T23:57:17.790394","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3111586272716522,"bbox":[247,44,271,66],"first_seen_time":"2026-02-05T23:57:17.790394","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2695234417915344,"bbox":[215,6,232,18],"first_seen_time":"2026-02-05T23:57:17.790394","duration":0.0}],"frame_number":15520,"task_type":"realtime"}	2026-02-05 23:57:17+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235717_frame15520_track0_car.jpg	\N	realtime	\N	\N	f	\N
271	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.8025206327438354,"bbox":[456,248,563,352],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6775144338607788,"bbox":[221,163,276,216],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5808016061782837,"bbox":[325,90,358,121],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5723993182182312,"bbox":[158,28,184,47],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5571103096008301,"bbox":[385,100,428,135],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4959622323513031,"bbox":[288,52,309,69],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4913727343082428,"bbox":[129,14,151,32],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.43997079133987427,"bbox":[39,75,89,112],"first_seen_time":"2026-02-05T23:57:23.187477","duration":0.0}],"frame_number":15570,"task_type":"realtime"}	2026-02-05 23:57:23+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235723_frame15570_track0_car.jpg	\N	realtime	\N	\N	f	\N
272	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":4,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7705130577087402,"bbox":[157,32,183,49],"first_seen_time":"2026-02-05T23:57:28.695749","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7292854189872742,"bbox":[176,245,261,338],"first_seen_time":"2026-02-05T23:57:28.695749","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.486448734998703,"bbox":[388,79,425,118],"first_seen_time":"2026-02-05T23:57:28.695749","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4305422306060791,"bbox":[249,110,289,147],"first_seen_time":"2026-02-05T23:57:28.695749","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3256717622280121,"bbox":[388,78,425,118],"first_seen_time":"2026-02-05T23:57:28.695749","duration":0.0}],"frame_number":15620,"task_type":"realtime"}	2026-02-05 23:57:28+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235728_frame15620_track0_car.jpg	\N	realtime	\N	\N	f	\N
273	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.7139450907707214,"bbox":[408,124,453,168],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.677541971206665,"bbox":[174,227,258,319],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6513161659240723,"bbox":[88,53,130,81],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6328245997428894,"bbox":[326,50,352,73],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5284566879272461,"bbox":[369,62,398,82],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5215139985084534,"bbox":[191,15,209,31],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4114750325679779,"bbox":[271,73,299,102],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.340552419424057,"bbox":[70,35,104,53],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2745450735092163,"bbox":[298,30,316,43],"first_seen_time":"2026-02-05T23:57:34.174855","duration":0.0}],"frame_number":15670,"task_type":"realtime"}	2026-02-05 23:57:34+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235734_frame15670_track0_car.jpg	\N	realtime	\N	\N	f	\N
274	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7418791651725769,"bbox":[36,33,74,53],"first_seen_time":"2026-02-05T23:57:39.600316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6629030108451843,"bbox":[410,146,467,196],"first_seen_time":"2026-02-05T23:57:39.600316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5786777138710022,"bbox":[316,189,381,267],"first_seen_time":"2026-02-05T23:57:39.600316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5624659061431885,"bbox":[131,25,158,44],"first_seen_time":"2026-02-05T23:57:39.600316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49852272868156433,"bbox":[125,9,147,25],"first_seen_time":"2026-02-05T23:57:39.600316","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29980382323265076,"bbox":[126,7,158,38],"first_seen_time":"2026-02-05T23:57:39.600316","duration":0.0}],"frame_number":15720,"task_type":"realtime"}	2026-02-05 23:57:39+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235739_frame15720_track0_car.jpg	\N	realtime	\N	\N	f	\N
275	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7012717127799988,"bbox":[279,60,307,84],"first_seen_time":"2026-02-05T23:57:44.960510","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6769207119941711,"bbox":[402,124,452,171],"first_seen_time":"2026-02-05T23:57:44.960510","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5711147785186768,"bbox":[166,110,226,160],"first_seen_time":"2026-02-05T23:57:44.960510","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5143676996231079,"bbox":[324,98,356,129],"first_seen_time":"2026-02-05T23:57:44.960510","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4675672948360443,"bbox":[324,35,344,49],"first_seen_time":"2026-02-05T23:57:44.960510","duration":0.0}],"frame_number":15770,"task_type":"realtime"}	2026-02-05 23:57:44+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235745_frame15770_track0_car.jpg	\N	realtime	\N	\N	f	\N
276	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.755033016204834,"bbox":[457,268,580,353],"first_seen_time":"2026-02-05T23:57:50.419014","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6784370541572571,"bbox":[310,228,378,316],"first_seen_time":"2026-02-05T23:57:50.419014","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.561061441898346,"bbox":[385,47,406,66],"first_seen_time":"2026-02-05T23:57:50.419014","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5334556102752686,"bbox":[244,46,273,72],"first_seen_time":"2026-02-05T23:57:50.419014","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5306535959243774,"bbox":[104,48,150,75],"first_seen_time":"2026-02-05T23:57:50.419014","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2999347448348999,"bbox":[322,73,355,104],"first_seen_time":"2026-02-05T23:57:50.419014","duration":0.0}],"frame_number":15820,"task_type":"realtime"}	2026-02-05 23:57:50+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235750_frame15820_track0_car.jpg	\N	realtime	\N	\N	f	\N
277	car	江北初中监控安防任务	\N	{"total_count":1,"object_counts":{"car":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.3720817565917969,"bbox":[362,31,381,46],"first_seen_time":"2026-02-05T23:57:56.374177","duration":0.0}],"frame_number":15875,"task_type":"realtime"}	2026-02-05 23:57:56+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235756_frame15875_track0_car.jpg	\N	realtime	\N	\N	f	\N
278	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.6779012680053711,"bbox":[154,235,252,342],"first_seen_time":"2026-02-05T23:58:01.795676","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6568831205368042,"bbox":[291,41,314,64],"first_seen_time":"2026-02-05T23:58:01.795676","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5386337041854858,"bbox":[90,40,121,62],"first_seen_time":"2026-02-05T23:58:01.795676","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46676987409591675,"bbox":[271,87,307,121],"first_seen_time":"2026-02-05T23:58:01.795676","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4536113739013672,"bbox":[393,51,417,72],"first_seen_time":"2026-02-05T23:58:01.795676","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3693108558654785,"bbox":[499,326,587,355],"first_seen_time":"2026-02-05T23:58:01.795676","duration":0.0}],"frame_number":15925,"task_type":"realtime"}	2026-02-05 23:58:01+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235801_frame15925_track0_car.jpg	\N	realtime	\N	\N	f	\N
279	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7959293127059937,"bbox":[312,122,352,163],"first_seen_time":"2026-02-05T23:58:07.261548","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7947840690612793,"bbox":[430,176,527,268],"first_seen_time":"2026-02-05T23:58:07.261548","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4816395342350006,"bbox":[324,42,346,59],"first_seen_time":"2026-02-05T23:58:07.261548","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3337915539741516,"bbox":[291,30,309,47],"first_seen_time":"2026-02-05T23:58:07.261548","duration":0.0}],"frame_number":15975,"task_type":"realtime"}	2026-02-05 23:58:07+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235807_frame15975_track0_car.jpg	\N	realtime	\N	\N	f	\N
280	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7086862921714783,"bbox":[57,63,107,97],"first_seen_time":"2026-02-05T23:58:12.554783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47512418031692505,"bbox":[123,6,154,26],"first_seen_time":"2026-02-05T23:58:12.554783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3191862404346466,"bbox":[324,16,343,32],"first_seen_time":"2026-02-05T23:58:12.554783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28965047001838684,"bbox":[367,35,390,56],"first_seen_time":"2026-02-05T23:58:12.554783","duration":0.0}],"frame_number":16025,"task_type":"realtime"}	2026-02-05 23:58:12+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235812_frame16025_track0_car.jpg	\N	realtime	\N	\N	f	\N
281	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6317105889320374,"bbox":[318,63,345,88],"first_seen_time":"2026-02-05T23:58:18.031852","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6021118760108948,"bbox":[394,95,441,140],"first_seen_time":"2026-02-05T23:58:18.031852","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32273292541503906,"bbox":[377,30,397,46],"first_seen_time":"2026-02-05T23:58:18.031852","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.310669869184494,"bbox":[325,24,347,40],"first_seen_time":"2026-02-05T23:58:18.031852","duration":0.0}],"frame_number":16075,"task_type":"realtime"}	2026-02-05 23:58:18+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235818_frame16075_track0_car.jpg	\N	realtime	\N	\N	f	\N
282	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.8088954091072083,"bbox":[426,219,528,322],"first_seen_time":"2026-02-05T23:58:23.556493","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6018641591072083,"bbox":[82,14,119,37],"first_seen_time":"2026-02-05T23:58:23.556493","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47382932901382446,"bbox":[141,15,163,29],"first_seen_time":"2026-02-05T23:58:23.556493","duration":0.0}],"frame_number":16125,"task_type":"realtime"}	2026-02-05 23:58:23+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235823_frame16125_track0_car.jpg	\N	realtime	\N	\N	f	\N
283	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.8380377888679504,"bbox":[399,134,452,183],"first_seen_time":"2026-02-05T23:58:28.890095","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.8219518661499023,"bbox":[360,32,383,52],"first_seen_time":"2026-02-05T23:58:28.890095","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6934455633163452,"bbox":[65,65,111,92],"first_seen_time":"2026-02-05T23:58:28.890095","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6829356551170349,"bbox":[63,25,89,45],"first_seen_time":"2026-02-05T23:58:28.890095","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.558291494846344,"bbox":[411,53,441,78],"first_seen_time":"2026-02-05T23:58:28.890095","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5532415509223938,"bbox":[320,50,345,68],"first_seen_time":"2026-02-05T23:58:28.890095","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5195570588111877,"bbox":[123,10,160,31],"first_seen_time":"2026-02-05T23:58:28.890095","duration":0.0}],"frame_number":16175,"task_type":"realtime"}	2026-02-05 23:58:28+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235829_frame16175_track0_car.jpg	\N	realtime	\N	\N	f	\N
284	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.6700999736785889,"bbox":[56,32,95,58],"first_seen_time":"2026-02-05T23:58:34.279021","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6209768056869507,"bbox":[322,216,392,306],"first_seen_time":"2026-02-05T23:58:34.279021","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5834304690361023,"bbox":[272,77,300,104],"first_seen_time":"2026-02-05T23:58:34.279021","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4161127209663391,"bbox":[403,50,427,67],"first_seen_time":"2026-02-05T23:58:34.279021","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3556564450263977,"bbox":[357,25,375,40],"first_seen_time":"2026-02-05T23:58:34.279021","duration":0.0}],"frame_number":16225,"task_type":"realtime"}	2026-02-05 23:58:34+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235834_frame16225_track0_car.jpg	\N	realtime	\N	\N	f	\N
285	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.6077995896339417,"bbox":[378,77,411,107],"first_seen_time":"2026-02-05T23:58:39.696133","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42675501108169556,"bbox":[0,55,37,84],"first_seen_time":"2026-02-05T23:58:39.696133","duration":0.0}],"frame_number":16275,"task_type":"realtime"}	2026-02-05 23:58:39+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235839_frame16275_track0_car.jpg	\N	realtime	\N	\N	f	\N
286	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.677236020565033,"bbox":[77,52,121,86],"first_seen_time":"2026-02-05T23:58:45.043194","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49236616492271423,"bbox":[325,44,351,71],"first_seen_time":"2026-02-05T23:58:45.043194","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45101216435432434,"bbox":[0,51,48,78],"first_seen_time":"2026-02-05T23:58:45.043194","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37708449363708496,"bbox":[24,54,47,75],"first_seen_time":"2026-02-05T23:58:45.043194","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35695478320121765,"bbox":[372,60,400,82],"first_seen_time":"2026-02-05T23:58:45.043194","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.31836819648742676,"bbox":[353,16,372,30],"first_seen_time":"2026-02-05T23:58:45.043194","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28177428245544434,"bbox":[69,24,100,42],"first_seen_time":"2026-02-05T23:58:45.043194","duration":0.0}],"frame_number":16325,"task_type":"realtime"}	2026-02-05 23:58:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235845_frame16325_track0_car.jpg	\N	realtime	\N	\N	f	\N
287	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.4309898018836975,"bbox":[371,56,398,75],"first_seen_time":"2026-02-05T23:58:50.888914","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34600135684013367,"bbox":[135,23,159,42],"first_seen_time":"2026-02-05T23:58:50.888914","duration":0.0}],"frame_number":16380,"task_type":"realtime"}	2026-02-05 23:58:50+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235851_frame16380_track0_car.jpg	\N	realtime	\N	\N	f	\N
288	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.6845808029174805,"bbox":[217,155,274,207],"first_seen_time":"2026-02-05T23:58:56.288131","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5531385540962219,"bbox":[393,87,429,121],"first_seen_time":"2026-02-05T23:58:56.288131","duration":0.0}],"frame_number":16430,"task_type":"realtime"}	2026-02-05 23:58:56+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235856_frame16430_track0_car.jpg	\N	realtime	\N	\N	f	\N
289	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.7757078409194946,"bbox":[193,178,269,253],"first_seen_time":"2026-02-05T23:59:01.664010","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7673662304878235,"bbox":[382,64,415,103],"first_seen_time":"2026-02-05T23:59:01.664010","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5342884063720703,"bbox":[139,27,171,55],"first_seen_time":"2026-02-05T23:59:01.664010","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4756583571434021,"bbox":[0,39,27,70],"first_seen_time":"2026-02-05T23:59:01.664010","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38915470242500305,"bbox":[369,17,385,31],"first_seen_time":"2026-02-05T23:59:01.664010","duration":0.0}],"frame_number":16480,"task_type":"realtime"}	2026-02-05 23:59:01+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235901_frame16480_track0_car.jpg	\N	realtime	\N	\N	f	\N
290	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.6172702312469482,"bbox":[8,35,51,59],"first_seen_time":"2026-02-05T23:59:06.984775","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5662665963172913,"bbox":[294,24,314,41],"first_seen_time":"2026-02-05T23:59:06.984775","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5649837255477905,"bbox":[84,56,123,86],"first_seen_time":"2026-02-05T23:59:06.984775","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36108002066612244,"bbox":[100,30,135,55],"first_seen_time":"2026-02-05T23:59:06.984775","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29971733689308167,"bbox":[198,4,217,17],"first_seen_time":"2026-02-05T23:59:06.984775","duration":0.0}],"frame_number":16530,"task_type":"realtime"}	2026-02-05 23:59:06+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235907_frame16530_track0_car.jpg	\N	realtime	\N	\N	f	\N
291	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.7690343260765076,"bbox":[370,42,394,65],"first_seen_time":"2026-02-05T23:59:12.379339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6342869400978088,"bbox":[253,91,294,123],"first_seen_time":"2026-02-05T23:59:12.379339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4675530195236206,"bbox":[194,9,218,28],"first_seen_time":"2026-02-05T23:59:12.379339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4238007962703705,"bbox":[59,46,115,91],"first_seen_time":"2026-02-05T23:59:12.379339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4166589379310608,"bbox":[136,8,158,21],"first_seen_time":"2026-02-05T23:59:12.379339","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.41033321619033813,"bbox":[365,7,382,23],"first_seen_time":"2026-02-05T23:59:12.379339","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.37045910954475403,"bbox":[60,46,115,91],"first_seen_time":"2026-02-05T23:59:12.379339","duration":0.0}],"frame_number":16580,"task_type":"realtime"}	2026-02-05 23:59:12+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235912_frame16580_track0_car.jpg	\N	realtime	\N	\N	f	\N
292	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7995800971984863,"bbox":[76,198,170,271],"first_seen_time":"2026-02-05T23:59:17.733060","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7944245338439941,"bbox":[421,210,505,293],"first_seen_time":"2026-02-05T23:59:17.733060","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.37868478894233704,"bbox":[11,56,64,91],"first_seen_time":"2026-02-05T23:59:17.733060","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3524344265460968,"bbox":[167,12,192,29],"first_seen_time":"2026-02-05T23:59:17.733060","duration":0.0}],"frame_number":16630,"task_type":"realtime"}	2026-02-05 23:59:17+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235917_frame16630_track0_car.jpg	\N	realtime	\N	\N	f	\N
293	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.706611156463623,"bbox":[398,129,447,172],"first_seen_time":"2026-02-05T23:59:23.229276","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6256527900695801,"bbox":[248,121,291,161],"first_seen_time":"2026-02-05T23:59:23.229276","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.511268138885498,"bbox":[320,89,353,120],"first_seen_time":"2026-02-05T23:59:23.229276","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5044282674789429,"bbox":[361,33,382,52],"first_seen_time":"2026-02-05T23:59:23.229276","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.45310068130493164,"bbox":[119,11,143,28],"first_seen_time":"2026-02-05T23:59:23.229276","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.37178727984428406,"bbox":[312,177,388,276],"first_seen_time":"2026-02-05T23:59:23.229276","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3598315119743347,"bbox":[311,177,389,275],"first_seen_time":"2026-02-05T23:59:23.229276","duration":0.0}],"frame_number":16680,"task_type":"realtime"}	2026-02-05 23:59:23+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235923_frame16680_track0_car.jpg	\N	realtime	\N	\N	f	\N
294	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.6997928619384766,"bbox":[295,132,340,181],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6483606696128845,"bbox":[94,19,121,37],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6453602313995361,"bbox":[134,137,205,198],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6196881532669067,"bbox":[278,46,303,71],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5680533647537231,"bbox":[50,44,81,61],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4681814908981323,"bbox":[262,86,294,117],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33873477578163147,"bbox":[325,18,346,44],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2950442135334015,"bbox":[125,10,149,25],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.27367523312568665,"bbox":[0,81,21,108],"first_seen_time":"2026-02-05T23:59:28.701129","duration":0.0}],"frame_number":16730,"task_type":"realtime"}	2026-02-05 23:59:28+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235928_frame16730_track0_car.jpg	\N	realtime	\N	\N	f	\N
295	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7024244070053101,"bbox":[230,158,281,209],"first_seen_time":"2026-02-05T23:59:34.157783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.493293434381485,"bbox":[382,65,414,96],"first_seen_time":"2026-02-05T23:59:34.157783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4210224151611328,"bbox":[153,15,173,36],"first_seen_time":"2026-02-05T23:59:34.157783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4183311462402344,"bbox":[123,12,147,28],"first_seen_time":"2026-02-05T23:59:34.157783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3059546649456024,"bbox":[171,27,194,41],"first_seen_time":"2026-02-05T23:59:34.157783","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25719329714775085,"bbox":[300,5,319,29],"first_seen_time":"2026-02-05T23:59:34.157783","duration":0.0}],"frame_number":16780,"task_type":"realtime"}	2026-02-05 23:59:34+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235934_frame16780_track0_car.jpg	\N	realtime	\N	\N	f	\N
296	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.760316789150238,"bbox":[314,68,342,96],"first_seen_time":"2026-02-05T23:59:39.644383","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6369760632514954,"bbox":[28,29,64,58],"first_seen_time":"2026-02-05T23:59:39.644383","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5843872427940369,"bbox":[290,29,309,48],"first_seen_time":"2026-02-05T23:59:39.644383","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5383803248405457,"bbox":[217,71,254,102],"first_seen_time":"2026-02-05T23:59:39.644383","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5276032090187073,"bbox":[277,54,304,74],"first_seen_time":"2026-02-05T23:59:39.644383","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5175870656967163,"bbox":[85,19,112,36],"first_seen_time":"2026-02-05T23:59:39.644383","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.2640511691570282,"bbox":[473,317,588,355],"first_seen_time":"2026-02-05T23:59:39.644383","duration":0.0}],"frame_number":16830,"task_type":"realtime"}	2026-02-05 23:59:39+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235939_frame16830_track0_car.jpg	\N	realtime	\N	\N	f	\N
297	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.6685361266136169,"bbox":[403,162,463,217],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6526637077331543,"bbox":[319,150,369,203],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5586796998977661,"bbox":[187,15,209,32],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5267010927200317,"bbox":[117,47,151,71],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4625270962715149,"bbox":[273,79,301,105],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4127356708049774,"bbox":[157,8,176,23],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36917757987976074,"bbox":[104,26,137,54],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34437689185142517,"bbox":[73,24,103,41],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2738286256790161,"bbox":[374,40,397,61],"first_seen_time":"2026-02-05T23:59:45.100910","duration":0.0}],"frame_number":16880,"task_type":"realtime"}	2026-02-05 23:59:45+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235945_frame16880_track0_car.jpg	\N	realtime	\N	\N	f	\N
298	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.70663982629776,"bbox":[384,60,412,82],"first_seen_time":"2026-02-05T23:59:50.507846","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5774562954902649,"bbox":[271,74,299,101],"first_seen_time":"2026-02-05T23:59:50.507846","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5768511295318604,"bbox":[123,46,154,67],"first_seen_time":"2026-02-05T23:59:50.507846","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5421728491783142,"bbox":[291,33,311,48],"first_seen_time":"2026-02-05T23:59:50.507846","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.25526660680770874,"bbox":[329,26,349,40],"first_seen_time":"2026-02-05T23:59:50.507846","duration":0.0}],"frame_number":16930,"task_type":"realtime"}	2026-02-05 23:59:50+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235950_frame16930_track0_car.jpg	\N	realtime	\N	\N	f	\N
299	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7867268323898315,"bbox":[185,211,271,305],"first_seen_time":"2026-02-05T23:59:55.916321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6572839021682739,"bbox":[381,66,410,91],"first_seen_time":"2026-02-05T23:59:55.916321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6454108953475952,"bbox":[71,20,102,40],"first_seen_time":"2026-02-05T23:59:55.916321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5462278723716736,"bbox":[32,59,63,88],"first_seen_time":"2026-02-05T23:59:55.916321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49279195070266724,"bbox":[323,79,353,105],"first_seen_time":"2026-02-05T23:59:55.916321","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3737831711769104,"bbox":[15,68,52,91],"first_seen_time":"2026-02-05T23:59:55.916321","duration":0.0}],"frame_number":16980,"task_type":"realtime"}	2026-02-05 23:59:55+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260205_235956_frame16980_track0_car.jpg	\N	realtime	\N	\N	f	\N
300	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.8164193630218506,"bbox":[82,182,180,262],"first_seen_time":"2026-02-06T00:00:01.346485","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6644556522369385,"bbox":[296,26,318,43],"first_seen_time":"2026-02-06T00:00:01.346485","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6387437582015991,"bbox":[375,56,403,78],"first_seen_time":"2026-02-06T00:00:01.346485","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.521026611328125,"bbox":[310,249,395,354],"first_seen_time":"2026-02-06T00:00:01.346485","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.48298966884613037,"bbox":[415,123,463,167],"first_seen_time":"2026-02-06T00:00:01.346485","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47140219807624817,"bbox":[247,41,275,65],"first_seen_time":"2026-02-06T00:00:01.346485","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3522135317325592,"bbox":[327,50,347,68],"first_seen_time":"2026-02-06T00:00:01.346485","duration":0.0}],"frame_number":17030,"task_type":"realtime"}	2026-02-06 00:00:01+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000001_frame17030_track0_car.jpg	\N	realtime	\N	\N	f	\N
301	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.6596518754959106,"bbox":[224,149,275,200],"first_seen_time":"2026-02-06T00:00:06.648545","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5995895266532898,"bbox":[387,94,426,126],"first_seen_time":"2026-02-06T00:00:06.648545","duration":0.0}],"frame_number":17080,"task_type":"realtime"}	2026-02-06 00:00:06+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000006_frame17080_track0_car.jpg	\N	realtime	\N	\N	f	\N
302	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7185003161430359,"bbox":[454,168,516,222],"first_seen_time":"2026-02-06T00:00:11.976443","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7107085585594177,"bbox":[111,51,150,73],"first_seen_time":"2026-02-06T00:00:11.976443","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6781739592552185,"bbox":[223,165,284,228],"first_seen_time":"2026-02-06T00:00:11.976443","duration":0.0}],"frame_number":17130,"task_type":"realtime"}	2026-02-06 00:00:11+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000012_frame17130_track0_car.jpg	\N	realtime	\N	\N	f	\N
303	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8138760328292847,"bbox":[312,153,365,209],"first_seen_time":"2026-02-06T00:00:17.400922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7187185883522034,"bbox":[420,138,473,185],"first_seen_time":"2026-02-06T00:00:17.400922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40946149826049805,"bbox":[250,100,290,139],"first_seen_time":"2026-02-06T00:00:17.400922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3989887833595276,"bbox":[290,48,313,67],"first_seen_time":"2026-02-06T00:00:17.400922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3510587513446808,"bbox":[382,31,400,47],"first_seen_time":"2026-02-06T00:00:17.400922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2509627938270569,"bbox":[299,23,319,39],"first_seen_time":"2026-02-06T00:00:17.400922","duration":0.0}],"frame_number":17180,"task_type":"realtime"}	2026-02-06 00:00:17+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000017_frame17180_track0_car.jpg	\N	realtime	\N	\N	f	\N
304	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":3,"truck":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.5907796621322632,"bbox":[318,76,348,102],"first_seen_time":"2026-02-06T00:00:22.886851","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5130516290664673,"bbox":[324,26,344,46],"first_seen_time":"2026-02-06T00:00:22.886851","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4751065671443939,"bbox":[208,200,280,275],"first_seen_time":"2026-02-06T00:00:22.886851","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.44139859080314636,"bbox":[208,200,279,274],"first_seen_time":"2026-02-06T00:00:22.886851","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.40396609902381897,"bbox":[404,89,459,167],"first_seen_time":"2026-02-06T00:00:22.886851","duration":0.0}],"frame_number":17230,"task_type":"realtime"}	2026-02-06 00:00:22+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000023_frame17230_track0_car.jpg	\N	realtime	\N	\N	f	\N
305	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":1,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.2728196084499359,"bbox":[292,319,374,356],"first_seen_time":"2026-02-06T00:00:28.326833","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.25390344858169556,"bbox":[397,78,431,109],"first_seen_time":"2026-02-06T00:00:28.326833","duration":0.0}],"frame_number":17280,"task_type":"realtime"}	2026-02-06 00:00:28+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000028_frame17280_track0_car.jpg	\N	realtime	\N	\N	f	\N
306	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6628252863883972,"bbox":[376,55,407,86],"first_seen_time":"2026-02-06T00:00:33.699362","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4968279004096985,"bbox":[321,37,343,53],"first_seen_time":"2026-02-06T00:00:33.699362","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3641248047351837,"bbox":[147,31,175,52],"first_seen_time":"2026-02-06T00:00:33.699362","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2520020306110382,"bbox":[304,5,320,19],"first_seen_time":"2026-02-06T00:00:33.699362","duration":0.0}],"frame_number":17330,"task_type":"realtime"}	2026-02-06 00:00:33+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000033_frame17330_track0_car.jpg	\N	realtime	\N	\N	f	\N
307	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.8542593121528625,"bbox":[308,221,373,302],"first_seen_time":"2026-02-06T00:00:39.067597","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.8478469848632812,"bbox":[501,162,588,223],"first_seen_time":"2026-02-06T00:00:39.067597","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6994316577911377,"bbox":[90,31,119,47],"first_seen_time":"2026-02-06T00:00:39.067597","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6266435384750366,"bbox":[385,99,428,141],"first_seen_time":"2026-02-06T00:00:39.067597","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5430317521095276,"bbox":[26,28,68,56],"first_seen_time":"2026-02-06T00:00:39.067597","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4120585024356842,"bbox":[133,25,160,43],"first_seen_time":"2026-02-06T00:00:39.067597","duration":0.0}],"frame_number":17380,"task_type":"realtime"}	2026-02-06 00:00:39+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000039_frame17380_track0_car.jpg	\N	realtime	\N	\N	f	\N
308	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7783978581428528,"bbox":[376,70,406,99],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7709980010986328,"bbox":[473,135,534,177],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6262078881263733,"bbox":[395,33,416,52],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5526257753372192,"bbox":[325,27,344,43],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5323019027709961,"bbox":[78,19,116,52],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.42476287484169006,"bbox":[0,48,17,70],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4212942123413086,"bbox":[142,5,187,22],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2793687880039215,"bbox":[356,20,374,35],"first_seen_time":"2026-02-06T00:00:44.472476","duration":0.0}],"frame_number":17430,"task_type":"realtime"}	2026-02-06 00:00:44+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000044_frame17430_track0_car.jpg	\N	realtime	\N	\N	f	\N
309	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.619735598564148,"bbox":[326,97,365,131],"first_seen_time":"2026-02-06T00:00:49.918436","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5545983910560608,"bbox":[290,42,310,58],"first_seen_time":"2026-02-06T00:00:49.918436","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5278916954994202,"bbox":[466,317,566,355],"first_seen_time":"2026-02-06T00:00:49.918436","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36398613452911377,"bbox":[139,19,160,31],"first_seen_time":"2026-02-06T00:00:49.918436","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3156434893608093,"bbox":[387,31,406,45],"first_seen_time":"2026-02-06T00:00:49.918436","duration":0.0}],"frame_number":17480,"task_type":"realtime"}	2026-02-06 00:00:49+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000050_frame17480_track0_car.jpg	\N	realtime	\N	\N	f	\N
310	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"truck":2,"car":3},"detections":[{"track_id":0,"class_name":"truck","confidence":0.5342763066291809,"bbox":[311,182,387,279],"first_seen_time":"2026-02-06T00:00:55.385005","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5157039761543274,"bbox":[365,44,390,68],"first_seen_time":"2026-02-06T00:00:55.385005","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.5015859603881836,"bbox":[432,213,524,305],"first_seen_time":"2026-02-06T00:00:55.385005","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.47673287987709045,"bbox":[432,214,524,305],"first_seen_time":"2026-02-06T00:00:55.385005","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2696506083011627,"bbox":[155,10,177,24],"first_seen_time":"2026-02-06T00:00:55.385005","duration":0.0}],"frame_number":17530,"task_type":"realtime"}	2026-02-06 00:00:55+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000055_frame17530_track0_truck.jpg	\N	realtime	\N	\N	f	\N
311	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.6330986618995667,"bbox":[430,210,524,298],"first_seen_time":"2026-02-06T00:01:00.818721","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4737471044063568,"bbox":[100,28,126,42],"first_seen_time":"2026-02-06T00:01:00.818721","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4198142886161804,"bbox":[0,44,27,67],"first_seen_time":"2026-02-06T00:01:00.818721","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28764060139656067,"bbox":[363,36,384,52],"first_seen_time":"2026-02-06T00:01:00.818721","duration":0.0}],"frame_number":17580,"task_type":"realtime"}	2026-02-06 00:01:00+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000100_frame17580_track0_car.jpg	\N	realtime	\N	\N	f	\N
312	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.6771496534347534,"bbox":[88,37,121,61],"first_seen_time":"2026-02-06T00:01:06.274029","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5991510152816772,"bbox":[29,40,57,56],"first_seen_time":"2026-02-06T00:01:06.274029","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36835888028144836,"bbox":[364,38,385,55],"first_seen_time":"2026-02-06T00:01:06.274029","duration":0.0}],"frame_number":17630,"task_type":"realtime"}	2026-02-06 00:01:06+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000106_frame17630_track0_car.jpg	\N	realtime	\N	\N	f	\N
313	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":2,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.463942289352417,"bbox":[32,43,74,67],"first_seen_time":"2026-02-06T00:01:11.711188","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3757411241531372,"bbox":[393,113,438,152],"first_seen_time":"2026-02-06T00:01:11.711188","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.3220466673374176,"bbox":[393,113,438,153],"first_seen_time":"2026-02-06T00:01:11.711188","duration":0.0}],"frame_number":17680,"task_type":"realtime"}	2026-02-06 00:01:11+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000111_frame17680_track0_car.jpg	\N	realtime	\N	\N	f	\N
314	car	江北初中监控安防任务	\N	{"total_count":2,"object_counts":{"car":2},"detections":[{"track_id":0,"class_name":"car","confidence":0.8408365845680237,"bbox":[448,241,550,341],"first_seen_time":"2026-02-06T00:01:17.157737","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.35496196150779724,"bbox":[0,71,40,105],"first_seen_time":"2026-02-06T00:01:17.157737","duration":0.0}],"frame_number":17730,"task_type":"realtime"}	2026-02-06 00:01:17+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000117_frame17730_track0_car.jpg	\N	realtime	\N	\N	f	\N
315	car	江北初中监控安防任务	\N	{"total_count":4,"object_counts":{"car":4},"detections":[{"track_id":0,"class_name":"car","confidence":0.7927746176719666,"bbox":[426,185,512,264],"first_seen_time":"2026-02-06T00:01:22.508015","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6099117398262024,"bbox":[193,9,218,27],"first_seen_time":"2026-02-06T00:01:22.508015","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.578201413154602,"bbox":[376,38,396,55],"first_seen_time":"2026-02-06T00:01:22.508015","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28834694623947144,"bbox":[283,47,305,68],"first_seen_time":"2026-02-06T00:01:22.508015","duration":0.0}],"frame_number":17780,"task_type":"realtime"}	2026-02-06 00:01:22+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000122_frame17780_track0_car.jpg	\N	realtime	\N	\N	f	\N
316	car	江北初中监控安防任务	\N	{"total_count":5,"object_counts":{"car":5},"detections":[{"track_id":0,"class_name":"car","confidence":0.8058328032493591,"bbox":[364,31,384,49],"first_seen_time":"2026-02-06T00:01:27.943127","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7178747057914734,"bbox":[276,58,304,81],"first_seen_time":"2026-02-06T00:01:27.943127","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5415255427360535,"bbox":[107,14,132,31],"first_seen_time":"2026-02-06T00:01:27.943127","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5184090733528137,"bbox":[173,14,197,39],"first_seen_time":"2026-02-06T00:01:27.943127","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.32164764404296875,"bbox":[0,70,50,100],"first_seen_time":"2026-02-06T00:01:27.943127","duration":0.0}],"frame_number":17830,"task_type":"realtime"}	2026-02-06 00:01:27+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000128_frame17830_track0_car.jpg	\N	realtime	\N	\N	f	\N
317	car	江北初中监控安防任务	\N	{"total_count":3,"object_counts":{"car":3},"detections":[{"track_id":0,"class_name":"car","confidence":0.7398937940597534,"bbox":[185,105,231,143],"first_seen_time":"2026-02-06T00:01:33.333501","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6706230044364929,"bbox":[390,117,435,163],"first_seen_time":"2026-02-06T00:01:33.333501","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.55308997631073,"bbox":[139,24,163,39],"first_seen_time":"2026-02-06T00:01:33.333501","duration":0.0}],"frame_number":17880,"task_type":"realtime"}	2026-02-06 00:01:33+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000133_frame17880_track0_car.jpg	\N	realtime	\N	\N	f	\N
318	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":6,"truck":1},"detections":[{"track_id":0,"class_name":"car","confidence":0.8849018216133118,"bbox":[150,229,244,322],"first_seen_time":"2026-02-06T00:01:38.666508","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5973473191261292,"bbox":[81,19,109,39],"first_seen_time":"2026-02-06T00:01:38.666508","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5214740037918091,"bbox":[272,78,302,105],"first_seen_time":"2026-02-06T00:01:38.666508","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.49073415994644165,"bbox":[381,82,414,111],"first_seen_time":"2026-02-06T00:01:38.666508","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40290042757987976,"bbox":[322,102,363,151],"first_seen_time":"2026-02-06T00:01:38.666508","duration":0.0},{"track_id":0,"class_name":"truck","confidence":0.39202263951301575,"bbox":[321,102,364,151],"first_seen_time":"2026-02-06T00:01:38.666508","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.29220324754714966,"bbox":[163,17,184,31],"first_seen_time":"2026-02-06T00:01:38.666508","duration":0.0}],"frame_number":17930,"task_type":"realtime"}	2026-02-06 00:01:38+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000138_frame17930_track0_car.jpg	\N	realtime	\N	\N	f	\N
319	car	江北初中监控安防任务	\N	{"total_count":7,"object_counts":{"car":7},"detections":[{"track_id":0,"class_name":"car","confidence":0.7949708104133606,"bbox":[311,78,342,109],"first_seen_time":"2026-02-06T00:01:43.924922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7685040831565857,"bbox":[40,29,78,52],"first_seen_time":"2026-02-06T00:01:43.924922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7089719176292419,"bbox":[275,58,304,80],"first_seen_time":"2026-02-06T00:01:43.924922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6941384673118591,"bbox":[288,30,308,51],"first_seen_time":"2026-02-06T00:01:43.924922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6275084018707275,"bbox":[95,17,120,33],"first_seen_time":"2026-02-06T00:01:43.924922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.33050158619880676,"bbox":[207,80,246,114],"first_seen_time":"2026-02-06T00:01:43.924922","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2900069057941437,"bbox":[0,60,16,85],"first_seen_time":"2026-02-06T00:01:43.924922","duration":0.0}],"frame_number":17980,"task_type":"realtime"}	2026-02-06 00:01:43+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000144_frame17980_track0_car.jpg	\N	realtime	\N	\N	f	\N
320	car	江北初中监控安防任务	\N	{"total_count":8,"object_counts":{"car":8},"detections":[{"track_id":0,"class_name":"car","confidence":0.7189972400665283,"bbox":[411,185,484,249],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6383872032165527,"bbox":[319,173,373,236],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5733511447906494,"bbox":[86,20,113,38],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5729004144668579,"bbox":[194,13,214,29],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4172726273536682,"bbox":[267,90,299,119],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.4100685715675354,"bbox":[161,5,183,21],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3591573238372803,"bbox":[376,43,399,70],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.2762645483016968,"bbox":[117,22,145,49],"first_seen_time":"2026-02-06T00:01:49.244056","duration":0.0}],"frame_number":18030,"task_type":"realtime"}	2026-02-06 00:01:49+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000149_frame18030_track0_car.jpg	\N	realtime	\N	\N	f	\N
321	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.7205962538719177,"bbox":[416,151,477,212],"first_seen_time":"2026-02-06T00:01:54.682353","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7178460955619812,"bbox":[68,60,113,92],"first_seen_time":"2026-02-06T00:01:54.682353","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5658938884735107,"bbox":[403,111,446,150],"first_seen_time":"2026-02-06T00:01:54.682353","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5507593750953674,"bbox":[193,178,269,254],"first_seen_time":"2026-02-06T00:01:54.682353","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.40406206250190735,"bbox":[369,55,393,75],"first_seen_time":"2026-02-06T00:01:54.682353","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3736773431301117,"bbox":[184,22,205,35],"first_seen_time":"2026-02-06T00:01:54.682353","duration":0.0}],"frame_number":18080,"task_type":"realtime"}	2026-02-06 00:01:54+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000154_frame18080_track0_car.jpg	\N	realtime	\N	\N	f	\N
322	car	江北初中监控安防任务	\N	{"total_count":9,"object_counts":{"car":9},"detections":[{"track_id":0,"class_name":"car","confidence":0.8309453129768372,"bbox":[450,236,549,338],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.7501624226570129,"bbox":[226,153,279,205],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.6655747294425964,"bbox":[155,29,181,49],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5870028734207153,"bbox":[127,14,149,34],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5288869738578796,"bbox":[326,87,358,118],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.5038555860519409,"bbox":[384,98,420,130],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.46601274609565735,"bbox":[55,39,94,57],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3738081753253937,"bbox":[5,44,29,61],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.28451329469680786,"bbox":[289,50,309,67],"first_seen_time":"2026-02-06T00:02:00.127642","duration":0.0}],"frame_number":18130,"task_type":"realtime"}	2026-02-06 00:02:00+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000200_frame18130_track0_car.jpg	\N	realtime	\N	\N	f	\N
323	car	江北初中监控安防任务	\N	{"total_count":6,"object_counts":{"car":6},"detections":[{"track_id":0,"class_name":"car","confidence":0.536940336227417,"bbox":[20,44,60,70],"first_seen_time":"2026-02-06T00:02:05.603734","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.381393700838089,"bbox":[150,3,170,17],"first_seen_time":"2026-02-06T00:02:05.603734","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.38045698404312134,"bbox":[173,12,193,28],"first_seen_time":"2026-02-06T00:02:05.603734","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.36077404022216797,"bbox":[284,44,304,60],"first_seen_time":"2026-02-06T00:02:05.603734","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.34780704975128174,"bbox":[374,14,394,42],"first_seen_time":"2026-02-06T00:02:05.603734","duration":0.0},{"track_id":0,"class_name":"car","confidence":0.3171614110469818,"bbox":[396,40,418,55],"first_seen_time":"2026-02-06T00:02:05.603734","duration":0.0}],"frame_number":18180,"task_type":"realtime"}	2026-02-06 00:02:05+08	1770328136613922767	大门设备	/app/alert_images/task_1/1770328136613922767/20260206_000205_frame18180_track0_car.jpg	\N	realtime	\N	\N	f	\N
\.


--
-- Data for Name: algorithm_model_service; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.algorithm_model_service (id, task_id, service_name, service_url, service_type, model_id, threshold, request_method, request_headers, request_body_template, timeout, is_enabled, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: algorithm_task; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.algorithm_task (id, task_name, task_code, task_type, model_ids, model_names, extract_interval, rtmp_input_url, rtmp_output_url, tracking_enabled, tracking_similarity_threshold, tracking_max_age, tracking_smooth_alpha, alert_event_enabled, alert_notification_enabled, alert_notification_config, alarm_suppress_time, last_notify_time, space_id, cron_expression, frame_skip, status, is_enabled, run_status, exception_reason, service_server_ip, service_port, service_process_id, service_last_heartbeat, service_log_path, total_frames, total_detections, total_captures, last_process_time, last_success_time, last_capture_time, description, defense_mode, defense_schedule, created_at, updated_at) FROM stdin;
1	江北初中监控安防任务	REALTIME_TASK_0EBD92CE	realtime	[-1]	yolo11n.pt (默认模型)	25	\N	\N	f	0.2	25	0.25	t	f	\N	300	\N	\N	\N	25	0	t	stopped	\N	192.168.43.143	\N	93	2026-02-06 00:02:07.434036	/app/logs/task_1	0	0	0	\N	\N	\N	\N	full	[[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]]	2026-02-05 21:50:13.537894	2026-02-06 00:02:07.434259
\.


--
-- Data for Name: algorithm_task_device; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.algorithm_task_device (task_id, device_id, created_at) FROM stdin;
6	1770324865416716433	2026-02-05 20:59:17.98074
1	1770328136613922767	2026-02-05 21:50:13.542769
\.


--
-- Data for Name: detection_region; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.detection_region (id, task_id, region_name, region_type, points, image_id, algorithm_type, algorithm_model_id, algorithm_threshold, algorithm_enabled, color, opacity, is_enabled, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: device; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.device (id, name, source, rtmp_stream, http_stream, ai_rtmp_stream, ai_http_stream, stream, ip, port, username, password, mac, manufacturer, model, firmware_version, serial_number, hardware_id, support_move, support_zoom, nvr_id, nvr_channel, enable_forward, auto_snap_enabled, directory_id, cover_image_path, created_at, updated_at) FROM stdin;
1770328136613922767	大门设备	rtmp://localhost:1935/live/1764341204704370850	rtmp://localhost:1935/live/1764341204704370859	http://localhost:8080/live/1764341204704370859.flv	rtmp://localhost:1935/ai/1770328136613922767	http://localhost:8080/ai/1770328136613922767.flv	0	localhost	554	http://localhost:8080/ai/live/1764341204704370885.flv	sk-ad119d177aaf41048377463ef628658e		EasyAIoT	Camera-EasyAIoT				f	f	\N	0	\N	f	\N	\N	2026-02-05 21:48:56.618211	2026-02-05 21:49:12.776039
\.


--
-- Data for Name: device_detection_region; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.device_detection_region (id, device_id, region_name, region_type, points, image_id, color, opacity, is_enabled, sort_order, model_ids, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: device_directory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.device_directory (id, name, parent_id, description, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: device_storage_config; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.device_storage_config (id, device_id, snap_storage_bucket, snap_storage_max_size, snap_storage_cleanup_enabled, snap_storage_cleanup_threshold, snap_storage_cleanup_ratio, video_storage_bucket, video_storage_max_size, video_storage_cleanup_enabled, video_storage_cleanup_threshold, video_storage_cleanup_ratio, last_snap_cleanup_time, last_video_cleanup_time, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: frame_extractor; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.frame_extractor (id, extractor_name, extractor_code, extractor_type, "interval", description, is_enabled, status, server_ip, port, process_id, last_heartbeat, log_path, task_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: image; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.image (id, filename, original_filename, path, width, height, created_at, device_id) FROM stdin;
\.


--
-- Data for Name: llm_config; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.llm_config (id, name, service_type, vendor, model_type, model_name, base_url, api_key, api_version, temperature, max_tokens, timeout, is_active, status, last_test_time, last_test_result, description, icon_url, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: llm_inference_record; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.llm_inference_record (id, record_name, llm_model_id, input_type, input_intent, input_image_path, input_video_path, output_text, output_json, output_image_path, output_video_path, status, error_message, inference_time, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: nvr; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.nvr (id, ip, username, password, name, model) FROM stdin;
\.


--
-- Data for Name: playback; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.playback (id, file_path, event_time, device_id, device_name, duration, thumbnail_path, file_size, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: pusher; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pusher (id, pusher_name, pusher_code, video_stream_enabled, video_stream_url, device_rtmp_mapping, video_stream_format, video_stream_quality, event_alert_enabled, event_alert_url, event_alert_method, event_alert_format, event_alert_headers, event_alert_template, description, is_enabled, status, server_ip, port, process_id, last_heartbeat, log_path, task_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: record_space; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.record_space (id, space_name, space_code, bucket_name, save_mode, save_time, description, device_id, created_at, updated_at) FROM stdin;
1	大门设备	RECORD_59E49615	record-space	0	0	设备 1770324865416716433 的自动创建监控录像空间	1770324865416716433	2026-02-05 20:54:25.457386	2026-02-05 20:54:25.457388
2	大门设备	RECORD_8DFA2359	record-space	0	0	设备 1770328136613922767 的自动创建监控录像空间	1770328136613922767	2026-02-05 21:48:56.651333	2026-02-05 21:48:56.651334
\.


--
-- Data for Name: region_model_service; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.region_model_service (id, region_id, service_name, service_url, service_type, model_id, threshold, request_method, request_headers, request_body_template, timeout, is_enabled, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: regulation_rule; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.regulation_rule (id, rule_name, rule_code, scene_type, rule_type, rule_description, severity, is_enabled, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: regulation_rule_detail; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.regulation_rule_detail (id, regulation_rule_id, rule_name, rule_description, priority, trigger_conditions, is_enabled, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: snap_space; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snap_space (id, space_name, space_code, bucket_name, save_mode, save_time, description, device_id, created_at, updated_at) FROM stdin;
1	大门设备	SPACE_D7233361	snap-space	0	0	设备 1770324865416716433 的自动创建抓拍空间	1770324865416716433	2026-02-05 20:54:25.440241	2026-02-05 20:54:25.440242
2	大门设备	SPACE_EA9432D8	snap-space	0	0	设备 1770328136613922767 的自动创建抓拍空间	1770328136613922767	2026-02-05 21:48:56.638303	2026-02-05 21:48:56.638304
\.


--
-- Data for Name: snap_task; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snap_task (id, task_name, task_code, space_id, device_id, pusher_id, capture_type, cron_expression, frame_skip, algorithm_enabled, algorithm_type, algorithm_model_id, algorithm_threshold, algorithm_night_mode, alarm_enabled, alarm_type, phone_number, email, notify_users, notify_methods, alarm_suppress_time, last_notify_time, auto_filename, custom_filename_prefix, status, is_enabled, exception_reason, run_status, total_captures, last_capture_time, last_success_time, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sorter; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sorter (id, sorter_name, sorter_code, sorter_type, sort_order, description, is_enabled, status, server_ip, port, process_id, last_heartbeat, log_path, task_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: stream_forward_task; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stream_forward_task (id, task_name, task_code, output_format, output_quality, output_bitrate, status, is_enabled, exception_reason, service_server_ip, service_port, service_process_id, service_last_heartbeat, service_log_path, total_streams, last_process_time, last_success_time, description, created_at, updated_at) FROM stdin;
2	大门设备-推流转发	STREAM_FORWARD_1463DDF5	rtmp	high	\N	0	t	所有缓流器线程已退出	192.168.43.143	6000	110	2026-02-06 00:02:05.859392	/app/logs/stream_forward_task_2	1	\N	2026-02-05 21:49:24.166654	为设备 大门设备 自动创建的推流转发任务	2026-02-05 21:48:56.661281	2026-02-06 00:02:05.85982
\.


--
-- Data for Name: stream_forward_task_device; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stream_forward_task_device (stream_forward_task_id, device_id, created_at) FROM stdin;
2	1770328136613922767	2026-02-05 21:48:56.664624
\.


--
-- Data for Name: streaming_session; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.streaming_session (id, llm_model_id, llm_model_name, prompt, video_config, status, websocket_status, processed_frames, duration_seconds, created_at, updated_at, started_at, stopped_at) FROM stdin;
\.


--
-- Data for Name: tracking_target; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tracking_target (id, task_id, device_id, device_name, track_id, class_id, class_name, first_seen_time, last_seen_time, leave_time, duration, first_seen_frame, last_seen_frame, total_detections, information, created_at, updated_at) FROM stdin;
\.


--
-- Name: alert_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.alert_id_seq', 323, true);


--
-- Name: algorithm_model_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.algorithm_model_service_id_seq', 1, false);


--
-- Name: algorithm_task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.algorithm_task_id_seq', 1, true);


--
-- Name: detection_region_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.detection_region_id_seq', 1, false);


--
-- Name: device_detection_region_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.device_detection_region_id_seq', 1, false);


--
-- Name: device_directory_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.device_directory_id_seq', 1, false);


--
-- Name: device_storage_config_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.device_storage_config_id_seq', 1, false);


--
-- Name: frame_extractor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.frame_extractor_id_seq', 1, false);


--
-- Name: image_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.image_id_seq', 1, false);


--
-- Name: llm_config_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.llm_config_id_seq', 1, false);


--
-- Name: llm_inference_record_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.llm_inference_record_id_seq', 1, false);


--
-- Name: nvr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nvr_id_seq', 1, false);


--
-- Name: playback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.playback_id_seq', 1, false);


--
-- Name: pusher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pusher_id_seq', 1, false);


--
-- Name: record_space_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.record_space_id_seq', 2, true);


--
-- Name: region_model_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.region_model_service_id_seq', 1, false);


--
-- Name: regulation_rule_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.regulation_rule_detail_id_seq', 1, false);


--
-- Name: regulation_rule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.regulation_rule_id_seq', 1, false);


--
-- Name: snap_space_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.snap_space_id_seq', 2, true);


--
-- Name: snap_task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.snap_task_id_seq', 1, false);


--
-- Name: sorter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sorter_id_seq', 1, false);


--
-- Name: stream_forward_task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.stream_forward_task_id_seq', 2, true);


--
-- Name: tracking_target_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tracking_target_id_seq', 1, false);


--
-- Name: alert alert_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert
    ADD CONSTRAINT alert_pkey PRIMARY KEY (id);


--
-- Name: algorithm_model_service algorithm_model_service_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.algorithm_model_service
    ADD CONSTRAINT algorithm_model_service_pkey PRIMARY KEY (id);


--
-- Name: algorithm_task_device algorithm_task_device_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.algorithm_task_device
    ADD CONSTRAINT algorithm_task_device_pkey PRIMARY KEY (task_id, device_id);


--
-- Name: algorithm_task algorithm_task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.algorithm_task
    ADD CONSTRAINT algorithm_task_pkey PRIMARY KEY (id);


--
-- Name: algorithm_task algorithm_task_task_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.algorithm_task
    ADD CONSTRAINT algorithm_task_task_code_key UNIQUE (task_code);


--
-- Name: detection_region detection_region_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_region
    ADD CONSTRAINT detection_region_pkey PRIMARY KEY (id);


--
-- Name: device_detection_region device_detection_region_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_detection_region
    ADD CONSTRAINT device_detection_region_pkey PRIMARY KEY (id);


--
-- Name: device_directory device_directory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_directory
    ADD CONSTRAINT device_directory_pkey PRIMARY KEY (id);


--
-- Name: device device_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- Name: device_storage_config device_storage_config_device_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_storage_config
    ADD CONSTRAINT device_storage_config_device_id_key UNIQUE (device_id);


--
-- Name: device_storage_config device_storage_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_storage_config
    ADD CONSTRAINT device_storage_config_pkey PRIMARY KEY (id);


--
-- Name: frame_extractor frame_extractor_extractor_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frame_extractor
    ADD CONSTRAINT frame_extractor_extractor_code_key UNIQUE (extractor_code);


--
-- Name: frame_extractor frame_extractor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frame_extractor
    ADD CONSTRAINT frame_extractor_pkey PRIMARY KEY (id);


--
-- Name: image image_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image
    ADD CONSTRAINT image_pkey PRIMARY KEY (id);


--
-- Name: llm_config llm_config_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_config
    ADD CONSTRAINT llm_config_name_key UNIQUE (name);


--
-- Name: llm_config llm_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_config
    ADD CONSTRAINT llm_config_pkey PRIMARY KEY (id);


--
-- Name: llm_inference_record llm_inference_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_inference_record
    ADD CONSTRAINT llm_inference_record_pkey PRIMARY KEY (id);


--
-- Name: nvr nvr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nvr
    ADD CONSTRAINT nvr_pkey PRIMARY KEY (id);


--
-- Name: playback playback_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playback
    ADD CONSTRAINT playback_pkey PRIMARY KEY (id);


--
-- Name: pusher pusher_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pusher
    ADD CONSTRAINT pusher_pkey PRIMARY KEY (id);


--
-- Name: pusher pusher_pusher_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pusher
    ADD CONSTRAINT pusher_pusher_code_key UNIQUE (pusher_code);


--
-- Name: record_space record_space_device_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.record_space
    ADD CONSTRAINT record_space_device_id_key UNIQUE (device_id);


--
-- Name: record_space record_space_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.record_space
    ADD CONSTRAINT record_space_pkey PRIMARY KEY (id);


--
-- Name: record_space record_space_space_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.record_space
    ADD CONSTRAINT record_space_space_code_key UNIQUE (space_code);


--
-- Name: region_model_service region_model_service_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_model_service
    ADD CONSTRAINT region_model_service_pkey PRIMARY KEY (id);


--
-- Name: regulation_rule_detail regulation_rule_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulation_rule_detail
    ADD CONSTRAINT regulation_rule_detail_pkey PRIMARY KEY (id);


--
-- Name: regulation_rule regulation_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulation_rule
    ADD CONSTRAINT regulation_rule_pkey PRIMARY KEY (id);


--
-- Name: regulation_rule regulation_rule_rule_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulation_rule
    ADD CONSTRAINT regulation_rule_rule_code_key UNIQUE (rule_code);


--
-- Name: snap_space snap_space_device_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_space
    ADD CONSTRAINT snap_space_device_id_key UNIQUE (device_id);


--
-- Name: snap_space snap_space_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_space
    ADD CONSTRAINT snap_space_pkey PRIMARY KEY (id);


--
-- Name: snap_space snap_space_space_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_space
    ADD CONSTRAINT snap_space_space_code_key UNIQUE (space_code);


--
-- Name: snap_task snap_task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_task
    ADD CONSTRAINT snap_task_pkey PRIMARY KEY (id);


--
-- Name: snap_task snap_task_task_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_task
    ADD CONSTRAINT snap_task_task_code_key UNIQUE (task_code);


--
-- Name: sorter sorter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sorter
    ADD CONSTRAINT sorter_pkey PRIMARY KEY (id);


--
-- Name: sorter sorter_sorter_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sorter
    ADD CONSTRAINT sorter_sorter_code_key UNIQUE (sorter_code);


--
-- Name: stream_forward_task_device stream_forward_task_device_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stream_forward_task_device
    ADD CONSTRAINT stream_forward_task_device_pkey PRIMARY KEY (stream_forward_task_id, device_id);


--
-- Name: stream_forward_task stream_forward_task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stream_forward_task
    ADD CONSTRAINT stream_forward_task_pkey PRIMARY KEY (id);


--
-- Name: stream_forward_task stream_forward_task_task_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stream_forward_task
    ADD CONSTRAINT stream_forward_task_task_code_key UNIQUE (task_code);


--
-- Name: streaming_session streaming_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streaming_session
    ADD CONSTRAINT streaming_session_pkey PRIMARY KEY (id);


--
-- Name: tracking_target tracking_target_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_target
    ADD CONSTRAINT tracking_target_pkey PRIMARY KEY (id);


--
-- Name: algorithm_task algorithm_task_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.algorithm_task
    ADD CONSTRAINT algorithm_task_space_id_fkey FOREIGN KEY (space_id) REFERENCES public.snap_space(id) ON DELETE CASCADE;


--
-- Name: detection_region detection_region_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detection_region
    ADD CONSTRAINT detection_region_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.image(id) ON DELETE SET NULL;


--
-- Name: device_detection_region device_detection_region_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_detection_region
    ADD CONSTRAINT device_detection_region_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.image(id) ON DELETE SET NULL;


--
-- Name: device device_directory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device
    ADD CONSTRAINT device_directory_id_fkey FOREIGN KEY (directory_id) REFERENCES public.device_directory(id) ON DELETE SET NULL;


--
-- Name: device_directory device_directory_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_directory
    ADD CONSTRAINT device_directory_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.device_directory(id) ON DELETE CASCADE;


--
-- Name: device device_nvr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device
    ADD CONSTRAINT device_nvr_id_fkey FOREIGN KEY (nvr_id) REFERENCES public.nvr(id) ON DELETE CASCADE;


--
-- Name: llm_inference_record llm_inference_record_llm_model_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_inference_record
    ADD CONSTRAINT llm_inference_record_llm_model_id_fkey FOREIGN KEY (llm_model_id) REFERENCES public.llm_config(id) ON DELETE SET NULL;


--
-- Name: region_model_service region_model_service_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_model_service
    ADD CONSTRAINT region_model_service_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.detection_region(id) ON DELETE CASCADE;


--
-- Name: regulation_rule_detail regulation_rule_detail_regulation_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulation_rule_detail
    ADD CONSTRAINT regulation_rule_detail_regulation_rule_id_fkey FOREIGN KEY (regulation_rule_id) REFERENCES public.regulation_rule(id) ON DELETE CASCADE;


--
-- Name: snap_task snap_task_pusher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_task
    ADD CONSTRAINT snap_task_pusher_id_fkey FOREIGN KEY (pusher_id) REFERENCES public.pusher(id) ON DELETE SET NULL;


--
-- Name: snap_task snap_task_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snap_task
    ADD CONSTRAINT snap_task_space_id_fkey FOREIGN KEY (space_id) REFERENCES public.snap_space(id) ON DELETE CASCADE;


--
-- Name: stream_forward_task_device stream_forward_task_device_stream_forward_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stream_forward_task_device
    ADD CONSTRAINT stream_forward_task_device_stream_forward_task_id_fkey FOREIGN KEY (stream_forward_task_id) REFERENCES public.stream_forward_task(id) ON DELETE CASCADE;


--
-- Name: streaming_session streaming_session_llm_model_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streaming_session
    ADD CONSTRAINT streaming_session_llm_model_id_fkey FOREIGN KEY (llm_model_id) REFERENCES public.llm_config(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict af7pCVwnp32bnyp4mwsppWdgPKo21zmcpy14bm8rfpenX2tHQTNYeDQecfK6NtJ

