# hello_world

This project is based on the hello world example from sam-cli.

## Build and deploy the sample application to ap-northeast-1

```bash
sam build
sam deploy
```

## Start local server

```bash
sam build
sam local start-api
curl http://localhost:3000/
curl http://localhost:3000/hello
```

## Unit tests

```bash
hello_world$ bundle exec ruby tests/unit/test_handler.rb
```
