## Cleanup test objects
gvm uninstall go1.4 > /dev/null 2>&1
gvm uninstall master > /dev/null 2>&1
gvm uninstall go1.1.1 > /dev/null 2>&1
gvm uninstall go1.2.2 > /dev/null 2>&1
#######################

gvm install go1.4 #status=0
GOROOT_BOOTSTRAP=$GVM_ROOT/gos/go1.4 gvm install master #status=0
gvm list #status=0; match=/master/
gvm install go1.1.1 #status=0
gvm list #status=0; match=/go1.1.1/
gvm install go1.2.2   #status=0
gvm list #status=0; match=/go1.2.2/
