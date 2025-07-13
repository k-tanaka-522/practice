"""
Async Text Generation Processor
==============================

Lambda function for processing text generation requests asynchronously.
Handles SQS events, batch processing, and failure management.

Features:
- SQS message processing
- Batch processing optimization
- Dead letter queue handling
- Retry logic with exponential backoff
- Progress tracking and notifications
- Result storage in S3
- Error handling and alerting

Author: Claude AI Assistant
License: MIT
"""

import json
import boto3
import os
import logging
import time
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from app import (
    generate_text, save_request_history, store_large_content,
    send_performance_metric, send_error_metric, validate_input,
    MODEL_CONFIGS, TASK_PROMPTS
)

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
sns = boto3.client('sns')
sqs = boto3.client('sqs')

# Environment variables
HISTORY_TABLE = os.environ.get('HISTORY_TABLE', '')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET', '')
NOTIFICATION_TOPIC = os.environ.get('NOTIFICATION_TOPIC', '')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'text-generation')
MAX_RETRIES = int(os.environ.get('MAX_RETRIES', '3'))
BATCH_SIZE = int(os.environ.get('BATCH_SIZE', '10'))

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main handler for async text generation processing
    
    Args:
        event: SQS event containing messages to process
        context: Lambda context object
        
    Returns:
        Processing result summary
    """
    start_time = time.time()
    
    try:
        logger.info(f"Starting async processing with {len(event.get('Records', []))} messages")
        
        # Process all SQS records
        results = process_sqs_records(event.get('Records', []))
        
        # Generate summary
        total_messages = len(results)
        successful = len([r for r in results if r['success']])
        failed = total_messages - successful
        
        processing_time = time.time() - start_time
        
        # Send metrics
        send_performance_metric('AsyncMessagesProcessed', total_messages)
        send_performance_metric('AsyncSuccessful', successful)
        send_performance_metric('AsyncFailed', failed)
        send_performance_metric('AsyncProcessingTime', processing_time)
        
        logger.info(f"Async processing completed: {successful}/{total_messages} successful, "
                   f"processing time: {processing_time:.2f}s")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': total_messages,
                'successful': successful,
                'failed': failed,
                'processing_time': processing_time
            })
        }
        
    except Exception as e:
        logger.error(f"Error in async processing: {str(e)}", exc_info=True)
        send_error_metric('AsyncProcessingError')
        raise e

def process_sqs_records(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Process SQS records"""
    results = []
    
    for record in records:
        try:
            # Parse message
            message_data = json.loads(record['body'])
            request_id = message_data.get('requestId', 'unknown')
            
            logger.info(f"Processing async request: {request_id}")
            
            # Process single request
            result = process_async_request(message_data)
            results.append(result)
            
        except Exception as e:
            logger.error(f"Error processing SQS record: {str(e)}")
            results.append({
                'success': False,
                'error': str(e),
                'requestId': message_data.get('requestId', 'unknown') if 'message_data' in locals() else 'unknown'
            })
    
    return results

def process_async_request(message_data: Dict[str, Any]) -> Dict[str, Any]:
    """Process a single async text generation request"""
    
    request_id = message_data.get('requestId', 'unknown')
    request_data = message_data.get('requestData', {})
    user_id = message_data.get('userId', 'anonymous')
    retry_count = message_data.get('retryCount', 0)
    
    try:
        # Update status to processing
        update_request_status(request_id, 'processing')
        
        # Validate request data
        validate_input(request_data)
        
        # Extract parameters
        text_input = request_data.get('input', '')
        model_id = request_data.get('model', os.environ.get('DEFAULT_MODEL', 'anthropic.claude-3-sonnet-20240229-v1:0'))
        task_type = request_data.get('task', 'generation')
        target_language = request_data.get('targetLanguage', 'English')
        max_tokens = request_data.get('maxTokens')
        temperature = request_data.get('temperature')
        
        # Generate text
        result = generate_text(text_input, model_id, task_type, target_language, max_tokens, temperature)
        
        # Store result in S3
        s3_location = store_result_in_s3(request_id, user_id, request_data, result)
        
        # Save to history
        save_request_history(request_id, user_id, text_input, result, model_id, task_type)
        
        # Update status to completed
        update_request_status(request_id, 'completed', s3_location, result)
        
        # Send notification (if configured)
        send_completion_notification(request_id, user_id, result, s3_location)
        
        logger.info(f"Successfully processed async request: {request_id}")
        
        return {
            'success': True,
            'requestId': request_id,
            'result': result,
            's3Location': s3_location
        }
        
    except Exception as e:
        logger.error(f"Error processing async request {request_id}: {str(e)}")
        
        # Handle retry logic
        if retry_count < MAX_RETRIES:
            return handle_retry(message_data, str(e))
        else:
            # Max retries reached, mark as failed
            update_request_status(request_id, 'failed', error_message=str(e))
            send_failure_notification(request_id, user_id, str(e))
            
            return {
                'success': False,
                'requestId': request_id,
                'error': str(e),
                'retries_exhausted': True
            }

def handle_retry(message_data: Dict[str, Any], error_message: str) -> Dict[str, Any]:
    """Handle retry logic for failed requests"""
    
    request_id = message_data.get('requestId', 'unknown')
    retry_count = message_data.get('retryCount', 0) + 1
    
    # Calculate exponential backoff delay
    delay_seconds = min(2 ** retry_count, 300)  # Max 5 minutes
    
    try:
        # Update message with new retry count
        message_data['retryCount'] = retry_count
        message_data['lastError'] = error_message
        message_data['nextRetryTime'] = (datetime.utcnow() + timedelta(seconds=delay_seconds)).isoformat()
        
        # Send back to queue with delay
        sqs.send_message(
            QueueUrl=os.environ.get('QUEUE_URL', ''),
            MessageBody=json.dumps(message_data),
            DelaySeconds=delay_seconds,
            MessageGroupId=message_data.get('userId', 'anonymous'),
            MessageDeduplicationId=f"{request_id}-retry-{retry_count}"
        )
        
        # Update status
        update_request_status(request_id, 'retrying', error_message=error_message, retry_count=retry_count)
        
        logger.info(f"Scheduled retry {retry_count} for request {request_id} after {delay_seconds}s")
        
        return {
            'success': False,
            'requestId': request_id,
            'error': error_message,
            'retry_scheduled': True,
            'retry_count': retry_count,
            'delay_seconds': delay_seconds
        }
        
    except Exception as e:
        logger.error(f"Error scheduling retry for request {request_id}: {str(e)}")
        return {
            'success': False,
            'requestId': request_id,
            'error': f"Original error: {error_message}, Retry error: {str(e)}",
            'retry_failed': True
        }

def store_result_in_s3(
    request_id: str, 
    user_id: str, 
    request_data: Dict[str, Any], 
    result: Dict[str, Any]
) -> str:
    """Store complete result in S3"""
    
    try:
        if not OUTPUT_BUCKET:
            return ""
        
        # Prepare complete result data
        complete_result = {
            'requestId': request_id,
            'userId': user_id,
            'request': request_data,
            'result': result,
            'processedAt': datetime.utcnow().isoformat(),
            'environment': ENVIRONMENT
        }
        
        # Generate S3 key with partitioning
        date_partition = datetime.utcnow().strftime('%Y/%m/%d')
        s3_key = f"async-results/{date_partition}/{request_id}.json"
        
        # Store in S3
        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=s3_key,
            Body=json.dumps(complete_result, ensure_ascii=False, indent=2),
            ContentType='application/json',
            ServerSideEncryption='AES256',
            Metadata={
                'request-id': request_id,
                'user-id': user_id,
                'processed-at': datetime.utcnow().isoformat()
            }
        )
        
        s3_location = f"s3://{OUTPUT_BUCKET}/{s3_key}"
        logger.info(f"Stored result for request {request_id} at {s3_location}")
        
        return s3_location
        
    except Exception as e:
        logger.error(f"Error storing result in S3 for request {request_id}: {str(e)}")
        return ""

def update_request_status(
    request_id: str, 
    status: str, 
    s3_location: str = None, 
    result: Dict[str, Any] = None,
    error_message: str = None,
    retry_count: int = None
) -> None:
    """Update request status in DynamoDB"""
    
    try:
        if not HISTORY_TABLE:
            return
            
        history_table = dynamodb.Table(HISTORY_TABLE)
        
        # Build update expression
        update_expression = 'SET #status = :status, lastUpdated = :timestamp'
        expression_values = {
            ':status': status,
            ':timestamp': datetime.utcnow().isoformat()
        }
        expression_names = {'#status': 'status'}
        
        # Add conditional fields
        if status == 'completed':
            if s3_location:
                update_expression += ', s3Location = :location'
                expression_values[':location'] = s3_location
            
            if result:
                update_expression += ', completedAt = :completed'
                expression_values[':completed'] = datetime.utcnow().isoformat()
                
                # Store summary metrics
                if 'usage' in result:
                    update_expression += ', tokenUsage = :usage'
                    expression_values[':usage'] = result['usage']
                
                if 'performance' in result:
                    update_expression += ', performance = :perf'
                    expression_values[':perf'] = result['performance']
        
        elif status == 'failed' and error_message:
            update_expression += ', errorMessage = :error, failedAt = :failed'
            expression_values[':error'] = error_message
            expression_values[':failed'] = datetime.utcnow().isoformat()
        
        elif status == 'retrying':
            if error_message:
                update_expression += ', lastError = :error'
                expression_values[':error'] = error_message
            
            if retry_count is not None:
                update_expression += ', retryCount = :retries'
                expression_values[':retries'] = retry_count
        
        # Update the item
        history_table.update_item(
            Key={'requestId': request_id},
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expression_names,
            ExpressionAttributeValues=expression_values
        )
        
    except Exception as e:
        logger.warning(f"Error updating request status for {request_id}: {str(e)}")

def send_completion_notification(
    request_id: str, 
    user_id: str, 
    result: Dict[str, Any], 
    s3_location: str
) -> None:
    """Send completion notification"""
    
    try:
        if not NOTIFICATION_TOPIC:
            return
        
        # Prepare notification message
        notification = {
            'type': 'text_generation_completed',
            'requestId': request_id,
            'userId': user_id,
            'completedAt': datetime.utcnow().isoformat(),
            'resultLocation': s3_location,
            'summary': {
                'model': result.get('model', ''),
                'taskType': result.get('task_type', ''),
                'tokensUsed': result.get('usage', {}).get('total_tokens', 0),
                'processingTime': result.get('performance', {}).get('response_time', 0)
            }
        }
        
        # Send SNS notification
        sns.publish(
            TopicArn=NOTIFICATION_TOPIC,
            Message=json.dumps(notification),
            Subject=f'Text Generation Completed - {request_id}',
            MessageAttributes={
                'event_type': {'DataType': 'String', 'StringValue': 'completion'},
                'user_id': {'DataType': 'String', 'StringValue': user_id},
                'request_id': {'DataType': 'String', 'StringValue': request_id}
            }
        )
        
        logger.info(f"Sent completion notification for request {request_id}")
        
    except Exception as e:
        logger.warning(f"Error sending completion notification for {request_id}: {str(e)}")

def send_failure_notification(request_id: str, user_id: str, error_message: str) -> None:
    """Send failure notification"""
    
    try:
        if not NOTIFICATION_TOPIC:
            return
        
        # Prepare failure notification
        notification = {
            'type': 'text_generation_failed',
            'requestId': request_id,
            'userId': user_id,
            'failedAt': datetime.utcnow().isoformat(),
            'errorMessage': error_message,
            'maxRetriesReached': True
        }
        
        # Send SNS notification
        sns.publish(
            TopicArn=NOTIFICATION_TOPIC,
            Message=json.dumps(notification),
            Subject=f'Text Generation Failed - {request_id}',
            MessageAttributes={
                'event_type': {'DataType': 'String', 'StringValue': 'failure'},
                'user_id': {'DataType': 'String', 'StringValue': user_id},
                'request_id': {'DataType': 'String', 'StringValue': request_id}
            }
        )
        
        logger.info(f"Sent failure notification for request {request_id}")
        
    except Exception as e:
        logger.warning(f"Error sending failure notification for {request_id}: {str(e)}")

def process_batch_requests(batch_requests: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Process multiple requests in batch for efficiency"""
    
    results = []
    batch_start_time = time.time()
    
    logger.info(f"Processing batch of {len(batch_requests)} requests")
    
    for request_data in batch_requests:
        try:
            result = process_async_request(request_data)
            results.append(result)
            
        except Exception as e:
            logger.error(f"Error in batch processing: {str(e)}")
            results.append({
                'success': False,
                'requestId': request_data.get('requestId', 'unknown'),
                'error': str(e)
            })
    
    batch_processing_time = time.time() - batch_start_time
    successful_count = len([r for r in results if r.get('success')])
    
    logger.info(f"Batch processing completed: {successful_count}/{len(batch_requests)} successful, "
               f"time: {batch_processing_time:.2f}s")
    
    # Send batch metrics
    send_performance_metric('BatchProcessingTime', batch_processing_time)
    send_performance_metric('BatchSize', len(batch_requests))
    send_performance_metric('BatchSuccessRate', successful_count / len(batch_requests))
    
    return results

def cleanup_old_records() -> None:
    """Clean up old records and temporary files"""
    
    try:
        # This function could be called periodically to clean up:
        # 1. Expired cache entries
        # 2. Old S3 objects
        # 3. Stale DynamoDB records
        # 4. Temporary processing files
        
        logger.info("Starting cleanup of old records")
        
        # Cleanup would be implemented based on specific requirements
        # For now, this is a placeholder
        
        logger.info("Cleanup completed")
        
    except Exception as e:
        logger.error(f"Error during cleanup: {str(e)}")

def get_processing_statistics() -> Dict[str, Any]:
    """Get processing statistics for monitoring"""
    
    try:
        # Query recent processing history
        if not HISTORY_TABLE:
            return {}
        
        history_table = dynamodb.Table(HISTORY_TABLE)
        
        # Get statistics for the last 24 hours
        since_timestamp = (datetime.utcnow() - timedelta(hours=24)).isoformat()
        
        # This would require a GSI on timestamp for efficient querying
        # For now, return basic stats
        
        return {
            'period': '24h',
            'timestamp': datetime.utcnow().isoformat(),
            'environment': ENVIRONMENT
        }
        
    except Exception as e:
        logger.error(f"Error getting processing statistics: {str(e)}")
        return {}

# Health check function for monitoring
def health_check() -> Dict[str, Any]:
    """Perform health check of async processing system"""
    
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'checks': {}
    }
    
    try:
        # Check DynamoDB connectivity
        if HISTORY_TABLE:
            history_table = dynamodb.Table(HISTORY_TABLE)
            history_table.get_item(Key={'requestId': 'health-check'})
            health_status['checks']['dynamodb'] = 'ok'
        
        # Check S3 connectivity
        if OUTPUT_BUCKET:
            s3.head_bucket(Bucket=OUTPUT_BUCKET)
            health_status['checks']['s3'] = 'ok'
        
        # Check SNS connectivity
        if NOTIFICATION_TOPIC:
            sns.get_topic_attributes(TopicArn=NOTIFICATION_TOPIC)
            health_status['checks']['sns'] = 'ok'
        
    except Exception as e:
        health_status['status'] = 'unhealthy'
        health_status['error'] = str(e)
        logger.error(f"Health check failed: {str(e)}")
    
    return health_status