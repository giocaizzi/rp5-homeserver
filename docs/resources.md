# Resource Allocation - Raspberry Pi 5 8GB with Swap

Optimized resource distribution for all services running on the homeserver with swap support.

## Total System Resources
- **RAM**: 8GB total
- **Swap**: Available (configured on host)
- **CPU**: 4 cores (ARM Cortex-A76)
- **Architecture**: ARM64

## Swap Configuration Strategy
All services are configured to use swap intelligently:
- **Conservative swappiness**: Prefer RAM but allow swap when needed
- **2x memory limits**: Allow up to 2x memory allocation via swap
- **AI workloads**: Very conservative swap usage (swappiness=1)
- **System services**: Moderate swap usage (swappiness=10)

## Service Resource Allocation

### Infrastructure Stack (infra/)
| Service | Memory Limit | Memory Reserve | CPU Limit | CPU Reserve |
|---------|-------------|----------------|-----------|-------------|
| Nginx | 128MB | 64MB | 0.5 | 0.25 |
| Portainer | 256MB | 128MB | 0.5 | 0.25 |
| Cloudflared | 64MB | 32MB | 0.25 | 0.1 |
| Netdata | 256MB | 128MB | 0.5 | 0.25 |
| Restic* | 512MB | 256MB | 1.0 | 0.5 |
| **Total** | **1216MB** | **608MB** | **2.75** | **1.35** |

*Restic runs only during backup operations, not continuously.

### N8N Stack (services/n8n/)
| Service | Memory Limit | Memory Reserve | CPU Limit | CPU Reserve |
|---------|-------------|----------------|-----------|-------------|
| n8n | 512MB | 256MB | 1.0 | 0.5 |
| PostgreSQL | 256MB | 128MB | 0.5 | 0.25 |
| **Total** | **768MB** | **384MB** | **1.5** | **0.75** |

### Ollama Stack (services/ollama/)
| Service | Memory Limit | Memory Reserve | CPU Limit | CPU Reserve |
|---------|-------------|----------------|-----------|-------------|
| Ollama | 3GB | 1GB | 3.0 | 1.0 |
| **Total** | **3GB** | **1GB** | **3.0** | **1.0** |

## Swap Configuration
- **Services support**: 2x memory limits via swap
- **Memory + Swap**: Total capacity allows graceful degradation
- **Swappiness**: AI workloads (1), system services (10)
- **Recommended swap size**: 4GB

### Swap Size Requirements
- **Current limits**: 4.28GB memory + 4.12GB potential swap usage
- **Recommended**: 4GB swap (covers all scenarios)

### Increase Swap Size
```bash
# Edit swap configuration
sudo nano /etc/dphys-swapfile
# Change: CONF_SWAPSIZE=4096

# Apply changes
sudo dphys-swapfile swapoff
sudo dphys-swapfile setup  
sudo dphys-swapfile swapon

# Verify
free -h
```

## Total Resource Usage

### Memory Distribution
```
Total RAM: 8GB (8192MB)
├── System/OS: ~1500MB (estimated)
├── Docker overhead: ~200MB
├── Infrastructure: 1216MB (limits)*
├── N8N Stack: 768MB (limits)
├── Ollama: 3072MB (limits)
└── Available buffer: ~1436MB

*Restic only runs during backup operations
```

### CPU Distribution
```
Total CPU: 4 cores
├── Infrastructure: 2.75 cores (limits)*
├── N8N Stack: 1.5 cores (limits)
├── Ollama: 3.0 cores (limits)
└── Overlap allowed: Services can share cores

*Restic only active during backups
```

## Memory Reservations (Guaranteed)
- **Infrastructure**: 608MB (352MB when backup not running)
- **N8N Stack**: 384MB  
- **Ollama**: 1GB
- **Total Reserved**: 1.99GB (1.74GB without backup)
- **Available for OS**: 6GB+ (6.26GB without backup)

## Optimization Benefits

### 1. **Memory Efficiency**
- 50% reduction from previous allocations
- Smart reservations prevent OOM conditions
- 2.2GB buffer for system operations

### 2. **CPU Utilization** 
- Allows burst usage above reservations
- Ollama can use 3/4 cores when needed
### 3. **Pi-Specific Tuning**
- PostgreSQL optimized for ARM architecture
- Reduced I/O pressure on SD card
- Conservative limits prevent thermal throttling

### 4. **Swap Integration**
- Services can use 2x memory limits via swap
- Graceful degradation instead of OOM kills
- Benefits: Prevents crashes during memory spikes

## Usage Guidelines

### Development
- Services use reservation values (~1.6GB total)
- Minimal swap usage

### Production Load  
- Services can burst to memory limits
- Swap provides safety margin for peak usage

## Monitoring
Monitor these metrics:
- Memory usage vs limits (`docker stats`)
- System memory pressure (`free -h`)
- Swap usage (`swapon --show`)
- Temperature (prevent throttling)

## Notes
- Values optimized for typical homeserver usage
- Infrastructure services intentionally conservative  
- System maintains 2GB+ RAM buffer for stability