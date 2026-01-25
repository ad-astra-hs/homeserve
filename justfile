default:
    just run

test:
    gleam test

lint:
    gleam check
    gleam format --check

check: lint test

run:
    bacon
