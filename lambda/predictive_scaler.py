import boto3
import os
import json
import pandas as pd
from prophet import Prophet
from datetime import datetime, timedelta

ASG_NAME = os.environ.get("ASG_NAME", "predictive-asg")

autoscaling_client = boto3.client("autoscaling")
cloudwatch_client = boto3.client("cloudwatch")

def collect_historical_metrics():
    """Collect historical CPU metrics for Prophet training"""
    response = cloudwatch_client.get_metric_data(
        MetricDataQueries=[
            {
                'Id': 'cpuusage',
                'MetricStat': {
                    'Metric': {
                        'Namespace': 'AWS/EC2',
                        'MetricName': 'CPUUtilization',
                        'Dimensions': [
                            {"Name": "AutoScalingGroupName", "Value": ASG_NAME}
                        ]
                    },
                    'Period': 300,
                    'Stat': 'Average'
                },
                'ReturnData': True
            }
        ],
        StartTime=datetime.utcnow() - timedelta(days=2),
        EndTime=datetime.utcnow()
    )
    
    data = response['MetricDataResults'][0]
    if not data['Timestamps']:
        print("No CPU data found")
        return None
    
    df = pd.DataFrame({
        "ds": data['Timestamps'],
        "y": data['Values']
    }).sort_values("ds")
    
    return df

def train_prophet_model(df):
    """Train Prophet model on historical data"""
    try:
        model = Prophet(
            changepoint_prior_scale=0.05,
            seasonality_prior_scale=10.0,
            seasonality_mode='multiplicative'
        )
        model.fit(df)
        return model
    except Exception as e:
        print(f"Error training Prophet model: {e}")
        return None

def make_scaling_decision(predicted_cpu, current_cpu):
    """Make scaling decision based on predicted and current CPU"""
    if predicted_cpu > 70:
        return 2  # Scale up
    elif predicted_cpu < 30 and current_cpu < 40:
        return 1  # Scale down
    else:
        return None  # No change needed

def lambda_handler(event, context):
    print(f"[{datetime.utcnow()}] Event: {json.dumps(event)}")
    
    try:
        # Try ML-based predictive scaling first
        print("Attempting ML-based predictive scaling...")
        
        # Collect historical data
        df = collect_historical_metrics()
        if df is None or len(df) < 10:  # Need minimum data points
            print("Insufficient data for ML, falling back to reactive scaling")
            raise Exception("Insufficient data")
        
        # Train Prophet model
        model = train_prophet_model(df)
        if model is None:
            raise Exception("Model training failed")
        
        # Make prediction for next 10 minutes
        future = model.make_future_dataframe(periods=2, freq="5min")
        forecast = model.predict(future)
        predicted_cpu = forecast.iloc[-1]["yhat"]
        
        print(f"Predicted CPU utilization: {predicted_cpu:.2f}%")
        
        # Get current CPU for comparison
        current_metric = cloudwatch_client.get_metric_statistics(
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
        
        current_cpu = 0
        if current_metric["Datapoints"]:
            current_cpu = current_metric["Datapoints"][0]["Average"]
        
        print(f"Current CPU utilization: {current_cpu}")
        
        # Make ML-based scaling decision
        desired_capacity = make_scaling_decision(predicted_cpu, current_cpu)
        
        if desired_capacity is not None:
            print(f"ML-based scaling decision: {desired_capacity} instances")
        else:
            print("No scaling change needed based on ML prediction")
            return {
                "statusCode": 200,
                "body": json.dumps(f"ML prediction: No scaling needed. Predicted CPU: {predicted_cpu:.2f}%")
            }
            
    except Exception as e:
        print(f"ML-based scaling failed: {e}, falling back to reactive scaling")
        
        # Fallback to reactive scaling
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
        print(f"Reactive scaling - Average CPU utilization: {avg_cpu}")

        if avg_cpu > 60:
            desired_capacity = 2
        else:
            desired_capacity = 1
        
        print(f"Reactive scaling decision: {desired_capacity} instances")

    # Update Auto Scaling Group
    autoscaling_client.update_auto_scaling_group(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=desired_capacity
    )

    return {
        "statusCode": 200,
        "body": json.dumps(f"ASG {ASG_NAME} updated to {desired_capacity} instances")
    }
