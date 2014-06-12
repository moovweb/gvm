## Cleanup test objects
gvm uninstall tip > /dev/null 2>&1
gvm uninstall go1.1.1 > /dev/null 2>&1
gvm uninstall go1.2.2 > /dev/null 2>&1
#######################

gvm install tip #status=0
gvm list #status=0; match=/tip/
gvm install go1.1.1 #status=0
gvm list #status=0; match=/go1.1.1/
gvm install go1.2.2   #status=0
gvm list #status=0; match=/go1.2.2/
