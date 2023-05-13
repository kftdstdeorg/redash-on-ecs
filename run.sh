#!/usr/bin/env bash



#--------------------------------------------------------#
###-----Define necessary environment variables if passed -----##
##------------------------------------------------------#
if [ ! -z "$1" ]; then    
    echo "Loading variables from $1"
    source $1 #many key variables returned
    app_name=${STACK_NAME}
    confdir=logs/configs
    logdir=logs/outputs
    mkdir -p $confdir $logdir
    echo ""
else
    echo "you have to pass config file that contains all necessary parameters!"
    exit
fi

profile=${2:-kifiya}
region=${AWS_REGION}
if [ ! -z $profile ] && [ ! -z $region ]; then
    auth="--profile $profile --region $region"
    ecsauth="--aws-profile $profile --region $region"
else
    echo "config file need to have profile and region parameters!"
    exit
fi
echo "using the following aws credential: $auth"


#--------------------------------------------------------#
###-----function to create or update stack
##------------------------------------------------------#


function create-or-update-stack() {
    usage="Usage: $(basename "$0") region stack-name [aws-cli-opts]

          where:
          stack-name   - the stack name
          aws-cli-opts - extra options passed directly to create-stack/update-stack
          "

    if [ "$1" == "-h" ] || [ "$1" == "--help" ] || [ "$1" == "help" ] || [ "$1" == "usage" ] ; then
        echo "$usage"
        exit -1
    fi

    if [ -z "$1" ]; then
        echo "$usage"
        exit -1
    fi


    shopt -s failglob
    set -eu -o pipefail

    echo "Checking if stack exists for stack_name=$1 ... "
    
    
    if ! aws cloudformation describe-stacks --stack-name $1 $auth ; then
        
        echo -e "\nStack=$1 does not exist, creating ..."
        echo "passed stack params are: params=${@:2}"
        aws cloudformation create-stack \
            $auth \
            --stack-name $1 \
            ${@:2}
        
        echo "Waiting for stack to be created ..."
        aws cloudformation wait stack-create-complete \
            --stack-name $1 \
            $auth 
            
    else
        
        echo -e "\nStack exists, attempting update ..."
        echo ${@:2}
        
        set +e
        update_output=$( aws cloudformation update-stack \
                             $auth \
                             --stack-name $1 \
                             ${@:2}  2>&1)
        status=$?
        set -e

        echo "$update_output"

        if [ $status -ne 0 ] ; then

            # Don't fail for no-op update
            if [[ $update_output == *"ValidationError"* && $update_output == *"No updates"* ]] ; then
                echo -e "\nFinished create/update - no updates to be performed"
                exit 0
            else
                exit $status
            fi

        fi

        echo "Waiting for stack update to complete ..."
        aws cloudformation wait stack-update-complete \
            $auth \
            --stack-name $1 

    fi

    echo "Finished create/update successfully!"
}
  
#--------------------------------------------------------#
###-------- main logic -----##
##------------------------------------------------------#

# create log group
fname="${logdir}/${AWS_LOG_GROUP}_log_group.json"
if [ ! -f $fname ]; then
    echo "cerating new cloudwatch log group: ${AWS_LOG_GROUP} .."
    aws logs create-log-group --log-group-name ${AWS_LOG_GROUP} $auth | tee $fname
else
    echo "using create-log-group existing output: "
    cat $fname
fi

#--------------------------------------------------------#
###-------- main logic -----##
##------------------------------------------------------#

echo "copying input param as ${confdir}/.env ..."
cp $1 ${confdir}/.env

echo "creating ecs task definition ..."
# create ecs task definition
ecs_cli_params_template=ecs-params-redash-app.yml
ecs_cli_params_file=${confdir}/${ecs_cli_params_template}
sed 's|YOUR_STACK_NAME|'"${STACK_NAME}"'|g' ${ecs_cli_params_template} > ${ecs_cli_params_file}
echo ""
echo "using the following ecs-params.yml file: "
echo "---------------------"
cat ${ecs_cli_params_file}
echo "---------------------"
echo ""

#
ecs_cli_compose_template=docker-compose-redash-app.yml
ecs_cli_compose_file=${confdir}/${ecs_cli_compose_template}
cp ${ecs_cli_compose_template} ${ecs_cli_compose_file}


ecs_task_name="${app_name}-ecs-task"

fname=${logdir}/ecs_cli_task_${app_name}.json
if [ ! -f $fname ]; then
    echo "creating ecs task ${ecs_task_name} using ecs-cli with $ecsauth ..."
    ecs-cli compose --project-name ${ecs_task_name} \
            --ecs-params ${ecs_cli_params_file} \
            -f ${ecs_cli_compose_file} create $ecsauth | tee $fname
    echo "ecs-cli done!"
else
    echo "ecs-cli existing output ${ecs_task_name}: "
    cat $fname
fi

#--------------------------------------------------------#
###-------- main logic -----##
##------------------------------------------------------#

#copy templates to s3
echo "sync cloudformation template to s3 bucket .."
aws s3 sync cfn-templates/ s3://kft-data-vpc-cfn-templates/  $auth


clf_template="cfn-templates/master.yaml"

stack_name=${STACK_NAME:-"data-vpc"}
fname=${logdir}/aws_clf_deploy_${stack_name}.json

echo "deploying cloudformation template ${clf_template} with stack_name=${stack_name} .."
# echo "--------the following is the expected change set-------"
# aws cloudformation deploy --template-file ${clf_template} \
#     --no-execute-changeset \
#     --stack-name ${stack_name} $auth 
# echo "--------------------------------------"
# echo ""

# echo "Deploy the expected changeset? Yes|no"
# read yesno
# yesno=$(echo "$yesno" | tr '[:upper:]' '[:lower:]')

yesno="yes"
echo "answer: $yesno"
if [ "$yesno" == "yes" ]; then
    echo "deploying cloudformation changeset .."

    #clfopts=""

    create-or-update-stack ${stack_name} \
                           --template-body file://${clf_template} \
                           --capabilities CAPABILITY_NAMED_IAM \
                           --disable-rollback | tee $fname \

    
    # aws cloudformation update-stack \
    #     --template-body file://${clf_template} \
    #     --stack-name ${stack_name} \
    #     --capabilities CAPABILITY_NAMED_IAM \
    #     --disable-rollback $auth | tee $fname
    
    echo "done"
fi



# YdIUpfc8BxFowLU
# Mx3jdZXUJU4MNs2
# MqLrK1WXSXwvWHQ
# 3y1tBkUQuoEWmMW
# MD2wNJtPPlsnHUe
# SPAhlm85WYrHNt5
# 1HVmgPM3r60eRg8
# E78YrABlrI6Uwym
# e22n3KoNXn2xb7j
# JDSumgnGQpqJm3x


#admin:JDSumgnGQpqJm3x
