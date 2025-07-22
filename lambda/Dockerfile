# Stage 1: Build stage with amazonlinux:2, install gcc9 and build dependencies
FROM amazonlinux:2 as builder

# Enable gcc9 via amazon-linux-extras and install build tools
RUN yum install -y amazon-linux-extras && \
    amazon-linux-extras enable gcc9 && \
    yum clean metadata && \
    yum install -y gcc9 gcc9-c++ make python3-devel python3-pip && \
    alternatives --install /usr/bin/gcc gcc /usr/bin/gcc9 90 && \
    alternatives --install /usr/bin/g++ g++ /usr/bin/g++9 90 && \
    yum clean all

# Upgrade pip and install Python dependencies to a folder
COPY requirements.txt .
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    python3 -m pip install --prefix=/install -r requirements.txt

# Stage 2: Lambda base image
FROM public.ecr.aws/lambda/python:3.11

# Copy dependencies from builder
COPY --from=builder /install /var/lang

# Copy lambda function code
COPY . ${LAMBDA_TASK_ROOT}

# Command to run your lambda handler
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