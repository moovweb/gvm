source $GVM_ROOT/scripts/gvm
gvm use go1.2 # status=0
go version # status=0; match=/go1\.2/
gvm use go1.0.3 # status=0
go version # status=0; match=/go1\.0\.3/
