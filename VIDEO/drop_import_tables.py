#!/usr/bin/env python3
"""
删除VIDEO服务所有数据库表并重新导入表结构的脚本

使用方法:
    python drop_import_tables.py [--env=环境名] [--confirm]

参数:
    --env: 指定环境配置文件，例如: --env=prod 会加载 .env.prod，默认加载 .env
    --confirm: 跳过交互式确认，直接执行删除和导入操作（谨慎使用）

示例:
    python drop_import_tables.py                    # 交互式确认
    python drop_import_tables.py --confirm          # 跳过确认直接执行
    python drop_import_tables.py --env=prod         # 使用指定环境配置并交互式确认

说明:
    - 如果不提供 --confirm 参数，脚本会显示将要删除的表列表，并交互式询问确认
    - 提供 --confirm 参数会跳过交互式确认，直接执行删除和导入操作
    - 建议在非交互式环境中使用 --confirm 参数
    - 脚本会先删除所有表，然后导入 .scripts/postgresql/iot-edge-video10.sql 文件到 iot-edge-video20 数据库

警告: 此操作会永久删除所有数据，请谨慎使用！
"""
import argparse
import os
import sys
import subprocess
import re
from urllib.parse import urlparse
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text

# 依赖检查和自动安装
def check_and_install_dependencies():
    """检查并自动安装必要的依赖包"""
    required_packages = {
        'dotenv': 'python-dotenv',
        'sqlalchemy': 'sqlalchemy',
        'psycopg2': 'psycopg2-binary'
    }
    
    missing_packages = []
    
    # 检查每个依赖
    for module_name, package_name in required_packages.items():
        try:
            if module_name == 'dotenv':
                __import__('dotenv')
            elif module_name == 'psycopg2':
                __import__('psycopg2')
            else:
                __import__(module_name)
        except ImportError:
            missing_packages.append((module_name, package_name))
    
    # 如果有缺失的包，尝试自动安装
    if missing_packages:
        package_names = [pkg for _, pkg in missing_packages]
        print(f"⚠️  检测到缺少以下依赖包: {', '.join(package_names)}")
        print("正在尝试自动安装...")
        
        try:
            # 使用清华镜像源加速安装
            pip_args = [
                sys.executable, '-m', 'pip', 'install',
                '--index-url', 'https://pypi.tuna.tsinghua.edu.cn/simple',
                '--quiet', '--upgrade'
            ] + package_names
            
            result = subprocess.run(
                pip_args,
                check=True,
                capture_output=True,
                text=True
            )
            
            print(f"✅ 成功安装依赖包: {', '.join(package_names)}")
            print("正在重新加载模块...")
            
            # 重新导入模块（清除导入缓存）
            for module_name, _ in missing_packages:
                if module_name in sys.modules:
                    del sys.modules[module_name]
        
        except subprocess.CalledProcessError as e:
            print(f"❌ 自动安装失败")
            if e.stderr:
                print(f"错误信息: {e.stderr}")
            print(f"\n💡 请手动安装依赖包:")
            print(f"   pip install {' '.join(package_names)}")
            print(f"\n   或使用清华镜像源:")
            print(f"   pip install -i https://pypi.tuna.tsinghua.edu.cn/simple {' '.join(package_names)}")
            sys.exit(1)
        except Exception as e:
            print(f"❌ 安装过程中发生错误: {str(e)}")
            print(f"\n💡 请手动安装依赖包:")
            print(f"   pip install {' '.join(package_names)}")
            sys.exit(1)

# 在导入之前检查和安装依赖
check_and_install_dependencies()

# 现在可以安全导入
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker

# 解析命令行参数
def parse_args():
    parser = argparse.ArgumentParser(description='删除VIDEO服务所有数据库表并重新导入表结构')
    parser.add_argument('--env', type=str, default='', 
                       help='指定环境配置文件，例如: --env=prod 会加载 .env.prod，默认加载 .env')
    parser.add_argument('--confirm', action='store_true',
                       help='跳过交互式确认，直接执行删除和导入操作（谨慎使用）')
    return parser.parse_args()

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
                sys.exit(1)
    else:
        if os.path.exists('.env'):
            load_dotenv('.env')
            print(f"✅ 已加载默认配置文件: .env")
        else:
            print(f"⚠️  默认配置文件 .env 不存在，尝试使用环境变量")

# 获取所有表名
def get_all_tables(engine):
    """获取数据库中所有表名"""
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    return tables

# 交互式确认
def interactive_confirm(tables):
    """交互式确认删除操作"""
    print(f"\n⚠️  警告: 即将删除以下 {len(tables)} 个表:")
    for i, table in enumerate(tables, 1):
        print(f"   {i}. {table}")
    
    print("\n⚠️  此操作会永久删除所有数据，无法恢复！")
    print("删除后将自动导入 .scripts/postgresql/iot-edge-video10.sql 文件到 iot-edge-video20 数据库")
    print("\n请确认是否继续删除和导入操作？")
    
    while True:
        try:
            response = input("输入 'yes' 或 'y' 确认执行，输入 'no' 或 'n' 取消: ").strip().lower()
            if response in ['yes', 'y']:
                return True
            elif response in ['no', 'n']:
                print("❌ 操作已取消")
                return False
            else:
                print("⚠️  请输入 'yes'/'y' 或 'no'/'n'")
        except KeyboardInterrupt:
            print("\n\n❌ 操作已取消（用户中断）")
            return False
        except EOFError:
            print("\n\n❌ 操作已取消（输入结束）")
            return False

# 删除所有表
def drop_all_tables(engine, confirm=False):
    """删除所有数据库表"""
    try:
        # 获取所有表名
        tables = get_all_tables(engine)
        
        if not tables:
            print("ℹ️  数据库中没有表需要删除")
            return True
        
        # 如果没有通过命令行确认，则进行交互式确认
        if not confirm:
            if not interactive_confirm(tables):
                return False
        
        print("\n正在执行删除操作...\n")
        
        # 使用事务执行删除
        with engine.connect() as conn:
            # 开始事务
            trans = conn.begin()
            try:
                # 禁用外键约束检查（PostgreSQL）
                conn.execute(text("SET session_replication_role = 'replica';"))
                
                # 删除所有表（使用CASCADE确保删除依赖关系）
                for table in tables:
                    try:
                        conn.execute(text(f'DROP TABLE IF EXISTS "{table}" CASCADE;'))
                        print(f"✅ 已删除表: {table}")
                    except Exception as e:
                        print(f"⚠️  删除表 {table} 时出错: {str(e)}")
                
                # 重新启用外键约束检查
                conn.execute(text("SET session_replication_role = 'origin';"))
                
                # 提交事务
                trans.commit()
                print(f"\n✅ 成功删除所有表！")
                return True
                
            except Exception as e:
                # 回滚事务
                trans.rollback()
                print(f"\n❌ 删除表时发生错误: {str(e)}")
                import traceback
                traceback.print_exc()
                return False
                
    except Exception as e:
        print(f"❌ 连接数据库时发生错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

# 从DATABASE_URL解析连接信息
def parse_database_url(database_url):
    """从DATABASE_URL解析数据库连接信息"""
    # 转换postgres://为postgresql://
    database_url = database_url.replace("postgres://", "postgresql://", 1)
    
    # 强制使用localhost作为数据库主机
    database_url = re.sub(r'@[^:/]+', '@localhost', database_url)
    
    parsed = urlparse(database_url)
    
    return {
        'user': parsed.username or 'postgres',
        'password': parsed.password or '',
        'host': parsed.hostname or 'localhost',
        'port': parsed.port or 5432,
        'database': parsed.path.lstrip('/') if parsed.path else 'postgres'
    }

# 导入SQL文件
def import_sql_file(db_info, sql_file_path, target_database='iot-edge-video20'):
    """使用psql命令导入SQL文件"""
    if not os.path.exists(sql_file_path):
        print(f"❌ SQL文件不存在: {sql_file_path}")
        return False
    
    print(f"\n正在导入SQL文件: {sql_file_path}")
    print(f"目标数据库: {target_database}\n")
    
    # 直接使用原始SQL文件，不需要替换数据库名
    temp_sql_path = sql_file_path
    
    # 构建psql命令
    # 使用PGPASSWORD环境变量传递密码，避免在命令行中暴露
    env = os.environ.copy()
    if db_info['password']:
        env['PGPASSWORD'] = db_info['password']
    
    # 构建psql连接字符串
    # 格式: psql -h host -p port -U user -d database -f sql_file
    psql_cmd = [
        'psql',
        '-h', db_info['host'],
        '-p', str(db_info['port']),
        '-U', db_info['user'],
        '-d', target_database,
        '-f', temp_sql_path,
        '-q'  # 安静模式，只显示错误
    ]
    
    try:
        result = subprocess.run(
            psql_cmd,
            env=env,
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode == 0:
            print("✅ SQL文件导入成功！")
            return True
        else:
            # 检查是否只是警告（某些SQL文件可能包含警告但实际执行成功）
            error_output = result.stderr
            if error_output:
                # 过滤掉常见的非致命错误
                lines = error_output.split('\n')
                fatal_errors = [line for line in lines 
                              if line and 'ERROR' in line.upper() 
                              and 'already exists' not in line.lower()
                              and 'does not exist' not in line.lower()]
                
                if fatal_errors:
                    print(f"⚠️  SQL文件导入时出现错误:")
                    for error in fatal_errors[:5]:  # 只显示前5个错误
                        print(f"   {error}")
                    return False
                else:
                    print("✅ SQL文件导入完成（可能有警告，但已忽略）")
                    return True
            else:
                print("✅ SQL文件导入成功！")
                return True
                
    except FileNotFoundError:
        print("❌ 错误: 未找到psql命令")
        print("💡 请确保已安装PostgreSQL客户端工具")
        return False
    except Exception as e:
        print(f"❌ 导入SQL文件时发生错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def main():
    # 解析命令行参数
    args = parse_args()
    
    # 加载环境变量
    load_env_file(args.env)
    
    # 获取数据库URL
    database_url = os.environ.get('DATABASE_URL')
    
    if not database_url:
        print("❌ 错误: DATABASE_URL环境变量未设置")
        print("💡 请检查.env文件或环境变量配置")
        sys.exit(1)
    
    # 转换postgres://为postgresql://（SQLAlchemy要求）
    database_url_for_sqlalchemy = database_url.replace("postgres://", "postgresql://", 1)
    
    # 强制使用localhost作为数据库主机
    database_url_for_sqlalchemy = re.sub(r'@[^:/]+', '@localhost', database_url_for_sqlalchemy)
    
    # 解析数据库连接信息（用于psql命令）
    db_info = parse_database_url(database_url)
    # 使用iot-edge-video20作为目标数据库
    db_info['database'] = 'iot-edge-video20'
    
    print(f"\n📊 数据库连接信息:")
    # 隐藏密码显示
    safe_url = database_url_for_sqlalchemy.split('@')[1] if '@' in database_url_for_sqlalchemy else database_url_for_sqlalchemy
    print(f"   数据库: {safe_url}")
    print(f"   目标数据库: iot-edge-video20")
    print()
    
    # 创建数据库引擎（用于删除表）
    try:
        # 修改数据库URL以连接到iot-edge-video20数据库
        db_url_for_drop = re.sub(r'/([^/]+)(\?|$)', f'/iot-edge-video20\\2', database_url_for_sqlalchemy)
        engine = create_engine(db_url_for_drop, pool_pre_ping=True)
        
        # 测试连接
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("✅ 数据库连接成功\n")
        
    except Exception as e:
        print(f"❌ 数据库连接失败: {str(e)}")
        sys.exit(1)
    
    # 执行删除操作
    success = drop_all_tables(engine, confirm=args.confirm)
    
    if not success:
        print("\n❌ 删除表操作失败，终止导入")
        sys.exit(1)
    
    # 导入SQL文件
    # 获取项目根目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    sql_file_path = os.path.join(project_root, '.scripts', 'postgresql', 'iot-edge-video10.sql')
    
    import_success = import_sql_file(db_info, sql_file_path, target_database='iot-edge-video20')
    
    if success and import_success:
        print("\n✅ 操作完成：已删除所有表并成功导入新表结构")
        sys.exit(0)
    else:
        print("\n❌ 操作失败")
        sys.exit(1)

if __name__ == '__main__':
    main()
