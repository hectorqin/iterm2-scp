# iterm2-scp

Iterm2 scp helper script

## Install

1. Enable SSH ControlMaster or enable SSH public key login, to make scp command noninteractive.

2. Place `server helper function` to shell profile on server.

    ```bash
    scp_helper_func(){ local s="";for i in $@; do s="$s '$i'"; done;echo $s; } && fs(){ scp_helper_func scp_send '-w' "'$(pwd)'" $*; } && js(){ scp_helper_func scp_receive '-w' "'$(pwd)'" $*; }
    ```

3. Add iterm2 trigger

- Regular Expression: `'scp_receive' .*`
- Action: `Run Coprocess`
- Parameters: `/path/to/iterm2-scp.sh '\(tab.currentSession. jobPid)' '\(matches[0])'`
- Turn on `Use interpolated strings for parameters`

## Download file from server

```bash
js /path/to/serverfile1 /path/to/serverfile2
```

## Upload local file to server

```bash
fs
```
