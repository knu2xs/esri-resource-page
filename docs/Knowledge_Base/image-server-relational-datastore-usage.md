# Image Server and Relational Data Store Usage

## Overview

When ArcGIS Image Server is configured as a **raster analytics server** in an ArcGIS Enterprise deployment, it creates significant activity in the hosted **relational data store**. Understanding what data and tasks are created, the load implications, and which workflows affect performance is critical for administrators managing enterprise deployments.

This document explains the interaction between Image Server raster analytics capabilities and the relational data store, with guidance on capacity planning and performance optimization.

---

## What Data and Tasks Are Created in the Relational Data Store

### Raster Analysis Job Metadata and Tracking

When raster analysis tools execute through ArcGIS Image Server (functioning as the raster analytics server), several types of data are created in the **relational data store**:

#### 1. **Analysis Job Records**
- **Job submission records**: Metadata about each raster analysis job including:

    - Job ID and status (queued, running, completed, failed)
    - Submitting user and timestamp
    - Input parameters and tool configuration
    - Processing extent and cell size settings
    - Execution duration and completion status

- **Job history**: Historical records of all raster analysis jobs for auditing and troubleshooting

#### 2. **Intermediate Processing Data**
While the primary raster data output is stored in the **raster store** (a registered folder or cloud storage location), certain processing artifacts may be temporarily written to the relational data store:

- Vector feature boundaries for extent management
- Attribute tables for raster datasets that include fields
- Metadata and statistics about processing results

#### 3. **Hosted Feature Layer Outputs**
Some raster analysis tools generate **hosted feature layers** as output (stored in the relational data store):

- **Extract Data** tool outputs (when extracting to feature format)
- **Zonal Statistics as Table** outputs
- **Sample** tool outputs (point features with sampled raster values)
- **Raster to Point/Line/Polygon** conversion outputs
- Analysis summary tables and statistics

#### 4. **Hosted Imagery Layer Metadata**
When raster analysis creates hosted imagery layers:

- **Service definitions** are stored in the relational data store
- **Layer properties** including rendering information, band combinations, and symbology
- **Metadata records** describing the imagery layer
- **Thumbnail images** and preview graphics
- **Footprint polygons** defining the spatial extent of raster datasets

Note: The actual raster pixels are stored in the **raster store**, not the relational data store.

#### 5. **System Service Tracking**
The relational data store tracks information about Image Server system services involved in raster analytics:

- **RasterAnalysisTools** service instance activity
- **RasterProcessing** service task queuing and execution
- **RasterRendering** service requests (when results are visualized)
- Service instance allocation and release timestamps

---

## Additional Load on the Relational Data Store

### Baseline Load Characteristics

The relational data store experiences increased load from Image Server raster analytics operations in several ways:

#### 1. **Connection Pool Utilization**
Each raster analysis task requires database connections:

- Multiple concurrent analysis jobs compete for connection pool resources
- Each **RasterProcessing** service instance may require its own connection
- Default maximum instances per machine: 2-4 (configurable up to 8+)
- High-concurrency scenarios can exhaust available connections

#### 2. **Transaction Volume**
Raster analysis generates significant transaction activity:

- **Job submission transactions**: Write operations for new job records
- **Status update transactions**: Frequent updates as jobs progress through stages
- **Result registration transactions**: Writing metadata for completed outputs
- **Feature insertion transactions**: When outputs include hosted feature layers

#### 3. **Read/Write I/O Operations**
The relational data store experiences increased I/O:

- **Read operations**: Querying job status, retrieving metadata, accessing footprints
- **Write operations**: Creating job records, updating progress, inserting features
- **Concurrent operations**: Multiple analysis jobs reading/writing simultaneously
- **Locking contention**: Potential for row-level locks during status updates

#### 4. **Storage Growth**
Over time, raster analytics activity consumes relational data store storage:

- **Job history accumulation**: Each analysis creates permanent records
- **Metadata proliferation**: Each hosted imagery layer adds metadata
- **Feature data accumulation**: Analysis outputs stored as hosted feature layers
- **Orphaned records**: Failed or cancelled jobs may leave residual data

#### 5. **Query Performance Impact**
Heavy raster analytics usage affects query performance:

- **Index overhead**: Frequent writes can fragment indexes
- **Table scanning**: Large job history tables slow down status queries
- **Join complexity**: Metadata queries may involve multiple table joins
- **Concurrent query contention**: Multiple users checking job status simultaneously

---

## Workflows That Significantly Affect Relational Data Store Load

### High-Impact Workflows

Understanding which raster analytics workflows place the greatest burden on the relational data store helps administrators plan capacity and optimize performance:

#### 1. **Distributed Raster Processing with High Parallelization**

**Characteristics:**

- Analysis jobs configured with **high parallel processing factors** (4-8 instances)
- Large raster datasets divided into many processing tiles
- Each tile processed as a separate task

**Relational Data Store Impact:**

- **Multiplied transaction volume**: Each parallel task generates separate database transactions
- **Connection saturation**: Each RasterProcessing instance requires database connections
- **Status update storms**: Frequent status updates from multiple concurrent tasks
- **Metadata explosion**: Each processing tile may generate intermediate metadata

**Examples:**

- Large-extent NDVI analysis with parallel processing factor of 8
- Multi-band raster function chains applied to entire imagery collections
- Time-series analysis across hundreds of raster datasets

**Mitigation Strategies:**

- Limit parallel processing factor based on relational data store capacity
- Stagger large analysis jobs to avoid concurrent execution
- Monitor connection pool utilization during peak processing

#### 2. **Raster Analysis Generating Feature Layer Outputs**

**Characteristics:**

- Tools that produce **hosted feature layers** instead of raster outputs
- Large numbers of features inserted into the relational data store
- Complex attribute tables with many fields

**Relational Data Store Impact:**

- **Direct feature storage**: All output features written to relational data store
- **Attribute indexing overhead**: Indexes created for feature layer fields
- **Large transaction sizes**: Inserting thousands or millions of features
- **Table growth**: Permanent storage consumption in relational data store

**Examples:**

- **Raster to Point conversion** on high-resolution imagery (millions of points)
- **Zonal Statistics as Table** with hundreds of zones
- **Extract Data** tool with feature format output and large extent
- **Sample** tool creating point features across large imagery collections

**Mitigation Strategies:**

- Consider raster output formats when appropriate instead of feature outputs
- Limit extent and resolution for feature-generating analyses
- Schedule large feature-generating jobs during off-peak hours
- Archive or delete old analysis results to prevent storage bloat

#### 3. **High-Frequency, Short-Duration Analysis Jobs**

**Characteristics:**

- Many small raster analysis jobs submitted in rapid succession
- Interactive user workflows repeatedly running tools
- Automated scripts or apps triggering frequent analyses

**Relational Data Store Impact:**

- **Transaction rate saturation**: High volume of small transactions
- **Connection thrashing**: Rapid connection acquisition and release
- **Job history bloat**: Large numbers of job records accumulating
- **Query performance degradation**: Job status queries slow down

**Examples:**

- Interactive map exploration with on-the-fly raster function application
- Automated monitoring systems running scheduled analyses every few minutes
- Training scenarios with many users simultaneously running tutorials
- Web applications applying raster functions to user-specified extents

**Mitigation Strategies:**

- Implement client-side caching for repeated analyses
- Use asynchronous processing patterns to reduce perceived latency
- Consider pre-generating commonly requested analysis results
- Implement rate limiting for automated systems

#### 4. **Large-Scale Mosaic Dataset-Based Workflows**

**Characteristics:**

- Imagery layers based on **large mosaic datasets** (thousands of rasters)
- On-the-fly raster function processing applied to mosaics
- Multiple users accessing and analyzing the same mosaic dataset

**Relational Data Store Impact:**

- **Footprint query overhead**: Querying mosaic footprints from relational data store
- **Metadata retrieval**: Loading raster metadata for visible extents
- **Rendering metadata**: Storing information about applied raster functions
- **Concurrent access contention**: Multiple users querying same metadata

**Examples:**

- Enterprise-wide imagery collections with 10,000+ individual rasters
- Time-enabled mosaic datasets with temporal queries
- Multi-resolution mosaic datasets with overview generation
- Mosaic datasets with complex query definitions

**Mitigation Strategies:**

- Enable query response caching in the **object store** (see next section)
- Optimize mosaic dataset footprint indexing
- Pre-generate overviews and reduce on-the-fly processing
- Consider splitting very large mosaic datasets by region or time

#### 5. **Batch Processing and Automation Scenarios**

**Characteristics:**

- Scripted workflows using ArcGIS API for Python or ArcPy
- Batch processing of multiple raster datasets in sequence or parallel
- Automated image processing pipelines

**Relational Data Store Impact:**

- **Sustained high load**: Continuous database activity during batch runs
- **Resource contention**: Competing with other Enterprise services
- **Backup interference**: Long-running batch jobs may overlap with backup windows
- **Connection pool depletion**: Batch scripts holding connections for extended periods

**Examples:**

- Nightly processing of satellite imagery acquisitions
- Automated change detection across historical imagery archives
- Bulk raster format conversion and optimization
- Scheduled generation of derived products (slope, aspect, hillshade)

**Mitigation Strategies:**

- Schedule batch processing during maintenance windows
- Implement batch job queuing to control concurrency
- Release database connections between processing iterations
- Monitor relational data store performance during automation runs

---

## Performance Optimization Strategies

### Relational Data Store Configuration

#### 1. **Capacity Planning**

- **CPU**: Allocate sufficient CPU cores for database operations (minimum 4 cores, recommend 8+)
- **Memory**: Provide adequate RAM for database caching (minimum 16 GB, recommend 32+ GB)
- **Disk I/O**: Use high-performance SSD storage for database files
- **Network**: Ensure low-latency network connection between Image Server and data store

#### 2. **Connection Pool Tuning**

- Monitor connection pool utilization during raster analytics operations
- Increase maximum connections if saturation occurs
- Configure connection timeout values appropriately
- Consider separate connection pools for different workload types

#### 3. **Index Maintenance**

- Regularly rebuild fragmented indexes on job history tables
- Create custom indexes for frequently queried metadata fields
- Archive old job records to reduce index overhead
- Monitor query execution plans for optimization opportunities

#### 4. **Storage Management**

- Implement archival policies for old raster analysis job records
- Clean up orphaned metadata from failed analyses
- Monitor database size growth trends
- Configure appropriate backup retention policies

### Image Server Configuration

#### 1. **Service Instance Management**

- Configure **RasterProcessing** service instances based on available resources
- Balance parallel processing factor against relational data store capacity
- Monitor service instance usage patterns
- Adjust instance counts based on workload characteristics

#### 2. **Workload Separation**

Implement the **workload separation** best practice:

- Dedicate separate Image Server sites for **image hosting** vs. **raster analytics**
- Image hosting server: Optimized for visualization (RasterRendering service)
- Raster analytics server: Optimized for processing (RasterProcessing service)
- Reduces resource contention and improves overall performance

#### 3. **Raster Store Configuration**

- Use high-performance storage for the raster store (output location)
- Consider SSD or cloud object storage for faster I/O
- Ensure adequate capacity for analysis outputs
- Use UNC paths for network-accessible raster stores

### Portal and Application Design

#### 1. **Result Caching**

- Enable **object store** for caching hosted feature layer query responses
- Pre-generate frequently requested raster analysis results
- Implement application-level caching for common queries
- Use tiled/cached imagery layers when possible instead of dynamic processing

#### 2. **User Education and Governance**

- Establish guidelines for appropriate use of raster analytics
- Discourage unnecessary re-running of identical analyses
- Encourage users to save and share analysis results
- Implement quotas or limits for resource-intensive operations

#### 3. **Monitoring and Alerting**

- Monitor relational data store performance metrics
- Set up alerts for connection pool saturation
- Track job completion rates and failure patterns
- Identify and address problematic workflows

---

## Relationship Between Data Stores

### Understanding the Data Flow

It's important to understand which data goes where in a raster analytics workflow:

| **Data Type** | **Storage Location** | **Purpose** |
|---------------|----------------------|-------------|
| Input raster files | Raster Store (registered folder/cloud) | Source data for analysis |
| Output raster pixels | Raster Store (registered folder/cloud) | Analysis results (imagery) |
| Job metadata & tracking | **Relational Data Store** | Job status, history, configuration |
| Hosted imagery layer metadata | **Relational Data Store** | Service definitions, symbology, properties |
| Feature layer outputs | **Relational Data Store** | Vector features, attribute tables |
| Footprint polygons | **Relational Data Store** | Spatial extent boundaries |
| Query response caches | **Object Store** (if configured) | Cached results for performance |
| Scene layer caches | **Object Store** | 3D layer tile caches |

### Why This Matters

The relational data store is designed for **structured transactional data**, not bulk raster storage. However, raster analytics operations generate significant **metadata, tracking information, and derivative feature data** that must be stored in the relational data store. This is why raster analytics can place unexpected load on the relational data store even though the actual imagery is stored elsewhere.

---

## Monitoring and Troubleshooting

### Key Metrics to Monitor

#### Relational Data Store Metrics

- Database connection count and connection pool utilization
- Transaction rate (commits/second)
- Query response times
- Disk I/O throughput and latency
- Database size and growth rate
- Index fragmentation levels

#### Image Server Metrics

- RasterProcessing service instance counts
- Job queue depth and wait times
- Analysis job completion rates
- Job failure rates and error patterns
- Service response times

#### System Resource Metrics

- CPU utilization on data store machine
- Memory usage and available RAM
- Disk space availability
- Network bandwidth utilization

### Common Issues and Solutions

#### Issue: Slow Raster Analysis Job Submission
**Symptoms**: Long delays when submitting raster analysis jobs  
**Likely Cause**: Relational data store connection pool saturation  
**Solutions**:

- Increase maximum database connections
- Reduce concurrent raster analysis jobs
- Optimize database query performance
- Scale up relational data store hardware

#### Issue: Analysis Jobs Stuck in "Submitted" State
**Symptoms**: Jobs remain queued and never transition to "Running"  
**Likely Cause**: RasterProcessing service issues or database transaction failures  
**Solutions**:

- Check RasterProcessing service status
- Review ArcGIS Server logs for errors
- Verify relational data store connectivity
- Restart Image Server services if necessary

#### Issue: Relational Data Store Storage Filling Up
**Symptoms**: Insufficient disk space warnings, backup failures  
**Likely Cause**: Job history and metadata accumulation  
**Solutions**:

- Archive or delete old raster analysis job records
- Clean up orphaned metadata from failed jobs
- Implement automated cleanup policies
- Add storage capacity to data store machine

---

## Best Practices Summary

### Planning and Architecture

1. **Separate Data Store Types**: Do not co-locate relational data store with spatiotemporal big data store or object store
2. **Implement Workload Separation**: Use dedicated Image Server sites for hosting vs. analytics
3. **Right-Size Infrastructure**: Allocate appropriate CPU, memory, and disk I/O for expected workload
4. **Configure Object Store**: Enable query response caching for improved performance

### Operational Management

1. **Monitor Performance**: Establish baseline metrics and track trends over time
2. **Implement Quotas**: Control resource-intensive operations through governance
3. **Schedule Batch Jobs**: Run large analyses during off-peak hours
4. **Maintain Databases**: Regularly rebuild indexes and clean up old records

### User Guidance

1. **Educate Users**: Train users on efficient raster analysis practices
2. **Encourage Reuse**: Share and reuse analysis results instead of re-running
3. **Optimize Workflows**: Use appropriate tools and parameters for each task
4. **Limit Parallelization**: Don't always max out parallel processing factors

### Development Practices

1. **Implement Caching**: Cache results at application and service levels
2. **Manage Connections**: Release database connections promptly in scripts
3. **Handle Errors Gracefully**: Implement retry logic and error handling
4. **Test at Scale**: Performance test with realistic workloads before production

---

## Related Documentation

### ArcGIS Enterprise Help
- [What is ArcGIS Data Store?](https://enterprise.arcgis.com/en/portal/latest/administer/windows/what-is-arcgis-data-store.htm)
- [Configure Image Server](https://enterprise.arcgis.com/en/image/latest/configure/windows/configure-image-server.htm)
- [Configure Raster Analytics](https://enterprise.arcgis.com/en/image/latest/configure/windows/configure-raster-analytics.htm)
- [ArcGIS Data Store Vocabulary](https://enterprise.arcgis.com/en/portal/latest/administer/windows/arcgis-data-store-terms.htm)

### ArcGIS Architecture Center
- [Workload Separation Best Practice](https://architecture.arcgis.com/en/)
- [Performance and Scalability Guidance](https://architecture.arcgis.com/en/)

### Additional Resources
- [Tune Services Using Best Practices](https://enterprise.arcgis.com/en/server/latest/publish-services/windows/tuning-and-configuring-services.htm)
- [Monitor ArcGIS Enterprise Performance](https://enterprise.arcgis.com/en/portal/latest/administer/windows/monitor-arcgis-enterprise.htm)

---

## Summary

ArcGIS Image Server, when functioning as a **raster analytics server**, creates significant activity in the **hosted relational data store** despite storing actual raster data in a separate raster store. The relational data store is used for:

- **Job metadata and tracking** for all raster analysis operations
- **Hosted imagery layer metadata** including service definitions and properties
- **Feature layer outputs** from raster-to-vector conversion tools
- **Footprint polygons** and spatial indexes for imagery collections
- **System service tracking** for RasterProcessing and RasterAnalysisTools services

Workflows that place the highest load on the relational data store include:

1. High-parallelization distributed raster processing
2. Raster analysis generating feature layer outputs
3. High-frequency short-duration analysis jobs
4. Large mosaic dataset-based workflows
5. Batch processing and automation scenarios

Effective management requires understanding these interactions, implementing appropriate monitoring, applying workload separation best practices, and configuring adequate infrastructure capacity to support both the raster analytics workload and the resulting relational data store activity.
