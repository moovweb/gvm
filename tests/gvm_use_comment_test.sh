source $GVM_ROOT/scripts/gvm
gvm use go1.7.6 # status=0
go version # status=0; match=/go1\.7\.6/
gvm use go1.6.4 # status=0
go version # status=0; match=/go1\.6\.4/

echo "go1.7.6" > .go-version
gvm use # status=0
go version # status=0; match=/go1\.7\.6/

echo "go1.6.4" > .go-version
gvm use --default # status=0
go version # status=0; match=/go1\.6\.4/