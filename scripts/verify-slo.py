#!/usr/bin/env python3
"""
SLO Verification Script
Verifies that the application meets the defined SLOs after deployment.
"""

import argparse
import boto3
import time
import sys
from datetime import datetime, timedelta
from typing import Dict, Any

class SLOVerifier:
    def __init__(self, environment: str, region: str = 'us-west-2'):
        self.environment = environment
        self.region = region
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.synthetics = boto3.client('synthetics', region_name=region)
        
        # SLO Thresholds
        self.slo_thresholds = {
            'availability': 99.95,  # 99.95%
            'latency_p95': 500,     # 500ms
            'error_rate': 0.1       # 0.1%
        }
    
    def verify_availability_slo(self) -> Dict[str, Any]:
        """Verify availability SLO using CloudWatch Synthetics"""
        try:
            canary_name = f"dotnet-migration-{self.environment}-availability-canary"
            
            # Get synthetics metrics for the last 15 minutes
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(minutes=15)
            
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/Synthetics',
                MetricName='SuccessPercent',
                Dimensions=[
                    {
                        'Name': 'CanaryName',
                        'Value': canary_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Average']
            )
            
            if not response['Datapoints']:
                return {
                    'metric': 'availability',
                    'status': 'NO_DATA',
                    'value': None,
                    'threshold': self.slo_thresholds['availability'],
                    'compliant': False,
                    'message': 'No availability data available'
                }
            
            # Get the latest datapoint
            latest_datapoint = max(response['Datapoints'], key=lambda x: x['Timestamp'])
            availability = latest_datapoint['Average']
            
            compliant = availability >= self.slo_thresholds['availability']
            
            return {
                'metric': 'availability',
                'status': 'SUCCESS' if compliant else 'VIOLATION',
                'value': availability,
                'threshold': self.slo_thresholds['availability'],
                'compliant': compliant,
                'message': f"Availability: {availability:.2f}% (Threshold: {self.slo_thresholds['availability']}%)"
            }
            
        except Exception as e:
            return {
                'metric': 'availability',
                'status': 'ERROR',
                'value': None,
                'threshold': self.slo_thresholds['availability'],
                'compliant': False,
                'message': f"Error checking availability: {str(e)}"
            }
    
    def verify_latency_slo(self) -> Dict[str, Any]:
        """Verify latency SLO using ALB metrics"""
        try:
            alb_name = f"dotnet-migration-{self.environment}-alb"
            
            # Get ALB metrics for the last 15 minutes
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(minutes=15)
            
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='TargetResponseTime',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['p95']
            )
            
            if not response['Datapoints']:
                return {
                    'metric': 'latency',
                    'status': 'NO_DATA',
                    'value': None,
                    'threshold': self.slo_thresholds['latency_p95'],
                    'compliant': False,
                    'message': 'No latency data available'
                }
            
            # Get the latest datapoint
            latest_datapoint = max(response['Datapoints'], key=lambda x: x['Timestamp'])
            latency_ms = latest_datapoint['p95'] * 1000  # Convert to milliseconds
            
            compliant = latency_ms <= self.slo_thresholds['latency_p95']
            
            return {
                'metric': 'latency',
                'status': 'SUCCESS' if compliant else 'VIOLATION',
                'value': latency_ms,
                'threshold': self.slo_thresholds['latency_p95'],
                'compliant': compliant,
                'message': f"P95 Latency: {latency_ms:.2f}ms (Threshold: {self.slo_thresholds['latency_p95']}ms)"
            }
            
        except Exception as e:
            return {
                'metric': 'latency',
                'status': 'ERROR',
                'value': None,
                'threshold': self.slo_thresholds['latency_p95'],
                'compliant': False,
                'message': f"Error checking latency: {str(e)}"
            }
    
    def verify_error_rate_slo(self) -> Dict[str, Any]:
        """Verify error rate SLO using ALB metrics"""
        try:
            alb_name = f"dotnet-migration-{self.environment}-alb"
            
            # Get ALB metrics for the last 15 minutes
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(minutes=15)
            
            # Get success requests (2xx)
            success_response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='HTTPCode_Target_2XX_Count',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )
            
            # Get error requests (4xx + 5xx)
            error4xx_response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='HTTPCode_Target_4XX_Count',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )
            
            error5xx_response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='HTTPCode_Target_5XX_Count',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Sum']
            )
            
            # Calculate totals
            success_count = sum([dp['Sum'] for dp in success_response['Datapoints']])
            error4xx_count = sum([dp['Sum'] for dp in error4xx_response['Datapoints']])
            error5xx_count = sum([dp['Sum'] for dp in error5xx_response['Datapoints']])
            
            total_requests = success_count + error4xx_count + error5xx_count
            error_requests = error4xx_count + error5xx_count
            
            if total_requests == 0:
                return {
                    'metric': 'error_rate',
                    'status': 'NO_DATA',
                    'value': None,
                    'threshold': self.slo_thresholds['error_rate'],
                    'compliant': False,
                    'message': 'No request data available'
                }
            
            error_rate = (error_requests / total_requests) * 100
            compliant = error_rate <= self.slo_thresholds['error_rate']
            
            return {
                'metric': 'error_rate',
                'status': 'SUCCESS' if compliant else 'VIOLATION',
                'value': error_rate,
                'threshold': self.slo_thresholds['error_rate'],
                'compliant': compliant,
                'message': f"Error Rate: {error_rate:.3f}% (Threshold: {self.slo_thresholds['error_rate']}%)"
            }
            
        except Exception as e:
            return {
                'metric': 'error_rate',
                'status': 'ERROR',
                'value': None,
                'threshold': self.slo_thresholds['error_rate'],
                'compliant': False,
                'message': f"Error checking error rate: {str(e)}"
            }
    
    def verify_all_slos(self) -> Dict[str, Any]:
        """Verify all SLOs and return comprehensive results"""
        print(f"🔍 Verifying SLOs for {self.environment} environment...")
        print(f"Timestamp: {datetime.utcnow().isoformat()}Z")
        print("-" * 60)
        
        results = {
            'environment': self.environment,
            'timestamp': datetime.utcnow().isoformat(),
            'slos': [],
            'overall_compliant': True,
            'violations': []
        }
        
        # Verify each SLO
        slo_checks = [
            self.verify_availability_slo(),
            self.verify_latency_slo(),
            self.verify_error_rate_slo()
        ]
        
        for slo_result in slo_checks:
            results['slos'].append(slo_result)
            
            # Print result
            status_emoji = {
                'SUCCESS': '✅',
                'VIOLATION': '❌',
                'ERROR': '⚠️',
                'NO_DATA': '📊'
            }
            
            print(f"{status_emoji.get(slo_result['status'], '❓')} {slo_result['message']}")
            
            # Track overall compliance
            if not slo_result['compliant']:
                results['overall_compliant'] = False
                if slo_result['status'] == 'VIOLATION':
                    results['violations'].append(slo_result['metric'])
        
        print("-" * 60)
        
        if results['overall_compliant']:
            print("🎉 All SLOs are compliant!")
        else:
            print(f"🚨 SLO violations detected: {', '.join(results['violations'])}")
        
        return results

def main():
    parser = argparse.ArgumentParser(description='Verify SLO compliance')
    parser.add_argument('--environment', required=True, 
                       choices=['dev', 'staging', 'prod'],
                       help='Environment to verify')
    parser.add_argument('--region', default='us-west-2',
                       help='AWS region (default: us-west-2)')
    
    args = parser.parse_args()
    
    verifier = SLOVerifier(args.environment, args.region)
    results = verifier.verify_all_slos()
    
    # Exit with error code if SLOs are not compliant
    if not results['overall_compliant']:
        sys.exit(1)
    
    sys.exit(0)

if __name__ == '__main__':
    main()
