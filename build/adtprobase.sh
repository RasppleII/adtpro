#!/bin/sh
#
# ADTPro - *nix startup shell script
#
# You can set two variables here:
#   1. $MY_JAVA_HOME - to pick a particular java to run under
#   2. $ADTPRO_HOME - to say where you installed ADTPro
#
# Set default ADTPRO_HOME to be the fully qualified
# current working directory.
export ADTPRO_HOME="`dirname \"$0\"`"
cd "$ADTPRO_HOME"
export ADTPRO_HOME=`pwd`

# Uncomment and modify one or both of the lines below if you
# want to specify a particular location for Java or ADTPro.
# NOTE: be sure to include a trailing slash on MY_JAVA_HOME.
#
# export MY_JAVA_HOME=/usr/local/java/bin/
# export ADTPRO_HOME=~/myuser/adtpro

OS=`uname`

# For Linux, use this:
if [ "$OS" = "Linux" ]; then
  export RXTXLIB=lib/rxtx/%RXTX_VERSION%/i686-pc-linux-gnu
fi

# For OSX, use this:
if [ "$OS" = "Darwin" ]; then
  export RXTXLIB=lib/rxtx/%RXTX_VERSION%/mac-10.5
fi

# For Solaris, use this:
if [ "$OS" = "SunOS" ]; then
  export RXTXLIB=lib/rxtx/%RXTX_VERSION%/sparc-sun-solaris2.10-32
fi

# Set up the library location.
export TWEAK1="-Djava.library.path="
export TWEAK=$TWEAK1$ADTPRO_HOME/$RXTXLIB

# Set up a comfortable Java execution environment.
# We want to execute Java (1), set a larger-than-default heap size (2),
# tell the OS where to find a native library to support rxtx (3), set
# the classpath to include ADTPro (4) and RXTXcomm (5), and finally
# tell Java what the class to execute is (6).  
# To wit:
cd "$ADTPRO_HOME"/disks
"$MY_JAVA_HOME"java -Xms256m -Xmx512m "$TWEAK" -cp ../lib/%ADTPRO_VERSION%:../lib/rxtx/%RXTX_VERSION%/RXTXcomm.jar org.adtpro.ADTPro
#               (1)     (2)     (2)      (3)                     (4)                     (5)                            (6)