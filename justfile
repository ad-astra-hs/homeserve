default:
    just run

test:
    gleam test

lint:
    gleam check
    gleam format --check

check: lint test

# Run with persistent Mnesia storage (uses disc_copies)
run: check
    gleam run -m setup verify
    ERL_FLAGS="-sname homeserve" gleam run

# Run with in-memory Mnesia storage (data lost on restart, useful for testing)
run-dev: check
    gleam run -m setup verify
    gleam run

# Create a production release
dist:
    gleam export erlang-shipment

# Run database verification
verify:
    ERL_FLAGS="-sname homeserve" gleam run -m setup verify
