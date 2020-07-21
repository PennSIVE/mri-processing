FROM processing-app-base

RUN Rscript -e "chooseCRANmirror(graphics=FALSE, ind=56); \
    install.packages(c('oro.nifti', 'oro.dicom', 'fslr', 'WhiteStripe')); \
    source('https://neuroconductor.org/neurocLite.R'); neuro_install(c('neurobase', 'ANTsR', 'extrantsr'))" && \
    mkdir /baseline /followup /processed

COPY app.R /src/

ENTRYPOINT [ "Rscript", "/src/app.R" ]