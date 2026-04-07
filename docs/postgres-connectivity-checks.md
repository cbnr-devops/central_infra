# PostgreSQL Connectivity Checks

## nslookup vs telnet

**nslookup** — queries DNS to resolve a hostname to an IP address (or vice versa). It tells you *if* a name resolves and *to what*.

```bash
nslookup example.com
# → 93.184.216.34
```

**telnet** — opens a TCP connection to a host on a specific port. It tells you *if* you can reach a service and *if* the port is open.

```bash
telnet example.com 443
# → Connected / Connection refused / Timeout
```

**Key difference:** nslookup checks **name resolution** (DNS layer), telnet checks **network connectivity** (TCP layer).

| Tool | Purpose | Layer | Answers |
|---|---|---|---|
| nslookup | DNS resolution | DNS (application/UDP) | "What IP is this hostname?" |
| telnet | TCP connectivity | TCP transport | "Can I reach this host:port?" |

**Typical workflow:** Use nslookup first to confirm the hostname resolves, then telnet to confirm the port is reachable.

---

## How to Check if a PostgreSQL DB is Reachable

### 1. DNS resolution — confirm the hostname resolves

```bash
nslookup <db-hostname>
```

### 2. TCP connectivity — confirm the port is open (default 5432)

```bash
# using telnet
telnet <db-hostname> 5432

# or using nc (netcat), often more convenient
nc -zv <db-hostname> 5432
```

### 3. Actual PostgreSQL connection — confirms the DB process is responding

```bash
# using psql
psql -h <db-hostname> -U <username> -d <dbname> -c "SELECT 1;"

# or just check if it accepts connections without a query
pg_isready -h <db-hostname> -p 5432
```

### Quick Summary

| Tool | What it checks |
|---|---|
| `nslookup` | DNS resolves |
| `nc -zv` / `telnet` | TCP port is open |
| `pg_isready` | PostgreSQL is accepting connections |
| `psql -c "SELECT 1"` | Full auth + query works |

`pg_isready` is usually the best single command — it's purpose-built for this and returns clear exit codes (`0` = accepting, `1` = rejecting, `2` = no response).

---

## How to Install pg_isready

`pg_isready` comes bundled with the **PostgreSQL client tools**.

**macOS:**

```bash
brew install libpq
# or for the full client
brew install postgresql
```

**Ubuntu/Debian:**

```bash
sudo apt-get install postgresql-client
```

**RHEL/CentOS/Amazon Linux:**

```bash
sudo yum install postgresql
# or on newer versions
sudo dnf install postgresql
```

**Alpine (Docker):**

```bash
apk add postgresql-client
```

**Verify installation:**

```bash
pg_isready --version
```

> **Note:** If you installed `libpq` on macOS via Homebrew, you may need to add it to your PATH:
>
> ```bash
> echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
> source ~/.zshrc
> ```
