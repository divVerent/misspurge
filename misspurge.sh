#!/bin/sh

implementation=
instance=
user=
client_id=
client_secret=
token=
maxage_sec=
sync_relations=
. ${1:-~/.misspurge.conf}

now=$(date +%s)
maxtime=$((now - maxage_sec))

CR=''
LF='
'

case "$implementation" in
	mastodon|pleroma)
		if [ -z "$client_id" ]; then
			set -- $(curl -s https://"$instance"/api/v1/apps -H 'Content-Type: application/json' --data-raw "{\"client_name\": \"misspurge\", \"redirect_uris\": \"urn:ietf:wg:oauth:2.0:oob\", \"scopes\": \"read write\", \"website\": \"https://github.com/divVerent/misspurge/\"}" | jq -r '.client_id + "\n" + .client_secret')
			client_id=$1
			client_secret=$2
			echo "Add to your config:"
			echo "client_id=$client_id"
			echo "client_secret=$client_secret"
			exit 42
		fi
		if [ -z "$token" ]; then
			echo "Go to https://$instance/oauth/authorize?response_type=code&client_id=$client_id&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=read+write"
			echo -n 'Authorization code: '
			read -r code
			token=$(curl -s https://"$instance"/oauth/token -H 'Content-Type: application/json' --data-raw "{\"grant_type\": \"authorization_code\", \"code\": \"$code\", \"client_id\": \"$client_id\", \"client_secret\": \"$client_secret\", \"redirect_uri\": \"urn:ietf:wg:oauth:2.0:oob\", \"scope\": \"read write\"}" | tee /dev/stderr | jq -r '.access_token')
			echo "Add to your config:"
			echo "token=$token"
			exit 42
		fi
		apicall() {
			echo >&2 "$1 api/v1/$2 $3"
			case "$1" in
				HEAD+GET)
					curl -D - -X GET -s https://"$instance"/api/v1/"$2${3+?$3}" -H "Authorization: Bearer $token"
					;;
				POST)
					curl -s https://"$instance"/api/v1/"$2" -H 'Content-Type: application/json' -H "Authorization: Bearer $token" --data-raw "$3"
					;;
				*)
					curl -X "$1" -s https://"$instance"/api/v1/"$2${3+?$3}" -H "Authorization: Bearer $token"
					;;
			esac
		}
		me=$(apicall GET accounts/verify_credentials '' | jq -r '.id')
		[ -n "$me" ] || exit 1
		list_notes() {
			apicall GET "accounts/$me/statuses" "limit=100${1:+&max_id=$1}" | jq -r '.[] | .id + " " + .created_at'
		}
		delete_note() {
			apicall DELETE "statuses/$1" ""
			sleep 1
		}
		list_files() {
			:  # Mastodon has no files.
		}
		protected_files() {
			:  # Mastodon has no files.
		}
		file_is_used_by_any_note() {
			:  # Mastodon has no files.
		}
		delete_file() {
			:  # Mastodon has no files.
		}
		list_blocks() {
			apicall HEAD+GET blocks "$1" | {
				get_next_token prev
				export instance
				jq -r '.[] | env.next_token + " " + .acct + "@" + env.instance' | sed -e 's,\(@.*\)@.*,\1,g'
			}
		}
		create_block() {
			export acct=$1
			export instance
			id=$(apicall GET accounts/search "q=@$1&resolve=true" | jq -r '.[] | select(.acct == env.acct or .acct + "@" + env.instance == env.acct) | .id')
			[ -n "$id" ] || return 1
			apicall POST accounts/"$id"/block '{}'
			sleep 1
		}
		delete_block() {
			export acct=$1
			export instance
			id=$(apicall GET accounts/search "q=@$1&resolve=true" | jq -r '.[] | select(.acct == env.acct or .acct + "@" + env.instance == env.acct) | .id')
			[ -n "$id" ] || return 1
			apicall POST accounts/"$id"/unblock '{}'
			sleep 1
		}
		list_mutes() {
			apicall HEAD+GET mutes "$1" | {
				get_next_token prev
				export instance
				jq -r '.[] | env.next_token + " " + .acct + "@" + env.instance' | sed -e 's,\(@.*\)@.*,\1,g'
			}
		}
		create_mute() {
			export acct=$1
			export instance
			id=$(apicall GET accounts/search "q=@$1&resolve=true" | jq -r '.[] | select(.acct == env.acct or .acct + "@" + env.instance == env.acct) | .id')
			[ -n "$id" ] || return 1
			apicall POST accounts/"$id"/mute '{"notifications": "false"}'
			sleep 1
		}
		delete_mute() {
			export acct=$1
			export instance
			id=$(apicall GET accounts/search "q=@$1&resolve=true" | jq -r '.[] | select(.acct == env.acct or .acct + "@" + env.instance == env.acct) | .id')
			[ -n "$id" ] || return 1
			apicall POST accounts/"$id"/unmute '{}'
			sleep 1
		}
		get_next_token() {
			rel=$1
			export next_token=
			while IFS=" " read -r header value; do
				header=${header%$CR}
				value=${value%$CR}
				case "$header" in
					'')
						break
						;;
					link:)
						save_IFS=$IFS
						IFS=","
						set -- $value
						IFS=$save_IFS
						for val in "$@"; do
							case "$val" in
								*'; rel="'"$rel"'"')
									url=${val%%>;*}
									next_token="${url##*\?}"
									;;
							esac
						done
						;;
				esac
			done
		}
		list_follows() {
			apicall HEAD+GET accounts/"$me"/following "$1" | {
				get_next_token next
				export instance
				jq -r '.[] | env.next_token + " " + .acct + "@" + env.instance' | sed -e 's,\(@.*\)@.*,\1,g'
			}
		}
		create_follow() {
			export acct=$1
			export instance
			id=$(apicall GET accounts/search "q=@$1&resolve=true" | jq -r '.[] | select(.acct == env.acct or .acct + "@" + env.instance == env.acct) | .id')
			[ -n "$id" ] || return 1
			apicall POST accounts/"$id"/follow '{}'
			sleep 1
		}
		delete_follow() {
			export acct=$1
			export instance
			id=$(apicall GET accounts/search "q=@$1&resolve=true" | jq -r '.[] | select(.acct == env.acct or .acct + "@" + env.instance == env.acct) | .id')
			[ -n "$id" ] || return 1
			apicall POST accounts/"$id"/unfollow '{}'
			sleep 1
		}
		;;
	misskey)
		if [ -z "$token" ]; then
			echo "Go to https://misskey.de/settings/api and create an access token."
			echo "The token needs the following permissions:"
			echo "- View your account information"
			echo "- View your list of blocked users"
			echo "- Edit your list of blocked users"
			echo "- Access your Drive files and folders"
			echo "- Edit or delete your Drive files and folders"
			echo "- View information on who you follow"
			echo "- Follow or unfollow other accounts"
			echo "- View your list of muted users"
			echo "- Edit your list of muted users"
			echo "- Compose or delete notes"
			echo "Then add to your config:"
			echo "token=<that token>"
			exit 42
		fi
		apicall() {
			echo >&2 "api/$1$2"
			curl -s https://"$instance"/api/"$1" -H 'Content-Type: application/json' --data-raw "{\"i\": \"$token\"$2}"
		}
		me=$(apicall i '' | jq -r '.id')
		list_notes() {
			apicall users/notes ", \"userId\": \"$me\", \"limit\": 100${1:+, \"untilId\": \"$1\"}" | jq -r '.[] | .id + " " + .createdAt'
		}
		delete_note() {
			apicall notes/delete ", \"noteId\": \"$1\""
			sleep 12  # Endpoint limit: 300 per 1 hour.
		}
		list_files() {
			apicall drive/files ", \"limit\": 100${1:+, \"untilId\": \"$1\"}" | jq -r '.[] | .id + " " + .createdAt'
		}
		protected_files() {
			apicall i '' | jq -r '.avatarId + "\n" + .bannerId'
		}
		file_is_used_by_any_note() {
			[ x$(apicall drive/files/attached-notes ", \"fileId\": \"$1\"" | jq -r 'length != 0') = x'true' ]
		}
		delete_file() {
			apicall drive/files/delete ", \"fileId\": \"$1\""
			sleep 12  # Same as delete_note.
		}
		list_blocks() {
			apicall blocking/list ", \"limit\": 100${1:+, \"untilId\": \"$1\"}" | jq -r '.[] | .id + " " + .blockee.username + "@" + .blockee.host'
			# also following/create
		}
		create_block() {
			id=$(apicall users/search-by-username-and-host ", \"username\": \"${1%@*}\", \"host\": \"${1##*@}\", \"limit\": 1" | jq -r '.[] | .id')
			[ -n "$id" ] || return 1
			apicall blocking/create ", \"userId\": \"$id\""
			sleep 12  # Same as delete_note.
		}
		delete_block() {
			id=$(apicall users/search-by-username-and-host ", \"username\": \"${1%@*}\", \"host\": \"${1##*@}\", \"limit\": 1" | jq -r '.[] | .id')
			[ -n "$id" ] || return 1
			apicall blocking/delete ", \"userId\": \"$id\""
			sleep 12  # Same as delete_note.
		}
		list_mutes() {
			apicall mute/list ", \"limit\": 100${1:+, \"untilId\": \"$1\"}" | jq -r '.[] | .id + " " + .mutee.username + "@" + .mutee.host'
			# also mute/create
		}
		create_mute() {
			id=$(apicall users/search-by-username-and-host ", \"username\": \"${1%@*}\", \"host\": \"${1##*@}\", \"limit\": 1" | jq -r '.[] | .id')
			[ -n "$id" ] || return 1
			apicall mute/create ", \"userId\": \"$id\""
			sleep 12  # Same as delete_note.
		}
		delete_mute() {
			id=$(apicall users/search-by-username-and-host ", \"username\": \"${1%@*}\", \"host\": \"${1##*@}\", \"limit\": 1" | jq -r '.[] | .id')
			[ -n "$id" ] || return 1
			apicall mute/delete ", \"userId\": \"$id\""
			sleep 12  # Same as delete_note.
		}
		list_follows() {
			apicall users/following ", \"userId\": \"$me\", \"limit\": 100${1:+, \"untilId\": \"$1\"}" | jq -r '.[] | .id + " " + .followee.username + "@" + .followee.host'
			# also following/create
		}
		create_follow() {
			id=$(apicall users/search-by-username-and-host ", \"username\": \"${1%@*}\", \"host\": \"${1##*@}\", \"limit\": 1" | jq -r '.[] | .id')
			[ -n "$id" ] || return 1
			apicall following/create ", \"userId\": \"$id\""
			sleep 12  # Same as delete_note.
		}
		delete_follow() {
			id=$(apicall users/search-by-username-and-host ", \"username\": \"${1%@*}\", \"host\": \"${1##*@}\", \"limit\": 1" | jq -r '.[] | .id')
			[ -n "$id" ] || return 1
			apicall following/delete ", \"userId\": \"$id\""
			sleep 12  # Same as delete_note.
		}
		;;
esac

all_items() {
	lister=$1
	while :; do
		save_IFS=$IFS
		IFS=$LF
		set -- $("$lister" "$continuation")
		IFS=
		continuation=
		while [ $# -gt 0 ]; do
			line=$1; shift
			echo "$line"
			continuation=${line%% *}
		done
		if [ -z "$continuation" ]; then
			break
		fi
	done
}

all_notes() {
	all_items list_notes
}

all_files() {
	all_items list_files
}

all_blocks() {
	all_items list_blocks
}

all_mutes() {
	all_items list_mutes
}

all_follows() {
	all_items list_follows
}

filter_age() {
	while read -r file created_at; do
		created_at=$(date +%s -d"$created_at")
		if [ $created_at -lt $maxtime ]; then
			echo "$file $created_at"
		fi
	done
}

filter_unused() {
	protected=$(protected_files)
	while read -r file created_at; do
		case "$LF$protected$LF" in
			*$LF$file$LF*)
				echo >&2 "$file is used as avatar or banner, skipping"
				continue
				;;
		esac
		if file_is_used_by_any_note "$file"; then
			echo >&2 "$file is used by a note, skipping"
		else
			echo >&2 "$file is unused"
			echo "$file $created_at"
		fi
	done
}

purge_notes() {
	while read -r note created_at; do
		echo >&2 "Purging note $note..."
		delete_note "$note"
	done
}

purge_files() {
	while read -r file created_at; do
		echo >&2 "Purging unused file $file..."
		delete_file "$file"
	done
}

if [ -n "$maxage_sec" ]; then
	all_notes | filter_age | purge_notes
	all_files | filter_age | filter_unused | purge_files
fi

sync_states() {
	state=$1
	unstates=$2
	exceptstates=$3
	ignorestates=$4

	mkdir -p "$sync_relations"/"$state"

	# Save all known ones.
	known=''
	while read -r id other; do
		ignore=false
		for ignorestate in $ignorestates; do
			if [ -f "$sync_relations"/"$exceptstate"/"$other" ]; then
				echo >&2 "Leave $other alone from $state because $other is also in $ignorestate."
				ignore=true
			fi
		done
		if $ignore; then
			continue
		fi
		delete=false
		for exceptstate in $exceptstates; do
			if [ -f "$sync_relations"/"$exceptstate"/"$other" ]; then
				echo >&2 "Delete $other from $state because $other is also in $exceptstate."
				delete=true
			fi
		done
		if $delete; then
			delete_"$state" "$other" | jq -c
			rm -f "$sync_relations"/"$state"/"$other"
			continue
		fi
		touch "$sync_relations"/"$state"/"$other"
		for unstate in $unstates; do
			rm -f "$sync_relations"/"$unstate"/"$other"
		done
		known="$known $other"
	done
	known="$known "

	# Add all unknown ones.
	for other in "$sync_relations"/"$state"/*; do
		other=${other##*/}
		case "$known" in
			*" $other "*)
				continue
				;;
		esac
		if [ x"$other" = x"$user@$instance" ]; then
			# No need to self-follow.
			continue
		fi
		create_"$state" "$other" | jq -c
	done
}

if [ -n "$sync_relations" ]; then
	all_blocks  | sync_states block  'mute follow' 'noblock'             nochange
	all_mutes   | sync_states mute   'follow'      'nomute block'        nochange
	all_follows | sync_states follow ''            'nofollow block mute' nochange
fi
