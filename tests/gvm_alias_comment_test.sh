source $GVM_ROOT/scripts/gvm

## Cleanup test objects
gvm alias delete foo
gvm alias delete bar
#######################

gvm alias # status=0
gvm alias create foo go1.2.2 # status=0
gvm alias create bar go1.1.1 # status=0
gvm alias list # status=0; match=/gvm go aliases/; match=/foo \(go1\.2\.2\)/; match=/bar \(go1\.1\.1\)/
gvm use foo # status=0
go version # status=0; match=/go1\.2\.2/
gvm use bar # status=0
go version # status=0; match=/go1\.1\.1/
gvm alias delete foo
gvm alias list # status=0; match=/gvm go aliases/; match!=/foo \(go1\.2\.2\)/; match=/bar \(go1\.1\.1\)/
gvm alias delete bar
gvm alias list # status=0; match=/gvm go aliases/; match!=/foo \(go1\.2\.2\)/; match!=/bar \(go1\.1\.1\)/
