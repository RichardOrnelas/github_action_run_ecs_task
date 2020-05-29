#!/bin/sh -l

DESIRED_COUNT=1
TASK_DEFINITION=$1
CLUSTER=$2
COMMAND=$3
CONTAINER_NAME=$4
REGION=$5

OVERRIDES='{"containerOverrides": [{"name": "'"$CONTAINER_NAME"'", "command": '"$COMMAND"'}]}'
run_result=$(aws ecs run-task --region $REGION --cluster $CLUSTER --task-definition $TASK_DEFINITION --count $DESIRED_COUNT --overrides "$OVERRIDES")

DO_RETRY=1
RETRIES=0

COMMAND_ARRAY=
IFS=' ' # space is set as delimiter
read -ra ADDR <<< "$str" # str is read into an array as tokens separated by IFS
for i in "${ADDR[@]}"; do # access each element of array
    echo "$i"
done

set +e
while [ "$RETRIES" -lt $MAX_RETRIES ] && [ $DO_RETRY -eq 1 ]; do
  DO_RETRY=0
  REASON_FAILURE=''
  RUN_TASK=$(run_task)
  RUN_TASK_EXIT_CODE=$?

  _echo $RUN_TASK

  FAILURES=$(echo $RUN_TASK | jq '.failures|length')
  if [ $FAILURES -eq 0 ]; then
    TASK_ARN=$(echo $RUN_TASK | jq '.tasks[0].taskArn' | sed -e 's/^"//' -e 's/"$//')
    WAITER_RETRY=1
    WAITER_RETRIES=0
    while [ $WAITER_RETRIES -lt $MAX_WAITER_RETRIES ] && [ $WAITER_RETRY -eq 1 ]; do
        WAITER_RETRY=0
        $AWS_ECS wait tasks-stopped --tasks "$TASK_ARN" --cluster $CLUSTER 2>/dev/null
        WAITER_EXIT_CODE=$?

        if [ $WAITER_EXIT_CODE -eq 0 ]; then
            DESCRIBE_TASKS=$($AWS_ECS describe-tasks --tasks "$TASK_ARN" --cluster $CLUSTER)
            EXIT_CODE=$(echo $DESCRIBE_TASKS | jq '.tasks[0].containers[0].exitCode')
            if [ $EXIT_CODE -eq 0 ]; then
              _echo "ECS task exited successfully"
              _echo $(logs_link $CONTAINER_NAME $TASK_ARN)
              exit 0
            else
              _echo "ECS task failed: $DESCRIBE_TASKS"
             _echo $(logs_link $CONTAINER_NAME $TASK_ARN)
              exit $EXIT_CODE
            fi

        elif [ $WAITER_EXIT_CODE -eq 255 ]; then
            ((WAITER_RETRIES++))
            WAITER_RETRY=1
            if [ $WAITER_RETRIES -eq $MAX_WAITER_RETRIES ]; then
                _echo "ECS Waiter max retries reached, $WAITER_RETRIES, exit"
                exit 255
            fi
            _echo "ECS Waiter because timeout,  waiter retry $WAITER_RETRIES (don't launch the task other time)"
        else
            _echo "ECS Waiter failed, status: $WAITER_EXIT_CODE"
            _echo $(logs_link $CONTAINER_NAME $TASK_ARN)
            exit $WAITER_EXIT_CODE
        fi
    done
  else
    REASON_FAILURE=$(echo $RUN_TASK | jq -r '.failures[0].reason')
    if [ -n "$REASON_FAILURE" ] && [[ "${RETRIES_ACCEPTED_FAILURES[@]}" =~ $REASON_FAILURE ]]; then
        DO_RETRY=1
        ((RETRIES++))
        if [ -n "$REASON_FAILURE" ] && [ $RETRIES -eq $MAX_RETRIES ]; then
            _echo "Max RETRIES reached REASON: $REASON_FAILURE  RETRIES: $RETRIES"
            _echo $(logs_link $CONTAINER_NAME $TASK_ARN)
            exit 253
        fi
        _echo "Retrying in ${RETRY_SLEEP_TIME}s, try number: $RETRIES because: $REASON_FAILURE"
        sleep $RETRY_SLEEP_TIME
    else
        _echo "ECS task failed: $REASON_FAILURE"
        _echo $(logs_link $CONTAINER_NAME $TASK_ARN)
        exit 1
    fi
  fi
done