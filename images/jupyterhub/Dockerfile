FROM jupyter/minimal-notebook:latest

RUN pip install jupyterlab==3.*
RUN pip install --no-cache-dir nbgitpuller 
RUN pip install --upgrade "jupyterlab<4" jupyterlab-git
RUN jupyter server extension enable jupyterlab_git

# RUN chmod 600 ./id_rsa_maverick_github
COPY id_rsa_maverick_github $HOME/.ssh/id_rsa_maverick_github
# RUN chmod 700 ~/.ssh && \
#     chmod 600 ~/.ssh/id_rsa_maverick_github

# && \
#     jupyter serverextension enable --py nbgitpuller --sys-prefix && \
#     jupyter labextension install @jupyterlab/git && \
#     pip install jupyterlab-git && \
#     jupyter serverextension enable --py jupyterlab_git