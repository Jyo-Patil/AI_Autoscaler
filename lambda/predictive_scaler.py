import boto3
import pandas as pd
from prophet import Prophet
import datetime

def lambda_handler(event, context):
    cloudwatch = boto3.client('cloudwatch')
    autoscaling = boto3.client('autoscaling')
    
    asg_name = os.environ['ASG_NAME']

    # 2 days worth of data
    response = cloudwatch.get_metric_data(
        MetricDataQueries=[
            {
                'Id': 'cpuusage',
                'MetricStat': {
                    'Metric': {
                        'Namespace': 'AWS/EC2',
                        'MetricName': 'CPUUtilization',
                        'Dimensions': [
                            {"Name": "AutoScalingGroupName", "Value": asg_name}
                        ]
                    },
                    'Period': 300,
                    'Stat': 'Average'
                },
                'ReturnData': True
            }
        ],
        StartTime=datetime.datetime.utcnow() - datetime.timedelta(days=2),
        EndTime=datetime.datetime.utcnow()
    )

    data = response['MetricDataResults'][0]
    if not data['Timestamps']:
        print("No CPU data found")
        return

    df = pd.DataFrame({
        "ds": data['Timestamps'],
        "y": data['Values']
    }).sort_values("ds")

    model = Prophet()
    model.fit(df)

    future = model.make_future_dataframe(periods=6, freq="10min")
    forecast = model.predict(future)

    predicted = forecast.iloc[-1]["yhat"]

    print(f"Predicted CPU utilization: {predicted:.2f}%")

    # scaling policy
    if predicted > 70:
        desired_capacity = 2
    else:
        desired_capacity = 1

    autoscaling.update_auto_scaling_group(
        AutoScalingGroupName=asg_name,
        DesiredCapacity=desired_capacity
    )

    return {"statusCode": 200, "message": f"Set capacity to {desired_capacity}"}
