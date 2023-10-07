FROM jupyter/minimal-notebook:latest

USER root
RUN pip install jupyterlab==3.*
RUN pip install --no-cache-dir nbgitpuller 
RUN pip install --upgrade "jupyterlab<4" jupyterlab-git
RUN jupyter server extension enable jupyterlab_git

COPY id_rsa_maverick_github /tmp/id_rsa_maverick_github