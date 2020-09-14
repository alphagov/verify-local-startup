# Running the Hub in Docker

## Contents

* [Introduction](#introduction)
* [Getting Started](#getting-started)
* [The Script](#the-script)
    * [Script Options](#script-options)
    * [Tips and Troubleshooting](#tips-and-troubleshooting)
    * [To do](#to-do)
* [Running the Compose Files](#running-the-compose-files)

## Introduction

This README is all about the content of this directory to give some idea as to
whats inside and how to run the Hub in Docker.  To make things easier we have
created a bash script which can build and start everything as well as up and 
look after the majority of a developers needs.

## Getting Started

To get start you're going to need a few things.  These are:

* Git
* Docker
* Docker-Compose
* Bash/ZSH (or compatible shell, sorry no FISH, TCSH, etc here)
* A copy of ida-hub-acceptance-tests
* GNU Core Utils (optional)
* User added to docker group (optional/recommended)

We're not going to go in to how to install these components.  If you need help
just ask any of the Verify developers and they should be able to give you hand.

> ### Note
>
> Also on Macs we recommend the GNU Core Utilities package.  This is completely 
> optional and won't affect the running or performance of the script generally.   
> You can be install this with Homebrew:
>
> ```bash
> $ brew install coreutils
> ```

## The Script

The scipt `hub-docker.sh` should be all you need to get up and running.  The
script does a number of important jobs.  These are:

* Check requirments
* Check to make sure you have all the repositories
* Build the Verify Hub Components on first run
* Create the Docker containers
* Run the docker containers
* Shutdown the docker containers

So to get going just:

```bash
$ ./hub-docker.sh
```

> ### Notes
>
> The script will give some warnings when running depending on which platform 
> you are running on.  These are perfectly normal and are safe to ignore.
>
> The first is it will warn you about using the `-p` option this tells the
> script to pull master on all the required repos.  Good for keeping things up
> to date and avoiding issues but bad for the startup time or running offline.
>
> The second warning comes when you run the script on Mac OS.  The script will
> advise you it should run the script with `-n` option.  This tells the script
> not to start up the Dozzle log viewer.  This is beacuse Docker Desktop has its
> own built in realtime log viewer.

This will do all the steps above aside from the last one.  When you want to stop
the hub you just need to run the script again:

```bash
$ ./hub-docker.sh
```

You can repeat these steps as often as you like.  Remember if you are actively 
working on a hub component you'll need to rebuild that compoent before starting
the hub up again.  Alternatively you can use the `-b` option to do a rebuild on
all components.

### Script Options

The script has a number of runtime options.  These are divided in to 4
categories.  These are:

* Run
* Config
* Standard
* Troubleshoot

<span style="color: #00ff00">Run</span> and <span style="color: #0000ff">
Standard</span> options are generally safe and won't have any significant impact 
on your use of the script or the Hub in Docker.  The <span style="color: 
#ffff00"> config</span> options can break your ability to run the Hub in Docker 
as this overrides the defaults built into the script.  Finally there are 
<span style="color: #ff0000">troubleshooting</span> options which can be quite 
destructive but are useful for sorting out issues when things aren't running as 
expected.

All commandline options can be found in the scripts help which can be accessed
by adding the `--help` options which should output the following:

```

Hub Docker Script Version 1.0
(c)  GDS  2020
(c) Crown Copyright 2020

Usage:
    Basic usage ./hub-docker.sh to start the hub running in docker.
    Run ./hub-docker.sh again to stop the hub running in docker.

Run Options:
    -b  --build                  Build the various java components before running the hub in Docker
    -l  --logs                   Shows the logs from the verify hub is running in Docker
    -n  --no-dozzle              Prevent the script from running Dozzle
    -p  --pull-repos             Pull all related repos before running (Highly recommended but off by default)
    -r  --restart                Restarts the Verify Hub if its running in Docker
    -R  --rm-images              Remove the existing docker images

Config Options:
    -c  --config-dir [PATH]      Specifies the configuration directory to get the microservices running
                                 The default is /home/gdsuser/Development/Verify/ida-hub-acceptance-tests/docker/docker-configuration
    -d  --dev-dir [PATH]         Specify your verify development directory.  docker-compose and this script
                                 will look for all related repos in this directory.
                                 The default is /home/gdsuser/Development/Verify/ida-hub-acceptance-tests/docker/../..
    -e  --env-file [PATH]        Specifies the environment file used to get the hub up and running
                                 The default is /home/gdsuser/Development/Verify/ida-hub-acceptance-tests/docker/hub.env

Standard Options
    -N  --no-colours             Disable script colours
    -v  --version                Shows version details
    -V  --verbose                Shows command output for debugging...
                                 You'll need to Ctrl-C to exit and shutdown the hub
    -h  --help                   Shows this usage message

Troubleshooting Options
    --troubleshoot               Theres some basic steps which can be done to troubleshoot making the hub
                                 work in docker.  Mostly removing everything, rebuilding and starting again.
                                 Thats what this option does and should be a first port of call if things
                                 don't work as expected.
    --debug                      Print debug information to console and save it to "/tmp/debug.log"
                                 This works well with -N.  If you've reached this point then you should
                                 also supply any other command line options you've used with it.
    --kill-with-fire             Kill with fire does exactly what its name suggests.  Its part of the
                                 troubleshooting steps above but instead of triggering a rebuild it stops
                                 at the point everything is clean again.  Useful for tear downs and moving on.

```

### Tips and Troubleshooting

1. Although the docker components come up quite quickly there can be a delay of up
to 2 - 3 minutes before all the compoents are ready to accept requests.  If you
get an error adivisng your browser can't connect it might be worth watiing a 
minute or two before trying agian.  This is especially import on a fresh build
and after using the troubleshooting option discuessed below.

2. The scripts requirements checker is capable of cloning all the required repos
to get up and running with the hub.  If you need a fresh master copy of
everything you only need to specify a directory with the `-d` option.  e.g.

    ```
    $ ./hub-docker.sh -b -d/tmp/verify
    ```

    This will clone everything needed to get up and running to `/tmp/verify` and
    the script will use this directory for running the hub components.  The `-b`
    option here is also import as this tells the script to build all the hub
    components otherwise you could have a number of docker errors on your hands
    as there maybe missing (not built) Java components which can't be started.

3. If things don't work as expected there are a few things you can do to try to 
get up and running again.  The first is to run the script with the 
`--troubleshoot` option.  This removes and recreates everything.  This is your
first port of call if things aren't working.  If you use this option be warned 
it can take up to 5 minutes to rebuild everything and to have a working hub
again... See the tip 1. above.

4. After troubleshooting comes getting help from other people.  This is what the
`--debug` option is for.  This gives you many of the scripts interal variables
as well as a complete run through of the scripts environment.  This information
is both printed to the console and saved to /tmp/debug.log for easy sharing. 
This gives lots of information useful for trying to sort out any issues.

5. So You've finished on Verify or its the end of the quarter and you want to
tear down everyting and start again.  We have you covered here with the
`--kill-with-fire` option.  This removes all the docker containers, volumes and 
network.  It also removes the .build.lock file.  Its the first part of the
troubleshoot option outlined above but rather than going on to go on to run the
hub again it just stops once everything has been removed.

### To do

- [ ] Make EIDAS work in Docker
- [ ] Merge the configuration
- [ ] Discuss moving to own Repo

## Running the Compose Files

The scripts are designed to make running the hub in Docker as easy as possible
but Developers like to be power users and often don't trust scripts. So this
section of the README is for them. This section is all about running the
actual docker compose files and not using the script to do things for you.  For
the most part it is pretty simple to get up and running with the compose files 
but it is not recommend way and your milage may vary.  Also you're on your own.

First you must export two environment variables.  These are `CONFIG_DIR` which 
is the location of the configuration directory used by the verify hub.  The
default is `$SCRIPTPATH/docker-configuration`.  The other is `REPO_DIR` which is 
the location of your development directory containing your copies of all the hub 
repositories.  The default for this is `$SCRIPTPATH/../..`

You can set these in Bash and ZSH like so:

```bash
export CONFIG_DIR="${CONFIG_DIR}"
export REPO_DIR="${REPO_DIR}"
```

Now you're ready to use docker-compose to run the hub using the included compose
files.

First the build file is the easiest to run.  No env files required just run 
docker-compose for them to get them going.  Docker-compose will exit when the 
buuld process is complete.

```bash
$ docker-compose --project-name verify-builder --file ./hub-build-docker-compose.yml up
```

Once the containers have exited and everything is built the containers, volumes 
and network largely redundant and can be safely removed.  This what the script
does once the build process is finished:

```bash
$ docker-compose --project-name verify-builder --file ./hub-build-docker-compose.yml rm -fsv
$ docker network rm verify-builder_default
$ docker volume rm verify-builder_maven-repository verify-builder_verify-frontend-gem
```

To use the hub compose file you're going to need an env file.  An exmaple one 
is provided along side the script and this README.  The one you need is
`hub.env` and this  contains all the environemnt variables for running the hub. 
So to run the hub in docker you need to do the following:

```bash
$ docker-compose --project-name verify --env-file ./hub.env --file ./hub-docker-compose.yml up
```

This will create the containers and start the hub up.  All logs for the 
containers will be printed to the console and you'll need to use `Ctrl-C` to
exit docker and shutdown the containers.

If you want to run it as a service (e.g. in the background) and you haven't yet
built the containers or run the up command above you can do the following:

```bash
$ docker-compose --project-name verify --env-file ./hub.env --file ./hub-docker-compose.yml up --no-start
$ docker-compose --project-name verify --env-file ./hub.env --file ./hub-docker-compose.yml start
```

The first commands builds the containers but importantly doesn't start them.
The second command starts the containers but forks them in to the background for
you.

To get access to the logs you have a number of options if running the hub as a
service. The first applies only if you are running things on a Mac or Windows
machine.  The Docker Desktop application comes with its own Dashboard which
display realtime log out put of all your running containers.  The ones for the
hub should be previed with with `verify` or whatever value you used for the
`--project-name` option for docker-compose.

Alternatively you can use the command line to print all the log and console
output of the containers using docker-compose:

```bash
$ docker-compose --project-name verify --file ./hub-docker-compose.yml logs
```

This will print the logs to the console in the order they were recieved by the
docker daemon.  If you want you can pipe to grep and use grep to filter for the
log output of individual containers.

The final option we'll discuss is the one provided in the script.  This is a 
docker log viewer called Dozzle.  Its lightweight and built using nodejs.  It
provides many of the same features provided by the Docker Desktop Dashboard.  To
use Dozzle you'll need to use the Docker command as it was decided not to
include Dozzle within the compose YAML files.  To run Dozzle simple do:

```bash
$ docker run --rm --name verify_dozzle_1 --detach --volume=/var/run/docker.sock:/var/run/docker.sock -p 50999:8080 amir20/dozzle
```

Once Dozzle has started you'll be able to access the dashboard at
 [http://localhost:50999/](http://localhost:50999). To stop Dozzle run the
following docker command because of the --rm option passed to start it the
containers will be removed and unloaded at the sametime the container is
stopped:

```bash
$ docker stop verify_dozzle_1
```

Finally stop the hub running as a service you need to run the following:

```bash
$ docker-compose --project-name verify --file ./hub-docker-compose.yml stop
```

The rest of the script is dedicated to troubleshooting, checking requirements
and trying to keep things up to date.