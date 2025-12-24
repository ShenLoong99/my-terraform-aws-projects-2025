import boto3
import os
import logging

# AWS clients
s3 = boto3.client("s3")
polly = boto3.client("polly")

# Environment variables
OUTPUT_BUCKET = os.environ["OUTPUT_BUCKET"]
VOICE_ID = "Joanna"

# Polly / cost guardrail
MAX_CHARS = 10000  # safe limit for free tier & Polly limits

# Logging setup
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:
        # Extract S3 event details
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        logger.info({
            "message": "Received S3 event",
            "input_bucket": bucket,
            "input_key": key
        })

        # Read text file from S3
        text_obj = s3.get_object(Bucket=bucket, Key=key)
        text = text_obj["Body"].read().decode("utf-8")

        text_length = len(text)

        logger.info({
            "message": "Text file loaded",
            "characters": text_length
        })

        # Guard against oversized text
        if text_length > MAX_CHARS:
            logger.warning({
                "message": "Text exceeds allowed character limit",
                "characters": text_length,
                "max_allowed": MAX_CHARS
            })
            raise ValueError("Text too long for Polly processing")

        # Call Amazon Polly
        response = polly.synthesize_speech(
            Text=text,
            VoiceId=VOICE_ID,
            OutputFormat="mp3"
        )

        # Save audio to output bucket
        audio_key = key.replace(".txt", ".mp3")
        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=audio_key,
            Body=response["AudioStream"].read(),
            ServerSideEncryption="AES256" # enforce encryption
        )

        logger.info({
            "message": "Audio file successfully generated",
            "output_bucket": OUTPUT_BUCKET,
            "output_key": audio_key
        })

        return {
            "status": "success",
            "input_file": key,
            "output_file": audio_key
        }

    except Exception as e:
        logger.error({
            "message": "Lambda execution failed",
            "error": str(e)
        })
        raise
