aws-cli-athena-wrapper-script
==============

Athena/Lambda [aws cli](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html) wrapper script

## Athena

### query
A script to input a query and receive the results from Athena.

![20241026-query](https://github.com/user-attachments/assets/92bf3694-7086-426d-9ccb-7c7d68cf8be6)


### file
A script to select a .sql file and retrieve the results from Athena.

![20241026-file](https://github.com/user-attachments/assets/0b86f2fa-1ea6-4361-a605-ba4f61edfba5)

### vimdiff
A script to display and compare two tables using vimdiff for easy difference checking.

![20241026-vimdiff](https://github.com/user-attachments/assets/c39d9054-9445-4b8c-9496-9aab271d1c66)

## Lambda

### list
A script to view a list of Lambda functions.

![20241026-list](https://github.com/user-attachments/assets/bee422de-aa8d-48bf-ad57-dc60f21b97fc)


### invoke
A script to execute a Lambda function and retrieve the return value. `--cli-binary-format raw-in-base64-out` and `--cli-read-timeout` are pre-configured for convenience.

![20241026-invoke](https://github.com/user-attachments/assets/394aad6f-1104-4062-a42a-b3c0a26ba84d)