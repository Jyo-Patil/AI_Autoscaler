
FROM public.ecr.aws/lambda/python:3.10

# (optional) system build deps, if Prophet needs compiling
RUN yum install -y gcc gcc-c++ python3-devel

# copy requirements & install into Lambda task root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# copy your code
COPY lambda/predictive_scaler.py ${LAMBDA_TASK_ROOT}

# Lambda entry point
CMD [ "predictive_scaler.lambda_handler" ]