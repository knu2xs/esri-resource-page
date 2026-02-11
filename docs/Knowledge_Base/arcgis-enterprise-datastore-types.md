# ArcGIS Enterprise Data Store Types

## Overview

ArcGIS Data Store provides managed storage options for ArcGIS Enterprise, supporting different types of data and workloads. Each data store type serves specific purposes and has different capabilities depending on the ArcGIS Enterprise version. Understanding the differences and version compatibility is essential for proper deployment planning.

---

## Data Store Types

### 1. Relational Data Store

**Purpose**: Stores feature layers and related data published to the ArcGIS Server hosting server.

**What it stores**:

- Feature layers and feature services
- Scene layers (cached 3D)
- Hosted feature layer data
- Geocoding services output
- Analysis results from spatial analysis tools
- Job metadata and tracking information

**Version availability**: Available since **ArcGIS Enterprise 10.4**

**Key characteristics**:

- Based on PostgreSQL database technology
- Required for hosting feature layers
- Supports high-availability configuration (primary/standby)
- Automatic backup and recovery capabilities
- Scales vertically (single machine, can be clustered for HA)

---

### 2. Tile Cache Data Store

**Purpose**: Stores caches for dynamic map and feature services as well as scene layer caches.

**What it stores**:

- Vector tile layers
- Scene layer caches
- Dynamic map service caches
- Hosted tile layer caches

**Version availability**: Available since **ArcGIS Enterprise 10.5**

**Key characteristics**:

- Based on NoSQL document database (CouchDB-derived)
- Optimized for fast read access to cached tiles
- Supports high-availability with multiple machines
- Can scale horizontally (add more machines for capacity)
- Automatic replication across data store machines
- Particularly beneficial for 3D scene layers

---

### 3. Spatiotemporal Big Data Store

**Purpose**: Stores large volumes of observation data and enables real-time and archival big data analytics.

**What it stores**:

- Observation data from ArcGIS GeoEvent Server
- Real-time stream services output
- Big data analytics results from GeoAnalytics Server
- Historical observation archives
- Feature layers with temporal data

**Version availability**: Available since **ArcGIS Enterprise 10.5**

**Key characteristics**:

- Based on Elasticsearch technology
- Optimized for time-series and spatiotemporal queries
- Supports distributed indexing and querying
- Horizontal scaling by adding more machines
- Designed for high-velocity data ingestion
- Required for GeoAnalytics Server workflows
- Supports archive and purge policies for data management

---

### 4. Graph Store

**Purpose**: Stores knowledge graphs for network analysis and relationship modeling.

**What it stores**:

- Knowledge graph data and relationships
- Entity-relationship models
- Network connectivity information
- Graph-based spatial relationships

**Version availability**: Available since **ArcGIS Enterprise 10.7**

**Key characteristics**:

- Based on graph database technology
- Optimized for complex relationship queries
- Supports knowledge graph services
- Enables advanced network analysis
- Required for ArcGIS Knowledge Server (introduced in 10.9)
- Stores both spatial and non-spatial graph data

---

### 5. Object Store

**Purpose**: Provides cloud-native object storage for raster and imagery data.

**What it stores**:

- Raster datasets and imagery
- Multidimensional raster data
- Large raster outputs from raster analytics
- Distributed raster collections

**Version availability**: Available since **ArcGIS Enterprise 10.8**

**Key characteristics**:

- Cloud-native object storage (similar to Amazon S3)
- Optimized for raster and imagery workloads
- Alternative to file share-based raster stores
- Particularly useful for distributed/cloud deployments
- Supports efficient storage and retrieval of large rasters
- Required for certain raster analytics workflows in distributed environments

**Important change at ArcGIS Enterprise 11.5**:

- **Object Store becomes mandatory** for distributed raster analytics workflows with ArcGIS Image Server
- Enhanced integration with raster analytics tools and improved performance
- File share-based raster stores deprecated for new distributed deployments
- Existing file share raster stores continue to work but migration to object store is recommended
- Object store provides better scalability, reliability, and performance for production raster analytics
- Supports multi-machine object store deployment for high availability and load distribution

---

## Version Compatibility Matrix

| Data Store Type | 10.4 | 10.5 | 10.6 | 10.7 | 10.8 | 10.9 | 11.0 | 11.1+ |
|----------------|------|------|------|------|------|------|------|-------|
| **Relational** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Tile Cache** | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Spatiotemporal** | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Graph** | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Object** | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |

---

## Common Deployment Patterns

### Basic Hosting Deployment

- **Relational Data Store** only
- Sufficient for feature layer hosting and basic web GIS
- Smallest footprint for simple deployments

### 3D and Visualization Deployment

- **Relational Data Store** (feature data)
- **Tile Cache Data Store** (scene layers and vector tiles)
- Optimal for 3D web scenes and high-performance visualization

### Real-Time Analytics Deployment

- **Relational Data Store** (feature data)
- **Spatiotemporal Big Data Store** (observation data)
- Required for GeoEvent Server and GeoAnalytics Server

### Knowledge and Graph Analysis Deployment

- **Relational Data Store** (feature data)
- **Graph Store** (knowledge graphs)
- Enables ArcGIS Knowledge Server capabilities

### Raster Analytics Deployment

- **Relational Data Store** (metadata and tracking)
- **Object Store** (raster data storage)
- Optimal for image server raster analytics at scale

### Enterprise-Scale Deployment

- All data store types configured
- Supports full ArcGIS Enterprise functionality
- Maximum flexibility for diverse workloads

---

## Choosing the Right Data Store Types

### Questions to Consider:

1. **Do you need to host feature layers?**
    - Yes → **Relational Data Store** (required)

2. **Will you publish 3D scene layers or vector tiles?**
    - Yes → **Tile Cache Data Store** (recommended)

3. **Do you use GeoEvent Server or GeoAnalytics Server?**
    - Yes → **Spatiotemporal Big Data Store** (required)

4. **Do you need knowledge graphs or network analysis?**
    - Yes → **Graph Store** (required)

5. **Do you perform raster analytics with Image Server?**
    - Yes, at scale → **Object Store** (recommended)
    - Yes, basic → File share raster store (alternative)

6. **What is your ArcGIS Enterprise version?**
    - Check version compatibility matrix above

---

## Best Practices

1. **Start minimal**: Deploy only the data store types you need initially
2. **Plan for growth**: Additional data store types can be added later as requirements evolve
3. **High availability**: Configure HA for production environments, especially for relational data store
4. **Separate machines**: Host data stores on dedicated machines separate from ArcGIS Server
5. **Monitor storage**: Each data store type has different storage growth patterns
6. **Backup strategy**: Configure automated backups, especially for relational and graph stores
7. **Version compatibility**: Ensure data store versions match your ArcGIS Enterprise version

---

## How to Back Up Data Stores

Proper backup strategies are critical for disaster recovery and business continuity. Each data store type has specific backup methods and considerations.

### Relational Data Store Backup

**Built-in Backup Tools**:

The relational data store includes built-in backup capabilities managed through the ArcGIS Data Store configuration wizard or command-line utilities.

**Backup Methods**:

1. **Automatic Scheduled Backups** (Recommended for Production):
    - Configure automatic backups in the ArcGIS Data Store configuration wizard
    - Set backup location (local path or network share)
    - Define backup schedule (default: daily at 2:00 AM)
    - Retention policy: keeps last 7 days by default (configurable)
    - Backups are full backups, not incremental

2. **Manual On-Demand Backups**:
    - Use `backupdatastore` command-line utility
    - Example: `backupdatastore /Users/arcgis/backups --store relational`
    - Useful before major upgrades or configuration changes

**Backup Location Best Practices**:

- Store backups on separate physical storage from the data store
- Use network-attached storage (NAS) or cloud storage for off-site protection
- Ensure backup location has sufficient space (at least 2-3x the data store size)
- Test backup integrity regularly by performing test restores

**Restore Process**:

- Use `restoredatastore` command-line utility
- Example: `restoredatastore /Users/arcgis/backups/backup_name`
- Requires stopping the data store during restore
- Can restore to same machine or different machine

### Tile Cache Data Store Backup

**Built-in Backup Tools**:

The tile cache data store uses the same backup framework as the relational data store.

**Backup Methods**:

1. **Automatic Scheduled Backups**:
    - Configure through ArcGIS Data Store configuration wizard
    - Same interface and options as relational data store
    - Backups can be large due to cached tile data

2. **Manual Backups**:
    - Use `backupdatastore` command-line utility
    - Example: `backupdatastore /Users/arcgis/backups --store tileCache`

**Special Considerations**:

- Tile cache backups can be very large (hundreds of GB to TB)
- Consider backup storage capacity carefully
- In multi-machine deployments, only need to back up one machine (data is replicated)
- Alternative: Cache data can be regenerated if source data still exists (time vs. storage tradeoff)

### Spatiotemporal Big Data Store Backup

**Built-in Backup Tools**:

The spatiotemporal big data store supports backups through the same utilities.

**Backup Methods**:

1. **Automatic Scheduled Backups**:
    - Configure through ArcGIS Data Store configuration wizard
    - Backs up entire Elasticsearch index

2. **Manual Backups**:
    - Use `backupdatastore` command-line utility
    - Example: `backupdatastore /Users/arcgis/backups --store spatiotemporal`

**Special Considerations**:

- Backup size depends on observation data volume
- High-velocity data ingestion may require more frequent backups
- Consider data retention policies to manage backup sizes
- Archive and purge old observation data to reduce backup overhead
- In multi-machine deployments, back up from primary node

### Graph Store Backup

**Built-in Backup Tools**:

The graph store uses the same backup framework as other data store types.

**Backup Methods**:

1. **Automatic Scheduled Backups**:
    - Configure through ArcGIS Data Store configuration wizard
    - Backs up knowledge graph data and relationships

2. **Manual Backups**:
    - Use `backupdatastore` command-line utility
    - Example: `backupdatastore /Users/arcgis/backups --store graph`

**Special Considerations**:

- Graph data includes complex relationships that must be backed up together
- Backup integrity is critical for graph databases
- Always verify graph store backups with test restores

### Object Store Backup

**Built-in Backup Tools**:

The object store supports backups starting with specific versions.

**Backup Methods**:

1. **Automatic Scheduled Backups**:
    - Configure through ArcGIS Data Store configuration wizard
    - Backs up raster metadata and storage configuration

2. **Manual Backups**:
    - Use `backupdatastore` command-line utility
    - Example: `backupdatastore /Users/arcgis/backups --store object`

3. **Alternative: Cloud Provider Backups**:
    - If using cloud-native deployment, leverage cloud provider backup tools
    - Azure Blob Storage snapshots
    - AWS S3 versioning and replication
    - Often more efficient for large raster datasets

**Special Considerations**:

- Object store backups can be extremely large due to raster data
- Consider cloud-based backup solutions for efficiency
- Raster data may be regenerated from source if backup storage is limited
- Multi-machine deployments provide built-in redundancy

### Cross-Data Store Backup Strategies

**All Data Stores at Once**:

To back up all registered data stores simultaneously:

```bash
backupdatastore /Users/arcgis/backups --store all
```

**Backup Verification**:

- Regularly test restore procedures (quarterly minimum)
- Document restore procedures and timelines
- Verify backup file integrity
- Monitor backup job completion and logs

**Monitoring and Alerting**:

- Set up alerts for failed backup jobs
- Monitor backup storage capacity
- Track backup duration trends
- Review backup logs regularly at `/arcgis/datastore/logs/`

**Backup Retention Policies**:

- Daily backups: Keep 7-14 days
- Weekly backups: Keep 4-8 weeks
- Monthly backups: Keep 3-12 months
- Adjust based on recovery point objectives (RPO) and available storage

---

## Additional Resources

- [ArcGIS Data Store Documentation](https://enterprise.arcgis.com/en/data-store/)
- [ArcGIS Enterprise Architecture](https://enterprise.arcgis.com/en/get-started/latest/windows/base-arcgis-enterprise-deployment.htm)
- [Data Store Types Overview](https://enterprise.arcgis.com/en/data-store/latest/windows/what-is-arcgis-data-store.htm)

---

## Related KB Articles

- [Image Server and Relational Data Store Usage](image-server-relational-datastore-usage.md)
