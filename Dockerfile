FROM python:3

RUN apt-get update
RUN apt-get install -y curl jq pep8 uncrustify
COPY requirements.txt /tmp
RUN pip install -r /tmp/requirements.txt

 