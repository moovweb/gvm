source $GVM_ROOT/scripts/gvm
gvm install 1.2 #status=0
gvm list #status=0; match=/1\.2/
gvm install go1.2 #status=0
gvm list #status=0; match=/go1\.2/
gvm use 1.2 #status=0
go version #status=0; match=/1\.2/
gvm use go1.2 #status=0
go version #status=0; match=/go1\.2/
