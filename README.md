# InterBase MCP Server

A Delphi demo of an MCP server which interacts with InterBase.

Part of the Delphi and C++Builder Demos for Embarcadero RAD Studio This software is Copyright 2026 Embarcadero Technologies, Inc. 

You may only use this software if you are an authorized licensee of an Embarcadero developer tools product. This software is considered a Redistributable as defined in the software license agreement that comes with the Embarcadero Products and is governed by the terms of such software license agreement (https://www.embarcadero.com/products/rad-studio/rad-studio-eula).

## Project Goals

The InterBase Model Context Protocol (MCP) Server provides a powerful, AI-ready bridge to your InterBase databases. It exposes a comprehensive suite of tools that allow AI agents to safely interact with, introspect, monitor, and manage your database instances.

## Features

This server exposes **30 MCP tools** across five categories:

### 🔍 Schema Introspection

Deeply analyze your database structure.

| Tool                    | Description                                                                         |
| ----------------------- | ----------------------------------------------------------------------------------- |
| `get_database_info`     | Retrieve high-level database metrics and configuration.                             |
| `get_tables`            | List all user tables in the database.                                               |
| `get_views`             | List all views with their source SQL.                                               |
| `get_columns`           | Inspect the columns for a given table.                                              |
| `get_indexes`           | Inspect the indexes defined on a given table.                                       |
| `get_foreign_keys`      | Inspect foreign key constraints for a given table.                                  |
| `get_check_constraints` | List all check constraints in the database.                                         |
| `get_stored_procedures` | Retrieve stored procedure source code and metadata (supports optional name filter). |
| `get_triggers`          | Retrieve trigger source code and metadata (supports optional table filter).         |
| `get_functions`         | Inspect user-defined functions (UDFs).                                              |
| `get_generators`        | Inspect generators and sequences.                                                   |
| `get_exceptions`        | Inspect named exceptions.                                                           |
| `get_domains`           | Inspect custom domain definitions.                                                  |

### ⚡ Query Execution

Run queries and analyze performance.

| Tool                | Description                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `open_cursor`       | Execute a **read-only `SELECT`** query and return the resulting dataset.                                                                   |
| `execute_sql`       | Execute a **non-query SQL statement** (`INSERT`, `UPDATE`, `DELETE`, or DDL). Requires CRUD or DBA access depending on the statement type. |
| `execute_procedure` | Execute an InterBase stored procedure by name with optional input parameters.                                                              |
| `explain_plan`      | Retrieve the InterBase execution plan for a query to analyse performance and index usage.                                                  |

### 📈 Performance & Monitoring

Monitor real-time database activity via InterBase monitoring views.

| Tool                | Description                                                       |
| ------------------- | ----------------------------------------------------------------- |
| `stat_attachments`  | One row per active connection to the database.                    |
| `stat_database`     | One row per database you are attached to.                         |
| `stat_transactions` | One row per active or in-limbo transaction.                       |
| `stat_statements`   | One row per statement currently executing across all connections. |
| `stat_procedures`   | One row per stored procedure loaded into the database cache.      |
| `stat_triggers`     | One row per trigger loaded into the database cache.               |
| `stat_pools`        | One row per active memory pool.                                   |
| `stat_pool_blocks`  | One row per block of memory within each pool.                     |
| `stat_heaps`        | One row per entry in the InterBase random and block heap.         |
| `stat_indices`      | One row per index loaded into the database cache.                 |
| `stat_relations`    | One row per relation (table) loaded into the database cache.      |

### 🛡️ Security & Auditing

Manage privileges and review audit logs.

| Tool                  | Description                                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `get_user_privileges` | List all privileges granted to a specific user.                                                                    |
| `list_roles`          | List all user-defined roles in the database.                                                                       |
| `get_role_members`    | List members of a role (supports optional role name filter).                                                       |
| `get_audit_log`       | Read today's tool-execution audit log with support for filtering by `tool_name`, `outcome`, `offset`, and `limit`. |

### 🧰 Database Management

Execute DBA-level maintenance tasks. All tools in this category require **DBA** access.

| Tool                | Description                                                                             |
| ------------------- | --------------------------------------------------------------------------------------- |
| `backup_database`   | Run an InterBase backup to a specified file path.                                       |
| `restore_database`  | Restore a database from a backup file to a target path (supports optional `page_size`). |
| `validate_database` | Validate database integrity; pass `repair=true` to attempt corruption repair.           |
| `sweep_database`    | Run an InterBase sweep to reclaim storage from old record versions.                     |

---

Installation Options
--------------------

Whether you want to get up and running instantly or customize the server code in Delphi, you have two flexible path options:



### Option A: Pre-built Releases (Quickest)

If you want to deploy without compiling, download the v1.0 release assets directly from the GitHub Releases page.

* Requirements: InterBase must be installed on the system (at a minimum, the InterBase Client DLLs / libraries are required to establish database connections).

* Available Packages:

* 🪟 Windows (x64): mcp_interbase-win64-v1.0.zip

* 🐧 Linux (x86_64): mcp_interbase-linux-x86-64-v1.0.zip

* ⚙️ Configuration Template: mcp_interbase.template.ini
1. Download and extract the zip archive for your platform.

2. Rename mcp_interbase.template.ini to mcp_interbase.ini in the binary directory.

3. Edit the INI file to set your database path, credentials, and port.

### Option B: Build locally with Delphi (Recommended for Developers)

Building locally allows you to extend tools, customize server logic, or contribute back to the project.

1. Install Prerequisites: Install Delphi 13.0 (or newer) and install the [Dext framework]([GitHub - cesarliws/dext: Dext - Modern Full Stack Framework for Delphi · GitHub](https://github.com/cesarliws/dext)) (recommended via [TMS Smart Setup](https://github.com/tmssoftware/smartsetup/)).

2. Clone the Repository:  
   git clone https://github.com/Embarcadero/InterbaseMCP.git

3. Build: Open the project in RAD Studio / Delphi and compile the executable.
   
   

**Important:** The InterBase MCP is designed for InterBase Server, though it also works seamlessly with InterBase Developer for local testing. If you don't have InterBase running yet, you can request a trial license for the Server edition at [embarcadero.com/products/interbase](https://www.embarcadero.com/products/interbase).

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

⚠️ Security levels are hierarchical. For example, a user with **DBA** privileges automatically inherits **CRUD** and **VIEW** permissions. If the **Secrets** field is left empty, no access control is enforced.

### `[Logging]`

* **`AuditPath`** (Default: `logs/audit.jsonl`): The path where the server writes tool execution audit logs.
  
  

* * *

## Issues and Roadmap

If you encounter any issues or have a feature request, please report them using **GitHub Issues**. You can also check out what’s planned for the **v1.1 release** by filtering by the `v1.1` milestone.
