#!/bin/bash
function onExit {
    service postgresql stop
}
trap onExit EXIT

service postgresql start
$@
exit $?