# Migrating from MySQL to PostgreSQL 

On Azure without downtime requires a carefully planned approach using logical replication and synchronized cutover strategies:

## Azure Database Migration Service (DMS) Approach

**Azure DMS** is the recommended tool for this migration as it supports online (minimal downtime) migrations:

1. **Setup Azure DMS**
- Create an Azure Database Migration Service instance
- Configure network connectivity between source MySQL and target PostgreSQL
- Ensure proper firewall rules and VNet peering if needed
1. **Configure Continuous Sync**
- Enable binary logging on MySQL source
- Create migration project in DMS with “Online migration” selected
- DMS will perform initial data load and then continuously sync changes

## Alternative Logical Replication Strategy

If Azure DMS doesn’t meet your needs, use a custom logical replication approach:

**Phase 1: Initial Setup**

```sql
-- On MySQL source
SET GLOBAL binlog_format = 'ROW';
SET GLOBAL binlog_row_image = 'FULL';

-- Create replication user
CREATE USER 'repl_user'@'%' IDENTIFIED BY 'secure_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
```

**Phase 2: Schema Migration**

- Use tools like `pgloader` or custom scripts to convert schema
- Handle data type differences (MySQL → PostgreSQL)
- Migrate indexes, constraints, and triggers separately

**Phase 3: Data Synchronization Tools**

- **AWS DMS** (works with Azure): Can replicate from MySQL to PostgreSQL
- **Debezium + Kafka**: Stream changes from MySQL binlog to PostgreSQL
- **Custom ETL pipeline**: Using tools like Apache Airflow

## Step-by-Step Migration Process

### 1. Pre-Migration Preparation

```bash
# Schema assessment and conversion
mysqldump --no-data --routines --triggers source_db > schema.sql
# Convert MySQL schema to PostgreSQL format
```

### 2. Setup Target PostgreSQL

- Create Azure Database for PostgreSQL
- Configure performance tier matching source workload
- Setup monitoring and backup policies

### 3. Initial Data Load

```bash
# Using pgloader for initial migration
pgloader mysql://user:pass@mysql-host/db postgresql://user:pass@pg-host/db
```

### 4. Continuous Replication Setup

Use Debezium for change data capture:

```yaml
# Debezium connector configuration
{
  "name": "mysql-postgres-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "database.hostname": "mysql-host",
    "database.port": "3306",
    "database.user": "repl_user",
    "database.password": "password",
    "database.server.id": "12345",
    "database.server.name": "mysql-server",
    "database.include.list": "your_database",
    "transforms": "route",
    "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.route.regex": "([^.]+)\\.([^.]+)\\.([^.]+)",
    "transforms.route.replacement": "$3"
  }
}
```

## Application Migration Strategy

### 1. Dual-Write Pattern

- Modify application to write to both MySQL and PostgreSQL
- Read from MySQL initially
- Validate data consistency between databases

### 2. Feature Flags

```python
# Application code example
if feature_flag_enabled('use_postgresql'):
    result = postgresql_query(sql)
else:
    result = mysql_query(sql)
```

### 3. Database Abstraction Layer

- Use ORM or database abstraction layer
- Switch database connections via configuration
- Handle SQL dialect differences

## Testing and Validation

### 1. Data Validation

```sql
-- Compare row counts
SELECT COUNT(*) FROM mysql_table;
SELECT COUNT(*) FROM postgresql_table;

-- Checksum validation
SELECT MD5(CONCAT_WS('|', col1, col2, col3)) FROM mysql_table ORDER BY id;
SELECT MD5(string_agg(col1||'|'||col2||'|'||col3, '' ORDER BY id)) FROM postgresql_table;
```

### 2. Performance Testing

- Run load tests against PostgreSQL
- Compare query performance
- Validate connection pooling and caching

## Cutover Process

### 1. Synchronized Cutover

```bash
# 1. Stop application writes
# 2. Wait for replication lag to reach zero
# 3. Perform final data validation
# 4. Switch application configuration
# 5. Start application with PostgreSQL
```

### 2. Rollback Plan

- Keep MySQL running for 24-48 hours
- Monitor application metrics
- Have immediate rollback procedure ready

## Azure-Specific Considerations

### 1. Network Configuration

- Use Azure Private Link for secure connectivity
- Configure VNet integration for DMS
- Setup NSG rules for database access

### 2. Monitoring and Alerting

```bash
# Azure CLI monitoring setup
az monitor metrics alert create \
  --name "PostgreSQL-CPU-Alert" \
  --resource-group myResourceGroup \
  --scopes "/subscriptions/.../resourceGroups/.../providers/Microsoft.DBforPostgreSQL/servers/myserver" \
  --condition "avg Percentage CPU > 80"
```

### 3. Backup Strategy

- Configure automated backups for PostgreSQL
- Test point-in-time recovery
- Document backup retention policies

## Common Challenges and Solutions

### 1. Data Type Mapping

```sql
-- MySQL to PostgreSQL mappings
TINYINT(1) → BOOLEAN
DATETIME → TIMESTAMP
ENUM → VARCHAR with CHECK constraint
AUTO_INCREMENT → SERIAL or IDENTITY
```

### 2. SQL Dialect Differences

- Replace MySQL-specific functions
- Handle LIMIT/OFFSET differences
- Update stored procedures and triggers

### 3. Character Set Issues

- Ensure UTF-8 encoding consistency
- Handle collation differences
- Test special characters thoroughly

This approach minimizes downtime to minutes during the final cutover while ensuring data consistency and providing rollback capabilities. The key is thorough testing and having multiple validation checkpoints throughout the process.​​​​​​​​​​​​​​​​