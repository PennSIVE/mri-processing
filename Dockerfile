# from https://github.com/ANTsX/ANTsR/issues/265#issuecomment-547964145
FROM dorianps/antsr

RUN r -e "install.packages(c('oro.nifti', 'oro.dicom', 'fslr', 'WhiteStripe', 'matrixStats', 'R.matlab', 'abind', 'R.utils', 'RNifti', 'stapler'))" && \
    r -e "source('https://neuroconductor.org/neurocLite.R'); neuro_install('neurobase')" && \
    r -e "devtools::install_github(c('muschellij2/extrantsr', 'muschellij2/itksnapr'), dependencies = FALSE)" && \
    mkdir /baseline /followup /processed

COPY app.R /src/

ENTRYPOINT []
CMD Rscript /src/app.R