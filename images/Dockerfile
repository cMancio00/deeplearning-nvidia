FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04 

RUN apt update && apt install curl htop nvtop git sudo -y --no-install-recommends && rm -rf /var/lib/apt/lists/

ARG USERNAME=mancio
RUN useradd -m -s /bin/bash -G sudo ${USERNAME} && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USERNAME}
ENV PATH=/home/${USERNAME}/.local/bin:$PATH
WORKDIR /home/${USERNAME}

