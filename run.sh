#!/bin/bash

docker run -p 80:3838 -e PASSWORD=123 -v $(pwd):/home/rstudio/mydata -d shiny-app