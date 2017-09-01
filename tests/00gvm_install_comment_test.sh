## Cleanup test objects
gvm uninstall go1.4.3 > /dev/null 2>&1
gvm uninstall master > /dev/null 2>&1
gvm uninstall go1.6.4 > /dev/null 2>&1
gvm uninstall go1.7.6 > /dev/null 2>&1
#######################

gvm install go1.4.3 #status=0
GOROOT_BOOTSTRAP=$GVM_ROOT/gos/go1.4.3 gvm install master #status=0
gvm list #status=0; match=/master/
GOROOT_BOOTSTRAP=$GVM_ROOT/gos/go1.4.3 gvm install go1.6.4 #status=0
gvm list #status=0; match=/go1.6.4/
GOROOT_BOOTSTRAP=$GVM_ROOT/gos/go1.4.3 gvm install go1.7.6 #status=0
gvm list #status=0; match=/go1.7.6/
