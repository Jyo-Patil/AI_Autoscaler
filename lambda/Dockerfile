FROM public.ecr.aws/lambda/python:3.11

# Enable gcc9 from Amazon Linux Extras and set it as default gcc
RUN yum install -y amazon-linux-extras && \
    amazon-linux-extras enable gcc9 && \
    yum clean metadata && \
    yum install -y gcc9 gcc9-c++ && \
    alternatives --install /usr/bin/gcc gcc /usr/bin/gcc9 90 && \
    alternatives --install /usr/bin/g++ g++ /usr/bin/g++9 90 && \
    yum install -y make python3-devel && \
    yum clean all

# Upgrade pip and setuptools for build compatibility
RUN pip install --upgrade pip setuptools wheel

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . ${LAMBDA_TASK_ROOT}

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