# GVM Build Debug

## Debug Travis-CI Build

It can be difficult and time consuming to debug a failing build on Travis-CI. Do
not abuse the upstream pull request mechanism to debug CI build failures!

There are two appropriate strategies for troubleshooting. First, you can add a
new personal repo (e.g. "my-gvm-test") and push your test code there (by adding
another remote server), then use a personal Travis-CI account to pull from the
duplicated repo (e.g. "my-gvm-test"). This approach fully supports enabling the
upload of build logs to an Amazon S3 bucket (normally, the log files are simply
discarded during the build process).

Another approach is to troubleshoot in a local Travis-CI Docker image:

[Troubleshooting Locally in a Docker Image](https://docs.travis-ci.com/user/common-build-problems/#Troubleshooting-Locally-in-a-Docker-Image)

The upside of using the Docker approach is that you can access the environment
at the terminal level. The downside of this approach is that you can't test on a
MacOS environment.

Once you've isolated and corrected for CI build failures, merge fixes back into
the repo/branch associated with your pull request and push. Every time you push
revisions to an open pull request it will trigger a build on the CI server for
the upstream repo.

### What debugging information is available?

GVM can output addtional debugging information during usage by simply defining
the `GVM_DEBUG` environment variable with a value of "1". During normal usage
you could simply do this:

```bash
    prompt> GVM_DEBUG=1 cd .
    Resolving defaults...
    Resolved default go: go1.7.1
    Resolved default pkgset: global
    No .go-version found. Using system or default go.
    Parsing gvm_use() argument: --quiet
    Parsing gvm_use() argument: go1.7.1
    Command (use) options dump:
    [--quiet]: true
    [--version]: go1.7.1
    ...
```

Support for the GVM_DEBUG flag is a work in progress. The following commands
currently support this flag:

```
    cd
    gvm use
    gvm pkgset use
    gvm install
```

>The `cd` command above refers to the GVM wrapper for the shell cd command. The
native `cd` command, obviously, does not support GVM_DEBUG.

Build logs are another source of useful information. When Travis-CI runs the GVM
test suite, a variety of download, compile and install logs will be generated.
These log files will be copied and transferred to a configured Amazon S3 bucket
(if configured) along with all other build artifacts.

Exposure of debugging information is configured via Environment Variables.

## Defining Environment Variables

Several Travis-CI Environment Variables can be configured to facilitate the CI
build debugging process. These variables will be exposed to the underlying build
environment for each build on the CI server.

>NOTE: The strategy is to define the variables on a personal Travis-CI account
or in a `.travis.yml` file to be used exclusively in conjunction with a build on
a local Travis-CI Docker image as described above. __DO NOT push a Travis-CI
config file that defines environment variables associated with troubleshooting
to the upstream build server.__

Environment Variables can be defined in Travis-CI under the _Settings_ menu for
your test repo (e.g. "my-gvm-test"). Variables can also be configured via the
Travis-CI configuration file (".travis.yml") within an "env" section as detailed
in the Travis-CI documentation:

[Defining public variables in .travis.yml](https://docs.travis-ci.com/user/environment-variables/)

In general, the second approach (i.e. defining an "env" section in ".travis.yml")
is not recommended.

### GVM Configuration

Enable additional debugging output from __GVM__ by enabling debugging.

| Name             | Value            | Description                     | Display value in build log |
| ---------------- |----------------- | ------------------------------- | --- |
| GVM_DEBUG        | 1                | Enable GVM debug output         | On  |

### Amazon S3

To preserve build logs you will need to configure an Amazon S3 bucket. You will
also need to enable artifiacts uploading in the `.travis.yml` file (see the next
section for instructions).

The following environment variables need to be configured in the __Settings__
section for your Travis-CI build configuration.

| Name             | Value            | Description                     | Display value in build log |
| ---------------- |----------------- | ------------------------------- | --- |
| ARTIFACTS_KEY    | *                | AWS access key id               | Off |
| ARTIFACTS_SECRET | *                | AWS secret access key           | Off |
| ARTIFACTS_REGION | us-east-1        | S3 region name                  | On  |
| ARTIFACTS_BUCKET | my-travis-bucket | S3 bucket name                  | On  |
| ARTIFACTS_PATHS  | ./build_logs     | GVM build paths to upload       | On  |
| ARTIFACTS_DEBUG  | 1                | Output additional debug details | On  |

It's not necessary or recommended to enable __ARTIFACTS_DEBUG__ but is provided
above for completeness. Omit the variable to disable it.

Pay attention to the "Display value in build log" setting. Sensitive information
should not be exposed in the build log.

#### Configure Travis

You will need to configure the `.travis.yml` file to enable build log uploads to
Amazon S3.

```yaml
language: c
os: [linux, osx]
env:
  global:
    - SRC_REPO=$TRAVIS_BUILD_DIR
    - GVM_NO_GIT_BAK=1
    - GVM_NO_UPDATE_PROFILE=1
git:
  depth: 9999999
# addons:
#   artifacts: true
before_install:
  - binscripts/gvm-installer $TRAVIS_COMMIT $TRAVIS_BUILD_DIR/tmp
install: gem install tf -v '>=0.4.1'
script:
  - rake default && rake scenario
```

The fields to enable are:

```yaml
addons:
  artifacts: true
```

Commit the updated file to your debugging repo and push the update. Provided
that you have correctly setup an Amazon S3 bucket, Travis-CI will upload all of
the build artifacts, including all build logs (available in the "build_logs"
directory for each build iteration), following a failed or successful build run.

__This updated `.travis.yml` file should only be committed to a debugging repo
(e.g. "my-gvm-test") and never to the upstream code.__
