source $GVM_ROOT/scripts/gvm
gvm use go1.7.6 # status=0
go version # status=0; match=/go1\.7\.6/
gvm use go1.6.4 # status=0
go version # status=0; match=/go1\.6\.4/
