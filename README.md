# <img src="fig.png" alt="Fig icon" style="height:2ch"> Fig

Fig is configuration management for small infrastructure. It's written in Bash and aims to provide just enough structure to make it pleasant to configure a system with shell scripts.

The central concept in Fig is a _module_. Fig modules can specify a list of packages to install, and can provide an `apply` function which is called on every configured module during a `fig apply`. Fig provides several idempotent helper functions allowing placing of files, template generation, and more.

A module is a directory under `modules/` which contains a `module.sh` file. Module names can contain slashes for namespacing, and in this case they appear as subdirectories somewhere under `modules/`. An example `module.sh` might look like:

```bash
packages=(
    nginx
)

apply() {
    ensure-file /etc/nginx/nginx.conf
    ensure-service nginx
}
```

When applied, this example module will install the `nginx` package, copy the file `files/etc/nginx/nginx.conf` relative to the module root to `/etc/nginx/nginx.conf` in the filesystem, and then enable and start the nginx systemd service.

The collection of modules to be applied to a system is defined in `index.sh` in the root of your configuration repository. `index.sh` defines a `modules` array, and can populate this array however makes sense. For example, you might use a system's hostname to determine which modules are applied:

```bash
# apply the base module to all nodes
modules=(
    base
)

# apply node-specific modules based on hostname
case "$(hostname -s)" in
web-server)
    modules+=(nginx)
    ;;
dns-server)
    modules+=(bind)
    ;;
esac
```

## Getting started

1. Create a new Git repository for your configuration and `cd` into it:
   ```sh-session
   $ git init my-infra
   $ cd my-infra
   ```

2. Add the Fig repository as a submodule at `fig` in the root of the repository:
   ```sh-session
   $ git submodule add https://github.com/haileys/fig fig
   ```

3. Create the necessary file structure:
   ```sh-session
   $ touch index.sh # the entrypoint to your fig configuration
   $ mkdir modules # fig modules go here
   ```

You're good to go! Use `rsync` to deploy your Fig repository to a server, and `ssh` to run `path-to-my-infra/fig/bin/fig apply` - where `path-to-my-infra` is the path you rsynced the repo to.

## Lifecycle of `fig apply`

1. Load `index.sh` to determine modules to apply on this system

2. Collect all `bootstrap_packages` from each configured module and install using system package manager

3. Call `before-packages` function for each configured module

4. Collect all `packages` from each configured module and install using system package manager

5. Call `apply` function for each configured module

## Repository layout

```
/                               # repo root
    index.sh                    # fig entrypoint, defines `modules` array
    modules/
        foo/
            module.sh           # module definition for "foo"
            files/
                etc/
                    foo.txt     # placed in /etc/foo.txt by `ensure-file`
            gen/
                etc/
                    magic.txt   # executable script which generates /etc/magic.txt called by `ensure-gen`
            bar/
                module.sh       # nested module definition for "foo/bar"
                                # NOTE: has no implicit relationship to "foo" module
```

## Full module structure

```bash
# Packages listed in the `packages` array are installed using the system package manager.
packages=()

# The `apply` function is called after installing packages.
#
# Example use case: place config files and enable systemd services.
apply() {
    true
}

# The `before-packages` function is called before installing packages.
#
# Example use case: setup third-party apt sources.
before-packages() {
    true
}

# Packages listed in `bootstrap_packages` are installed before calling `before-packages`.
# Use sparingly, because there's no hook that comes before this one.
#
# Example use case: install gnupg for verifying third-party apt signatures, or install
# `ca-certificates` for accessing apt repos over https.
bootstrap_packages=()
```

## Ensure helpers

### `ensure-service`

<pre>
usage: ensure-service <b><i>service</i></b>
</pre>

Enables and starts systemd unit **_service_**.

### `ensure-file`

<pre>
usage: ensure-file <b><i>path</i></b> [source=<b><i>source</i></b>] [chown=<b><i>chown</i></b>] [chmod=<b><i>chmod</i></b>]
</pre>

Places a file at **_path_** in the filesystem, sourcing from <code>files/<b><i>path</i></b></code> by default.

* **_source_** - path to source file, relative to module root

* **_chown_** - arguments to _chown(1)_, eg. `user`, `user:group`, `:group`

* **_chmod_** - arguments to _chmod(1)_, eg. `+w`, `u+wa+x`, `0755`

### `ensure-dir`

<pre>
usage: ensure-dir <b><i>path</i></b> [chown=<b><i>chown</i></b>] [chmod=<b><i>chmod</i></b>]
</pre>

Ensures **_path_** in the filesystem is a directory.

* **_chown_** - arguments to _chown(1)_, eg. `user`, `user:group`, `:group`

* **_chmod_** - arguments to _chmod(1)_, eg. `+w`, `u+wa+x`, `0755`

### `ensure-gen`

<pre>
usage: ensure-gen <b><i>path</i></b> [template=<b><i>template</i></b>] [chown=<b><i>chown</i></b>] [chmod=<b><i>chmod</i></b>]
</pre>

Executes a script to generate the contents of **_path_** in the filesystem, executing <code>gen/<b><i>path</i></b></code> by default.

* **_template_** - path to executable template file, relative to module root

* **_chown_** - arguments to _chown(1)_, eg. `user`, `user:group`, `:group`

* **_chmod_** - arguments to _chmod(1)_, eg. `+w`, `u+wa+x`, `0755`

### `ensure-url`

<pre>
usage: ensure-url <b><i>path</i></b> <b><i>url</i></b> sha256=<b><i>sha256</i></b> [chown=<b><i>chown</i></b>] [chmod=<b><i>chmod</i></b>]
</pre>

Downloads file from **_url_**, validates checksum according to **_sha256_**, and places in filesystem at **_path_**.

* **_sha256_** - sha256 checksum for validation. mandatory

* **_chown_** - arguments to _chown(1)_, eg. `user`, `user:group`, `:group`

* **_chmod_** - arguments to _chmod(1)_, eg. `+w`, `u+wa+x`, `0755`

### `ensure-user`

<pre>
usage: ensure-user <b><i>user</i></b> [groups=<b><i>groups</i></b>] [usergroup=1] [homedir=<b><i>homedir</i></b>] [createhome=1] [shell=<b><i>shell</i></b>] [uid=<b><i>uid</i></b>] [gid=<b><i>gid</i></b>]
</pre>

Creates user with name **_user_** if user does not already exist.

⚠️ Does not make any changes if user with name **_user_** already exists.

* **_groups_** - comma separated list of supplementary groups for new user, eg. `sudo`, `sudo,wheel`

* **_usergroup_** - create group with same name as user

* **_homedir_** - home directory of the new user

* **_createhome_** - create the user's home directory

* **_shell_** - login shell for new user

* **_uid_** - uid for new user

* **_gid_** - gid for new user

### `ensure-group`

<pre>
usage: ensure-group <b><i>group</i></b> [gid=<b><i>gid</i></b>]
</pre>

Creates group with name **_group_** if group does not already exist.

⚠️ Does not make any changes if group with name **_group_** already exists.

* **_gid_** - gid for new group

### `ensure-ssh-keygen`

<pre>
usage: ensure-ssh-keygen <b><i>user</i></b> [type=<b><i>type</i></b>] [file=<b><i>file</i></b>]
</pre>

Ensures SSH key exists for <b><i>user</i></b> at <code><b><i>file</i></b></code>.

* **_type_** - `-t` parameter to _ssh-keygen(1)_, defaults to `ed25519`

* **_file_** - file path for SSH key, defaults to <code>~<b><i>user</i></b>/.ssh/id_<b><i>type</i></b></code>

---

_Fig icon in `fig.png` designed by [Freepik](http://www.freepik.com/), sourced from https://www.freepik.com/icon/fig_13324385_
