# gvm

[English](./README.md) | 简体中文

一个 Go 版本管理器，用法照搬大家熟悉的 nvm：`gvm install stable`、
`gvm use stable`，把各个 Go 版本放在一个目录里随你切换，不用动你的项目。


```console
$ gvm install 1.24
Downloading go1.24.13.linux-amd64.tar.gz
go1.24.13 successfully installed

$ gvm use 1.24
Now using version go1.24.13

$ go version
go version go1.24.13 linux/amd64
```

## 安装

不需要编译。任选一种：

```console
$ bash <(curl -sSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
```

或者从源码装：

```console
$ git clone https://github.com/moovweb/gvm.git
$ cd gvm
$ ./install.sh
```

或者用 make：

```console
$ make install                      # 装到 ~/.gvm
$ make install PREFIX=~/go/gvm
```

安装脚本默认装到 `~/.gvm`，往你的 shell 配置文件里加一行，然后不再动任何其他
东西。它拒绝覆盖一个不是 gvm 的目录，所以 `--force` 需要你主动写出来。

| 参数 | 作用 |
| --- | --- |
| `--prefix <dir>` | 安装位置，默认 `~/.gvm` |
| `--profile <file>` | 指定要改的配置文件，不自动猜 |
| `--no-profile` | 不动任何配置文件 |
| `--force` | 覆盖已有的 gvm 重新安装 |
| `--no-clone` | 直接用当前的 gvm 源码目录安装，不联网 |
| `--keep-repo` | 保留 git checkout 原样，不改名成 `git.bak` |
| `--uninstall` | 卸载 gvm；配合 `--force` 会保留 `$PREFIX/gos` |

写进配置文件的那一行是：

```bash
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
```

`scripts/gvm` 会从自己的位置反推 `GVM_ROOT`，所以你把目录挪走或者做成软链接都
不用改配置文件。`gvm implode` 会把这一行从配置文件里删掉，并在旁边留一个
`.gvm-backup`。

bash 和 zsh 都能用；安装脚本会把那行写进它找到的那个 shell 的配置。依赖：
`bash` 3.2+（或 zsh 5+）、`tar`、`gzip`、`awk`、`sed`，以及一个 SHA256 工具
（`sha256sum` 或 `shasum`）。下载需要 `curl`；只有源码构建才需要 `make` 和 C
编译器。`gvm doctor` 会把这些都检查一遍。

## 更新 gvm 本身

`gvm update` 会从这次安装的来源仓库 fetch 过来然后 fast-forward，就像
`brew update` 那样：

```console
$ gvm update
Fetching origin
gvm 1.1.0 -> 1.2.0 (949184e..a1b2c3d)
1 new commit(s):
  a1b2c3d Release 1.2.0

gvm is now at 1.2.0 (a1b2c3d).
Start a new shell to pick it up:  exec $SHELL
Go versions under /home/you/.gvm/gos were not touched.
```

| 参数 | 作用 |
| --- | --- |
| `--check` | 只报告会做什么，什么都不改 |
| `--repo <url>` | 从别的仓库 fetch，不会添加 remote |
| `--ref <name>` | fetch 指定的分支或 tag，而不是当前跟踪的那个 |

它只做 fast-forward。带着本地提交、带着对 gvm 自身文件的本地修改、或者有被中断
的 merge / rebase 的 checkout，一律拒绝，并且报错里直接给出该敲哪条命令——本地
修改对应 `git -C ~/.gvm stash`，本地提交对应 `gvm update --repo <你的 fork>`。
一个按 gvm 自己的判断去「解决」你的冲突的更新，比不更新更糟。

`install.sh` 一直保留着它 clone 下来的历史，放在 `~/.gvm/git.bak`，所以用一行命令
装的 gvm 不重装也能更新：第一次 `gvm update` 把它挪回 `.git`，然后从那里
fast-forward。`install.sh --keep-repo` 则让它就留在原处，之后再重装也不会把它收
走。完全没有历史的安装（比如手工解压的压缩包）不会被拿一个没验证过的 URL 去更新，
而是告诉你怎么先弄一个 checkout。

`gvm update` 不碰 `gos/` 下的 Go 版本、别名和 package set，也不会切换你正在用
的版本。它只改文件；你当前这个 shell 要开新的才能用上。

## 使用

### 版本

```console
$ gvm ls                    # 已安装的版本和别名
$ gvm ls-remote 1.24        # 已发布的版本
$ gvm use 1.24              # 已安装的 go1.24.x 里最新的一个
$ gvm use go1.24.13         # 精确指定
$ gvm use stable            # 最新的稳定版，装没装都行
$ gvm which                 # 当前生效的 GOROOT
$ gvm which 1.24 go         # 该版本里 go 命令的路径
$ gvm current               # 当前选中的版本
```

`gvm install` 接受同样的参数：完整版本号、部分版本号，或者一个别名。`gvm use`
只会切换到已经装好的版本；没装的话它会告诉你要装，而不是背着你偷偷去下载。

### gvm 认识的写法

| 写法 | 含义 |
| --- | --- |
| `1.24.13`、`go1.24.13` | 就是这个版本 |
| `1.24`、`1.24.*` | 最新的 `go1.24.x` |
| `1.24.0rc1` | 这个发布候选版 |
| `stable`、`latest` | 最新的稳定版 |
| `unstable` | 最新的 beta 或 RC |
| `newest` | 最新的版本，不管是不是预发布 |
| `oldest` | gvm 知道的最老的稳定版 |
| `default` | `gvm use --default` 记录下来的那个 |
| `system` | 你 `PATH` 上原本就有的 Go，gvm 不接管 |

预发布版本只会在你明确要求时才被选中。要装 `1.25` 而本地没有稳定的
`go1.25.x` 时，它会挑最新的稳定版；如果只找得到 RC，切换之前会先告诉你一声。

### 别名

```console
$ gvm alias create work 1.24
$ gvm use work
$ gvm alias list
$ gvm alias delete work
```

别名可以指向版本，也可以指向别的别名（包括内置的那些），所以
`gvm alias create mine stable` 是可以的。出现环的时候 gvm 会报错，而不是一直
跟着转。

### 按目录切换版本

在项目里放一个 `.go-version`，`cd` 进去的时候 gvm 就会自动切换：

```console
$ cat .go-version
1.24.13
$ cat .go-pkgset        # 可选，同时指定包集合
myproject
```

这个文件是从当前目录往上级目录找的，所以 monorepo 放在根目录一个就够。钩子
随配置文件一起安装；如果你本来就有自己的 `cd` 函数覆写，它会被保留。

`gvm applymod` 会读 `go.mod` 里的 `go` 声明并切到满足它的版本，和 Go 一样把它
当成「最低要求」而不是精确锁定：

```console
$ gvm applymod
go.mod asks for go1.24.0
Now using version go1.24.13
```

它不会偷偷下载东西：没有合适的版本时，它会把要执行的 `gvm install` 命令打出来。

### 包集合

`GOPATH` 从「一台机器一份」变成了「一个项目一份」：

```console
$ gvm pkgset create myproject
$ gvm use 1.24@myproject
$ gvm pkgset list
$ gvm pkgenv myproject     # 打印环境变量；加 --edit 用 $EDITOR 编辑
```

`gvm linkthis` 会把当前目录软链到 `GOPATH/src` 里，照顾还在用老 GOPATH 工作流
的场景。

### 源码构建

```console
$ gvm install 1.25 --source
```

`--source` 是从 `go.dev/dl` 的源码构建，而不是下载二进制。它需要一个引导
工具链，gvm 会替你装好：每个系列锁定一个最老的受支持版本，Go 1.26 及以后用
偶数号的次版本。想自己指定就用 `GOROOT_BOOTSTRAP`：

```console
$ GOROOT_BOOTSTRAP=$HOME/sdk/go1.24.6 gvm install 1.26 --source
```

构建开发版是 git 操作，需要完整的 C 工具链：

```console
$ gvm install master --from-git
```

它会把 `golang/go` 按你给的 ref 浅克隆下来再构建。这是唯一用到 git 的路径，
当然也慢。

### 交叉编译

gvm 不会为每个平台各留一份 Go 树。用你手上这个工具链构建别的平台就行：

```console
$ GOOS=darwin GOARCH=arm64 go build ./...
$ GOOS=windows GOARCH=amd64 go build -o app.exe .
```

如果你确实想要每个平台一个独立的工具链，Go 官方有
[`golang.org/dl`](https://pkg.go.dev/golang.org/dl)，它自己管理下载：

```console
$ go install golang.org/dl/go1.24.13@latest
$ go1.24.13 download
```

### 盯着 Go 别乱来

`gvm diff` 会拿安装时记录的文件清单做对比，报出已安装的 Go 树里被改动了什么：

```console
$ gvm diff 1.24
WARNING: *Dirty* /home/you/.gvm/gos/go1.24.13
  added:
    + ./src/handwritten.go
```

`gvm doctor` 会汇报安装本身的状态，以及各个命令分别需要哪些工具。

## 安全性

- 每个压缩包在解压之前都会用 Go 发布索引里的 SHA256 校验。`GVM_NO_VERIFY=1`
  可以关掉，但不建议。
- 索引来自 `go.dev/dl`。隔离网络的机器可以用 `GVM_INDEX_FILE` 固定一份已经
  解析好的 TSV（不是原始 JSON）。
- `gvm implode` 是唯一会删掉整棵目录树的命令。它会拒绝一个既没有 `scripts/`
  又没有 `VERSION` 的 `GVM_ROOT`，而且只在有终端的时候才提示确认，所以脚本里
  拿到的是报错，而不是一直挂着。
- `gvm uninstall` 拒绝删除正在使用的版本，除非加 `--force`。
- `gvm update` 只做 fast-forward，遇到脏的、分叉的或者停在半截的 checkout 会
  拒绝，而不是替你和稀泥。一个会覆盖掉你为了让它跑起来而改过的文件的工具，
  那不叫更新。
- `gvm install <版本> --force` 只替换 GOROOT，别的不动。你的 package set 会保留，
  这一点很重要：模块缓存和 `go get` 装出来的东西都在里面。重装某个版本本来就是
  用来修坏掉的 Go 树的，不应该顺便把下载缓存也赔进去。

## 环境变量

| 变量 | 作用 |
| --- | --- |
| `GVM_ROOT` | gvm 的安装位置。由配置文件里那一行设置，不要手动改 |
| `GVM_OFFLINE` | 永不刷新发布索引 |
| `GVM_DL_BASE_URL` | 从镜像而不是 `go.dev` 下载 |
| `GVM_NO_VERIFY` | 跳过校验和验证 |
| `GOROOT_BOOTSTRAP` | 源码构建用的引导工具链 |
| `GVM_QUIET` | 少说点话 |
| `GVM_DEBUG` | 打印内部追踪信息 |

布尔型的变量认 `1/true/yes/on` 和 `0/false/no/off`，写成 `GVM_NO_VERIFY=0`
就是「仍然要校验」，不是「不校验」。不是布尔值的写法会报一句错并当作 false。

## 工作原理

`GOTOOLCHAIN` 是这里唯一和直觉不太一样的地方。现代 Go 自己就能下载和切换
工具链，所以 gvm 在选中版本时会设 `GOTOOLCHAIN=local`。不这样的话，一个写着
`go 1.30` 的 `go.mod` 会让工具链自己去抓一个 Go 1.30，然后你选的那个版本就被
悄悄忽略了。如果你更想让 Go 自己管这件事，自行设置 `GOTOOLCHAIN` 即可。

`$GVM_ROOT/.gvm-source` 记录安装脚本放进去的东西：仓库、ref、commit、版本，
以及这次安装是不是一个 git checkout。`gvm update` 会更新它，`gvm doctor` 会打
印它，报 bug 时它也是最该先贴出来的东西。只有 `gvm update` 会写它，`gvm ls`
这类命令根本不读它，所以文件坏掉也不会连累跟它无关的命令。

## 1.1.0 和 1.2.0 改了什么

1.2.0 加了 `gvm update`（见[更新 gvm 本身](#更新-gvm-本身)），并修掉了挡在它
前面的两件事。下面这些属于 1.1.0，也就是重写本身。

1.0.22 是 2016 年的版本，发布列表是仓库里的一个文件。这次重写了其中
已经老化的部分，命令行接口保持不变：

- **发布信息来自 [go.dev](https://go.dev/dl)。** `gvm install 1.24` 会解析成
  真正发布过的最新 `go1.24.x`，包括比本仓库最后一次提交还新的补丁版本，并按平台
  选对应的产物。`GVM_INDEX_FILE` 可以固定一份解析好的索引，`GVM_OFFLINE=1` 复用
  缓存且不刷新——给上不了网的机器用。
- **下载一律校验。** 每个产物都比对索引里的 SHA256，对不上就拒绝并删掉文件，只有
  显式设置 `GVM_NO_VERIFY=1` 才能跳过。
- **选中 gvm 管理的版本时导出 `GOTOOLCHAIN=local`**，这样 `go.mod` 要求更高版本
  时，选中的工具链不会背着你去下载并使用另一个。
- **zsh 和 bash 一样被支持并有测试**，不只是能跑；带空格的路径（`GVM_ROOT=
  "/opt/my gvm"`）到处都能用。
- **安装器不再需要 autotools 和 Ruby。** 从 checkout 安装不会再去 clone 一份覆盖
  上来，正在使用中的 gvm 不会被删掉，`--uninstall` 也遵守 `--no-profile`。
  `gvm install X --force` 重装时会保留该版本的 package set——修坏掉的 Go 树不该
  连带赔上模块缓存。
- **新命令**：`gvm update`（用 git 更新 gvm 自己）、`gvm doctor`（这台安装哪里不对）、
  `gvm ls-remote`（官方发布了什么）、`gvm applymod`（按 `go.mod` 切到满足它的版本，
  把它当成最低要求）、`gvm which`、`gvm delete`，以及重写的 `gvm diff` 和
  `gvm help`。
- **测试套件**是 785 条断言的纯 bash，不依赖任何框架，每个文件自己建一个一次性
  `GVM_ROOT`；如果测试改到了你真实的 `~/.bashrc` 或 `~/.zshrc`，它会直接失败。
  `gvm update` 是拿真实的仓库测的，仓库是用真实的 gvm 树搭出来的，「远端」就是
  一个目录，所以测试不需要联网。GitHub Actions 在 Linux 和 macOS 上都跑，macOS
  的 `bash` 是 3.2。
- **中文文档**（就是本文件）和一份完整的 `CHANGELOG.md`。

值得单独点出的几个静默 bug：`gvm implode` 会删掉作为 `$HOME` 的 `GVM_ROOT`；
`gvm uninstall` 会删掉你正在用的那个版本，并让 `environments/default` 指向空处；
`gvm install --force` 会清空它正在重装的那个版本的 package set。

## 开发

```console
$ make test          # 在一次性的沙箱里跑完整套测试
$ make lint          # 解析每一个 shell 脚本
$ ./tests/run.sh     # 同上
```

每个测试文件都是独立的，不需要任何测试框架，并且会在 `/tmp` 下建自己的
`GVM_ROOT`，所以测试永远不会碰到你真实的安装。需要发布索引的测试会把它固定
到一份 fixture。

macOS 是最可能用到 gvm 的地方，而它的 `bash` 是 3.2，所以即使在 Linux 上也值得
在那个版本里跑一遍套件。一个容器就够了：

```console
$ docker build -t gvm-bash32 - <<'EOF'
FROM bash:3.2
RUN apk add --no-cache coreutils findutils grep gawk sed procps git python3 go curl make
RUN ln -sf /usr/local/bin/bash /usr/bin/bash && ln -sf /usr/local/bin/bash /bin/bash
EOF
$ docker run --rm -v "$PWD:/w" -w /w -e HOME=/tmp gvm-bash32 bash tests/run.sh
```

还有两个条件值得故意去复现，因为它们各自弄坏过一个在别处全都通过的测试，而且
都不需要 macOS：

```console
$ TMPDIR=/tmp/whatever/ bash tests/run.sh       # macOS 的 TMPDIR 带结尾斜杠
$ ln -s /tmp /tmp/varlink
$ TMPDIR=/tmp/varlink/ bash tests/run.sh        # ... 而且位于 /var -> /private/var 之下
```

目录结构刻意做得很平：`bin/gvm` 按文件名分发，所以一个命令就是
`scripts/<名字>`，一个 shell 函数就是 `scripts/env/<名字>`。`make lint` 和
`tests/09_cli_test.sh` 里的帮助一致性测试都会在「文件列表、帮助文本、对外宣称
的命令」这三者对不上的时候失败。

## 许可

MIT，未作改动：`LICENSE` 属于 Moov Corp.，这里不动它。
