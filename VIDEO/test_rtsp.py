#!/usr/bin/env python3
"""
RTSP到RTMP推流测试脚本
将本地摄像头的RTSP地址推流到远端SRS RTMP地址

@author 翱翔的雄库鲁
@email andywebjava@163.com
@wechat EasyAIoT2025
"""
import os
import sys
import subprocess
import signal
import time
import argparse
from typing import Optional

# 添加VIDEO模块路径
video_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, video_root)

# 全局变量，用于存储ffmpeg进程
ffmpeg_process: Optional[subprocess.Popen] = None


def signal_handler(sig, frame):
    """信号处理函数，用于优雅退出"""
    global ffmpeg_process
    print("\n\n收到退出信号，正在停止推流...")
    if ffmpeg_process:
        try:
            ffmpeg_process.terminate()
            # 等待进程退出
            try:
                ffmpeg_process.wait(timeout=5)
                print("✅ FFmpeg进程已正常退出")
            except subprocess.TimeoutExpired:
                print("⚠️  FFmpeg进程未在5秒内退出，强制终止...")
                ffmpeg_process.kill()
                ffmpeg_process.wait()
                print("✅ FFmpeg进程已强制终止")
        except Exception as e:
            print(f"❌ 停止FFmpeg进程时出错: {str(e)}")
    sys.exit(0)


def check_ffmpeg():
    """检查ffmpeg是否安装"""
    try:
        result = subprocess.run(
            ['ffmpeg', '-version'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5
        )
        if result.returncode == 0:
            version_line = result.stdout.decode('utf-8', errors='ignore').split('\n')[0]
            print(f"✅ FFmpeg已安装: {version_line}")
            return True
        else:
            print("❌ FFmpeg未正确安装")
            return False
    except FileNotFoundError:
        print("❌ FFmpeg未安装，请先安装FFmpeg")
        print("   安装方法: sudo apt-get install ffmpeg  (Ubuntu/Debian)")
        print("            brew install ffmpeg  (macOS)")
        return False
    except Exception as e:
        print(f"❌ 检查FFmpeg时出错: {str(e)}")
        return False


def test_rtsp_connection(rtsp_url: str, timeout: int = 5) -> bool:
    """测试RTSP连接是否可用"""
    print(f"\n🔍 测试RTSP连接: {rtsp_url}")
    try:
        # 使用ffprobe测试RTSP流
        result = subprocess.run(
            [
                'ffprobe',
                '-rtsp_transport', 'udp',
                '-i', rtsp_url,
                '-v', 'error',
                '-show_entries', 'stream=codec_name,width,height,r_frame_rate',
                '-of', 'json',
                '-timeout', str(timeout * 1000000)  # 微秒
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout + 2
        )
        
        if result.returncode == 0:
            import json
            try:
                info = json.loads(result.stdout.decode('utf-8', errors='ignore'))
                if 'streams' in info and len(info['streams']) > 0:
                    stream = info['streams'][0]
                    width = stream.get('width', 'N/A')
                    height = stream.get('height', 'N/A')
                    codec = stream.get('codec_name', 'N/A')
                    fps = stream.get('r_frame_rate', 'N/A')
                    print(f"✅ RTSP流可用")
                    print(f"   编码: {codec}, 分辨率: {width}x{height}, 帧率: {fps}")
                    return True
                else:
                    print("⚠️  RTSP流信息为空")
                    return False
            except json.JSONDecodeError:
                print("⚠️  无法解析RTSP流信息")
                return False
        else:
            error_msg = result.stderr.decode('utf-8', errors='ignore')
            print(f"❌ RTSP连接失败")
            if error_msg:
                print(f"   错误: {error_msg[:200]}")
            return False
    except subprocess.TimeoutExpired:
        print(f"❌ RTSP连接超时（{timeout}秒）")
        return False
    except FileNotFoundError:
        print("⚠️  ffprobe未安装，跳过RTSP连接测试")
        return True  # 不阻止推流，只是无法测试
    except Exception as e:
        print(f"⚠️  测试RTSP连接时出错: {str(e)}")
        return True  # 不阻止推流，只是无法测试


def start_rtsp_to_rtmp_push(rtsp_url: str, rtmp_url: str, 
                            bitrate: str = '2000k',
                            preset: str = 'veryfast',
                            rtsp_transport: str = 'udp',
                            enable_audio: bool = False) -> Optional[subprocess.Popen]:
    """
    启动RTSP到RTMP的推流
    
    Args:
        rtsp_url: RTSP输入流地址
        rtmp_url: RTMP输出流地址
        bitrate: 视频比特率 (默认: 2000k)
        preset: 编码预设 (默认: veryfast, 可选: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow)
        rtsp_transport: RTSP传输协议 (tcp 或 udp, 默认: udp)
        enable_audio: 是否启用音频 (默认: False)
    
    Returns:
        subprocess.Popen对象，如果失败返回None
    """
    global ffmpeg_process
    
    # 构建FFmpeg命令
    ffmpeg_cmd = [
        'ffmpeg',
        '-rtsp_transport', rtsp_transport,
        '-i', rtsp_url,  # RTSP输入流
        '-c:v', 'libx264',  # 视频编码器
        '-b:v', bitrate,  # 视频比特率
        '-preset', preset,  # 编码预设
        '-tune', 'zerolatency',  # 零延迟调优
        '-f', 'flv',  # 输出格式为FLV（RTMP标准格式）
        '-loglevel', 'info',  # 日志级别
    ]
    
    # 音频处理
    if not enable_audio:
        ffmpeg_cmd.insert(-1, '-an')  # 禁用音频
    else:
        ffmpeg_cmd.extend(['-c:a', 'aac', '-b:a', '128k'])  # 启用音频编码
    
    # 添加输出地址
    ffmpeg_cmd.append(rtmp_url)
    
    try:
        print(f"\n🚀 启动RTSP到RTMP推流")
        print(f"   输入: {rtsp_url}")
        print(f"   输出: {rtmp_url}")
        print(f"   码率: {bitrate}")
        print(f"   编码预设: {preset}")
        print(f"   RTSP传输: {rtsp_transport}")
        print(f"   音频: {'启用' if enable_audio else '禁用'}")
        print(f"\n   FFmpeg命令: {' '.join(ffmpeg_cmd)}")
        
        # 启动FFmpeg进程
        ffmpeg_process = subprocess.Popen(
            ffmpeg_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,  # 将stderr重定向到stdout
            universal_newlines=True,
            bufsize=1  # 行缓冲
        )
        
        # 等待一小段时间，检查进程是否立即退出
        time.sleep(2)
        
        if ffmpeg_process.poll() is not None:
            # 进程已退出，读取错误信息
            output, _ = ffmpeg_process.communicate(timeout=1)
            print(f"\n❌ FFmpeg进程立即退出 (退出码: {ffmpeg_process.returncode})")
            if output:
                # 提取关键错误信息
                error_lines = [line for line in output.split('\n') 
                             if any(keyword in line.lower() for keyword in 
                                   ['error', 'failed', 'cannot', 'unable', 'invalid', 
                                    'connection refused', 'connection reset', 'timeout'])]
                if error_lines:
                    print("   错误信息:")
                    for line in error_lines[:10]:  # 只显示前10行错误
                        print(f"     {line}")
                else:
                    print(f"   输出: {output[:500]}")
            return None
        
        print(f"\n✅ FFmpeg推流进程已启动 (PID: {ffmpeg_process.pid})")
        print(f"   推流进行中，按 Ctrl+C 停止...\n")
        
        # 实时输出FFmpeg日志
        try:
            for line in iter(ffmpeg_process.stdout.readline, ''):
                if line:
                    line = line.strip()
                    # 过滤掉一些不重要的信息
                    if any(skip in line.lower() for skip in ['frame=', 'fps=', 'bitrate=', 'time=']):
                        # 每10秒打印一次统计信息
                        if 'time=' in line:
                            print(f"   {line}")
                    elif any(keyword in line.lower() for keyword in 
                           ['error', 'failed', 'warning', 'connection']):
                        print(f"   ⚠️  {line}")
        except Exception as e:
            print(f"\n⚠️  读取FFmpeg输出时出错: {str(e)}")
        
        return ffmpeg_process
        
    except KeyboardInterrupt:
        print("\n\n收到中断信号...")
        return ffmpeg_process
    except Exception as e:
        print(f"\n❌ 启动推流失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return None


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='RTSP到RTMP推流测试脚本',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 基本用法
  python test_rtsp.py rtsp://admin:password@192.168.1.100:554/stream rtmp://srs.example.com:1935/live/stream1

  # 指定码率和编码预设
  python test_rtsp.py rtsp://admin:password@192.168.1.100:554/stream \\
      rtmp://srs.example.com:1935/live/stream1 \\
      --bitrate 1500k --preset ultrafast

  # 使用UDP传输并启用音频
  python test_rtsp.py rtsp://admin:password@192.168.1.100:554/stream \\
      rtmp://srs.example.com:1935/live/stream1 \\
      --rtsp-transport udp --enable-audio

  # 跳过RTSP连接测试
  python test_rtsp.py rtsp://admin:password@192.168.1.100:554/stream \\
      rtmp://srs.example.com:1935/live/stream1 \\
      --skip-test
        """
    )
    
    parser.add_argument(
        'rtsp_url',
        type=str,
        help='RTSP输入流地址 (例如: rtsp://admin:password@192.168.1.100:554/stream)'
    )
    
    parser.add_argument(
        'rtmp_url',
        type=str,
        help='RTMP输出流地址 (例如: rtmp://srs.example.com:1935/live/stream1)'
    )
    
    parser.add_argument(
        '--bitrate',
        type=str,
        default='2000k',
        help='视频比特率 (默认: 2000k)'
    )
    
    parser.add_argument(
        '--preset',
        type=str,
        default='veryfast',
        choices=['ultrafast', 'superfast', 'veryfast', 'faster', 'fast', 'medium', 'slow', 'slower', 'veryslow'],
        help='编码预设 (默认: veryfast)'
    )
    
    parser.add_argument(
        '--rtsp-transport',
        type=str,
        default='udp',
        choices=['tcp', 'udp'],
        help='RTSP传输协议 (默认: udp)'
    )
    
    parser.add_argument(
        '--enable-audio',
        action='store_true',
        help='启用音频编码 (默认: 禁用)'
    )
    
    parser.add_argument(
        '--skip-test',
        action='store_true',
        help='跳过RTSP连接测试'
    )
    
    args = parser.parse_args()
    
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    print("=" * 60)
    print("RTSP到RTMP推流测试脚本")
    print("=" * 60)
    
    # 检查FFmpeg
    if not check_ffmpeg():
        sys.exit(1)
    
    # 测试RTSP连接
    if not args.skip_test:
        if not test_rtsp_connection(args.rtsp_url):
            print("\n⚠️  RTSP连接测试失败，但将继续尝试推流...")
            response = input("是否继续? (y/n): ")
            if response.lower() != 'y':
                sys.exit(1)
    
    # 启动推流
    process = start_rtsp_to_rtmp_push(
        rtsp_url=args.rtsp_url,
        rtmp_url=args.rtmp_url,
        bitrate=args.bitrate,
        preset=args.preset,
        rtsp_transport=args.rtsp_transport,
        enable_audio=args.enable_audio
    )
    
    if process:
        try:
            # 等待进程结束
            process.wait()
            print(f"\n\n推流已结束 (退出码: {process.returncode})")
        except KeyboardInterrupt:
            signal_handler(None, None)
    else:
        print("\n❌ 推流启动失败")
        sys.exit(1)


if __name__ == '__main__':
    main()
