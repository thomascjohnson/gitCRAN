FROM cloudfoundry/cflinuxfs3

ENV R_LIBS_USER=/opt/Rlib

RUN apt update && \
  apt install software-properties-common -y && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
  add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' && \
  apt update && \
  apt install -y r-base=3.6.3-1bionic && \
  mkdir -p $R_LIBS_USER && \
  mkdir -p /opt/gitCRAN

RUN R -e "install.packages('devtools', repos = 'cloud.r-project.org')"
RUN R -e "devtools::install_github('thomascjohnson/CRANpiled')"
RUN R -e "devtools::install_github('thomascjohnson/gitCRAN')"

WORKDIR /opt/gitCRAN
