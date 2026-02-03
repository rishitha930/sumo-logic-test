import json
import logging
import os
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

INSTANCE_ID_ENV = "INSTANCE_ID"
SNS_TOPIC_ARN_ENV = "SNS_TOPIC_ARN"


def _get_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def handler(event, context):
    instance_id = _get_env(INSTANCE_ID_ENV)
    topic_arn = _get_env(SNS_TOPIC_ARN_ENV)

    logger.info("Received event: %s", json.dumps(event, default=str))

    action_time = datetime.now(timezone.utc).isoformat()

    try:
        ec2.reboot_instances(InstanceIds=[instance_id])
        message = (
            f"Reboot requested for EC2 instance {instance_id} at {action_time}. "
            "Triggered by Sumo Logic alert."
        )
        logger.info(message)

        sns.publish(
            TopicArn=topic_arn,
            Subject="EC2 instance reboot triggered by Sumo Logic alert",
            Message=message,
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "instance_id": instance_id,
                    "action": "reboot",
                    "timestamp": action_time,
                }
            ),
        }
    except Exception as exc:
        logger.exception("Failed to reboot instance or publish SNS message")
        raise exc