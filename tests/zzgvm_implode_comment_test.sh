source $GVM_ROOT/scripts/gvm
yes n | gvm implode # status=0; match=/Action cancelled/
yes | gvm implode # status=0; match=/GVM successfully removed/
