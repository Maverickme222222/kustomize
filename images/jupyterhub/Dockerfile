FROM jupyter/minimal-notebook:latest

RUN pip install --no-cache-dir nbgitpuller 
RUN pip install jupyterlab-git && \
    jupyter server extension enable jupyterlab_git

# && \
#     jupyter serverextension enable --py nbgitpuller --sys-prefix && \
#     jupyter labextension install @jupyterlab/git && \
#     pip install jupyterlab-git && \
#     jupyter serverextension enable --py jupyterlab_git