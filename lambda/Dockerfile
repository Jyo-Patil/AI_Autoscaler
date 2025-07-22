FROM public.ecr.aws/lambda/python:3.11

# Install system build dependencies needed for Prophet and pandas
RUN yum install -y gcc gcc-c++ make python3-devel && \
    yum clean all

# Copy requirements file
COPY requirements.txt .

# Upgrade pip and setuptools for compatibility
RUN pip install --upgrade pip setuptools wheel

# Install python dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your lambda function code
COPY . ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD ["predictive_scaler.lambda_handler"]





# FROM public.ecr.aws/lambda/python:3.11

# # Install dependencies
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt

# # Copy function code
# COPY predictive_scaler.py ${LAMBDA_TASK_ROOT}

# # Set handler
# CMD ["predictive_scaler.lambda_handler"]



# FROM public.ecr.aws/lambda/python:3.10

# # (optional) system build deps, if Prophet needs compiling
# RUN yum install -y gcc gcc-c++ python3-devel

# # copy requirements & install into Lambda task root
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# # copy your code
# COPY lambda/predictive_scaler.py ${LAMBDA_TASK_ROOT}

# # Lambda entry point
# CMD [ "predictive_scaler.lambda_handler" ]