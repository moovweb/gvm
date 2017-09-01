source $GVM_ROOT/scripts/gvm

## Cleanup test objects
gvm alias delete foo
gvm alias delete bar
#######################

gvm alias # status=0
gvm alias create foo go1.7.6 # status=0
gvm alias create bar go1.6.4 # status=0
gvm alias list # status=0; match=/gvm go aliases/; match=/foo \(go1\.7\.6\)/; match=/bar \(go1\.6\.4\)/
gvm use foo # status=0
go version # status=0; match=/go1\.7\.6/
gvm use bar # status=0
go version # status=0; match=/go1\.6\.4/
gvm alias delete foo
gvm alias list # status=0; match=/gvm go aliases/; match!=/foo \(go1\.7\.6\)/; match=/bar \(go1\.6\.4\)/
gvm alias delete bar
gvm alias list # status=0; match=/gvm go aliases/; match!=/foo \(go1\.7\.6\)/; match!=/bar \(go1\.6\.4\)/
