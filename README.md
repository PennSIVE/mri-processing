### Neuroimaging pre-processing and visualization 

You can run this container directly from [docker hub](https://hub.docker.com/r/terf/shiny-app) with `docker run -p 80:3838 -e PASSWORD=123 -d terf/shiny-app`, or you can clone this repo, `cd` into it, `./build.sh` to build the container and `./run.sh` to run it (on port 80). You should then be able to access the app at http://localhost

If you want to access files from the container that reside on the host, bind mount them in with `-v /files/on/computer/I/want/in/container:/path/in/container/to/place/files`.