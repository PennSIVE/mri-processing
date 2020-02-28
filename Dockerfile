# from https://github.com/ANTsX/ANTsR/issues/265#issuecomment-547964145
FROM dorianps/antsr

RUN apt-get update && apt-get install -y \
    sudo \
    gdebi-core \
    pandoc \
    pandoc-citeproc \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    wget && \
    r -e "install.packages(c('oro.nifti', 'oro.dicom', 'fslr', 'WhiteStripe', 'matrixStats', 'R.matlab', 'abind', 'R.utils', 'RNifti', 'stapler'))" && \
    r -e "source('https://neuroconductor.org/neurocLite.R'); neuro_install('neurobase')" && \
    r -e "devtools::install_github(c('muschellij2/extrantsr', 'muschellij2/itksnapr'), dependencies = FALSE)" && \
    wget --no-verbose https://download3.rstudio.org/ubuntu-14.04/x86_64/VERSION -O "version.txt" && \
    VERSION=$(cat version.txt)  && \
    wget --no-verbose "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-$VERSION-amd64.deb" -O ss-latest.deb && \
    gdebi -n ss-latest.deb && \
    rm -f version.txt ss-latest.deb && \
    . /etc/environment && \
    R -e "install.packages(c('shiny', 'rmarkdown', 'shinyFiles', 'shinyWidgets'), repos='$MRAN')" && \
    cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/ && \
    rm /srv/shiny-server/index.html

COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
COPY *.R /srv/shiny-server/

EXPOSE 3838

CMD exec shiny-server