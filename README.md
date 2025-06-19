# DockerFiles
This repo use to make a docker image.

user can change the base image in the make_docker.sh file  # BASE_IMAGE, default is ubuntu22.04
the tag of the docker images is needed to pass to the script

After the docker image have been make, user can copy the scripts folder to the root of their project

user then run the script  scripts/dev_start.sh to create a container, user can change the container name by 
pass \ -n container_name to the script, the default name is "j6_tros_${USER}", user can use a normal user, dont 
need the root user. The new container will auto map the project path of the host to container.
if user need other additonal path of the host map into the container, user can pass -v path_of_host to the script.

After the container have been make, user can run script scripts/dev_into.sh,  the same, user need to pass the container name
which is passed to dev_start.sh just now.

eg:

scripts/dev_start.sh  -n my_pro -v /home/damon/Work
scripts/dev_into.sh my_pro