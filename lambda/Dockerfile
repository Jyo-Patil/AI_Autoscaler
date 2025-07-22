FROM public.ecr.aws/lambda/python:3.11

# Install bash (optional, for better shell support)
RUN yum install -y bash && yum clean all

# Use bash shell for following RUN commands
SHELL ["/bin/bash", "-c"]

# Install gcc9 and related tools from amazon-linux-extras
RUN yum install -y amazon-linux-extras && \
    amazon-linux-extras enable gcc9 && \
    yum clean metadata && \
    yum install -y gcc9 gcc9-c++ make python3-devel && \
    alternatives --install /usr/bin/gcc gcc /usr/bin/gcc9 90 && \
    alternatives --install /usr/bin/g++ g++ /usr/bin/g++9 90 && \
    yum clean all

# Upgrade pip and wheel before installing dependencies
RUN pip install --upgrade pip setuptools wheel

# Copy requirements file and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your Lambda function code
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