g_path_script="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && /bin/pwd)"
. "${g_path_script}/../scripts/function/munge_path" || return 1

##
## munge a path
##

## Setup expectation
expectedMungedPath="/Users/me/.rvm/gems/ruby-2.0.0-p247@railstutorial_rails_4_0/bin"
expectedMungedPath+=":/Users/me/.rvm/gems/ruby-2.0.0-p247@global/bin"
expectedMungedPath+=":/Users/me/.rvm/rubies/ruby-2.0.0-p247/bin"
expectedMungedPath+=":/Users/me/.rvm/bin"
expectedMungedPath+=":/Users/me/.gvm/pkgsets/go1.7/global/bin"
expectedMungedPath+=":/Users/me/.gvm/gos/go1.7/bin"
expectedMungedPath+=":/Users/me/.gvm/pkgsets/go1.7/global/overlay/bin"
expectedMungedPath+=":/Users/me/.gvm/bin"
expectedMungedPath+=":/Users/me/.gvm/bin"
expectedMungedPath+=":/usr/local/bin"
expectedMungedPath+=":/usr/bin"
expectedMungedPath+=":/bin"
expectedMungedPath+=":/usr/sbin"
expectedMungedPath+=":/sbin"

## Execute command
testPath="/Users/me/.gvm/pkgsets/go1.7/global/bin"
testPath+=":/Users/me/.gvm/gos/go1.7/bin:/Users/me/.gvm/pkgsets/go1.7/global/overlay/bin"
testPath+=":/Users/me/.gvm/bin"
testPath+=":/Users/me/.gvm/bin"
testPath+=":/Users/me/.rvm/gems/ruby-2.0.0-p247@railstutorial_rails_4_0/bin"
testPath+=":/Users/me/.rvm/gems/ruby-2.0.0-p247@global/bin"
testPath+=":/Users/me/.rvm/rubies/ruby-2.0.0-p247/bin"
testPath+=":/Users/me/.rvm/bin"
testPath+=":/usr/local/bin"
testPath+=":/usr/bin"
testPath+=":/bin"
testPath+=":/usr/sbin"
testPath+=":/sbin"

mungedPath="$(__gvm_munge_path "${testPath}" false)"

echo "testPath: ${testPath}"
echo "expectedMungedPath: ${expectedMungedPath}"
echo "mungedPath: ${mungedPath}"

## Evaluate result
[[ "${mungedPath}" == "${expectedMungedPath}" ]] # status=0

##
## munge a path with deduplication
##

## Setup expectation
expectedMungedPath="/Users/me/.rvm/gems/ruby-2.0.0-p247@railstutorial_rails_4_0/bin"
expectedMungedPath+=":/Users/me/.rvm/gems/ruby-2.0.0-p247@global/bin"
expectedMungedPath+=":/Users/me/.rvm/rubies/ruby-2.0.0-p247/bin"
expectedMungedPath+=":/Users/me/.rvm/bin"
expectedMungedPath+=":/Users/me/.gvm/pkgsets/go1.7/global/bin"
expectedMungedPath+=":/Users/me/.gvm/gos/go1.7/bin"
expectedMungedPath+=":/Users/me/.gvm/pkgsets/go1.7/global/overlay/bin"
expectedMungedPath+=":/Users/me/.gvm/bin"
expectedMungedPath+=":/usr/local/bin"
expectedMungedPath+=":/usr/bin"
expectedMungedPath+=":/bin"
expectedMungedPath+=":/usr/sbin"
expectedMungedPath+=":/sbin"

## Execute command
testPath="/Users/me/.gvm/pkgsets/go1.7/global/bin"
testPath+=":/Users/me/.gvm/gos/go1.7/bin:/Users/me/.gvm/pkgsets/go1.7/global/overlay/bin"
testPath+=":/Users/me/.gvm/bin"
testPath+=":/Users/me/.gvm/bin"
testPath+=":/Users/me/.rvm/gems/ruby-2.0.0-p247@railstutorial_rails_4_0/bin"
testPath+=":/Users/me/.rvm/gems/ruby-2.0.0-p247@global/bin"
testPath+=":/Users/me/.rvm/rubies/ruby-2.0.0-p247/bin"
testPath+=":/Users/me/.rvm/bin"
testPath+=":/usr/local/bin"
testPath+=":/usr/bin"
testPath+=":/bin"
testPath+=":/usr/sbin"
testPath+=":/sbin"

mungedPath="$(__gvm_munge_path "${testPath}" true)"

## Evaluate result
[[ "${mungedPath}" == "${expectedMungedPath}" ]] # status=0
