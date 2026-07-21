# InterBase MCP Server

A Delphi demo of an MCP server which interacts with InterBase.

Part of the Delphi and C++Builder Demos for Embarcadero RAD Studio This software is Copyright 2026 Embarcadero Technologies, Inc. 

You may only use this software if you are an authorized licensee of an Embarcadero developer tools product. This software is considered a Redistributable as defined in the software license agreement that comes with the Embarcadero Products and is governed by the terms of such software license agreement (https://www.embarcadero.com/products/rad-studio/rad-studio-eula).

## Project Goals

The InterBase Model Context Protocol (MCP) Server provides a powerful, AI-ready bridge to your InterBase databases. It exposes a comprehensive suite of tools that allow AI agents to safely interact with, introspect, monitor, and manage your database instances.

## Features

This server provides the following categories of tools:

### 🔍 Schema Introspection

Deeply analyze your database structure.

* **`get_database_info`**: Retrieve high-level database metrics and configuration.
* **`get_tables`, `get_views`**: List available tables and views.
* **`get_columns`, `get_indexes`, `get_foreign_keys`, `get_check_constraints`**: Inspect table structures and constraints.
* **`get_stored_procedures`, `get_triggers`, `get_functions`**: Retrieve the source code and metadata of business logic objects.
* **`get_generators`, `get_exceptions`, `get_domains`**: Inspect other database objects.

### ⚡ Query Execution

Run queries and analyze performance.

* **`execute_sql`**: Execute `SELECT` queries (or write operations, if explicitly permitted).
* **`execute_procedure`**: Safely execute stored procedures.
* **`explain_plan`**: Retrieve the InterBase execution plan to optimize query performance.

### 📈 Performance & Monitoring

Monitor real-time database activity.

* **`stat_attachments`, `stat_database`, `stat_transactions`**: Monitor connections and transaction states.
* **`stat_statements`, `stat_procedures`, `stat_triggers`**: Monitor executing statements and cached logic.
* **`stat_pools`, `stat_pool_blocks`, `stat_heaps`, `stat_indices`, `stat_relations`**: Monitor memory usage and cache statistics.

### 🛡️ Security & Auditing

Manage privileges and review audit logs.

* **`validate_sql`**: Verify if a SQL statement is safe to run according to server policies.
* **`get_user_privileges`, `list_roles`, `get_role_members`**: Inspect database security rules and access control.
* **`get_audit_log`**: Read the server's internal audit log of executed tools and events.

### 🧰 Database Management

Execute DBA-level tasks asynchronously.

* **`backup_database`, `restore_database`**: Automate database backups and restores.
* **`validate_database`, `sweep_database`**: Perform database maintenance tasks.

---

## Installation

This project has been tested with **Delphi 13.0 and newer versions** and has a strict dependency on the **DEXT framework**.

1. **Install DEXT**: You must install the DEXT framework first. It is highly recommended to do this using [TMS Smart Setup](https://github.com/tmssoftware/smartsetup/).
2. **Get the Source**: Clone this repository or download the source code files.
3. **Build**: Open the project in RAD Studio / Delphi and build the executable.

---

## Configuration

Before running the server, you must configure the connection and security settings in the `mcp_interbase.ini` file located in the same directory as the executable.

Below is an overview of the required and optional parameters:

### `[MCPServer]`

* **`MCPHost`** (Default: `localhost`): The hostname or IP address the MCP server binds to.
* **`MCPPort`** (Default: `5000`): The port the MCP server will listen on.
* **`UseHttps`** (Default: `0`): Set to `1` to enable HTTPS on the MCP endpoint.
* **`SslProvider`** (Default: `OpenSSL`): The SSL/TLS provider to use (e.g. `OpenSSL`).
* **`SslCert`** (Default: `server.crt`): Path to the SSL certificate file.
* **`SslKey`** (Default: `server.key`): Path to the SSL private key file.
* **`SslRootCert`** (Default: empty): Path to the root/CA certificate file (optional).

### `[Database]`

* **`Host`** (Default: `localhost`): The hostname or IP address of the InterBase server.
* **`Port`** (Default: `3050`): The connection port.
* **`Database`**: The file path or alias of the InterBase database.
* **`UserName`**: The username for authentication.
* **`Password`**: The password for authentication.
* **`CharacterSet`** (Default: `UTF8`): The character set for the connection.

### `[Security]`

**`ForbiddenDML`** (Default: `INSERT,UPDATE,DELETE,TRUNCATE`): Comma-separated list of blocked DML statements.

**`ForbiddenDDL`** (Default: `CREATE,ALTER,DROP,GRANT,REVOKE,SET`): Comma-separated list of blocked DDL statements.

**`VIEWSecret`**: Shared secret required to call read-only (VIEW-level) tools.

**`CRUDSecret`**: Shared secret required to call write (CRUD-level) tools. 

**`DBASecret`**: Shared secret required to call DBA-level tools (metadata changes, backup, restore, validate, sweep).

⚠️ Empty Secret means no access control.

### `[Logging]`

* **`AuditPath`** (Default: `logs/audit.jsonl`): The path where the server writes tool execution audit logs.
