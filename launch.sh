#!/bin/bash

# usage : ./launch.sh ami-d05e75b8 3 t2.micro itmo544-mp1-key sg-1b360c7c subnet-25000852 phpDeveloper
# 1 -> image id
# 2 -> count
# 3 -> instance-type
# 4 -> key name 
# 5 -> security group ids
# 6 -> subnet ids
# 7 -> role name

./cleanup.sh


declare -a  instance_array 

mapfile -t instance_array < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://../application-setup/install-ws-mp1.sh --output table |grep InstanceId|sed "s/|//g" | tr -d ' '|sed "s/InstanceId//g")

echo ${instance_array[@]}
aws ec2 wait instance-running --instance-ids ${instance_array[@]}
echo "Instances are running"

ELBURL=(`aws elb create-load-balancer --load-balancer-name itmo544-lu-mp1-elb --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --security-groups $5 --subnets $6 --output=text`);
#echo $ELBURL
echo -e "\nFinished launching ELB and sleeping 25 seconds"

for i in {0..25};do echo -ne '.';sleep 1;done
echo "\n"

aws elb register-instances-with-load-balancer --load-balancer-name itmo544-lu-mp1-elb --instances ${instance_array[@]}

aws elb configure-health-check --load-balancer-name itmo544-lu-mp1-elb --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

echo -e "\nWaiting additional 3 minutes (180 seconds) before opening the ELB in a web browser"
for i in {0..180};do echo -ne '.';sleep 1;done

#cloud watch
aws cloudwatch put-metric-alarm --alarm-name cpugreaterthan30 --alarm-description "Alarm when CPU exceeds 30 percent" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold  --dimensions Name=itmo-544-extended-auto-scaling-group-2,Value=itmo-544-extended-auto-scaling-group-2 --evaluation-periods 2 --alarm-actions arn:aws:sns:us-east-1:111122223333:MyTopic --unit Percent

aws cloudwatch put-metric-alarm --alarm-name cpulessthan10 --alarm-description "Alarm when CPU is less than 10 percent" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 10 --comparison-operator LessThanOrEqualToThreshold --dimensions Name=itmo-544-extended-auto-scaling-group-2,Value=itmo-544-extended-auto-scaling-group-2 --evaluation-periods 2 --alarm-actions arn:aws:sns:us-east-1:111122223333:MyTopic --unit Percent

#autoscaling
aws autoscaling create-launch-configuration --launch-configuration-name itmo-launch-configuration-1 --image-id $1 --key-name $4 --security-groups $5 --instance-type $3 --user-data file://../application-setup/install-webserver.sh --iam-instance-profile $7

aws autoscaling create-auto-scaling-group --auto-scaling-group-name itmo-544-extended-auto-scaling-group-2 --launch-configuration-name itmo-launch-configuration-1 --load-balancer-names itmo544-lu-mp1-elb --health-check-type ELB --min-size 1 --max-size 3 --desired-capacity 2 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $6

aws rds create-db-subnet-group --db-subnet-group-name itmo544-mp1-db-subnet-group --db-subnet-group-description "subnet group db" --subnet-ids subnet-939c95e4 subnet-25000852



aws rds create-db-instance --db-name customerrecords --db-instance-identifier luana-mp1-db --db-instance-class db.t1.micro --engine MySQL --master-username controller --master-user-password letmein888 --allocated-storage 5 --db-subnet-group-name ITMO544-mp1-subnet-group --publicly-accessible


aws rds wait db-instance-available --db-instance-identifier luana-mp1-db

aws rds create-db-instance-read-replica --db-instance-identifier luana-mp1-db-readreplica --source-db-instance-identifier luana-mp1-db --publicly-accessible



echo "done"
