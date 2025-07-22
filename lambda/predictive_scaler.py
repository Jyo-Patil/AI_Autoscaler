import boto3
import os
import json
from datetime import datetime, timedelta

ASG_NAME = os.environ.get("ASG_NAME", "predictive-asg")

autoscaling_client = boto3.client("autoscaling")
cloudwatch_client = boto3.client("cloudwatch")

def lambda_handler(event, context):
    print(f"[{datetime.utcnow()}] Event: {json.dumps(event)}")

    # Example logic: If average CPU > 60%, scale up; else scale down
    metric = cloudwatch_client.get_metric_statistics(
        Namespace="AWS/EC2",
        MetricName="CPUUtilization",
        Dimensions=[
            {"Name": "AutoScalingGroupName", "Value": ASG_NAME}
        ],
        StartTime=datetime.utcnow() - timedelta(minutes=10),
        EndTime=datetime.utcnow(),
        Period=300,
        Statistics=["Average"]
    )

    avg_cpu = 0
    if metric["Datapoints"]:
        avg_cpu = metric["Datapoints"][0]["Average"]
    print(f"Average CPU utilization: {avg_cpu}")

    if avg_cpu > 60:
        desired_capacity = 2
    else:
        desired_capacity = 1

    autoscaling_client.update_auto_scaling_group(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=desired_capacity
    )

    return {
        "statusCode": 200,
        "body": json.dumps(f"ASG {ASG_NAME} updated to {desired_capacity} instances")
    }



# import boto3
# import pandas as pd
# from prophet import Prophet
# import datetime

# def lambda_handler(event, context):
#     cloudwatch = boto3.client('cloudwatch')
#     autoscaling = boto3.client('autoscaling')
    
#     asg_name = os.environ['ASG_NAME']

#     # 2 days worth of data
#     response = cloudwatch.get_metric_data(
#         MetricDataQueries=[
#             {
#                 'Id': 'cpuusage',
#                 'MetricStat': {
#                     'Metric': {
#                         'Namespace': 'AWS/EC2',
#                         'MetricName': 'CPUUtilization',
#                         'Dimensions': [
#                             {"Name": "AutoScalingGroupName", "Value": asg_name}
#                         ]
#                     },
#                     'Period': 300,
#                     'Stat': 'Average'
#                 },
#                 'ReturnData': True
#             }
#         ],
#         StartTime=datetime.datetime.utcnow() - datetime.timedelta(days=2),
#         EndTime=datetime.datetime.utcnow()
#     )

#     data = response['MetricDataResults'][0]
#     if not data['Timestamps']:
#         print("No CPU data found")
#         return

#     df = pd.DataFrame({
#         "ds": data['Timestamps'],
#         "y": data['Values']
#     }).sort_values("ds")

#     model = Prophet()
#     model.fit(df)

#     future = model.make_future_dataframe(periods=6, freq="10min")
#     forecast = model.predict(future)

#     predicted = forecast.iloc[-1]["yhat"]

#     print(f"Predicted CPU utilization: {predicted:.2f}%")

#     # scaling policy
#     if predicted > 70:
#         desired_capacity = 2
#     else:
#         desired_capacity = 1

#     autoscaling.update_auto_scaling_group(
#         AutoScalingGroupName=asg_name,
#         DesiredCapacity=desired_capacity
#     )

#     return {"statusCode": 200, "message": f"Set capacity to {desired_capacity}"}
