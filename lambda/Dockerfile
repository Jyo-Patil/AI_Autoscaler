FROM public.ecr.aws/lambda/python:3.11

# Run yum commands in shell properly
RUN yum install -y amazon-linux-extras

RUN amazon-linux-extras enable gcc9

RUN yum clean metadata

RUN yum install -y gcc9 gcc9-c++ make python3-devel

RUN alternatives --install /usr/bin/gcc gcc /usr/bin/gcc9 90

RUN alternatives --install /usr/bin/g++ g++ /usr/bin/g++9 90

RUN yum clean all

# Upgrade pip etc.
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