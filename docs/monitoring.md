# Monitoring & SLO Runbook

## Overview

This runbook provides comprehensive guidance for monitoring the AWS Cloud Migration solution and maintaining Service Level Objectives (SLOs). It includes procedures for detecting, investigating, and resolving SLO violations.

## Service Level Objectives (SLOs)

### Defined SLOs

| SLO | Target | Error Budget | Measurement | Alert Threshold |
|-----|--------|--------------|-------------|-----------------|
| **Availability** | 99.95% | 0.05% | CloudWatch Synthetics | < 99.95% over 5 minutes |
| **Latency (P95)** | < 500ms | N/A | ALB target response time | > 500ms over 5 minutes |
| **Error Rate** | < 0.1% | 0.1% | ALB 4xx/5xx responses | > 0.1% over 5 minutes |

### Error Budget Calculation

```
Monthly Error Budget = (1 - SLO) × Total Requests
Example: (1 - 0.9995) × 1,000,000 = 500 errors per month
```

## Monitoring Infrastructure

### CloudWatch Dashboards

#### 1. SLO Dashboard (`dotnet-migration-{env}-slo-dashboard`)
- **Purpose**: Real-time SLO monitoring
- **Metrics**:
  - Availability percentage (Synthetics)
  - P95 latency trends
  - Error rate percentage
  - HTTP response code distribution

#### 2. SLO Tracking Dashboard (`dotnet-migration-{env}-slo-tracking`)
- **Purpose**: Current SLO status
- **Widgets**:
  - Current availability (single value)
  - Current P95 latency (single value)
  - Current error rate (single value)
  - Running task count

#### 3. Infrastructure Dashboard
- **Purpose**: Infrastructure health monitoring
- **Metrics**:
  - ECS CPU/Memory utilization
  - ALB request count and latency
  - Auto-scaling events
  - Database performance (if enabled)

### CloudWatch Synthetics

#### Availability Canary
- **Name**: `dotnet-migration-{env}-availability-canary`
- **Frequency**: 1 minute (prod), 2 minutes (staging), 5 minutes (dev)
- **Endpoints**:
  - `/health` - Health check endpoint
  - `/` - Application root
- **Success Criteria**: HTTP 200 response within 60 seconds

### Alarms Configuration

#### Critical Alarms (PagerDuty/Immediate Response)
1. **Availability SLO Breach**
   - Condition: Success rate < 99.95% for 2 consecutive periods
   - Action: Page on-call engineer

2. **High Error Rate**
   - Condition: Error rate > 0.1% for 2 consecutive periods
   - Action: Page on-call engineer

#### Warning Alarms (Slack/Email)
1. **Latency SLO Warning**
   - Condition: P95 latency > 500ms for 2 consecutive periods
   - Action: Notify team via Slack

2. **High CPU Utilization**
   - Condition: CPU > 80% for 10 minutes
   - Action: Email alerts

3. **High Memory Utilization**
   - Condition: Memory > 85% for 10 minutes
   - Action: Email alerts

## SLO Violation Response Procedures

### 1. Availability SLO Violation

#### Immediate Actions (< 5 minutes)
1. **Acknowledge the alert**
2. **Check application status**:
   ```bash
   # Get service status
   aws ecs describe-services \
     --cluster dotnet-migration-{env} \
     --services dotnet-migration-{env}-dotnet-app
   
   # Check task health
   aws ecs list-tasks \
     --cluster dotnet-migration-{env} \
     --service-name dotnet-migration-{env}-dotnet-app
   ```

3. **Verify ALB target health**:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <target-group-arn>
   ```

#### Investigation Steps (5-15 minutes)
1. **Check CloudWatch Synthetics results**:
   - Navigate to CloudWatch > Synthetics
   - Review canary execution results
   - Check for error details and screenshots

2. **Review ECS service events**:
   ```bash
   aws ecs describe-services \
     --cluster dotnet-migration-{env} \
     --services dotnet-migration-{env}-dotnet-app \
     --query 'services[0].events'
   ```

3. **Check application logs**:
   ```bash
   aws logs tail /ecs/dotnet-migration-{env}/dotnet-app \
     --since 15m --follow
   ```

#### Resolution Actions
1. **If tasks are unhealthy**:
   ```bash
   # Force new deployment
   aws ecs update-service \
     --cluster dotnet-migration-{env} \
     --service dotnet-migration-{env}-dotnet-app \
     --force-new-deployment
   ```

2. **If ALB issues**:
   - Check security group rules
   - Verify target group health check settings
   - Review WAF logs for blocks

3. **If application issues**:
   - Check database connectivity
   - Verify secrets and environment variables
   - Review application error logs

#### Escalation
- **Level 1**: Development team (immediate)
- **Level 2**: Platform team (after 15 minutes)
- **Level 3**: Engineering manager (after 30 minutes)

### 2. Latency SLO Violation

#### Immediate Actions
1. **Check current load**:
   ```bash
   # Check request count
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ApplicationELB \
     --metric-name RequestCount \
     --dimensions Name=LoadBalancer,Value=dotnet-migration-{env}-alb \
     --start-time $(date -d '15 minutes ago' -u +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Sum
   ```

2. **Check ECS resource utilization**:
   ```bash
   # CPU utilization
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ECS \
     --metric-name CPUUtilization \
     --dimensions Name=ServiceName,Value=dotnet-migration-{env}-dotnet-app \
                  Name=ClusterName,Value=dotnet-migration-{env} \
     --start-time $(date -d '15 minutes ago' -u +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average
   ```

#### Investigation Steps
1. **Review auto-scaling events**
2. **Check database performance** (if applicable)
3. **Analyze application performance metrics**
4. **Review external service dependencies**

#### Resolution Actions
1. **Scale up manually** if auto-scaling is slow:
   ```bash
   aws ecs update-service \
     --cluster dotnet-migration-{env} \
     --service dotnet-migration-{env}-dotnet-app \
     --desired-count <increased-count>
   ```

2. **Optimize application performance**:
   - Review slow queries
   - Check caching mechanisms
   - Analyze code bottlenecks

### 3. Error Rate SLO Violation

#### Immediate Actions
1. **Identify error types**:
   ```bash
   # Check 4xx errors
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ApplicationELB \
     --metric-name HTTPCode_Target_4XX_Count \
     --dimensions Name=LoadBalancer,Value=dotnet-migration-{env}-alb \
     --start-time $(date -d '15 minutes ago' -u +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Sum
   
   # Check 5xx errors
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ApplicationELB \
     --metric-name HTTPCode_Target_5XX_Count \
     --dimensions Name=LoadBalancer,Value=dotnet-migration-{env}-alb \
     --start-time $(date -d '15 minutes ago' -u +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Sum
   ```

2. **Review application logs for errors**:
   ```bash
   aws logs filter-log-events \
     --log-group-name /ecs/dotnet-migration-{env}/dotnet-app \
     --start-time $(date -d '15 minutes ago' +%s)000 \
     --filter-pattern "ERROR"
   ```

#### Investigation Steps
1. **Check for deployment correlations**
2. **Review recent configuration changes**
3. **Analyze error patterns and root causes**
4. **Check external service status**

#### Resolution Actions
1. **If deployment-related**: Rollback to previous version
2. **If configuration issue**: Revert configuration changes
3. **If dependency issue**: Implement circuit breaker or fallback

## Monitoring Tools and Commands

### CloudWatch Logs Insights Queries

#### Find Application Errors
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

#### Analyze Request Latency
```sql
fields @timestamp, @message
| filter @message like /Completed request/
| parse @message /in (?<duration>\d+)ms/
| stats avg(duration), max(duration), min(duration) by bin(5m)
```

#### Error Rate Analysis
```sql
fields @timestamp, @message
| filter @message like /status/
| parse @message /status (?<status>\d+)/
| stats count() by status, bin(5m)
```

### Useful AWS CLI Commands

#### ECS Service Status
```bash
# Get service details
aws ecs describe-services \
  --cluster dotnet-migration-{env} \
  --services dotnet-migration-{env}-dotnet-app

# Get running tasks
aws ecs list-tasks \
  --cluster dotnet-migration-{env} \
  --service-name dotnet-migration-{env}-dotnet-app

# Get task definition
aws ecs describe-task-definition \
  --task-definition dotnet-migration-{env}-dotnet-app
```

#### ALB Health Checks
```bash
# Target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Load balancer details
aws elbv2 describe-load-balancers \
  --names dotnet-migration-{env}-alb
```

### SLO Verification Script

Use the automated SLO verification script:

```bash
# Verify current SLO status
python3 scripts/verify-slo.py --environment {env}

# Continuous monitoring (15 minutes)
python3 scripts/monitor-slo.py --environment {env} --duration 900
```

## Incident Response Workflow

### 1. Detection
- Automated alerts via CloudWatch Alarms
- Manual detection via dashboards
- Customer reports

### 2. Triage (< 5 minutes)
- Assess severity and impact
- Determine if SLO violation is occurring
- Assign incident commander

### 3. Investigation (< 15 minutes)
- Gather relevant metrics and logs
- Identify root cause
- Estimate time to resolution

### 4. Resolution
- Implement fix or workaround
- Verify SLO compliance restored
- Monitor for stability

### 5. Post-Incident
- Document incident details
- Conduct post-mortem if significant
- Update runbooks and procedures

## Maintenance and Updates

### Weekly Reviews
- Review SLO compliance metrics
- Analyze error budget consumption
- Check for trending issues

### Monthly Reports
- Generate SLO compliance report
- Review alert effectiveness
- Update monitoring thresholds if needed

### Quarterly Assessments
- Review SLO targets for relevance
- Update monitoring infrastructure
- Conduct disaster recovery tests

## Contact Information

### Escalation Chain
1. **On-call Engineer**: +1-XXX-XXX-XXXX
2. **Platform Team Lead**: platform-lead@company.com
3. **Engineering Manager**: eng-manager@company.com
4. **VP Engineering**: vp-eng@company.com

### Communication Channels
- **Incident Response**: #incidents
- **Platform Team**: #platform
- **Alerts**: #alerts
- **General**: #engineering

### External Contacts
- **AWS Support**: Enterprise Support Case
- **Third-party Services**: vendor-support@provider.com

## Appendix

### SLO Calculation Examples

#### Availability Calculation
```
Availability = (Total Requests - Failed Requests) / Total Requests × 100
Example: (999,500 - 500) / 999,500 × 100 = 99.95%
```

#### Error Budget Consumption
```
Error Budget Used = (Failed Requests / Total Requests) / (1 - SLO Target)
Example: (500 / 999,500) / (1 - 0.9995) = 100% of error budget consumed
```

### Useful Metrics Formulas

#### Request Success Rate
```
Success Rate = 2xx_responses / (2xx_responses + 4xx_responses + 5xx_responses) × 100
```

#### P95 Latency Threshold Check
```
Latency_Breach = P95_Latency > 500ms for 2 consecutive 5-minute periods
```

### Dashboard URLs

- **Production SLO Dashboard**: `https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=dotnet-migration-prod-slo-dashboard`
- **Staging SLO Dashboard**: `https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=dotnet-migration-staging-slo-dashboard`
- **Development SLO Dashboard**: `https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=dotnet-migration-dev-slo-dashboard`
