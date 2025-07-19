#!/usr/bin/env python3
"""
k6 Load Test Results Analyzer
Analyzes k6 test results and generates comprehensive reports
"""

import json
import argparse
import sys
import os
from datetime import datetime
from typing import Dict, List, Any
import statistics

try:
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from matplotlib.backends.backend_pdf import PdfPages
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Warning: matplotlib not found. Charts will not be generated.")
    print("Install with: pip install matplotlib")

def load_k6_results(file_path: str) -> Dict[str, Any]:
    """Load k6 JSON results file"""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
            
        # k6 JSON output has one JSON object per line
        metrics = {}
        data_points = []
        
        for line in lines:
            try:
                data = json.loads(line.strip())
                if data.get('type') == 'Metric':
                    metric_name = data.get('data', {}).get('name')
                    if metric_name:
                        metrics[metric_name] = data.get('data', {})
                elif data.get('type') == 'Point':
                    data_points.append(data.get('data', {}))
            except json.JSONDecodeError:
                continue
                
        return {
            'metrics': metrics,
            'data_points': data_points
        }
    except Exception as e:
        print(f"Error loading results file {file_path}: {e}")
        return {}

def analyze_basic_metrics(results: Dict[str, Any]) -> Dict[str, Any]:
    """Analyze basic performance metrics"""
    metrics = results.get('metrics', {})
    analysis = {}
    
    # HTTP request metrics
    if 'http_reqs' in metrics:
        http_reqs = metrics['http_reqs']
        analysis['total_requests'] = http_reqs.get('values', {}).get('count', 0)
        analysis['request_rate'] = http_reqs.get('values', {}).get('rate', 0)
    
    # Response time metrics
    if 'http_req_duration' in metrics:
        duration = metrics['http_req_duration']
        values = duration.get('values', {})
        analysis['response_times'] = {
            'avg': values.get('avg', 0),
            'min': values.get('min', 0),
            'max': values.get('max', 0),
            'p50': values.get('med', 0),
            'p90': values.get('p(90)', 0),
            'p95': values.get('p(95)', 0),
            'p99': values.get('p(99)', 0)
        }
    
    # Error rate
    if 'http_req_failed' in metrics:
        failed = metrics['http_req_failed']
        analysis['error_rate'] = failed.get('values', {}).get('rate', 0)
    
    # Custom metrics for scale-to-zero tests
    if 'cold_start_requests' in metrics:
        analysis['cold_starts'] = metrics['cold_start_requests'].get('values', {}).get('count', 0)
    
    if 'scale_up_time' in metrics:
        scale_up = metrics['scale_up_time']
        values = scale_up.get('values', {})
        analysis['scale_up_times'] = {
            'avg': values.get('avg', 0),
            'max': values.get('max', 0),
            'p90': values.get('p(90)', 0)
        }
    
    return analysis

def analyze_data_points(results: Dict[str, Any]) -> Dict[str, Any]:
    """Analyze time-series data points"""
    data_points = results.get('data_points', [])
    
    if not data_points:
        return {}
    
    # Group data points by metric name
    metrics_over_time = {}
    for point in data_points:
        metric_name = point.get('metric')
        if metric_name:
            if metric_name not in metrics_over_time:
                metrics_over_time[metric_name] = []
            metrics_over_time[metric_name].append({
                'time': point.get('time'),
                'value': point.get('value')
            })
    
    return metrics_over_time

def generate_text_report(analysis: Dict[str, Any], output_file: str = None):
    """Generate text-based analysis report"""
    report_lines = []
    
    report_lines.append("=" * 60)
    report_lines.append("k6 LOAD TEST ANALYSIS REPORT")
    report_lines.append("=" * 60)
    report_lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report_lines.append("")
    
    # Basic metrics
    if 'total_requests' in analysis:
        report_lines.append("📊 BASIC METRICS")
        report_lines.append("-" * 20)
        report_lines.append(f"Total Requests: {analysis['total_requests']:,}")
        report_lines.append(f"Request Rate: {analysis.get('request_rate', 0):.2f} req/s")
        report_lines.append(f"Error Rate: {analysis.get('error_rate', 0) * 100:.2f}%")
        report_lines.append("")
    
    # Response times
    if 'response_times' in analysis:
        rt = analysis['response_times']
        report_lines.append("⏱️  RESPONSE TIMES (ms)")
        report_lines.append("-" * 25)
        report_lines.append(f"Average: {rt.get('avg', 0):.2f}")
        report_lines.append(f"Minimum: {rt.get('min', 0):.2f}")
        report_lines.append(f"Maximum: {rt.get('max', 0):.2f}")
        report_lines.append(f"50th percentile: {rt.get('p50', 0):.2f}")
        report_lines.append(f"90th percentile: {rt.get('p90', 0):.2f}")
        report_lines.append(f"95th percentile: {rt.get('p95', 0):.2f}")
        report_lines.append(f"99th percentile: {rt.get('p99', 0):.2f}")
        report_lines.append("")
    
    # Scale-to-zero specific metrics
    if 'cold_starts' in analysis:
        report_lines.append("🔄 SCALE-TO-ZERO METRICS")
        report_lines.append("-" * 26)
        report_lines.append(f"Cold Starts Detected: {analysis['cold_starts']}")
        
        if 'scale_up_times' in analysis:
            st = analysis['scale_up_times']
            report_lines.append(f"Average Scale-up Time: {st.get('avg', 0):.2f} ms")
            report_lines.append(f"Maximum Scale-up Time: {st.get('max', 0):.2f} ms")
            report_lines.append(f"90th percentile Scale-up: {st.get('p90', 0):.2f} ms")
        report_lines.append("")
    
    # Performance assessment
    report_lines.append("🎯 PERFORMANCE ASSESSMENT")
    report_lines.append("-" * 28)
    
    error_rate = analysis.get('error_rate', 0)
    avg_response = analysis.get('response_times', {}).get('avg', 0)
    p95_response = analysis.get('response_times', {}).get('p95', 0)
    
    if error_rate < 0.01:
        report_lines.append("✅ Error Rate: EXCELLENT (< 1%)")
    elif error_rate < 0.05:
        report_lines.append("✅ Error Rate: GOOD (< 5%)")
    else:
        report_lines.append("❌ Error Rate: NEEDS IMPROVEMENT (≥ 5%)")
    
    if p95_response < 1000:
        report_lines.append("✅ Response Time: EXCELLENT (P95 < 1s)")
    elif p95_response < 2000:
        report_lines.append("✅ Response Time: GOOD (P95 < 2s)")
    else:
        report_lines.append("⚠️  Response Time: NEEDS IMPROVEMENT (P95 ≥ 2s)")
    
    report_lines.append("")
    report_lines.append("=" * 60)
    
    report_text = "\n".join(report_lines)
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(report_text)
        print(f"Text report saved to: {output_file}")
    else:
        print(report_text)

def generate_charts(analysis: Dict[str, Any], metrics_over_time: Dict[str, Any], output_file: str):
    """Generate charts and save to PDF"""
    if not HAS_MATPLOTLIB:
        print("Cannot generate charts: matplotlib not available")
        return
    
    with PdfPages(output_file) as pdf:
        # Response time distribution
        if 'response_times' in analysis:
            fig, ax = plt.subplots(figsize=(10, 6))
            rt = analysis['response_times']
            
            percentiles = ['p50', 'p90', 'p95', 'p99']
            values = [rt.get(p, 0) for p in percentiles]
            labels = ['50th', '90th', '95th', '99th']
            
            bars = ax.bar(labels, values, color=['green', 'yellow', 'orange', 'red'])
            ax.set_ylabel('Response Time (ms)')
            ax.set_title('Response Time Percentiles')
            ax.set_xlabel('Percentile')
            
            # Add value labels on bars
            for bar, value in zip(bars, values):
                ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(values)*0.01,
                       f'{value:.1f}ms', ha='center', va='bottom')
            
            plt.tight_layout()
            pdf.savefig(fig)
            plt.close()
        
        # Request rate over time
        if 'http_reqs' in metrics_over_time:
            fig, ax = plt.subplots(figsize=(12, 6))
            
            http_reqs_data = metrics_over_time['http_reqs']
            times = [datetime.fromisoformat(point['time'].replace('Z', '+00:00')) for point in http_reqs_data]
            values = [point['value'] for point in http_reqs_data]
            
            ax.plot(times, values, linewidth=2, color='blue')
            ax.set_ylabel('Requests/second')
            ax.set_title('Request Rate Over Time')
            ax.set_xlabel('Time')
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M:%S'))
            ax.xaxis.set_major_locator(mdates.MinuteLocator(interval=1))
            plt.xticks(rotation=45)
            
            plt.tight_layout()
            pdf.savefig(fig)
            plt.close()
        
        # Scale-to-zero specific charts
        if 'scale_up_time' in metrics_over_time:
            fig, ax = plt.subplots(figsize=(12, 6))
            
            scale_data = metrics_over_time['scale_up_time']
            times = [datetime.fromisoformat(point['time'].replace('Z', '+00:00')) for point in scale_data]
            values = [point['value'] for point in scale_data]
            
            ax.scatter(times, values, color='red', s=50, alpha=0.7)
            ax.set_ylabel('Scale-up Time (ms)')
            ax.set_title('Scale-up Events Over Time')
            ax.set_xlabel('Time')
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M:%S'))
            plt.xticks(rotation=45)
            
            plt.tight_layout()
            pdf.savefig(fig)
            plt.close()
    
    print(f"Charts saved to: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Analyze k6 load test results')
    parser.add_argument('results_file', help='Path to k6 JSON results file')
    parser.add_argument('--output-dir', '-o', default='./analysis', 
                       help='Output directory for reports (default: ./analysis)')
    parser.add_argument('--no-charts', action='store_true',
                       help='Skip chart generation')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.results_file):
        print(f"Error: Results file {args.results_file} not found")
        sys.exit(1)
    
    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Load results
    print(f"Loading results from {args.results_file}...")
    results = load_k6_results(args.results_file)
    
    if not results:
        print("Error: Could not load results")
        sys.exit(1)
    
    # Analyze results
    print("Analyzing results...")
    analysis = analyze_basic_metrics(results)
    metrics_over_time = analyze_data_points(results)
    
    # Generate base filename
    base_name = os.path.splitext(os.path.basename(args.results_file))[0]
    
    # Generate text report
    text_report_file = os.path.join(args.output_dir, f"{base_name}_analysis.txt")
    generate_text_report(analysis, text_report_file)
    
    # Generate charts
    if not args.no_charts and HAS_MATPLOTLIB:
        chart_file = os.path.join(args.output_dir, f"{base_name}_charts.pdf")
        generate_charts(analysis, metrics_over_time, chart_file)
    
    # Generate JSON summary
    summary_file = os.path.join(args.output_dir, f"{base_name}_summary.json")
    summary_data = {
        'analysis': analysis,
        'generated_at': datetime.now().isoformat(),
        'source_file': args.results_file
    }
    
    with open(summary_file, 'w') as f:
        json.dump(summary_data, f, indent=2)
    
    print(f"JSON summary saved to: {summary_file}")
    print("\nAnalysis complete!")

if __name__ == '__main__':
    main() 