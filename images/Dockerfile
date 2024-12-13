FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04

RUN apt update && apt install curl wget htop nvtop git sudo jq -y --no-install-recommends
#For sign commits
RUN apt -y install keychain gnupg2 gnupg-agent pinentry-gnome3 && rm -rf /var/lib/apt/lists/

ARG USERNAME=mancio
RUN useradd -m -s /bin/bash -G sudo ${USERNAME} && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USERNAME}
ENV PATH=/home/${USERNAME}/.local/bin:$PATH
WORKDIR /home/${USERNAME}

#Intall conda
RUN mkdir -p ~/miniconda3
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
RUN bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
RUN rm ~/miniconda3/miniconda.sh

