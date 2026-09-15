# Agents

This repository is designed to be operated by a coding agent. The full brief — lab state machine,
teaching contract, verification tooling, known data traps — lives in [`CLAUDE.md`](CLAUDE.md).

Read that file first, whatever agent you are. The only machine interface you need is:

```bash
./setup/lab.sh status --json     # state of the lab
./setup/lab.sh up && ./setup/lab.sh load   # bring it up and fill it
./setup/lab.sh spl '<search>'    # run SPL and read the result
./setup/lab.sh verify            # 10 assertions on data integrity
```
