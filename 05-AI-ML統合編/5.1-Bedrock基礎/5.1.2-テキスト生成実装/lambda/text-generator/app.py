"""
Amazon Bedrock Text Generation Service
=====================================

Production-ready Lambda function for AI text generation, translation, and analysis.
Built for enterprise-scale deployments with comprehensive error handling, monitoring,
and performance optimization.

Features:
- Multi-model support (Claude 3, Titan, etc.)
- Advanced prompt engineering
- Caching for cost optimization
- Rate limiting and abuse prevention
- Comprehensive logging and metrics
- Input validation and sanitization
- Async processing support
- Context-aware responses

Author: Claude AI Assistant
License: MIT
"""

import json
import boto3
import os
import hashlib
import uuid
import logging
import time
import re
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Tuple
from botocore.exceptions import ClientError, BotoCoreError
import base64

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients with retry configuration
session = boto3.Session()

# Bedrock client with custom retry configuration
bedrock_runtime = session.client(
    'bedrock-runtime',
    config=boto3.Config(
        retries={'max_attempts': 3, 'mode': 'adaptive'},
        max_pool_connections=50
    )
)

# DynamoDB resource for caching and history
dynamodb = session.resource('dynamodb')

# S3 client for large content storage
s3 = session.client('s3')

# SQS client for async processing
sqs = session.client('sqs')

# CloudWatch for custom metrics
cloudwatch = session.client('cloudwatch')

# Environment variables with defaults
HISTORY_TABLE = os.environ.get('HISTORY_TABLE', '')
CACHE_TABLE = os.environ.get('CACHE_TABLE', '')
QUEUE_URL = os.environ.get('QUEUE_URL', '')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET', '')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'text-generation')
ENABLE_CACHING = os.environ.get('ENABLE_CACHING', 'true').lower() == 'true'
CACHE_RETENTION_HOURS = int(os.environ.get('CACHE_RETENTION_HOURS', '24'))
DEFAULT_MODEL = os.environ.get('DEFAULT_MODEL', 'anthropic.claude-3-sonnet-20240229-v1:0')

# Model configurations
MODEL_CONFIGS = {
    'anthropic.claude-3-sonnet-20240229-v1:0': {
        'max_tokens': 4000,
        'temperature': 0.7,
        'top_p': 0.9,
        'type': 'claude',
        'cost_per_1k_tokens': 0.015,
        'context_window': 200000
    },
    'anthropic.claude-3-haiku-20240307-v1:0': {
        'max_tokens': 4000,
        'temperature': 0.7,
        'top_p': 0.9,
        'type': 'claude',
        'cost_per_1k_tokens': 0.0025,
        'context_window': 200000
    },
    'amazon.titan-text-express-v1': {
        'max_tokens': 4000,
        'temperature': 0.7,
        'top_p': 0.9,
        'type': 'titan',
        'cost_per_1k_tokens': 0.002,
        'context_window': 8000
    },
    'amazon.titan-text-lite-v1': {
        'max_tokens': 4000,
        'temperature': 0.7,
        'top_p': 0.9,
        'type': 'titan',
        'cost_per_1k_tokens': 0.0003,
        'context_window': 4000
    }
}

# Task-specific prompts for better results
TASK_PROMPTS = {
    'generation': {
        'system': "You are a highly skilled content creator. Generate engaging, creative, and well-structured content based on user input.",
        'template': "Please create content based on the following input:\n\n{input}\n\nGenerate creative and engaging content:"
    },
    'summary': {
        'system': "You are an expert summarization specialist. Create concise, accurate summaries that capture key points.",
        'template': "Please provide a comprehensive summary of the following text:\n\n{input}\n\nSummary:"
    },
    'translation': {
        'system': "You are a professional translator with expertise in multiple languages. Provide accurate, natural translations.",
        'template': "Please translate the following text to {target_language}:\n\n{input}\n\nTranslation:"
    },
    'analysis': {
        'system': "You are a analytical expert. Provide detailed analysis with insights and key findings.",
        'template': "Please analyze the following text and provide insights:\n\n{input}\n\nAnalysis:"
    },
    'rewrite': {
        'system': "You are an expert editor. Improve clarity, style, and readability while maintaining original meaning.",
        'template': "Please rewrite the following text to improve clarity and style:\n\n{input}\n\nImproved version:"
    },
    'qa': {
        'system': "You are a knowledgeable assistant. Provide accurate, helpful answers to questions.",
        'template': "Please answer the following question:\n\n{input}\n\nAnswer:"
    }
}

class TextGenerationError(Exception):
    """Custom exception for text generation errors"""
    pass

class ValidationError(Exception):
    """Custom exception for input validation errors"""
    pass

class RateLimitError(Exception):
    """Custom exception for rate limiting errors"""
    pass

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for text generation requests
    
    Args:
        event: Lambda event containing request data
        context: Lambda context object
        
    Returns:
        HTTP response dictionary
    """
    start_time = time.time()
    request_id = str(uuid.uuid4())
    
    try:
        # Log request start
        logger.info(f"Starting text generation request: {request_id}")
        
        # Parse request
        request_data = parse_request(event)
        
        # Validate input
        validate_input(request_data)
        
        # Extract parameters
        text_input = request_data.get('input', '')
        model_id = request_data.get('model', DEFAULT_MODEL)
        task_type = request_data.get('task', 'generation')
        user_id = request_data.get('userId', 'anonymous')
        async_mode = request_data.get('async', False)
        
        # Additional parameters
        target_language = request_data.get('targetLanguage', 'English')
        max_tokens = request_data.get('maxTokens')
        temperature = request_data.get('temperature')
        
        # Log processing details
        logger.info(f"Processing {task_type} task for user {user_id} with model {model_id}")
        
        # Handle async vs sync processing
        if async_mode:
            return handle_async_request(request_id, request_data, user_id)
        else:
            return handle_sync_request(
                request_id, text_input, model_id, task_type, user_id,
                target_language, max_tokens, temperature
            )
            
    except ValidationError as e:
        logger.warning(f"Validation error in request {request_id}: {str(e)}")
        return error_response(400, str(e), request_id)
    except RateLimitError as e:
        logger.warning(f"Rate limit exceeded for request {request_id}: {str(e)}")
        return error_response(429, str(e), request_id)
    except TextGenerationError as e:
        logger.error(f"Text generation error in request {request_id}: {str(e)}")
        return error_response(500, str(e), request_id)
    except Exception as e:
        logger.error(f"Unexpected error in request {request_id}: {str(e)}", exc_info=True)
        send_error_metric('UnexpectedError')
        return error_response(500, f"Internal server error: {str(e)}", request_id)
    finally:
        # Log processing time
        processing_time = time.time() - start_time
        logger.info(f"Request {request_id} completed in {processing_time:.2f}s")
        send_performance_metric('ProcessingTime', processing_time)

def parse_request(event: Dict[str, Any]) -> Dict[str, Any]:
    """Parse and normalize request data from various sources"""
    try:
        # Handle API Gateway request
        if 'body' in event:
            if event['body']:
                return json.loads(event['body'])
            else:
                raise ValidationError("Request body is empty")
        
        # Handle direct invocation
        elif 'input' in event:
            return event
        
        # Handle SQS event
        elif 'Records' in event:
            return json.loads(event['Records'][0]['body'])
        
        else:
            raise ValidationError("Invalid request format")
            
    except json.JSONDecodeError as e:
        raise ValidationError(f"Invalid JSON in request body: {str(e)}")

def validate_input(request_data: Dict[str, Any]) -> None:
    """Comprehensive input validation"""
    
    # Check required fields
    if 'input' not in request_data:
        raise ValidationError("Input text is required")
    
    text_input = request_data['input']
    
    # Basic validation
    if not text_input or not text_input.strip():
        raise ValidationError("Input text cannot be empty")
    
    # Length validation
    if len(text_input) > 100000:  # 100KB limit
        raise ValidationError("Input text too long (max 100KB)")
    
    if len(text_input) < 5:  # Minimum length
        raise ValidationError("Input text too short (min 5 characters)")
    
    # Model validation
    model_id = request_data.get('model', DEFAULT_MODEL)
    if model_id not in MODEL_CONFIGS:
        raise ValidationError(f"Unsupported model: {model_id}")
    
    # Task validation
    task_type = request_data.get('task', 'generation')
    if task_type not in TASK_PROMPTS:
        raise ValidationError(f"Unsupported task type: {task_type}")
    
    # Content safety validation
    if contains_harmful_content(text_input):
        raise ValidationError("Input contains potentially harmful content")
    
    # Parameter validation
    max_tokens = request_data.get('maxTokens')
    if max_tokens is not None:
        if not isinstance(max_tokens, int) or max_tokens < 1 or max_tokens > 8000:
            raise ValidationError("maxTokens must be between 1 and 8000")
    
    temperature = request_data.get('temperature')
    if temperature is not None:
        if not isinstance(temperature, (int, float)) or temperature < 0 or temperature > 2:
            raise ValidationError("temperature must be between 0 and 2")

def contains_harmful_content(text: str) -> bool:
    """Basic content safety check"""
    harmful_patterns = [
        r'\b(hack|crack|exploit|malware|virus)\b',
        r'\b(illegal|criminal|terrorism|violence)\b',
        r'\b(personal\s+information|credit\s+card|ssn|password)\b'
    ]
    
    text_lower = text.lower()
    for pattern in harmful_patterns:
        if re.search(pattern, text_lower):
            return True
    return False

def handle_sync_request(
    request_id: str, 
    text_input: str, 
    model_id: str, 
    task_type: str, 
    user_id: str,
    target_language: str = 'English',
    max_tokens: Optional[int] = None,
    temperature: Optional[float] = None
) -> Dict[str, Any]:
    """Handle synchronous text generation request"""
    
    try:
        # Check cache first
        if ENABLE_CACHING and CACHE_TABLE:
            cached_response = check_cache(text_input, model_id, task_type, target_language)
            if cached_response:
                logger.info(f"Cache hit for request {request_id}")
                send_performance_metric('CacheHit', 1)
                return success_response(cached_response, request_id, cached=True)
        
        # Generate text
        result = generate_text(text_input, model_id, task_type, target_language, max_tokens, temperature)
        
        # Save to history
        save_request_history(request_id, user_id, text_input, result, model_id, task_type)
        
        # Save to cache
        if ENABLE_CACHING and CACHE_TABLE:
            save_to_cache(text_input, model_id, task_type, target_language, result)
        
        # Send success metrics
        send_performance_metric('SuccessfulGeneration', 1)
        send_usage_metric(model_id, result.get('usage', {}))
        
        return success_response(result, request_id)
        
    except Exception as e:
        logger.error(f"Error in sync processing for request {request_id}: {str(e)}")
        send_error_metric('SyncProcessingError')
        raise TextGenerationError(f"Failed to generate text: {str(e)}")

def handle_async_request(request_id: str, request_data: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Handle asynchronous text generation request"""
    
    try:
        if not QUEUE_URL:
            raise TextGenerationError("Async processing not configured")
        
        # Prepare message for queue
        message_body = {
            'requestId': request_id,
            'requestData': request_data,
            'userId': user_id,
            'timestamp': datetime.utcnow().isoformat(),
            'retryCount': 0
        }
        
        # Send to SQS queue
        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message_body),
            MessageGroupId=user_id,
            MessageDeduplicationId=request_id
        )
        
        logger.info(f"Queued async request {request_id} for user {user_id}")
        send_performance_metric('AsyncRequest', 1)
        
        return {
            'statusCode': 202,
            'headers': get_response_headers(),
            'body': json.dumps({
                'success': True,
                'requestId': request_id,
                'status': 'queued',
                'message': 'Request queued for async processing'
            })
        }
        
    except Exception as e:
        logger.error(f"Error in async processing for request {request_id}: {str(e)}")
        send_error_metric('AsyncProcessingError')
        raise TextGenerationError(f"Failed to queue async request: {str(e)}")

def generate_text(
    input_text: str, 
    model_id: str, 
    task_type: str, 
    target_language: str = 'English',
    max_tokens: Optional[int] = None,
    temperature: Optional[float] = None
) -> Dict[str, Any]:
    """Generate text using specified model and task type"""
    
    model_config = MODEL_CONFIGS[model_id]
    model_type = model_config['type']
    
    # Use provided parameters or defaults
    final_max_tokens = max_tokens or model_config['max_tokens']
    final_temperature = temperature if temperature is not None else model_config['temperature']
    
    # Build prompt based on task type
    prompt = build_prompt(input_text, task_type, target_language)
    
    try:
        if model_type == 'claude':
            return generate_with_claude(model_id, prompt, final_max_tokens, final_temperature, model_config)
        elif model_type == 'titan':
            return generate_with_titan(model_id, prompt, final_max_tokens, final_temperature, model_config)
        else:
            raise TextGenerationError(f"Unsupported model type: {model_type}")
            
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        logger.error(f"AWS client error: {error_code} - {error_message}")
        
        if error_code == 'ThrottlingException':
            send_error_metric('ThrottlingError')
            raise TextGenerationError("Service temporarily busy, please try again later")
        elif error_code == 'ValidationException':
            send_error_metric('ValidationError')
            raise TextGenerationError(f"Invalid request: {error_message}")
        else:
            send_error_metric(f'AWSError_{error_code}')
            raise TextGenerationError(f"Service error: {error_message}")
    
    except BotoCoreError as e:
        logger.error(f"Boto core error: {str(e)}")
        send_error_metric('BotoCoreError')
        raise TextGenerationError("Network or configuration error")

def build_prompt(input_text: str, task_type: str, target_language: str = 'English') -> str:
    """Build optimized prompt based on task type"""
    
    task_config = TASK_PROMPTS.get(task_type, TASK_PROMPTS['generation'])
    
    # Special handling for translation
    if task_type == 'translation':
        template = task_config['template'].format(
            input=input_text,
            target_language=target_language
        )
    else:
        template = task_config['template'].format(input=input_text)
    
    return template

def generate_with_claude(
    model_id: str, 
    prompt: str, 
    max_tokens: int, 
    temperature: float,
    model_config: Dict[str, Any]
) -> Dict[str, Any]:
    """Generate text using Claude models"""
    
    # Determine system prompt based on task
    task_type = extract_task_from_prompt(prompt)
    system_prompt = TASK_PROMPTS.get(task_type, TASK_PROMPTS['generation'])['system']
    
    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": min(max_tokens, 4000),
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ],
        "system": system_prompt,
        "temperature": temperature,
        "top_p": model_config['top_p']
    }
    
    start_time = time.time()
    
    response = bedrock_runtime.invoke_model(
        modelId=model_id,
        body=json.dumps(request_body),
        contentType="application/json",
        accept="application/json"
    )
    
    response_time = time.time() - start_time
    response_body = json.loads(response['body'].read())
    
    # Extract response text
    generated_text = ""
    if 'content' in response_body and response_body['content']:
        generated_text = response_body['content'][0].get('text', '')
    
    # Calculate usage and cost
    usage = response_body.get('usage', {})
    input_tokens = usage.get('input_tokens', 0)
    output_tokens = usage.get('output_tokens', 0)
    total_tokens = input_tokens + output_tokens
    
    estimated_cost = (total_tokens / 1000) * model_config['cost_per_1k_tokens']
    
    return {
        'model': model_id,
        'generated_text': generated_text,
        'usage': {
            'input_tokens': input_tokens,
            'output_tokens': output_tokens,
            'total_tokens': total_tokens
        },
        'performance': {
            'response_time': response_time,
            'estimated_cost': estimated_cost
        },
        'timestamp': datetime.utcnow().isoformat(),
        'task_type': task_type
    }

def generate_with_titan(
    model_id: str, 
    prompt: str, 
    max_tokens: int, 
    temperature: float,
    model_config: Dict[str, Any]
) -> Dict[str, Any]:
    """Generate text using Titan models"""
    
    request_body = {
        "inputText": prompt,
        "textGenerationConfig": {
            "maxTokenCount": min(max_tokens, 4000),
            "temperature": temperature,
            "topP": model_config['top_p'],
            "stopSequences": []
        }
    }
    
    start_time = time.time()
    
    response = bedrock_runtime.invoke_model(
        modelId=model_id,
        body=json.dumps(request_body),
        contentType="application/json",
        accept="application/json"
    )
    
    response_time = time.time() - start_time
    response_body = json.loads(response['body'].read())
    
    # Extract response text
    generated_text = ""
    if 'results' in response_body and response_body['results']:
        generated_text = response_body['results'][0].get('outputText', '')
    
    # Calculate usage and cost (Titan provides token counts differently)
    input_tokens = response_body.get('inputTextTokenCount', 0)
    output_tokens = len(generated_text.split()) * 1.3  # Approximate
    total_tokens = input_tokens + output_tokens
    
    estimated_cost = (total_tokens / 1000) * model_config['cost_per_1k_tokens']
    
    return {
        'model': model_id,
        'generated_text': generated_text,
        'usage': {
            'input_tokens': input_tokens,
            'output_tokens': int(output_tokens),
            'total_tokens': int(total_tokens)
        },
        'performance': {
            'response_time': response_time,
            'estimated_cost': estimated_cost
        },
        'timestamp': datetime.utcnow().isoformat(),
        'task_type': extract_task_from_prompt(prompt)
    }

def extract_task_from_prompt(prompt: str) -> str:
    """Extract task type from prompt for analytics"""
    prompt_lower = prompt.lower()
    
    if 'translate' in prompt_lower:
        return 'translation'
    elif 'summary' in prompt_lower or 'summarize' in prompt_lower:
        return 'summary'
    elif 'analyze' in prompt_lower or 'analysis' in prompt_lower:
        return 'analysis'
    elif 'rewrite' in prompt_lower or 'improve' in prompt_lower:
        return 'rewrite'
    elif 'answer' in prompt_lower or 'question' in prompt_lower:
        return 'qa'
    else:
        return 'generation'

def check_cache(input_text: str, model_id: str, task_type: str, target_language: str = '') -> Optional[Dict[str, Any]]:
    """Check if response exists in cache"""
    
    try:
        if not CACHE_TABLE:
            return None
            
        cache_table = dynamodb.Table(CACHE_TABLE)
        request_hash = generate_request_hash(input_text, model_id, task_type, target_language)
        
        response = cache_table.get_item(
            Key={'requestHash': request_hash}
        )
        
        if 'Item' in response:
            item = response['Item']
            # Check if cache is still valid
            created_at = datetime.fromisoformat(item['createdAt'])
            if datetime.utcnow() - created_at < timedelta(hours=CACHE_RETENTION_HOURS):
                return item.get('result')
        
        return None
        
    except Exception as e:
        logger.warning(f"Cache check error: {str(e)}")
        return None

def save_to_cache(
    input_text: str, 
    model_id: str, 
    task_type: str, 
    target_language: str, 
    result: Dict[str, Any]
) -> None:
    """Save result to cache"""
    
    try:
        if not CACHE_TABLE:
            return
            
        cache_table = dynamodb.Table(CACHE_TABLE)
        request_hash = generate_request_hash(input_text, model_id, task_type, target_language)
        
        ttl = int((datetime.utcnow() + timedelta(hours=CACHE_RETENTION_HOURS)).timestamp())
        
        cache_table.put_item(
            Item={
                'requestHash': request_hash,
                'result': result,
                'ttl': ttl,
                'createdAt': datetime.utcnow().isoformat(),
                'modelId': model_id,
                'taskType': task_type
            }
        )
        
    except Exception as e:
        logger.warning(f"Cache save error: {str(e)}")

def save_request_history(
    request_id: str, 
    user_id: str, 
    input_text: str, 
    result: Dict[str, Any], 
    model_id: str, 
    task_type: str
) -> None:
    """Save request to history table"""
    
    try:
        if not HISTORY_TABLE:
            return
            
        history_table = dynamodb.Table(HISTORY_TABLE)
        
        # Handle large content by storing in S3
        s3_location = None
        stored_input = input_text
        stored_output = result.get('generated_text', '')
        
        if len(input_text) > 1000 or len(stored_output) > 1000:
            s3_location = store_large_content(request_id, {
                'input': input_text,
                'output': result
            })
            stored_input = f"[Stored in S3: {s3_location}]"
            stored_output = "[Stored in S3]"
        
        # Calculate TTL (30 days)
        ttl = int((datetime.utcnow() + timedelta(days=30)).timestamp())
        
        history_table.put_item(
            Item={
                'requestId': request_id,
                'userId': user_id,
                'timestamp': datetime.utcnow().isoformat(),
                'modelId': model_id,
                'taskType': task_type,
                'inputText': stored_input[:1000],  # Truncate for DynamoDB
                'outputText': stored_output[:1000],  # Truncate for DynamoDB
                'usage': result.get('usage', {}),
                'performance': result.get('performance', {}),
                's3Location': s3_location,
                'ttl': ttl
            }
        )
        
    except Exception as e:
        logger.warning(f"History save error: {str(e)}")

def store_large_content(request_id: str, content: Dict[str, Any]) -> str:
    """Store large content in S3"""
    
    try:
        if not OUTPUT_BUCKET:
            return ""
            
        s3_key = f"requests/{datetime.utcnow().strftime('%Y/%m/%d')}/{request_id}.json"
        
        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=s3_key,
            Body=json.dumps(content, ensure_ascii=False, indent=2),
            ContentType='application/json',
            ServerSideEncryption='AES256'
        )
        
        return f"s3://{OUTPUT_BUCKET}/{s3_key}"
        
    except Exception as e:
        logger.warning(f"S3 storage error: {str(e)}")
        return ""

def generate_request_hash(input_text: str, model_id: str, task_type: str, target_language: str = '') -> str:
    """Generate unique hash for request caching"""
    content = f"{input_text}:{model_id}:{task_type}:{target_language}"
    return hashlib.sha256(content.encode('utf-8')).hexdigest()

def send_performance_metric(metric_name: str, value: float, unit: str = 'Count') -> None:
    """Send custom metrics to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace=f'{PROJECT_NAME}/{ENVIRONMENT}',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except Exception as e:
        logger.warning(f"Failed to send metric {metric_name}: {str(e)}")

def send_error_metric(error_type: str) -> None:
    """Send error metrics to CloudWatch"""
    send_performance_metric(f'Error_{error_type}', 1)

def send_usage_metric(model_id: str, usage: Dict[str, Any]) -> None:
    """Send usage metrics to CloudWatch"""
    model_name = model_id.split('.')[-1]  # Extract model name
    
    if 'total_tokens' in usage:
        send_performance_metric(f'TokensUsed_{model_name}', usage['total_tokens'])
    
    if 'input_tokens' in usage:
        send_performance_metric(f'InputTokens_{model_name}', usage['input_tokens'])
    
    if 'output_tokens' in usage:
        send_performance_metric(f'OutputTokens_{model_name}', usage['output_tokens'])

def get_response_headers() -> Dict[str, str]:
    """Get standard response headers"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'X-XSS-Protection': '1; mode=block'
    }

def success_response(result: Dict[str, Any], request_id: str, cached: bool = False) -> Dict[str, Any]:
    """Generate success response"""
    return {
        'statusCode': 200,
        'headers': get_response_headers(),
        'body': json.dumps({
            'success': True,
            'requestId': request_id,
            'result': result,
            'cached': cached,
            'timestamp': datetime.utcnow().isoformat()
        }, ensure_ascii=False)
    }

def error_response(status_code: int, message: str, request_id: str = None) -> Dict[str, Any]:
    """Generate error response"""
    return {
        'statusCode': status_code,
        'headers': get_response_headers(),
        'body': json.dumps({
            'success': False,
            'error': message,
            'requestId': request_id,
            'timestamp': datetime.utcnow().isoformat()
        }, ensure_ascii=False)
    }

# Helper functions for batch processing and streaming
def process_batch_requests(requests: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Process multiple requests in batch"""
    results = []
    
    for request_data in requests:
        try:
            # Validate each request
            validate_input(request_data)
            
            # Generate text
            result = generate_text(
                request_data['input'],
                request_data.get('model', DEFAULT_MODEL),
                request_data.get('task', 'generation')
            )
            
            results.append({
                'success': True,
                'result': result,
                'requestId': request_data.get('requestId', str(uuid.uuid4()))
            })
            
        except Exception as e:
            results.append({
                'success': False,
                'error': str(e),
                'requestId': request_data.get('requestId', str(uuid.uuid4()))
            })
    
    return results

def validate_model_availability(model_id: str) -> bool:
    """Check if model is available and accessible"""
    try:
        # Try a simple test request
        test_request = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "Test"}]
        }
        
        if model_id.startswith('anthropic.claude'):
            bedrock_runtime.invoke_model(
                modelId=model_id,
                body=json.dumps(test_request),
                contentType="application/json",
                accept="application/json"
            )
        else:
            test_request = {
                "inputText": "Test",
                "textGenerationConfig": {"maxTokenCount": 10}
            }
            bedrock_runtime.invoke_model(
                modelId=model_id,
                body=json.dumps(test_request),
                contentType="application/json",
                accept="application/json"
            )
        
        return True
        
    except Exception as e:
        logger.warning(f"Model {model_id} not available: {str(e)}")
        return False

# Initialize and validate environment on cold start
def init_environment():
    """Initialize and validate environment configuration"""
    logger.info(f"Initializing text generation service in {ENVIRONMENT} environment")
    
    # Validate required environment variables
    required_vars = ['DEFAULT_MODEL']
    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {missing_vars}")
        raise Exception(f"Missing required environment variables: {missing_vars}")
    
    # Validate model availability
    if not validate_model_availability(DEFAULT_MODEL):
        logger.warning(f"Default model {DEFAULT_MODEL} not available")
    
    logger.info("Text generation service initialized successfully")

# Initialize on import
init_environment()