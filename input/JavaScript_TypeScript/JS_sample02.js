class ChartConfig {
    constructor(type, data, options = {}) {
        this.type = type;
        this.data = data;
        this.options = {
            width: 800,
            height: 400,
            margin: { top: 20, right: 30, bottom: 40, left: 50 },
            colors: ['#3498db', '#e74c3c', '#2ecc71', '#f39c12', '#9b59b6'],
            ...options
        };
        this.id = this.generateId();
    }

    generateId() {
        return 'chart-' + Math.random().toString(36).substr(2, 9);
    }
}

class DataSet {
    constructor(name, data = []) {
        this.name = name;
        this.data = data;
        this.createdAt = new Date();
        this.lastUpdated = new Date();
    }

    addDataPoint(point) {
        this.data.push(point);
        this.lastUpdated = new Date();
        return this;
    }

    updateDataPoint(index, newPoint) {
        if (index >= 0 && index < this.data.length) {
            this.data[index] = newPoint;
            this.lastUpdated = new Date();
        }
        return this;
    }

    removeDataPoint(index) {
        if (index >= 0 && index < this.data.length) {
            this.data.splice(index, 1);
            this.lastUpdated = new Date();
        }
        return this;
    }

    getStats() {
        if (this.data.length === 0) return null;

        const values = this.data.map(d => typeof d === 'object' ? d.value || d.y || 0 : d);
        const sum = values.reduce((a, b) => a + b, 0);
        const avg = sum / values.length;
        const sorted = values.slice().sort((a, b) => a - b);
        const median = sorted.length % 2 === 0 ?
            (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2 :
            sorted[Math.floor(sorted.length / 2)];

        return {
            count: values.length,
            sum,
            average: avg,
            median,
            min: Math.min(...values),
            max: Math.max(...values),
            range: Math.max(...values) - Math.min(...values)
        };
    }
}

class SVGChartRenderer {
    constructor(container) {
        this.container = container;
        this.svg = null;
    }

    createSVG(width, height) {
        this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        this.svg.setAttribute('width', width);
        this.svg.setAttribute('height', height);
        this.svg.style.border = '1px solid #ddd';
        this.svg.style.backgroundColor = '#fafafa';
        this.container.appendChild(this.svg);
        return this.svg;
    }

    createElement(type, attributes = {}) {
        const element = document.createElementNS('http://www.w3.org/2000/svg', type);
        Object.entries(attributes).forEach(([key, value]) => {
            element.setAttribute(key, value);
        });
        return element;
    }

    renderLineChart(config) {
        const { data, options } = config;
        const { width, height, margin, colors } = options;

        this.createSVG(width, height);

        const chartWidth = width - margin.left - margin.right;
        const chartHeight = height - margin.top - margin.bottom;

        const chartGroup = this.createElement('g', {
            transform: `translate(${margin.left}, ${margin.top})`
        });
        this.svg.appendChild(chartGroup);

        const xMax = Math.max(...data.map(d => d.x));
        const yMax = Math.max(...data.map(d => d.y));
        const xScale = chartWidth / xMax;
        const yScale = chartHeight / yMax;

        this.drawAxes(chartGroup, chartWidth, chartHeight);

        const pathData = data.map((d, i) => {
            const x = d.x * xScale;
            const y = chartHeight - (d.y * yScale);
            return `${i === 0 ? 'M' : 'L'} ${x} ${y}`;
        }).join(' ');

        const path = this.createElement('path', {
            d: pathData,
            stroke: colors[0],
            'stroke-width': 2,
            fill: 'none'
        });
        chartGroup.appendChild(path);

        data.forEach(d => {
            const circle = this.createElement('circle', {
                cx: d.x * xScale,
                cy: chartHeight - (d.y * yScale),
                r: 4,
                fill: colors[0],
                stroke: 'white',
                'stroke-width': 2
            });

            circle.addEventListener('mouseenter', (e) => {
                this.showTooltip(e, `(${d.x}, ${d.y})`);
            });
            circle.addEventListener('mouseleave', () => {
                this.hideTooltip();
            });

            chartGroup.appendChild(circle);
        });
    }

    renderBarChart(config) {
        const { data, options } = config;
        const { width, height, margin, colors } = options;

        this.createSVG(width, height);

        const chartWidth = width - margin.left - margin.right;
        const chartHeight = height - margin.top - margin.bottom;

        const chartGroup = this.createElement('g', {
            transform: `translate(${margin.left}, ${margin.top})`
        });
        this.svg.appendChild(chartGroup);

        const maxValue = Math.max(...data.map(d => d.value));
        const barWidth = chartWidth / data.length * 0.8;
        const barSpacing = chartWidth / data.length * 0.2;

        this.drawAxes(chartGroup, chartWidth, chartHeight);

        data.forEach((d, i) => {
            const barHeight = (d.value / maxValue) * chartHeight;
            const x = i * (barWidth + barSpacing) + barSpacing / 2;
            const y = chartHeight - barHeight;

            const rect = this.createElement('rect', {
                x: x,
                y: y,
                width: barWidth,
                height: barHeight,
                fill: colors[i % colors.length],
                'fill-opacity': 0.8
            });

            rect.addEventListener('mouseenter', (e) => {
                rect.setAttribute('fill-opacity', 1);
                this.showTooltip(e, `${d.label}: ${d.value}`);
            });
            rect.addEventListener('mouseleave', () => {
                rect.setAttribute('fill-opacity', 0.8);
                this.hideTooltip();
            });

            chartGroup.appendChild(rect);

            const text = this.createElement('text', {
                x: x + barWidth / 2,
                y: chartHeight + 15,
                'text-anchor': 'middle',
                'font-size': '12px',
                fill: '#666'
            });
            text.textContent = d.label;
            chartGroup.appendChild(text);
        });
    }

    renderPieChart(config) {
        const { data, options } = config;
        const { width, height, colors } = options;

        this.createSVG(width, height);

        const radius = Math.min(width, height) / 2 - 50;
        const centerX = width / 2;
        const centerY = height / 2;

        const total = data.reduce((sum, d) => sum + d.value, 0);
        let currentAngle = 0;

        data.forEach((d, i) => {
            const sliceAngle = (d.value / total) * 2 * Math.PI;
            const endAngle = currentAngle + sliceAngle;

            const largeArcFlag = sliceAngle > Math.PI ? 1 : 0;
            const x1 = centerX + radius * Math.cos(currentAngle);
            const y1 = centerY + radius * Math.sin(currentAngle);
            const x2 = centerX + radius * Math.cos(endAngle);
            const y2 = centerY + radius * Math.sin(endAngle);

            const pathData = [
                `M ${centerX} ${centerY}`,
                `L ${x1} ${y1}`,
                `A ${radius} ${radius} 0 ${largeArcFlag} 1 ${x2} ${y2}`,
                'Z'
            ].join(' ');

            const path = this.createElement('path', {
                d: pathData,
                fill: colors[i % colors.length],
                stroke: 'white',
                'stroke-width': 2
            });

            path.addEventListener('mouseenter', (e) => {
                const percentage = ((d.value / total) * 100).toFixed(1);
                this.showTooltip(e, `${d.label}: ${d.value} (${percentage}%)`);
            });
            path.addEventListener('mouseleave', () => {
                this.hideTooltip();
            });

            this.svg.appendChild(path);

            currentAngle = endAngle;
        });

        this.addLegend(data, colors, width - 150, 20);
    }

    drawAxes(container, width, height) {
        const xAxis = this.createElement('line', {
            x1: 0, y1: height,
            x2: width, y2: height,
            stroke: '#333',
            'stroke-width': 1
        });
        container.appendChild(xAxis);

        const yAxis = this.createElement('line', {
            x1: 0, y1: 0,
            x2: 0, y2: height,
            stroke: '#333',
            'stroke-width': 1
        });
        container.appendChild(yAxis);
    }

    addLegend(data, colors, x, y) {
        data.forEach((d, i) => {
            const legendGroup = this.createElement('g', {
                transform: `translate(${x}, ${y + i * 20})`
            });

            const rect = this.createElement('rect', {
                x: 0, y: 0, width: 15, height: 15,
                fill: colors[i % colors.length]
            });

            const text = this.createElement('text', {
                x: 20, y: 12,
                'font-size': '12px',
                fill: '#333'
            });
            text.textContent = d.label;

            legendGroup.appendChild(rect);
            legendGroup.appendChild(text);
            this.svg.appendChild(legendGroup);
        });
    }

    showTooltip(event, text) {
        this.hideTooltip();

        const tooltip = document.createElement('div');
        tooltip.id = 'chart-tooltip';
        tooltip.style.cssText = `
            position: absolute;
            background: rgba(0,0,0,0.8);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 12px;
            pointer-events: none;
            z-index: 1000;
            left: ${event.pageX + 10}px;
            top: ${event.pageY - 30}px;
        `;
        tooltip.textContent = text;
        document.body.appendChild(tooltip);
    }

    hideTooltip() {
        const tooltip = document.getElementById('chart-tooltip');
        if (tooltip) {
            tooltip.remove();
        }
    }

    clear() {
        if (this.svg) {
            this.svg.remove();
            this.svg = null;
        }
    }
}

class DataVisualizationDashboard {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.datasets = new Map();
        this.charts = new Map();
        this.realTimeUpdates = new Map();
        this.filters = new Map();

        this.initializeDashboard();
        this.loadSampleData();
    }

    initializeDashboard() {
        this.container.innerHTML = `
            <div class="dashboard-header">
                <h1>Data Visualization Dashboard</h1>
                <div class="dashboard-controls">
                    <button id="addChart">Add Chart</button>
                    <button id="toggleRealTime">Toggle Real-time</button>
                    <button id="exportData">Export Data</button>
                    <select id="chartType">
                        <option value="line">Line Chart</option>
                        <option value="bar">Bar Chart</option>
                        <option value="pie">Pie Chart</option>
                    </select>
                </div>
            </div>
            <div class="dashboard-stats">
                <div class="stat-card">
                    <h3>Total Charts</h3>
                    <span id="totalCharts">0</span>
                </div>
                <div class="stat-card">
                    <h3>Data Points</h3>
                    <span id="totalDataPoints">0</span>
                </div>
                <div class="stat-card">
                    <h3>Real-time Updates</h3>
                    <span id="realTimeStatus">Stopped</span>
                </div>
            </div>
            <div class="charts-container" id="chartsContainer"></div>
        `;

        this.addStyles();
        this.bindEvents();
    }

    addStyles() {
        const style = document.createElement('style');
        style.textContent = `
            .dashboard-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 20px;
                background: #f8f9fa;
                border-bottom: 1px solid #dee2e6;
            }
            .dashboard-controls button, .dashboard-controls select {
                margin: 0 5px;
                padding: 8px 16px;
                border: 1px solid #ddd;
                border-radius: 4px;
                background: white;
                cursor: pointer;
            }
            .dashboard-stats {
                display: flex;
                padding: 20px;
                gap: 20px;
            }
            .stat-card {
                background: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                text-align: center;
                flex: 1;
            }
            .stat-card h3 {
                margin: 0 0 10px 0;
                color: #666;
                font-size: 14px;
            }
            .stat-card span {
                font-size: 24px;
                font-weight: bold;
                color: #333;
            }
            .charts-container {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
                gap: 20px;
                padding: 20px;
            }
            .chart-wrapper {
                background: white;
                border-radius: 8px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                padding: 20px;
                position: relative;
            }
            .chart-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
            }
            .chart-title {
                font-size: 16px;
                font-weight: bold;
                color: #333;
            }
            .chart-controls button {
                padding: 4px 8px;
                font-size: 12px;
                border: 1px solid #ddd;
                background: white;
                border-radius: 4px;
                cursor: pointer;
                margin-left: 5px;
            }
        `;
        document.head.appendChild(style);
    }

    bindEvents() {
        document.getElementById('addChart').addEventListener('click', () => {
            this.addChart();
        });

        document.getElementById('toggleRealTime').addEventListener('click', () => {
            this.toggleRealTimeUpdates();
        });

        document.getElementById('exportData').addEventListener('click', () => {
            this.exportData();
        });
    }

    loadSampleData() {
        const salesData = new DataSet('Monthly Sales', [
            { x: 1, y: 1200 }, { x: 2, y: 1900 }, { x: 3, y: 1500 },
            { x: 4, y: 2100 }, { x: 5, y: 1800 }, { x: 6, y: 2400 }
        ]);
        this.datasets.set('sales', salesData);

        const categoryData = new DataSet('Product Categories', [
            { label: 'Electronics', value: 45 },
            { label: 'Clothing', value: 30 },
            { label: 'Books', value: 15 },
            { label: 'Home & Garden', value: 10 }
        ]);
        this.datasets.set('categories', categoryData);

        const performanceData = new DataSet('Performance Metrics', [
            { label: 'Load Time', value: 2.3 },
            { label: 'Response Time', value: 1.8 },
            { label: 'Throughput', value: 95.2 },
            { label: 'Error Rate', value: 0.5 }
        ]);
        this.datasets.set('performance', performanceData);

        this.createChart('line', 'sales', 'Monthly Sales Trend');
        this.createChart('pie', 'categories', 'Product Distribution');
        this.createChart('bar', 'performance', 'System Performance');

        this.updateStats();
    }

    createChart(type, datasetKey, title) {
        const dataset = this.datasets.get(datasetKey);
        if (!dataset) return null;

        const config = new ChartConfig(type, dataset.data, {
            title: title
        });

        const chartWrapper = document.createElement('div');
        chartWrapper.className = 'chart-wrapper';
        chartWrapper.innerHTML = `
            <div class="chart-header">
                <div class="chart-title">${title}</div>
                <div class="chart-controls">
                    <button onclick="dashboard.refreshChart('${config.id}')">Refresh</button>
                    <button onclick="dashboard.removeChart('${config.id}')">Remove</button>
                </div>
            </div>
            <div id="${config.id}"></div>
        `;

        document.getElementById('chartsContainer').appendChild(chartWrapper);

        const renderer = new SVGChartRenderer(document.getElementById(config.id));

        switch (type) {
            case 'line':
                renderer.renderLineChart(config);
                break;
            case 'bar':
                renderer.renderBarChart(config);
                break;
            case 'pie':
                renderer.renderPieChart(config);
                break;
        }

        this.charts.set(config.id, {
            config,
            renderer,
            dataset: datasetKey,
            wrapper: chartWrapper
        });

        return config.id;
    }

    addChart() {
        const type = document.getElementById('chartType').value;
        const datasetKeys = Array.from(this.datasets.keys());
        const randomDataset = datasetKeys[Math.floor(Math.random() * datasetKeys.length)];
        const dataset = this.datasets.get(randomDataset);

        const title = `${type.charAt(0).toUpperCase() + type.slice(1)} Chart - ${dataset.name}`;
        this.createChart(type, randomDataset, title);
        this.updateStats();
    }

    removeChart(chartId) {
        const chart = this.charts.get(chartId);
        if (chart) {
            chart.renderer.clear();
            chart.wrapper.remove();
            this.charts.delete(chartId);
            this.updateStats();
        }
    }

    refreshChart(chartId) {
        const chart = this.charts.get(chartId);
        if (chart) {
            const dataset = this.datasets.get(chart.dataset);
            chart.config.data = dataset.data;
            chart.renderer.clear();

            const container = document.getElementById(chartId);
            chart.renderer.container = container;

            switch (chart.config.type) {
                case 'line':
                    chart.renderer.renderLineChart(chart.config);
                    break;
                case 'bar':
                    chart.renderer.renderBarChart(chart.config);
                    break;
                case 'pie':
                    chart.renderer.renderPieChart(chart.config);
                    break;
            }
        }
    }

    toggleRealTimeUpdates() {
        const isRunning = this.realTimeUpdates.size > 0;

        if (isRunning) {
            this.realTimeUpdates.forEach(interval => clearInterval(interval));
            this.realTimeUpdates.clear();
            document.getElementById('realTimeStatus').textContent = 'Stopped';
        } else {
            const salesUpdate = setInterval(() => {
                const salesData = this.datasets.get('sales');
                if (salesData.data.length > 0) {
                    const lastPoint = salesData.data[salesData.data.length - 1];
                    const newPoint = {
                        x: lastPoint.x + 1,
                        y: Math.max(100, lastPoint.y + (Math.random() - 0.5) * 500)
                    };
                    salesData.addDataPoint(newPoint);

                    if (salesData.data.length > 10) {
                        salesData.data.shift();
                        salesData.data.forEach((point, index) => {
                            point.x = index + 1;
                        });
                    }

                    this.refreshChartsForDataset('sales');
                }
            }, 2000);

            this.realTimeUpdates.set('sales', salesUpdate);
            document.getElementById('realTimeStatus').textContent = 'Running';
        }
    }

    refreshChartsForDataset(datasetKey) {
        this.charts.forEach((chart, chartId) => {
            if (chart.dataset === datasetKey) {
                this.refreshChart(chartId);
            }
        });
        this.updateStats();
    }

    exportData() {
        const exportData = {
            timestamp: new Date().toISOString(),
            datasets: {},
            charts: Array.from(this.charts.values()).map(chart => ({
                id: chart.config.id,
                type: chart.config.type,
                dataset: chart.dataset,
                title: chart.config.options.title
            }))
        };

        this.datasets.forEach((dataset, key) => {
            exportData.datasets[key] = {
                name: dataset.name,
                data: dataset.data,
                stats: dataset.getStats(),
                createdAt: dataset.createdAt,
                lastUpdated: dataset.lastUpdated
            };
        });

        const blob = new Blob([JSON.stringify(exportData, null, 2)], {
            type: 'application/json'
        });

        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `dashboard-export-${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }

    updateStats() {
        const totalCharts = this.charts.size;
        const totalDataPoints = Array.from(this.datasets.values())
            .reduce((sum, dataset) => sum + dataset.data.length, 0);

        document.getElementById('totalCharts').textContent = totalCharts;
        document.getElementById('totalDataPoints').textContent = totalDataPoints;
    }

    getDatasetStats() {
        const stats = {};
        this.datasets.forEach((dataset, key) => {
            stats[key] = dataset.getStats();
        });
        return stats;
    }
}

document.addEventListener('DOMContentLoaded', () => {
    if (!document.getElementById('dashboard')) {
        const container = document.createElement('div');
        container.id = 'dashboard';
        document.body.appendChild(container);
    }

    window.dashboard = new DataVisualizationDashboard('dashboard');

    console.log('📊 Data Visualization Dashboard initialized');
    console.log('Available datasets:', Array.from(window.dashboard.datasets.keys()));
});

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        DataVisualizationDashboard,
        DataSet,
        ChartConfig,
        SVGChartRenderer
    };
} 