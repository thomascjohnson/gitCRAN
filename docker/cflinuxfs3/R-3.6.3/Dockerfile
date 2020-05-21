FROM cloudfoundry/cflinuxfs3

ENV R_LIBS_USER=/opt/R/Rlib

RUN apt update && \
  apt install software-properties-common -y && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
  add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' && \
  apt update && \
  apt install -y r-base=3.6.3-1bionic && \
  mkdir -p $R_LIBS_USER

RUN R -e "options(repos = 'cloud.r-project.org'); install.packages('devtools')"

WORKDIR /opt/gitCRAN
