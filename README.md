# Nosint

A command-line OSINT tool for gathering information from nosint.org.

## Installation

### From CPAN (recommended)

```bash
cpanm Nosint
```

### From source

```bash
git clone https://github.com/yourusername/nosint.git
cd nosint
perl Makefile.pl
make
make test
make install
```

## Usage

```bash
# Set your nosint.org authentication cookie
export NOSINT_COOKIE='next-auth.csrf-token=value; next-auth.callback-url=value; next-auth.session-token=value'

# Run a search
nosint --target user@example.com --plugin-type email

# Get help
nosint --help
```

## Required Arguments

- `--target, -t EMAIL`: Target email address to search
- `--plugin-type, -p TYPE`: Plugin type (e.g., 'email')

## Options

- `--aggressive, -a`: Enable aggressive search, alerts user (default: off)
- `--cookie, -c COOKIE`: Authentication cookie for nosint.org
- `--json, -j`: Output in JSONL format
- `--help, -h`: Show this help message
- `--show-not-found`: Show not found results (default: off)
- `--verbose, -v`: Show verbose output

## Environment Variables

- `NOSINT_COOKIE`: Authentication cookie (if not provided with --cookie)

## License

This project is licensed under the Artistic License 2.0. 