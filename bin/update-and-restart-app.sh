#!/bin/bash

APP=underground
PORT=42103
APP_HOME=/home/cade/pro/underground-app-decor/
GIT_ORIGIN=fax
GIT_BRANCH=master


#--------------------------------------------------------------------------------------------------------------

cd ${APP_HOME}

PID=`cat /home/cade/pro/decor/var/core/${APP}_${UID}/pid/app_server/Decor::Core::Net::Server::App.port${PORT}`

echo "stopping $APP with PID $PID..."
kill    $PID 1> /dev/null 2> /dev/null
sleep 2
kill -9 $PID 1> /dev/null 2> /dev/null
sleep 1

echo "stopped, waiting 4 seconds to update and restart. press CTRL+C to cancel?"
sleep 4

git pull ${GIT_ORIGIN} ${GIT_BRANCH}

/home/cade/pro/decor/core/bin/decor-rebuild-db.pl         ${APP}
/home/cade/pro/decor/core/bin/decor-load-static-data.pl   ${APP}
/home/cade/pro/decor/core/bin/decor-core-app-server.pl -e ${APP} -p ${PORT} -d 1>> decor.log 2>> decor.log &

sleep 2
NPID=`cat /home/cade/pro/decor/var/core/${APP}_${UID}/pid/app_server/Decor::Core::Net::Server::App.port${PORT}`

echo "$APP restarted with PID $NPID into $APP_HOME"
