import boto3
import json
import os
from PyPDF2 import PdfReader
import tempfile

def split_pdf(pdf_path, chunk_size):
    chunks = []
    with open(pdf_path, 'rb') as file:
        pdf = PdfReader(file)
        total_pages = len(pdf.pages)
        
        for i in range(0, total_pages, chunk_size):
            chunk_end = min(i + chunk_size, total_pages)
            chunks.append((i, chunk_end))
    
    return chunks

def process_chunk(bucket, key, start_page, end_page):
    textract = boto3.client('textract')
    
    try:
        response = textract.start_document_analysis(
            DocumentLocation={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            },
            FeatureTypes=['TABLES', 'FORMS'],
            JobTag=f'chunk_{start_page}_{end_page}',
            NotificationChannel={
                'SNSTopicArn': os.environ['SNS_TOPIC_ARN'],
                'RoleArn': os.environ['TEXTRACT_ROLE_ARN']
            },
            Pages=list(range(start_page + 1, end_page + 1))
        )
        
        return response['JobId']
    
    except Exception as e:
        print(f"Error processing chunk {start_page}-{end_page}: {str(e)}")
        raise

def handler(event, context):
    s3 = boto3.client('s3')
    sqs = boto3.client('sqs')
    
    try:
        bucket = event['bucket']
        key = event['key']
        
        with tempfile.NamedTemporaryFile(suffix='.pdf') as temp_file:
            s3.download_file(bucket, key, temp_file.name)
            
            chunks = split_pdf(temp_file.name, int(os.environ['MAX_PAGES_CHUNK']))
            
            for start_page, end_page in chunks:
                job_id = process_chunk(bucket, key, start_page, end_page)
                
                sqs.send_message(
                    QueueUrl=os.environ['SQS_QUEUE_URL'],
                    MessageBody=json.dumps({
                        'job_id': job_id,
                        'bucket': bucket,
                        'key': key,
                        'start_page': start_page,
                        'end_page': end_page
                    })
                )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Started processing {len(chunks)} chunks',
                'total_chunks': len(chunks)
            })
        }
        
    except Exception as e:
        print(f"Error processing PDF: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
