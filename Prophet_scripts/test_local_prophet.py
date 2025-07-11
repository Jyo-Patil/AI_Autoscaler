import pandas as pd
from prophet import Prophet
import numpy as np

# generate synthetic data
rng = pd.date_range("2024-05-01", periods=300, freq="10min")
cpu = np.random.uniform(20, 60, size=len(rng))

df = pd.DataFrame({
    "ds": rng,
    "y": cpu
})

model = Prophet()
model.fit(df)

future = model.make_future_dataframe(periods=12, freq="10min")
forecast = model.predict(future)

print(forecast[["ds", "yhat"]].tail(12))
