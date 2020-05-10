FROM cloudfoundry/cflinuxfs3

ENV R_LIBS_USER=/opt/Rlib

RUN apt update && \
  apt install software-properties-common -y && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
  add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' && \
  apt update && \
  apt install -y r-base=3.6.3-1bionic && \
  mkdir /opt/gitCRAN && \
  mkdir /opt/Rlib

RUN R -e "options(repos = 'cloud.r-project.org'); install.packages('devtools')"

RUN wget https://github.com/thomascjohnson/gitCRAN/archive/master.zip && \
  unzip master.zip -d /opt/gitCRAN && \
  R -e "options(repos = 'cloud.r-project.org'); devtools::install('/opt/gitCRAN/gitCRAN-master')"

WORKDIR /opt/gitCRAN
