# Misspurge

A tool for Misskey (but also Mastodon, Pleroma and Akkoma) users that
can apply policies to Fediverse accounts.

To use, first install `curl` and `jq`, and set up a `misspurge.conf`
file based on the example and launch `./misspurge.sh`. At first you will
be prompted to log in and edit `misspurge.conf` to add a login token.
Once done, it will run to the end and can be set up as a cron job if so
desired.

Features are as follows:

## Retention Policies

Set `maxage_sec` to the maximum age of notes to retain in seconds.

Misspurge then will delete any notes or files older than this age. Files
are deleted only if they are not also referenced by another note.

## Follow Syncing

Follows, mutes and blocks can be synchronized across instances by
creating multiple `misspurge.conf` files that contain the same directory
as value of the `sync_relations` variable. You can then pass the path to
the file as argument to `misspurge.sh`, e.g. by writing a script like:

    #!/bin/sh
    
    ./misspurge.sh ~/.misspurge.conf.mastodon.social
    ./misspurge.sh ~/.misspurge.conf.misskey.io

and setting this up as a cronjob.

Any follow, mute or block seen in the instance to be synced will be
written to the given directory, and any follow, mute or block in the
directory will be uploaded to the instance.

Note that this provides for no easy way to *remove* a follow, mute or
block. To do so, the following rules apply:

  - Mutes remove follows.
  - Blocks remove mutes and follows.
  - Otherwise, to remove follow, create a directory called `nofollow`
    and move the file inside `follow` named after the handle to the
    `nofollow` directory.
  - Similarly, `nomute` and `noblock` directories can be used to remove
    those.

## Contributing

Feel free to contribute to this project on GitHub.

## License

This software is licensed under the [MIT license](LICENSE.txt).
