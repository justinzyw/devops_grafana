#!/bin/bash

# Fetch the variables
. parm.txt

# function to get the current time formatted
currentTime()
{
  date +"%Y-%m-%d %H:%M:%S";
}

sudo docker service scale devops-cadvisor=0
sudo docker service scale devops-grafana=0
sudo docker service scale devops-grafanadb=0


echo ---$(currentTime)---populate the volumes---
#to zip, use: sudo tar zcvf devops_grafana_volume.tar.gz /var/nfs/volumes/devops_grafana*
sudo tar zxvf devops_grafana_volume.tar.gz -C /


echo ---$(currentTime)---create Grafanadb service---
sudo docker service create -d \
--name devops-grafanadb \
--mount type=volume,source=devops_grafanadb_volume,destination=/var/lib/influxdb,\
volume-driver=local-persist,volume-opt=mountpoint=/var/nfs/volumes/devops_grafanadb_volume \
--network $NETWORK_NAME \
--replicas 1 \
--constraint 'node.role == manager' \
$GRAFANADB_IMAGE


echo ---$(currentTime)---create Grafana service---
sudo docker service create -d \
--name devops-grafana \
--publish $GRAFANA_PORT:3000 \
--mount type=volume,source=devops_grafana_volume_data,destination=/var/lib/grafana,\
volume-driver=local-persist,volume-opt=mountpoint=/var/nfs/volumes/devops_grafana_volume_data \
--mount type=volume,source=devops_grafana_volume_config,destination=/etc/grafana,\
volume-driver=local-persist,volume-opt=mountpoint=/var/nfs/volumes/devops_grafana_volume_config \
--network $NETWORK_NAME \
--replicas 1 \
--constraint 'node.role == manager' \
$GRAFANA_IMAGE


echo ---$(currentTime)---create cadvisor service---
sudo docker service create -d \
--publish $CADVISOR_PORT:8080 \
--name devops-cadvisor \
--hostname="{{.Node.ID}}" \
--mount type=bind,src=/,dst=/rootfs \
--mount type=bind,src=/var/run,dst=/var/run \
--mount type=bind,src=/sys,dst=/sys \
--mount type=bind,src=/var/lib/docker/,dst=/var/lib/docker \
--mount type=bind,src=/dev/disk/,dst=/dev/disk/ \
--network $NETWORK_NAME \
--mode global \
$CADVISOR_IMAGE \
-logtostderr \
-docker_only \
-storage_driver=influxdb \
-storage_driver_db=cadvisor \
-storage_driver_host=devops-grafanadb:8086


sudo docker service scale devops-grafanadb=1
sudo docker service scale devops-grafana=1
sudo docker service scale devops-cadvisor=1

