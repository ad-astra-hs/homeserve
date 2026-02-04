default:
    just run

test:
    gleam test

lint:
    gleam check
    gleam format --check

check: lint test

run: check
    gleam run -m setup verify
    gleam run
