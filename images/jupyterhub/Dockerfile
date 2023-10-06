FROM jupyter/minimal-notebook:latest

RUN pip install jupyterlab==3.*
RUN pip install --no-cache-dir nbgitpuller 
RUN pip install --upgrade "jupyterlab<4" jupyterlab-git
RUN jupyter server extension enable jupyterlab_git

# && \
#     jupyter serverextension enable --py nbgitpuller --sys-prefix && \
#     jupyter labextension install @jupyterlab/git && \
#     pip install jupyterlab-git && \
#     jupyter serverextension enable --py jupyterlab_git