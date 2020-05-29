require "awesome_print"
require "aws-sdk-ecs"
require "shellwords"

DESIRED_COUNT = 1
TASK_DEFINITION = ARGV[0]
CLUSTER = ARGV[1]
COMMAND = ARGV[2]
CONTAINER_NAME = ARGV[3]
REGION = ARGV[4]
SUBNET = ARGV[5]
SECURITY_GROUP = ARGV[6]

command = COMMAND.shellsplit

ECS = Aws::ECS::Client.new()

run_task = ECS.run_task({
  cluster: CLUSTER,
  task_definition: TASK_DEFINITION,
  count: 1,
  launch_type: "FARGATE",
  network_configuration: {
    awsvpc_configuration: {
      subnets: [SUBNET],
      security_groups: [SECURITY_GROUP]
    }
  },
  overrides: {
    container_overrides: [
      name: CONTAINER_NAME,
      command: command
    ]
  }
})

task_arn = run_task.tasks[0].task_arn

ECS.wait_until(:tasks_stopped, { cluster: CLUSTER, tasks:[ task_arn ]}, { max_attempts: 10, delay: 10 }) do |w|
  logger.info("Waiting for task to stop #{task_arn}")
end
logger.info("Waiting for task to stop #{task_arn}")

task = ECS.describe_task({
  cluster: CLUSTER,
  tasks: [ task_arn ]
})

task_exit_code = task.tasks[0].containers[0].exit_code

exit(task_exit_code || 255)