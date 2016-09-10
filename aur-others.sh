#! /bin/bash

workdir='/mnt/aur'
repo='/mnt/srv/ftp/repo/'
declare -a PKG
declare -a DEP
export EDITOR=/bin/true
export PKGDEST="$repo"
cd $workdir

function naming {
 PKG=( $1 ${PKG[@]} )
}

function check_installed {
  pacman -Qi $1 2> /dev/null > /dev/null ; if [ ! $? = 0 ]
    then pacman -Qsq ^$1\$ 2> /dev/null > /dev/null ; if [ ! $? = 0 ]
      then pacman -Si $1 2> /dev/null > /dev/null ; if [ ! $? = 0 ]
        then DEP=( $1 ${DEP[@]/$1} )
        return 1
      fi
    fi
  fi
}

function deps_calc {
  local loop=true
  for i in $(cower --format='%D %K %M' -i $1)
    do while true
      do check_installed "$(echo $i | cut -f1 -d">")"
        if [ "$?" = 1 ]
          then deps_calc "$(echo $i | cut -f1 -d">")"
          else break 1
        fi
      done
  done
}

function Build {
  cower -fd $1 ; cd $1
  if [ -e ~/.config/aur-hooks/$1.hook ]
    then bash ~/.config/aur-hooks/$1.hook
  fi
  $EDITOR PKGBUILD ; yes \  | makepkg -fsri
}

function update_repo {
  rm -rf $workdir/*
  cd $repo
  for i in *pkg.tar.xz
    do if [ ! -e "$i.sig" ] ; then
      gpg --detach-sign --no-armor $i
    fi
  done
  repo-add -n okeanos.db.tar.xz ./*pkg.tar.xz
  rm -rf okeanos.db
  cp okeanos.db.tar.xz okeanos.db
  rm okeanos.files
  cp okeanos.files.tar.xz okeanos.files
  chmod 765 *
  paccache -r -c . -v -k 1
}


help='Usage: packages from the aur separated by whitespace

Dependencies not necessery'

if [[ -z $(echo $@) ]] ; then echo 'use -h | --help for help' ; exit ; fi

while true; do
  case $1 in
    '' 			  	) break ;;
    -h | --help 		) echo $help ; exit 0 ;;
    -u				) exit 1 ;;
    -U				) update_repo ; exit 0 ;;
    *			    	) naming $1 ; shift 1 ;;
  esac
done

for i in ${PKG[@]} ; do
  deps_calc $i ; done

for i in ${DEP[@]}
 do Build $i
 PKG=( ${PKG[@]/$i} )
 done

for i in ${PKG[@]} ; do
  Build $i
done

update_repo
