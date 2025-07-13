#!/usr/bin/env python3
"""
高度なKinesisデータ生成スクリプト
企業レベルのリアルなデータパターンを生成
"""

import json
import boto3
import random
import time
import argparse
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed
import uuid
from dataclasses import dataclass
import numpy as np
from faker import Faker

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class DataGeneratorConfig:
    """データ生成設定"""
    stream_name: str
    events_per_second: int = 10
    duration_seconds: int = 300
    data_types: List[str] = None
    realistic_patterns: bool = True
    burst_mode: bool = False
    burst_events: int = 1000
    
    def __post_init__(self):
        if self.data_types is None:
            self.data_types = ['user_activity', 'transaction', 'system_metric', 'sensor_data']

class EnterpriseDataGenerator:
    """エンタープライズ級データ生成器"""
    
    def __init__(self, config: DataGeneratorConfig):
        self.config = config
        self.kinesis = boto3.client('kinesis')
        self.fake = Faker(['ja_JP', 'en_US'])
        self.start_time = datetime.now()
        
        # データテンプレート
        self.data_templates = {
            'user_activity': self._create_user_activity_template,
            'transaction': self._create_transaction_template,
            'system_metric': self._create_system_metric_template,
            'sensor_data': self._create_sensor_data_template,
            'clickstream': self._create_clickstream_template,
            'app_log': self._create_app_log_template
        }
        
        # リアルなデータパターン用の状態
        self.user_sessions = {}
        self.product_catalog = self._generate_product_catalog()
        self.user_profiles = self._generate_user_profiles()
        self.system_components = ['web-server', 'database', 'cache', 'api-gateway', 'cdn']
        
    def _generate_product_catalog(self) -> List[Dict]:
        """商品カタログ生成"""
        categories = [
            'Electronics', 'Fashion', 'Books', 'Home & Garden', 
            'Sports', 'Beauty', 'Automotive', 'Food'
        ]
        
        products = []
        for i in range(500):
            category = random.choice(categories)
            products.append({
                'product_id': f'PROD_{i:04d}',
                'name': self.fake.catch_phrase(),
                'category': category,
                'price': round(random.uniform(10, 1000), 2),
                'popularity_score': random.uniform(0, 1)
            })
        
        return products
    
    def _generate_user_profiles(self) -> List[Dict]:
        """ユーザープロファイル生成"""
        profiles = []
        for i in range(1000):
            profiles.append({
                'user_id': f'USER_{i:04d}',
                'age': random.randint(18, 70),
                'gender': random.choice(['M', 'F', 'Other']),
                'location': self.fake.city(),
                'customer_tier': random.choice(['bronze', 'silver', 'gold', 'platinum']),
                'preferences': random.sample(
                    ['Electronics', 'Fashion', 'Books', 'Sports'], 
                    k=random.randint(1, 3)
                )
            })
        
        return profiles
    
    def generate_data_stream(self):
        """データストリーム生成のメイン関数"""
        if self.config.burst_mode:
            self._generate_burst_data()
        else:
            self._generate_continuous_data()
    
    def _generate_continuous_data(self):
        """継続的データ生成"""
        logger.info(f"Starting continuous data generation for {self.config.duration_seconds} seconds")
        logger.info(f"Target rate: {self.config.events_per_second} events/second")
        
        end_time = self.start_time + timedelta(seconds=self.config.duration_seconds)
        events_sent = 0
        
        with ThreadPoolExecutor(max_workers=10) as executor:
            while datetime.now() < end_time:
                batch_start = time.time()
                
                # 1秒間のバッチ生成
                futures = []
                for _ in range(self.config.events_per_second):
                    future = executor.submit(self._generate_and_send_event)
                    futures.append(future)
                
                # バッチ完了を待つ
                for future in as_completed(futures):
                    try:
                        future.result()
                        events_sent += 1
                    except Exception as e:
                        logger.error(f"Event generation failed: {e}")
                
                # レート制御
                batch_duration = time.time() - batch_start
                if batch_duration < 1.0:
                    time.sleep(1.0 - batch_duration)
                
                # 進捗レポート
                if events_sent % (self.config.events_per_second * 10) == 0:
                    elapsed = (datetime.now() - self.start_time).total_seconds()
                    rate = events_sent / elapsed if elapsed > 0 else 0
                    logger.info(f"Sent {events_sent} events, Rate: {rate:.1f} events/sec")
        
        logger.info(f"Data generation completed. Total events sent: {events_sent}")
    
    def _generate_burst_data(self):
        """バーストデータ生成"""
        logger.info(f"Starting burst data generation: {self.config.burst_events} events")
        
        batch_size = 100
        events_sent = 0
        
        with ThreadPoolExecutor(max_workers=20) as executor:
            for batch_start in range(0, self.config.burst_events, batch_size):
                batch_end = min(batch_start + batch_size, self.config.burst_events)
                batch_events = batch_end - batch_start
                
                futures = []
                for _ in range(batch_events):
                    future = executor.submit(self._generate_and_send_event)
                    futures.append(future)
                
                # バッチ完了を待つ
                for future in as_completed(futures):
                    try:
                        future.result()
                        events_sent += 1
                    except Exception as e:
                        logger.error(f"Event generation failed: {e}")
                
                # 進捗レポート
                if events_sent % 1000 == 0:
                    logger.info(f"Burst progress: {events_sent}/{self.config.burst_events} events sent")
        
        logger.info(f"Burst generation completed. Total events sent: {events_sent}")
    
    def _generate_and_send_event(self) -> bool:
        """イベント生成と送信"""
        try:
            # データタイプをランダム選択（重み付き）
            data_type = random.choices(
                self.config.data_types,
                weights=[3, 2, 1, 1],  # user_activity, transaction, system_metric, sensor_data
                k=1
            )[0]
            
            # イベントデータ生成
            event_data = self.data_templates[data_type]()
            
            # Kinesisに送信
            partition_key = event_data.get('partition_key', str(uuid.uuid4()))
            
            response = self.kinesis.put_record(
                StreamName=self.config.stream_name,
                Data=json.dumps(event_data, default=str, ensure_ascii=False),
                PartitionKey=partition_key
            )
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to generate/send event: {e}")
            return False
    
    def _create_user_activity_template(self) -> Dict:
        """ユーザー活動データテンプレート"""
        user = random.choice(self.user_profiles)
        
        # セッション管理（リアルな行動パターン）
        session_id = self._get_or_create_session(user['user_id'])
        
        event_types = ['page_view', 'click', 'search', 'login', 'logout', 'add_to_cart', 'purchase']
        event_weights = [30, 25, 15, 5, 5, 10, 10]  # リアルな重み
        
        event_type = random.choices(event_types, weights=event_weights, k=1)[0]
        
        # 時間帯による行動パターン
        current_hour = datetime.now().hour
        if 9 <= current_hour <= 17:  # 勤務時間
            bounce_rate = 0.7
        elif 19 <= current_hour <= 22:  # プライムタイム
            bounce_rate = 0.3
        else:  # その他の時間
            bounce_rate = 0.5
        
        return {
            'event_id': str(uuid.uuid4()),
            'event_type': event_type,
            'user_id': user['user_id'],
            'session_id': session_id,
            'timestamp': datetime.now().isoformat(),
            'user_tier': user['customer_tier'],
            'page_url': f"/category/{random.choice(['electronics', 'fashion', 'books'])}",
            'referrer': random.choice(['google.com', 'facebook.com', 'direct', 'email']),
            'device_type': random.choice(['desktop', 'mobile', 'tablet']),
            'browser': random.choice(['chrome', 'firefox', 'safari', 'edge']),
            'os': random.choice(['windows', 'macos', 'android', 'ios']),
            'location': user['location'],
            'bounce_probability': bounce_rate,
            'partition_key': user['user_id']
        }
    
    def _create_transaction_template(self) -> Dict:
        """取引データテンプレート"""
        user = random.choice(self.user_profiles)
        product = random.choice(self.product_catalog)
        
        # 顧客ティアによる購買パターン
        tier_multipliers = {
            'bronze': 0.5,
            'silver': 0.8,
            'gold': 1.2,
            'platinum': 2.0
        }
        
        base_quantity = random.randint(1, 5)
        quantity = max(1, int(base_quantity * tier_multipliers[user['customer_tier']]))
        
        # 割引計算（プロモーション、ロイヤルティ）
        discount_rate = 0
        if random.random() < 0.2:  # 20%の確率でプロモーション
            discount_rate = random.uniform(0.05, 0.3)
        
        if user['customer_tier'] in ['gold', 'platinum']:
            discount_rate += 0.05  # VIP割引
        
        total_amount = product['price'] * quantity
        discount_amount = total_amount * discount_rate
        final_amount = total_amount - discount_amount
        
        return {
            'transaction_id': f"TXN_{uuid.uuid4().hex[:8].upper()}",
            'user_id': user['user_id'],
            'product_id': product['product_id'],
            'product_name': product['name'],
            'category': product['category'],
            'quantity': quantity,
            'unit_price': product['price'],
            'total_amount': round(total_amount, 2),
            'discount_rate': round(discount_rate, 3),
            'discount_amount': round(discount_amount, 2),
            'final_amount': round(final_amount, 2),
            'payment_method': random.choice(['credit_card', 'debit_card', 'paypal', 'bank_transfer']),
            'currency': 'JPY',
            'timestamp': datetime.now().isoformat(),
            'store_id': f"STORE_{random.randint(1, 50):03d}",
            'customer_tier': user['customer_tier'],
            'is_repeat_customer': random.random() < 0.6,
            'partition_key': user['user_id']
        }
    
    def _create_system_metric_template(self) -> Dict:
        """システムメトリクスデータテンプレート"""
        component = random.choice(self.system_components)
        
        # コンポーネント別のメトリクス生成
        if component == 'web-server':
            metrics = {
                'cpu_usage': max(0, min(100, random.gauss(35, 15))),
                'memory_usage': max(0, min(100, random.gauss(60, 20))),
                'response_time_ms': max(10, random.lognormvariate(4, 0.5)),
                'requests_per_second': max(0, random.gauss(100, 30)),
                'error_rate': max(0, min(1, random.gauss(0.02, 0.01)))
            }
        elif component == 'database':
            metrics = {
                'cpu_usage': max(0, min(100, random.gauss(25, 10))),
                'memory_usage': max(0, min(100, random.gauss(70, 15))),
                'query_time_ms': max(1, random.lognormvariate(3, 0.7)),
                'connections_active': random.randint(10, 200),
                'disk_io_ops': random.randint(50, 500)
            }
        else:
            metrics = {
                'cpu_usage': max(0, min(100, random.gauss(30, 12))),
                'memory_usage': max(0, min(100, random.gauss(50, 18))),
                'network_bytes_in': random.randint(1000, 100000),
                'network_bytes_out': random.randint(5000, 200000)
            }
        
        return {
            'metric_id': str(uuid.uuid4()),
            'component': component,
            'instance_id': f"{component}-{random.randint(1, 10):02d}",
            'metrics': metrics,
            'timestamp': datetime.now().isoformat(),
            'region': random.choice(['us-east-1', 'ap-northeast-1', 'eu-west-1']),
            'environment': random.choice(['prod', 'staging', 'dev']),
            'partition_key': component
        }
    
    def _create_sensor_data_template(self) -> Dict:
        """センサーデータテンプレート"""
        sensor_types = ['temperature', 'humidity', 'pressure', 'vibration', 'light']
        sensor_type = random.choice(sensor_types)
        
        # センサータイプ別の値生成
        if sensor_type == 'temperature':
            value = round(random.gauss(22, 5), 2)  # 摂氏
            unit = 'celsius'
        elif sensor_type == 'humidity':
            value = round(max(0, min(100, random.gauss(45, 15))), 2)
            unit = 'percent'
        elif sensor_type == 'pressure':
            value = round(random.gauss(1013.25, 20), 2)  # hPa
            unit = 'hPa'
        elif sensor_type == 'vibration':
            value = round(max(0, random.lognormvariate(1, 0.5)), 3)
            unit = 'g'
        else:  # light
            value = round(max(0, random.lognormvariate(6, 1)), 1)
            unit = 'lux'
        
        return {
            'sensor_id': f"SENSOR_{random.randint(1, 1000):04d}",
            'sensor_type': sensor_type,
            'value': value,
            'unit': unit,
            'timestamp': datetime.now().isoformat(),
            'location': {
                'building': f"Building_{random.choice(['A', 'B', 'C'])}",
                'floor': random.randint(1, 10),
                'room': f"Room_{random.randint(101, 999)}"
            },
            'battery_level': round(random.uniform(0.1, 1.0), 2),
            'signal_strength': random.randint(-80, -30),
            'partition_key': f"sensor_type_{sensor_type}"
        }
    
    def _create_clickstream_template(self) -> Dict:
        """クリックストリームデータテンプレート"""
        user = random.choice(self.user_profiles)
        session_id = self._get_or_create_session(user['user_id'])
        
        return {
            'event_id': str(uuid.uuid4()),
            'user_id': user['user_id'],
            'session_id': session_id,
            'event_type': 'click',
            'element_id': f"btn_{random.choice(['buy', 'cart', 'search', 'menu', 'filter'])}",
            'element_text': self.fake.word(),
            'page_url': f"/product/{random.choice(self.product_catalog)['product_id']}",
            'x_coordinate': random.randint(0, 1920),
            'y_coordinate': random.randint(0, 1080),
            'viewport_width': random.choice([1920, 1366, 768, 414]),
            'viewport_height': random.choice([1080, 768, 1024, 896]),
            'timestamp': datetime.now().isoformat(),
            'partition_key': user['user_id']
        }
    
    def _create_app_log_template(self) -> Dict:
        """アプリケーションログテンプレート"""
        log_levels = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']
        log_weights = [10, 60, 20, 8, 2]
        
        level = random.choices(log_levels, weights=log_weights, k=1)[0]
        component = random.choice(self.system_components)
        
        # ログレベルに応じたメッセージ生成
        if level == 'ERROR':
            messages = [
                "Database connection timeout",
                "Authentication failed for user",
                "Payment processing failed",
                "External API returned 500 error"
            ]
        elif level == 'WARN':
            messages = [
                "High memory usage detected",
                "Slow query execution time",
                "Rate limit approaching",
                "Cache miss ratio high"
            ]
        else:
            messages = [
                "Request processed successfully",
                "User authenticated",
                "Cache refreshed",
                "Background job completed"
            ]
        
        return {
            'log_id': str(uuid.uuid4()),
            'timestamp': datetime.now().isoformat(),
            'level': level,
            'component': component,
            'message': random.choice(messages),
            'request_id': str(uuid.uuid4()),
            'user_id': random.choice(self.user_profiles)['user_id'] if random.random() < 0.7 else None,
            'execution_time_ms': random.randint(1, 5000) if level != 'DEBUG' else random.randint(1, 100),
            'partition_key': component
        }
    
    def _get_or_create_session(self, user_id: str) -> str:
        """セッション管理"""
        current_time = datetime.now()
        
        # 既存セッションの有効性チェック
        if user_id in self.user_sessions:
            session_info = self.user_sessions[user_id]
            session_age = (current_time - session_info['created']).total_seconds()
            
            # 30分以内なら既存セッション継続
            if session_age < 1800:
                return session_info['session_id']
        
        # 新しいセッション作成
        session_id = str(uuid.uuid4())
        self.user_sessions[user_id] = {
            'session_id': session_id,
            'created': current_time
        }
        
        return session_id

def main():
    """メイン実行関数"""
    parser = argparse.ArgumentParser(description='Advanced Kinesis Data Generator')
    parser.add_argument('--stream-name', required=True, help='Kinesis stream name')
    parser.add_argument('--events-per-second', type=int, default=10, help='Events per second')
    parser.add_argument('--duration', type=int, default=300, help='Duration in seconds')
    parser.add_argument('--mode', choices=['continuous', 'burst'], default='continuous', help='Generation mode')
    parser.add_argument('--burst-events', type=int, default=1000, help='Number of events for burst mode')
    parser.add_argument('--data-types', nargs='+', 
                       choices=['user_activity', 'transaction', 'system_metric', 'sensor_data', 'clickstream', 'app_log'],
                       default=['user_activity', 'transaction', 'system_metric', 'sensor_data'],
                       help='Types of data to generate')
    
    args = parser.parse_args()
    
    # 設定作成
    config = DataGeneratorConfig(
        stream_name=args.stream_name,
        events_per_second=args.events_per_second,
        duration_seconds=args.duration,
        data_types=args.data_types,
        burst_mode=(args.mode == 'burst'),
        burst_events=args.burst_events
    )
    
    # データ生成実行
    generator = EnterpriseDataGenerator(config)
    
    try:
        generator.generate_data_stream()
    except KeyboardInterrupt:
        logger.info("Data generation interrupted by user")
    except Exception as e:
        logger.error(f"Data generation failed: {e}")
        raise

if __name__ == "__main__":
    main()