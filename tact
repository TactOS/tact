#!/bin/bash

GENTOO_BUILD_SERVER="http://tactos.net"
ATOM=${1}
PKGDIR='/usr/portage/packages'

emerge -pv ${ATOM} || exit

atoms=(`emerge -pq ${ATOM} | sed -e 's/\[[^]]*\]\([^ ]*\)/\1/g' | tr -d ' '`)

downloads=()

for (( i = 0; i < ${#atoms[*]}; ++i )); do
  echo -e "\n${atoms[i]}"
  rest_url=$(qatom --format '%{CATEGORY}/%{PN}/%{PV}-%[PR]' ${atoms[i]} | sed -e 's/-$//')
  uses_json=$(equery -q u ${atoms[i]} | sed -e 's/\([+-]\)\(.*\)/"\2":\1/' -e 's/-$/false/' -e 's/+$/true/' -e 's/.*/\0,/')
  uses_json=${uses_json%,}
  if download=$(curl -f -s -H "Accept: application/json" -H "Content-type: application/json" -X POST -d "{\"use\":{${uses_json}}}" ${GENTOO_BUILD_SERVER}/api/1/atoms/gentoo/${rest_url}/builds); then
    echo "http://${GENTOO_BUILD_SERVER}/api/1/atoms/${download}"
    downloads+=(${download})
  else
    echo "Failed!"
    unset atoms[i]
  fi
done
atoms=(${atoms[*]})

for (( i = 0; i < ${#downloads[*]}; ++i )); do
  category=$(qatom --format '%{CATEGORY}' ${atoms[i]})
  package=$(qatom --format '%{PN}' ${atoms[i]})
  version=$(qatom -F '%{PV}-%[PR]' ${atoms[i]} | sed -e 's/-$//')

  echo -e "\nWait for ${category}/${package}-${version}.tbz2"
  echo "http://${GENTOO_BUILD_SERVER}/api/1/atoms/${downloads[i]}"

  while true; do
    case $(curl -s ${GENTOO_BUILD_SERVER}/api/1/atoms/${downloads[i]}/status) in
      'success')
        echo -e "\nBuild success! ($(( ${i} + 1 )) of ${#downloads[*]})"
      break;;
      'failed')
        echo -e "\nBuild failed! ($(( ${i} + 1 )) of ${#downloads[*]})"
      break;;
      *)
      sleep 10
      echo -n '.';;
    esac
  done

  mkdir -p ${PKGDIR}/${category}
  if curl -f -s -o ${PKGDIR}/${category}/${package}-${version}.tbz2 ${GENTOO_BUILD_SERVER}/api/1/atoms/${downloads[i]}; then
    echo "Download success!"
  else
    echo "Download failed!"
  fi
done

emerge -avk ${ATOM}
