# Elasticsearch Docker Container for AARCH64 and X64

## Docker Container usage
To start an Elasticsearch 5.6 container execute

```
$ ./dc-run.sh 5.6

```

This will also print the TCP port number that Elasticsearch can be accessed by.

To stop the container use

```
$ ./dc-stop.sh 5.6

```

## Required Docker Image
The Docker Image **indexing-elasticsearch-\<ARCH\>** will automaticly be downloaded from the Docker Hub.  
The source for the image can be found here [https://github.com/tsitle/dockerimage-indexing-elasticsearch](https://github.com/tsitle/dockerimage-indexing-elasticsearch).
